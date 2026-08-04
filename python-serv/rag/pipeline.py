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
from langchain_core.messages import AIMessage, HumanMessage, SystemMessage
from graph.chat_graph import invoke_chat

from . import index as rag_index
from . import web as rag_web
from .paths import UPLOAD_DIR, WEB_DIR, ensure_dirs

logger = logging.getLogger("kt-server")

# Returned by _generate when the LLM call itself fails (auth / network / model
# missing). Unlike "INSUFFICIENT_CONTEXT:" this is fatal: there is no point
# re-searching or re-crawling when the model can't answer at all.
LLM_ERROR_PREFIX = "LLM_ERROR:"

SYSTEM_PROMPT = (
    "You are a strict evaluation and research assistant. "
    "Answer the user's question using ONLY the provided context. "
    'If the context completely lacks the required information or only '
    'contains irrelevant/outdated dates/years, start your response with the '
    'exact phrase: "INSUFFICIENT_CONTEXT:" followed by an explanation of what '
    "is missing. Otherwise, provide a clear, concise answer."
)

# Minimum semantic relevance (hybrid score in [0,1]) before a retrieved parent
# is treated as actually about the query. Below this we keep searching instead
# of forcing the LLM to answer from unrelated text.
MIN_RELEVANCE = 0.06

# Ceiling on the amount of context handed to the LLM so large crawls never
# blow a small model's window.
MAX_CONTEXT_CHARS = 6000


def _query_variants(query: str) -> list:
    """Candidate search queries, progressively broadened per retry attempt."""
    query = query.strip()
    variants = [query]
    variants.append(f"{query} latest update")
    variants.append(f"{query} overview")
    variants.append(f"{query} news report")
    return variants


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
        # Distinct marker for a hard LLM failure (auth, network, model missing).
        # The pipeline treats this as fatal — it must NOT look like an
        # "INSUFFICIENT_CONTEXT" retry, or the client waits through max_loops
        # full re-crawls for no reason.
        return LLM_ERROR_PREFIX + "Failed to generate an answer from the model."


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
    variants = _query_variants(query)
    final_response = "No answer generated."
    final_sources: list = []
    first_attempt = True

    while attempt < max_loops:
        attempt += 1
        # Later attempts use a progressively broader search so a dead-end first
        # result doesn't make the whole search give up.
        search_query = variants[min(attempt - 1, len(variants) - 1)]

        if mode == "web":
            yield {
                "event": "stage",
                "stage": "searching",
                "message": f"Searching the web for: {search_query}",
                "attempt": attempt,
            }
            urls = rag_web.fetch_duckduckgo_urls(search_query, target_count=10)
            final_sources = urls
            yield {
                "event": "stage",
                "stage": "crawling",
                "message": f"Found {len(urls)} page(s) — crawling & saving",
                "attempt": attempt,
            }
            saved = 0
            try:
                # Clear the web dir only on the first attempt so a retry keeps
                # the previously crawled pages and adds to them (no re-crawl).
                saved = asyncio.run(
                    rag_web.crawl_and_save_urls(urls, WEB_DIR, clear_dir=first_attempt)
                )
            except Exception:  # pragma: no cover - one bad crawl must not abort the run
                logger.exception("Web crawl failed")
            first_attempt = False
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
        parents, sources, relevance = rag_index.retrieve(query, dirs, top_n=2)
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
                "message": (
                    f"Retrieved {len(parents)} chunk(s) · hybrid relevance "
                    f"{relevance:.2f}"
                ),
                "attempt": attempt,
            }
            context = "\n\n---\n\n".join(parents)[:MAX_CONTEXT_CHARS]

        yield {
            "event": "stage",
            "stage": "generating",
            "message": "Generating answer",
            "attempt": attempt,
        }
        response = _generate(query, context, upstream_model, api_key).strip()

        # A hard LLM failure (auth/network/model missing) is fatal — don't
        # waste time on more searches/crawls the model still can't answer.
        if response.startswith(LLM_ERROR_PREFIX):
            final_response = response.replace(LLM_ERROR_PREFIX, "").strip()
            yield {"event": "error", "message": final_response}
            break

        insufficient = (
            not context
            or relevance < MIN_RELEVANCE
            or "INSUFFICIENT_CONTEXT:" in response
            or len(response) < 30
        )
        if insufficient:
            final_response = response.replace("INSUFFICIENT_CONTEXT:", "").strip()
            if attempt < max_loops:
                nxt = variants[min(attempt, len(variants) - 1)]
                yield {
                    "event": "retry",
                    "attempt": attempt,
                    "message": f"Context not useful — retrying with: {nxt}",
                }
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
