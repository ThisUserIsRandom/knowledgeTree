import config
from typing import AsyncIterator, List, Optional

from langgraph.graph import StateGraph, END
from langgraph.graph.message import add_messages
from langchain_core.messages import BaseMessage

from providers import get_provider
from utils import chunk_text

try:
    from typing import TypedDict, Annotated
except ImportError:  # pragma: no cover
    from typing_extensions import TypedDict, Annotated  # type: ignore


class ChatState(TypedDict):
    messages: Annotated[list, add_messages]


def build_chat_graph(model) -> "CompiledGraph":
    """Wrap a chat model in a minimal LangGraph: a single node that invokes
    the model. Streaming flows through the graph's event stream."""

    def call_model(state: ChatState) -> ChatState:
        return {"messages": [model.invoke(state["messages"])]}

    builder = StateGraph(ChatState)
    builder.add_node("call_model", call_model)
    builder.set_entry_point("call_model")
    builder.add_edge("call_model", END)
    return builder.compile()


async def stream_graph_tokens(model, lc_messages: List[BaseMessage]) -> AsyncIterator[str]:
    """Stream tokens straight from the chat model.

    LangGraph 1.x removed the old ``astream_events(version="v2")`` API that the
    previous implementation relied on, so we stream directly from the model's
    native async ``astream`` instead.
    """
    async for chunk in model.astream(lc_messages):
        text = chunk_text(chunk)
        if text:
            yield text


def _attempts(model_name: str) -> List[str]:
    """Model names to try, transparently appending ``:free`` for paid models."""
    return (
        [model_name, f"{model_name}:free"]
        if not model_name.endswith(":free")
        else [model_name]
    )


async def stream_chat(
    lc_messages: List[BaseMessage],
    model_name: str,
    temperature: float,
    api_key: Optional[str] = None,
    timeout: Optional[float] = None,
) -> AsyncIterator[str]:
    """Stream tokens for ``model_name``, retrying once with a ``:free`` suffix
    on a missing/unaffordable model (e.g. ``tencent/hy3`` -> ``tencent/hy3:free``)."""
    timeout = timeout if timeout is not None else config.CONFIG["timeout"]
    provider = get_provider()
    attempts = _attempts(model_name)
    last_exc: Optional[BaseException] = None
    for attempt in attempts:
        try:
            model = provider.build_model(attempt, temperature, api_key, timeout)
            async for tok in stream_graph_tokens(model, lc_messages):
                yield tok
            return
        except Exception as e:  # noqa: BLE001
            last_exc = e
            continue
    raise last_exc or RuntimeError("Model request failed")


def invoke_chat(
    lc_messages: List[BaseMessage],
    model_name: str,
    temperature: float,
    api_key: Optional[str] = None,
    timeout: Optional[float] = None,
):
    """Non-streaming variant of :func:`stream_chat` (synchronous)."""
    timeout = timeout if timeout is not None else config.CONFIG["timeout"]
    provider = get_provider()
    attempts = _attempts(model_name)
    last_exc: Optional[BaseException] = None
    for attempt in attempts:
        try:
            model = provider.build_model(attempt, temperature, api_key, timeout)
            graph = build_chat_graph(model)
            result = graph.invoke({"messages": lc_messages})
            return result["messages"][-1].content
        except Exception as e:  # noqa: BLE001
            last_exc = e
            continue
    raise last_exc or RuntimeError("Model request failed")
