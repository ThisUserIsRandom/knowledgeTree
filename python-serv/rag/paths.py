import os

_BASE_DIR = os.path.dirname(os.path.abspath(__file__))
_SERVER_DIR = os.path.dirname(_BASE_DIR)

DATA_DIR = os.path.join(_SERVER_DIR, "data", "rag")
UPLOAD_DIR = os.path.join(DATA_DIR, "uploaded")
WEB_DIR = os.path.join(DATA_DIR, "web")


def ensure_dirs() -> None:
    for d in (UPLOAD_DIR, WEB_DIR):
        os.makedirs(d, exist_ok=True)
