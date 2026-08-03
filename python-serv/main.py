import logging
import os
import sys

# Make the pure-Python `tiktoken` shim in this directory shadow the Rust
# `tiktoken` pulled in by langchain-openai. The Rust build links ndk-context and
# panics ("android context was not initialized") under Termux, aborting the
# server. Token counting is not used by this server, so a stdlib-only stand-in
# is safe. This must run before anything imports langchain.
_THIS_DIR = os.path.dirname(os.path.abspath(__file__))
if _THIS_DIR not in sys.path:
    sys.path.insert(0, _THIS_DIR)

from app import create_app
import config

app = create_app()

if __name__ == "__main__":
    logging.getLogger("kt-server").info(
        f"Starting Knowledge Tree AI Server | "
        f"api_type={config.CONFIG['api_type']} base={config.CONFIG['base_url']}"
    )
    app.run(host="0.0.0.0", port=8000, threaded=True)
