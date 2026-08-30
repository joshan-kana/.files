"""
title: Restart Recovery Marker
author: joshan-kana
version: 1.2.0
description: Durably marks active Open WebUI turns so genuinely interrupted work can be recovered after a restart.
"""

from __future__ import annotations

import time
import uuid

from open_webui.internal.db import get_async_db_context
from open_webui.models.chats import Chat
from pydantic import BaseModel, Field


class Filter:
    class Valves(BaseModel):
        priority: int = Field(default=-1000, description="Run before normal request filters.")

    def __init__(self):
        self.valves = self.Valves()

    async def _write_marker(self, chat_id: str, marker: dict | None) -> None:
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

    async def inlet(
        self,
        body: dict,
        __metadata__: dict | None = None,
        __user__: dict | None = None,
    ) -> dict:
        metadata = __metadata__ or {}
        chat_id = metadata.get("chat_id")
        assistant_message_id = metadata.get("message_id")
        user_message_id = metadata.get("user_message_id")

        if (
            not chat_id
            or not assistant_message_id
            or chat_id.startswith(("temporary:", "channel:"))
            or metadata.get("internal") is True
            or metadata.get("task")
        ):
            return body

        attempts = 0
        user_message = metadata.get("user_message") or {}
        if (user_message.get("meta") or {}).get("restart_recovery"):
            async with get_async_db_context() as db:
                chat = await db.get(Chat, chat_id)
                existing = dict((chat.meta or {}).get("restart_recovery") or {}) if chat else {}
                attempts = int(existing.get("attempts") or 0)

        dispatch_id = str(uuid.uuid4())
        await self._write_marker(
            chat_id,
            {
                "state": "running",
                "dispatch_id": dispatch_id,
                "model": body.get("model"),
                "assistant_message_id": assistant_message_id,
                "user_message_id": user_message_id,
                "user_id": metadata.get("user_id") or (__user__ or {}).get("id"),
                "attempts": attempts,
                "started_at": int(time.time()),
            },
        )
        metadata["_restart_recovery_dispatch_id"] = dispatch_id
        return body

    async def outlet(self, body: dict, __metadata__: dict | None = None) -> dict:
        metadata = __metadata__ or {}
        chat_id = metadata.get("chat_id")
        dispatch_id = metadata.get("_restart_recovery_dispatch_id")
        if not chat_id or not dispatch_id:
            return body

        async with get_async_db_context() as db:
            chat = await db.get(Chat, chat_id)
            if chat is None:
                return body
            meta = dict(chat.meta or {})
            marker = dict(meta.get("restart_recovery") or {})
            if marker.get("dispatch_id") == dispatch_id:
                meta.pop("restart_recovery", None)
                chat.meta = meta
                await db.commit()

        return body
