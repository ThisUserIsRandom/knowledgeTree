import logging
import traceback

from flask import Blueprint, jsonify

import config
import utils

bp = Blueprint("models", __name__)
logger = logging.getLogger("kt-server")


@bp.route("/v1/models")
def list_models():
    logger.info("MODELS | listing available models")
    models = {}
    for name in config.CONFIG["model_map"].keys():
        models[name] = {"id": name, "object": "model"}
    if config.CONFIG["default_model"]:
        models[config.CONFIG["default_model"]] = {"id": config.CONFIG["default_model"], "object": "model"}

    try:
        if config.CONFIG["api_type"] == "ollama":
            url = f"{config.CONFIG['base_url'].rstrip('/')}/api/tags"
            data = utils.http_get(url)
            for m in data.get("models", []):
                models[m["name"]] = {"id": m["name"], "object": "model"}
        elif (
            config.CONFIG["api_type"] in ("openai", "openai_compatible", "openrouter")
            and config.CONFIG["api_key"]
        ):
            base = config.CONFIG["base_url"].rstrip("/")
            url = f"{base}/models" if base.endswith("/v1") else f"{base}/v1/models"
            data = utils.http_get(url, headers={"Authorization": f"Bearer {config.CONFIG['api_key']}"})
            for m in data.get("data", []):
                models[m["id"]] = {"id": m["id"], "object": "model"}
    except Exception:  # noqa: BLE001
        logger.warning(traceback.format_exc())

    return jsonify(
        {
            "data": list(models.values())
            or [{"id": config.CONFIG["default_model"] or "unknown", "object": "model"}]
        }
    )
