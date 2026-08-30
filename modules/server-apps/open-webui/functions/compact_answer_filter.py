"""Open WebUI toggle filter for compact answers.

Managed by joshan-kana/.files. The module-level ``toggle`` flag makes this a
per-chat opt-in filter even though the function is globally available.
"""

from __future__ import annotations

toggle = True

_COMPACT_INSTRUCTION = """[COMPACT ANSWER MODE]
Keep the answer concise and information-dense. Lead with the result or next
action, preserve exact commands/identifiers that matter, avoid repeating context
already established in the conversation, and omit optional background unless it
changes the decision. Do not sacrifice correctness, required warnings, or
validation evidence merely to be shorter."""


class Filter:
    async def inlet(self, body: dict) -> dict:
        messages = body.get("messages")
        if not isinstance(messages, list):
            return body

        system_message = next(
            (message for message in messages if isinstance(message, dict) and message.get("role") == "system"),
            None,
        )
        if system_message is not None and isinstance(system_message.get("content"), str):
            if _COMPACT_INSTRUCTION not in system_message["content"]:
                system_message["content"] = f"{system_message['content'].rstrip()}\n\n{_COMPACT_INSTRUCTION}"
        else:
            messages.insert(0, {"role": "system", "content": _COMPACT_INSTRUCTION})

        return body
