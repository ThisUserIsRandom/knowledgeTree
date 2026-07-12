from abc import ABC, abstractmethod

from langchain_core.language_models import BaseChatModel


class ChatProvider(ABC):
    """A pluggable upstream LLM backend.

    Implement ``build_model`` to return a LangChain chat model configured for
    the target provider. New providers are registered via
    ``providers.factory.register_provider`` (or simply added to the
    ``_PROVIDERS`` map)."""

    @abstractmethod
    def build_model(
        self, model_name: str, temperature: float, api_key: str, timeout: float
    ) -> BaseChatModel:
        raise NotImplementedError
