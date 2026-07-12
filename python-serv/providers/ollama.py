import config

from langchain_openai import ChatOpenAI

from .base import ChatProvider


class OllamaProvider(ChatProvider):
    """Ollama via its OpenAI-compatible ``/v1`` endpoint."""

    def build_model(self, model_name, temperature, api_key, timeout):
        base = config.CONFIG["base_url"].rstrip("/")
        openai_base = base if base.endswith("/v1") else f"{base}/v1"
        return ChatOpenAI(
            model=model_name,
            openai_api_base=openai_base,
            openai_api_key=api_key or "ollama",
            temperature=temperature,
            streaming=True,
            request_timeout=timeout,
        )
