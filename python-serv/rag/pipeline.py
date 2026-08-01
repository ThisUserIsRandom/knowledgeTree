"""RAG pipeline for the gateway (port of the LangGraph ``execute.py`` flow).

The standalone pipeline's LangGraph DAG (search -> crawl -> index -> retrieve
-> generate -> loop-if-insufficient -> export) is reimplemented as a generator
that yields SSE-style event dicts so the Flutter client can animate each stage.

LLM generation reuses the gateway's own provider stack
(``graph.chat_graph.invoke_chat``) instead of a second llama-index client, so
the RAG answers use the exact model/provider configured in the Connector.
"""

import asyncio
import logging
import traceback

import config
import utils
from langchain_core.messages import SystemMessage, HumanMessage
from graph.chat_graph import invoke_chat

from . import index as rag_index
from . import web as rag_web
from .paths import UPLOAD_DIR, WEB_DIR, ensure_dirs

logger = logging.getLogger("kt-server")

SYSTEM_PROMPT = (
    "You are a strict evaluation and research assistant. "
    "Answer the user's question using ONLY the provided context. "
    'If the context completely lacks the required information or only '
    'contains irrelevant/outdated dates/years, start your response with the '
    'exact phrase: "INSUFFICIENT_CONTEXT:" followed by an explanation of what '
    "is missing. Otherwise, provide a clear, concise answer."
)


def _generate(query: str, context: str, model: str, api_key) -> str:
    messages = [
        SystemMessage(content=SYSTEM_PROMPT),
        HumanMessage(content=f"User Question: {query}\nContext: {context}\nAnswer:"),
    ]
    try:
        result = invoke_chat(messages, model, 0.7, api_key)
        return result if isinstance(result, str) else utils.chunk_text(result)
    except Exception:  # noqa: BLE001
        logger.error(traceback.format_exc())
        return "INSUFFICIENT_CONTEXT: Error generating answer from LLM."


def run_rag_pipeline(
    query: str,
    *,
    mode: str = "web",
    max_loops: int = 3,
    model: str = "",
    api_key=None,
):
    """Run the retrieval pipeline, yielding event dicts:

    ``{"event": "stage", "stage": ..., "message": ..., "attempt": n}``
    ``{"event": "retry", "attempt": n, "message": ...}``
    ``{"event": "done", "response": ..., "attempts": n, "mode": ..., "sources": [...]}``
    ``{"event": "error", "message": ...}``
    """
    ensure_dirs()
    query = (query or "").strip()
    if not query:
        yield {"event": "error", "message": "Query is empty."}
        return

    dirs = [UPLOAD_DIR, WEB_DIR] if mode == "web" else [UPLOAD_DIR]
    upstream_model = model.strip() or config.CONFIG["default_model"]
    attempt = 0
    search_query = query
    final_response = "No answer generated."
    final_sources: list = []

    while attempt < max_loops:
        attempt += 1

        if mode == "web":
            yield {
                "event": "stage",
                "stage": "searching",
                "message": f"Searching the web for: {search_query}",
                "attempt": attempt,
            }
            urls = rag_web.fetch_duckduckgo_urls(search_query, target_count=4)
            final_sources = urls
            yield {
                "event": "stage",
                "stage": "crawling",
                "message": f"Found {len(urls)} page(s) — crawling & saving",
                "attempt": attempt,
            }
            saved = asyncio.run(rag_web.crawl_and_save_urls(urls, WEB_DIR))
            yield {
                "event": "stage",
                "stage": "crawling",
                "message": f"Saved {saved} page(s)",
                "attempt": attempt,
            }
        else:
            yield {
                "event": "stage",
                "stage": "indexing",
                "message": "Searching uploaded documents",
                "attempt": attempt,
            }

        yield {
            "event": "stage",
            "stage": "indexing",
            "message": "Building hierarchical index",
            "attempt": attempt,
        }
        parents, sources = rag_index.retrieve(query, dirs, top_n=2)
        if not parents:
            yield {
                "event": "stage",
                "stage": "retrieving",
                "message": "No relevant context found",
                "attempt": attempt,
            }
            context = ""
        else:
            yield {
                "event": "stage",
                "stage": "retrieving",
                "message": f"Retrieved {len(parents)} parent chunk(s) with BM25",
                "attempt": attempt,
            }
            context = "\n\n---\n\n".join(parents)

        yield {
            "event": "stage",
            "stage": "generating",
            "message": "Generating answer",
            "attempt": attempt,
        }
        response = _generate(query, context, upstream_model, api_key).strip()

        if not context or "INSUFFICIENT_CONTEXT:" in response or len(response) < 30:
            final_response = response.replace("INSUFFICIENT_CONTEXT:", "").strip()
            if attempt < max_loops:
                yield {
                    "event": "retry",
                    "attempt": attempt,
                    "message": "Context unsatisfactory — retrying with a broader query",
                }
                search_query = f"{query} latest update news reports"
                continue
        else:
            final_response = response
            break

    yield {
        "event": "done",
        "response": final_response,
        "attempts": attempt,
        "mode": mode,
        "sources": final_sources if mode == "web" else [],
    }
