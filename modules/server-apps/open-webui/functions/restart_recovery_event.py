"""
title: Restart Recovery
author: joshan-kana
version: 1.3.0
description: Continues genuinely interrupted Open WebUI turns after a service restart without replaying the original prompt.
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


class Valves(BaseModel):
    max_attempts: int = Field(default=3, ge=1, le=10)
    startup_delay_seconds: int = Field(default=3, ge=0, le=60)


valves = Valves()
_startup_task: asyncio.Task | None = None


async def _set_marker(chat_id: str, marker: dict | None) -> None:
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


async def _pending_chats() -> list[tuple[str, str, dict]]:
    pending: list[tuple[str, str, dict]] = []
    async with get_async_db_context() as db:
        result = await db.execute(select(Chat))
        for chat in result.scalars().all():
            marker = dict((chat.meta or {}).get("restart_recovery") or {})
            if marker.get("state") in {"running", "recovering"}:
                pending.append((chat.id, chat.user_id, marker))
    return pending


def _request(app) -> Request:
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
        "server": ("127.0.0.1", 8081),
        "app": app,
    }
    request = Request(scope)
    request.state.internal = False
    return request


async def _recover_one(app, chat_id: str, owner_id: str, marker: dict) -> None:
    assistant_message_id = marker.get("assistant_message_id")
    model = marker.get("model")
    attempts = int(marker.get("attempts") or 0)

    if not assistant_message_id or not model:
        await _set_marker(chat_id, None)
        return

    previous = await Chats.get_message_by_id_and_message_id(chat_id, assistant_message_id)
    if previous and (previous.get("done") is True or previous.get("error")):
        await _set_marker(chat_id, None)
        return

    if attempts >= valves.max_attempts:
        await _set_marker(
            chat_id,
            {**marker, "state": "exhausted", "exhausted_at": int(time.time())},
        )
        if previous:
            await Chats.upsert_message_to_chat_by_id_and_message_id(
                chat_id,
                assistant_message_id,
                {
                    "done": True,
                    "error": {
                        "content": ("Automatic restart recovery reached its retry limit. Inspect current state before continuing manually.")
                    },
                },
            )
        return

    user = await Users.get_user_by_id(owner_id)
    if user is None:
        await _set_marker(chat_id, None)
        return

    if previous:
        await Chats.upsert_message_to_chat_by_id_and_message_id(
            chat_id,
            assistant_message_id,
            {
                "done": True,
                "error": {"content": "Execution was interrupted by a service restart; automatic recovery continues below."},
            },
        )

    recovery_attempt = attempts + 1
    recovering = {
        **marker,
        "state": "recovering",
        "attempts": recovery_attempt,
        "last_attempt_at": int(time.time()),
    }
    await _set_marker(chat_id, recovering)

    recovery_assistant_id = str(uuid4())
    recovery_user = {
        "id": str(uuid4()),
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

    handler = getattr(app.state, "CHAT_COMPLETION_HANDLER", None)
    if handler is None:
        recovering["state"] = "running"
        await _set_marker(chat_id, recovering)
        return

    await handler(
        _request(app),
        {
            "model": model,
            "messages": [{"role": "user", "content": RECOVERY_PROMPT}],
            "chat_id": chat_id,
            "parent_id": assistant_message_id,
            "id": recovery_assistant_id,
            "user_message": recovery_user,
            "stream": False,
            "params": {},
            "features": {},
        },
        user,
    )


async def _recover(app) -> None:
    if valves.startup_delay_seconds:
        await asyncio.sleep(valves.startup_delay_seconds)

    for chat_id, owner_id, marker in await _pending_chats():
        try:
            await _recover_one(app, chat_id, owner_id, marker)
        except Exception:
            await _set_marker(
                chat_id,
                {
                    **marker,
                    "state": "running",
                    "attempts": int(marker.get("attempts") or 0) + 1,
                    "last_attempt_at": int(time.time()),
                },
            )


def _subject_chat_id(event_payload: dict) -> str | None:
    subject = event_payload.get("subject") or {}
    subject_id = subject.get("id") if isinstance(subject, dict) else None
    return subject_id if isinstance(subject_id, str) and subject_id else None


async def event(
    event: dict,
    __event_name__: str | None = None,
    __app__=None,
    **kwargs,
):
    global _startup_task

    if __event_name__ in {"chat.finished", "chat.failed"}:
        chat_id = _subject_chat_id(event)
        if chat_id:
            await _set_marker(chat_id, None)
        return

    if __event_name__ != "system.startup.completed" or __app__ is None:
        return
    if _startup_task and not _startup_task.done():
        return

    _startup_task = asyncio.create_task(_recover(__app__))
