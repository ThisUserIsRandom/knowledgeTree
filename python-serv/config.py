import os
import json
import logging
from typing import Optional

# A single OpenAI-compatible gateway in front of any upstream provider. It is
# configured through config.json (a sibling file) and/or environment variables
# so it can point at a *different API url*, speak a *different API format*
# (api_type) and remap *model names* on the fly.
#
# config.json example:
# {
#   "base_url": "https://openrouter.ai/api/v1",
#   "api_type": "openrouter",   // ollama | openai | openai_compatible | openrouter
#   "api_key": "sk-or-...",
#   "timeout": 120,
#   "default_model": "tencent/hy3:free",
#   "model_map": { "mini": "tencent/hy3:free" }
# }
#
# Environment overrides (highest precedence):
#   KT_BASE_URL, KT_API_TYPE, KT_API_KEY, KT_TIMEOUT, KT_DEFAULT_MODEL

CONFIG_PATH = os.path.join(os.path.dirname(__file__), "config.json")


def _load_config() -> dict:
    cfg: dict = {}
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH) as f:
                cfg = json.load(f)
        except Exception as e:  # noqa: BLE001
            logging.getLogger("kt-server").warning(f"Failed to read config.json: {e}")

    return {
        "base_url": os.getenv("KT_BASE_URL", cfg.get("base_url", "http://localhost:11434")).rstrip("/"),
        "api_type": os.getenv("KT_API_TYPE", cfg.get("api_type", "ollama")).lower(),
        "api_key": os.getenv("KT_API_KEY", cfg.get("api_key", "")).strip(),
        "timeout": float(os.getenv("KT_TIMEOUT", cfg.get("timeout", 120))),
        "default_model": os.getenv("KT_DEFAULT_MODEL", cfg.get("default_model", "llama3.2")).strip(),
        "model_map": cfg.get("model_map", {}) or {},
    }


# Live config (reloadable via POST /v1/config/reload and POST /v1/config/set).
# Routes read this as `config.CONFIG` (attribute access) so live mutations and
# reloads (which reassign the attribute) are always seen.
CONFIG = _load_config()


def _resolve_model(model: str) -> str:
    """Map a client-facing model name to the upstream model name."""
    m = (model or "").strip()
    if m and m in CONFIG["model_map"]:
        return CONFIG["model_map"][m]
    if not m:
        return CONFIG["default_model"]
    return m


def _provider_to_api_type(provider: str) -> str:
    p = (provider or "").strip().lower()
    if p == "ollama":
        return "ollama"
    if p in ("openrouter", "open ai", "openai"):
        return "openrouter"
    return "openai_compatible"
