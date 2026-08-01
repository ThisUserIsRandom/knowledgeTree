import logging
from flask import Flask, jsonify

from routes import chat_bp, models_bp, config_bp, rag_bp
import config


def create_app() -> Flask:
    app = Flask(__name__)

    app.register_blueprint(chat_bp)
    app.register_blueprint(models_bp)
    app.register_blueprint(config_bp)
    app.register_blueprint(rag_bp)

    @app.route("/health")
    def health():
        return jsonify(
            {
                "status": "ok",
                "api_type": config.CONFIG["api_type"],
                "model": config.CONFIG["default_model"],
            }
        )

    @app.after_request
    def _cors(resp):
        resp.headers["Access-Control-Allow-Origin"] = "*"
        resp.headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization"
        resp.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
        return resp

    @app.route("/", defaults={"_path": ""}, methods=["OPTIONS"])
    @app.route("/<path:_path>", methods=["OPTIONS"])
    def _options(_path=""):
        return ("", 204)

    return app
