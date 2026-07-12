# Knowledge Tree AI

An interactive, hierarchical AI chat app. Knowledge is organized as a **tree of
nodes**; each node can hold its own chat conversation with an LLM. A Flutter
client talks to a small Python gateway that proxies any OpenAI-compatible
provider (Ollama, OpenRouter, OpenAI, …) and streams responses back.

## Monorepo layout

```
proj4/
├── README.md                     # this file
├── docs/
│   ├── frontend/README.md        # Flutter client documentation
│   └── backend/README.md         # Python gateway documentation
├── knowledgetree/                # Flutter app (frontend)
└── python-serv/                  # Flask + LangChain/LangGraph gateway (backend)
```

- **`knowledgetree/`** — Flutter client. See [docs/frontend/README.md](docs/frontend/README.md).
- **`python-serv/`** — LLM gateway. See [docs/backend/README.md](docs/backend/README.md).

## Quick start

### 1. Backend (Python gateway)

```bash
cd python-serv
python -m venv env
source env/bin/activate            # Windows: env\Scripts\activate
pip install flask langchain-core langchain-openai langgraph
cp config.example.json config.json   # then set api_key / base_url / api_type
python main.py                       # listens on http://0.0.0.0:8000
```

Health check: `GET http://localhost:8000/health`.

### 2. Frontend (Flutter)

```bash
cd knowledgetree
flutter pub get
flutter run
```

The first screen is the **Connector** (provider setup). Once a provider is
configured it is remembered via `shared_preferences` and the app opens into the
**Main Menu** → **Knowledge Tree**.

## How they fit together

```
Flutter (knowledgetree)  ──HTTP/SSE──▶  Flask (python-serv)  ──▶  Upstream LLM
   TreeView + ChatPanel            /v1/chat/completions            (Ollama/OpenRouter/…)
```

The backend exposes an OpenAI-compatible `/v1/chat/completions` endpoint and
streams Server-Sent Events. The frontend renders the tree with the `graphview`
package and opens a chat panel per node.

## License

Internal project.
