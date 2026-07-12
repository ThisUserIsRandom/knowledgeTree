import json
import time
import uuid
import traceback
import logging

from flask import Blueprint, request, Response, jsonify, stream_with_context

import config
import utils
from graph.chat_graph import stream_chat, invoke_chat

bp = Blueprint("chat", __name__)
logger = logging.getLogger("kt-server")


@bp.route("/v1/chat/completions", methods=["POST"])
def chat_completions():
    body = request.get_json(force=True, silent=True) or {}
    msgs = body.get("messages", [])
    model = body.get("model", "") or config.CONFIG["default_model"]
    temperature = float(body.get("temperature", 0.7))
    stream = bool(body.get("stream", True))

    # Honor a per-request Authorization header (the client's provider key)
    # so the upstream can be authenticated without a server-side api_key.
    upstream_key = None
    auth = request.headers.get("authorization")
    if auth and auth.lower().startswith("bearer "):
        upstream_key = auth[7:].strip()
    api_key = upstream_key or config.CONFIG["api_key"]

    lc_messages = utils.to_lc_messages(msgs)
    upstream_model = config._resolve_model(model)
    logger.info(
        f"CHAT | api_type={config.CONFIG['api_type']} | "
        f"model={model} -> {upstream_model} | stream={stream}"
    )

    if not stream:
        try:
            content = invoke_chat(lc_messages, upstream_model, temperature, api_key)
            content = content if isinstance(content, str) else utils.chunk_text(content)
            return jsonify(
                {
                    "id": f"chatcmpl-{uuid.uuid4().hex[:12]}",
                    "object": "chat.completion",
                    "created": int(time.time()),
                    "model": model,
                    "choices": [
                        {
                            "index": 0,
                            "message": {"role": "assistant", "content": content},
                            "finish_reason": "stop",
                        }
                    ],
                    "usage": {
                        "prompt_tokens": len(" ".join(m["content"] for m in msgs)) // 4,
                        "completion_tokens": len(content) // 4,
                        "total_tokens": (len(content) + len(" ".join(m["content"] for m in msgs))) // 4,
                    },
                }
            )
        except Exception as e:  # noqa: BLE001
            logger.error(traceback.format_exc())
            return jsonify({"error": f"Upstream error: {e}"[:800]}), 502

    def generate():
        chunk_id = f"chatcmpl-{uuid.uuid4().hex[:12]}"
        created = int(time.time())
        try:
            for item in utils.stream_to_queue(
                lambda: stream_chat(lc_messages, upstream_model, temperature, api_key)
            ):
                if isinstance(item, tuple) and item[0] == "__error__":
                    yield f"data: {json.dumps(utils.sse_error_chunk(chunk_id, created, item[1]))}\n\n"
                else:
                    delta = {
                        "id": chunk_id,
                        "object": "chat.completion.chunk",
                        "created": created,
                        "model": model,
                        "choices": [
                            {"index": 0, "delta": {"content": item}, "finish_reason": None}
                        ],
                    }
                    yield f"data: {json.dumps(delta)}\n\n"
        finally:
            pass

        final = {
            "id": chunk_id,
            "object": "chat.completion.chunk",
            "created": created,
            "model": model,
            "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
        }
        yield f"data: {json.dumps(final)}\n\n"
        yield "data: [DONE]\n\n"

    return Response(stream_with_context(generate()), mimetype="text/event-stream")
