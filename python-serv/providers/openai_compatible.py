import config

from langchain_openai import ChatOpenAI

from .base import ChatProvider


class OpenAICompatibleProvider(ChatProvider):
    """OpenAI-compatible endpoints (OpenAI, OpenRouter, any /v1 server).

    Subclasses can set ``extra_headers`` (e.g. OpenRouter's attribution
    headers)."""

    extra_headers: dict = {}

    def build_model(self, model_name, temperature, api_key, timeout):
        base = config.CONFIG["base_url"].rstrip("/")
        openai_base = base if base.endswith("/v1") else f"{base}/v1"
        kwargs = {}
        if self.extra_headers:
            kwargs["model_kwargs"] = {"extra_headers": dict(self.extra_headers)}
        return ChatOpenAI(
            model=model_name,
            openai_api_base=openai_base,
            openai_api_key=api_key,
            temperature=temperature,
            streaming=True,
            request_timeout=timeout,
            **kwargs,
        )


class OpenRouterProvider(OpenAICompatibleProvider):
    """OpenRouter — OpenAI-compatible with recommended attribution headers."""

    extra_headers = {
        "HTTP-Referer": "https://github.com/opencode/knowledge-tree",
        "X-Title": "Knowledge Tree",
    }
