"""
title: Restart Recovery
author: joshan-kana
version: 1.0.0
description: Continues genuinely interrupted Open WebUI turns after a service restart without blindly replaying the original prompt.
"""

from __future__ import annotations

import asyncio
import time
from uuid import uuid4

from open_webui.internal.db import get_async_db_context
from open_webui.models.chats import Chat, Chats
from open_webui.models.users import Users
from pydantic import BaseModel, Field
from sqlalchemy import select
from starlette.requests import Request


RECOVERY_PROMPT = """Previous execution was interrupted by an Open WebUI or worker service restart.

Inspect the conversation, tool history, files, Git state, and current machine/system state before taking any action. Determine what already completed successfully. Continue only the unfinished work from the original request. Do not repeat completed side effects, and do not wait for the user merely because the previous execution was interrupted.
"""


class Event:
    class Valves(BaseModel):
        max_attempts: int = Field(default=3, ge=1, le=10)
        startup_delay_seconds: int = Field(default=3, ge=0, le=60)

    def __init__(self):
        self.valves = self.Valves()
        self._startup_task: asyncio.Task | None = None

    async def _set_marker(self, chat_id: str, marker: dict | None) -> None:
        async with get_async_db_context() as db:
            chat = await db.get(Chat, chat_id)
            if chat is None:
                return
            meta = dict(chat.meta or {})
            if marker is None:
                meta.pop("restart_recovery", None)
            else:
                meta["restart_recovery"] = marker
            chat.meta = meta
            await db.commit()

    async def _pending_chats(self) -> list[tuple[str, str, dict]]:
        pending: list[tuple[str, str, dict]] = []
        async with get_async_db_context() as db:
            result = await db.execute(select(Chat))
            for chat in result.scalars().all():
                marker = dict((chat.meta or {}).get("restart_recovery") or {})
                if marker.get("state") in {"running", "recovering"}:
                    pending.append((chat.id, chat.user_id, marker))
        return pending

    def _request(self, app) -> Request:
        scope = {
            "type": "http",
            "http_version": "1.1",
            "method": "POST",
            "scheme": "http",
            "path": "/api/chat/completions",
            "raw_path": b"/api/chat/completions",
            "query_string": b"",
            "headers": [(b"user-agent", b"open-webui-restart-recovery")],
            "client": ("127.0.0.1", 0),
            "server": ("127.0.0.1", 8080),
            "app": app,
        }
        request = Request(scope)
        request.state.internal = False
        return request

    async def _recover_one(self, app, chat_id: str, owner_id: str, marker: dict) -> None:
        assistant_message_id = marker.get("assistant_message_id")
        model = marker.get("model")
        attempts = int(marker.get("attempts") or 0)

        if not assistant_message_id or not model:
            await self._set_marker(chat_id, None)
            return

        previous = await Chats.get_message_by_id_and_message_id(chat_id, assistant_message_id)
        if previous and (previous.get("done") is True or previous.get("error")):
            # A normal completion/failure reached durable chat state but the
            # filter outlet did not get a chance to clean its marker.
            await self._set_marker(chat_id, None)
            return

        if attempts >= self.valves.max_attempts:
            exhausted = {
                **marker,
                "state": "exhausted",
                "exhausted_at": int(time.time()),
            }
            await self._set_marker(chat_id, exhausted)
            if previous:
                await Chats.upsert_message_to_chat_by_id_and_message_id(
                    chat_id,
                    assistant_message_id,
                    {
                        "done": True,
                        "error": {
                            "content": (
                                "Automatic restart recovery reached its retry limit. "
                                "Inspect current state before continuing manually."
                            )
                        },
                    },
                )
            return

        user = await Users.get_user_by_id(owner_id)
        if user is None:
            await self._set_marker(chat_id, None)
            return

        # Mark the interrupted placeholder as terminal so the UI does not keep
        # showing an endless spinner. Recovery continues as the next internal
        # turn in the same chat and, for Computer, therefore the same native
        # backend session/thread.
        if previous:
            await Chats.upsert_message_to_chat_by_id_and_message_id(
                chat_id,
                assistant_message_id,
                {
                    "done": True,
                    "error": {
                        "content": "Execution was interrupted by a service restart; automatic recovery continues below."
                    },
                },
            )

        recovery_attempt = attempts + 1
        recovering = {
            **marker,
            "state": "recovering",
            "attempts": recovery_attempt,
            "last_attempt_at": int(time.time()),
        }
        await self._set_marker(chat_id, recovering)

        recovery_user_id = str(uuid4())
        recovery_assistant_id = str(uuid4())
        recovery_user = {
            "id": recovery_user_id,
            "parentId": assistant_message_id,
            "childrenIds": [recovery_assistant_id],
            "role": "user",
            "content": RECOVERY_PROMPT,
            "models": [model],
            "timestamp": int(time.time()),
            "meta": {
                "internal": True,
                "restart_recovery": True,
                "restart_recovery_attempt": recovery_attempt,
            },
        }

        form_data = {
            "model": model,
            "messages": [{"role": "user", "content": RECOVERY_PROMPT}],
            "chat_id": chat_id,
            "parent_id": assistant_message_id,
            "id": recovery_assistant_id,
            "user_message": recovery_user,
            "stream": False,
            "params": {},
            "features": {},
        }

        request = self._request(app)
        handler = getattr(app.state, "CHAT_COMPLETION_HANDLER", None)
        if handler is None:
            recovering["state"] = "running"
            await self._set_marker(chat_id, recovering)
            return

        await handler(request, form_data, user)

    async def _recover(self, app) -> None:
        if self.valves.startup_delay_seconds:
            await asyncio.sleep(self.valves.startup_delay_seconds)
        for chat_id, owner_id, marker in await self._pending_chats():
            try:
                await self._recover_one(app, chat_id, owner_id, marker)
            except Exception:
                # Keep the durable marker for the next bounded recovery attempt.
                marker = {
                    **marker,
                    "state": "running",
                    "attempts": int(marker.get("attempts") or 0) + 1,
                    "last_attempt_at": int(time.time()),
                }
                await self._set_marker(chat_id, marker)

    async def event(
        self,
        event: dict,
        __event_name__: str | None = None,
        __app__=None,
        **kwargs,
    ):
        if __event_name__ != "system.startup.completed" or __app__ is None:
            return
        if self._startup_task and not self._startup_task.done():
            return
        self._startup_task = asyncio.create_task(self._recover(__app__))
