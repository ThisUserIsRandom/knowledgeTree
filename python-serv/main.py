import logging

from app import create_app
import config

app = create_app()

if __name__ == "__main__":
    logging.getLogger("kt-server").info(
        f"Starting Knowledge Tree AI Server | "
        f"api_type={config.CONFIG['api_type']} base={config.CONFIG['base_url']}"
    )
    app.run(host="0.0.0.0", port=8000, threaded=True)
