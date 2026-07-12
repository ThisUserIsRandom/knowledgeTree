from .base import ChatProvider
from .openai_compatible import OpenAICompatibleProvider, OpenRouterProvider
from .ollama import OllamaProvider

# api_type -> provider class. Add new providers here (or via register_provider).
_PROVIDERS = {
    "openrouter": OpenRouterProvider,
    "openai": OpenAICompatibleProvider,
    "openai_compatible": OpenAICompatibleProvider,
    "ollama": OllamaProvider,
}

_DEFAULT = OpenAICompatibleProvider


def get_provider(api_type: str = None) -> ChatProvider:
    """Return a provider instance for ``api_type`` (defaults to the live
    configured api_type)."""
    if api_type is None:
        import config

        api_type = config.CONFIG["api_type"]
    cls = _PROVIDERS.get(api_type, _DEFAULT)
    return cls()


def register_provider(api_type: str, provider_cls) -> None:
    """Register (or override) a provider for an api_type key."""
    _PROVIDERS[api_type] = provider_cls
