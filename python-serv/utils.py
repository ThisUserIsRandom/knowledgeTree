import json
import time
import uuid
import asyncio
import threading
import queue as _queue
import traceback
import urllib.request
import urllib.error
from typing import Callable, AsyncIterator

import config
from langchain_core.messages import HumanMessage, AIMessage, SystemMessage, BaseMessage


def to_lc_messages(messages: list) -> list:
    """Convert OpenAI-style {role, content} dicts into LangChain messages."""
    lc: list = []
    for m in messages:
        role = (m.get("role") or "").lower()
        content = m.get("content") or ""
        if role == "system":
            lc.append(SystemMessage(content=content))
        elif role == "assistant":
            lc.append(AIMessage(content=content))
        else:
            lc.append(HumanMessage(content=content))
    return lc


def chunk_text(chunk) -> str:
    """Extract plain text from a LangChain message / message chunk."""
    content = getattr(chunk, "content", "")
    if isinstance(content, str):
        return content
    if isinstance(content, list):
        parts = []
        for item in content:
            if isinstance(item, dict) and item.get("type") == "text":
                parts.append(item.get("text", ""))
            elif isinstance(item, str):
                parts.append(item)
        return "".join(parts)
    return ""


def sse_error_chunk(chunk_id: str, created: int, err: str) -> dict:
    return {
        "id": chunk_id,
        "object": "chat.completion.chunk",
        "created": created,
        "model": config.CONFIG["default_model"],
        "choices": [
            {
                "index": 0,
                "delta": {"content": f"\n[upstream error] {err}"[:800]},
                "finish_reason": "stop",
            }
        ],
    }


def http_get(url: str, headers: dict = None) -> dict:
    req = urllib.request.Request(url, headers=headers or {})
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read().decode("utf-8"))


def stream_to_queue(async_gen_factory: Callable[[], AsyncIterator], error_tag: str = "__error__"):
    """Bridge an async generator to a synchronous one via a queue + thread.

    The async generator runs in its own event loop on a background thread;
    items (or an ``(error_tag, traceback)`` tuple on failure) are pushed onto
    a queue that the calling (Flask) thread reads."""
    msg_q: _queue.Queue = _queue.Queue()
    loop = asyncio.new_event_loop()

    async def produce():
        try:
            async for item in async_gen_factory():
                msg_q.put(item)
        except Exception:  # noqa: BLE001
            msg_q.put((error_tag, traceback.format_exc()))
        finally:
            msg_q.put(None)

    threading.Thread(target=lambda: loop.run_until_complete(produce()), daemon=True).start()

    try:
        while True:
            item = msg_q.get()
            if item is None:
                break
            yield item
    finally:
        loop.close()
