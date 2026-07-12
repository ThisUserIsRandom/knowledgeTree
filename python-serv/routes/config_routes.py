import logging
import traceback

from flask import Blueprint, jsonify, request

import config

bp = Blueprint("config", __name__)
logger = logging.getLogger("kt-server")


def _mask(cfg: dict) -> dict:
    safe = dict(cfg)
    if safe.get("api_key"):
        safe["api_key"] = "***" + safe["api_key"][-4:] if len(safe["api_key"]) > 4 else "***"
    return safe


@bp.route("/v1/config")
def get_config():
    return jsonify({"config": _mask(config.CONFIG)})


@bp.route("/v1/config/reload", methods=["POST"])
def reload_config():
    config.CONFIG = config._load_config()
    logger.info(f"CONFIG reloaded | api_type={config.CONFIG['api_type']} base={config.CONFIG['base_url']}")
    return jsonify(
        {
            "status": "ok",
            "api_type": config.CONFIG["api_type"],
            "base_url": config.CONFIG["base_url"],
        }
    )


@bp.route("/v1/config/set", methods=["POST"])
def set_config():
    """Live-update the upstream routing from client settings (the provider
    dropdown). The client sends the provider it selected in the UI plus the
    upstream base url / key / model; the server adopts them so subsequent
    requests are routed to ollama or openrouter accordingly."""
    body = request.get_json(force=True, silent=True) or {}
    if body.get("api_type"):
        config.CONFIG["api_type"] = body["api_type"].lower()
    elif body.get("provider"):
        config.CONFIG["api_type"] = config._provider_to_api_type(body["provider"])
    if body.get("base_url"):
        config.CONFIG["base_url"] = body["base_url"].strip().rstrip("/")
    if body.get("api_key") is not None:
        config.CONFIG["api_key"] = body["api_key"].strip()
    if body.get("model"):
        config.CONFIG["default_model"] = body["model"].strip()

    logger.info(
        f"CONFIG set | provider={body.get('provider', '-')} "
        f"api_type={config.CONFIG['api_type']} base={config.CONFIG['base_url']} "
        f"model={config.CONFIG['default_model']}"
    )
    return jsonify({"status": "ok", "config": _mask(config.CONFIG)})
