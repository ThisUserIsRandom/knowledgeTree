import json
import logging
import os
import traceback
import uuid

from flask import Blueprint, Response, jsonify, request, stream_with_context

import config
from rag import index as rag_index
from rag.pipeline import run_rag_pipeline
from rag.paths import UPLOAD_DIR, WEB_DIR, ensure_dirs

bp = Blueprint("rag", __name__)
logger = logging.getLogger("kt-server")


def _auth_key():
    auth = request.headers.get("authorization")
    if auth and auth.lower().startswith("bearer "):
        return auth[7:].strip()
    return None


@bp.route("/v1/rag/search", methods=["POST"])
def rag_search():
    """Run the RAG pipeline and stream stage events + final answer as SSE.

    Body: ``{"query": "...", "mode": "web"|"local", "max_loops": 3, "model": "..."}``
    """
    body = request.get_json(force=True, silent=True) or {}
    query = (body.get("query") or "").strip()
    mode = body.get("mode", "web")
    max_loops = max(1, min(int(body.get("max_loops", 3)), 6))
    model = body.get("model") or ""
    api_key = _auth_key() or config.CONFIG["api_key"]

    if not query:
        return jsonify({"error": "query is required"}), 400

    logger.info(f"RAG | mode={mode} | query={query[:80]} | max_loops={max_loops}")

    def generate():
        try:
            for ev in run_rag_pipeline(
                query, mode=mode, max_loops=max_loops, model=model, api_key=api_key
            ):
                yield f"data: {json.dumps(ev)}\n\n"
        except Exception:  # noqa: BLE001
            logger.error(traceback.format_exc())
            yield f"data: {json.dumps({'event': 'error', 'message': 'Pipeline failed'})}\n\n"
        yield "data: [DONE]\n\n"

    return Response(stream_with_context(generate()), mimetype="text/event-stream")


@bp.route("/v1/rag/upload", methods=["POST"])
def rag_upload():
    """Store uploaded files (multipart ``files[]``) for the local index."""
    ensure_dirs()
    files = request.files.getlist("files")
    if not files:
        return jsonify({"error": "No files uploaded"}), 400

    saved = []
    for f in files:
        if not f or not f.filename:
            continue
        name = "".join(c for c in os.path.basename(f.filename) if c.isalnum() or c in "._-").strip()
        if not name:
            name = f"file_{uuid.uuid4().hex[:8]}"
        f.save(os.path.join(UPLOAD_DIR, name))
        saved.append(name)

    chunks = rag_index.count_chunks([UPLOAD_DIR])
    logger.info(f"RAG upload | files={saved} | chunks={chunks}")
    return jsonify({"status": "ok", "uploaded": saved, "files": len(saved), "chunks": chunks})


@bp.route("/v1/rag/index", methods=["GET"])
def rag_index_status():
    ensure_dirs()
    uploaded = [
        f
        for f in os.listdir(UPLOAD_DIR)
        if os.path.isfile(os.path.join(UPLOAD_DIR, f))
    ]
    web = [f for f in os.listdir(WEB_DIR) if os.path.isfile(os.path.join(WEB_DIR, f))]
    chunks = rag_index.count_chunks([UPLOAD_DIR, WEB_DIR])
    return jsonify(
        {
            "status": "ok",
            "uploaded_files": len(uploaded),
            "web_files": len(web),
            "chunks": chunks,
        }
    )


@bp.route("/v1/rag/index", methods=["DELETE"])
def rag_index_clear():
    """Remove all crawled + uploaded files (resets the local knowledge base)."""
    cleared = 0
    for d in (UPLOAD_DIR, WEB_DIR):
        for name in os.listdir(d):
            path = os.path.join(d, name)
            if os.path.isfile(path):
                os.remove(path)
                cleared += 1
    return jsonify({"status": "ok", "cleared": cleared})
