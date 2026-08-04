# Backend — Knowledge Tree Gateway (Python)

A thin Flask gateway that turns any OpenAI-compatible LLM (Ollama, OpenRouter,
OpenAI, …) into a single streaming `/v1/chat/completions` endpoint the Flutter
client can talk to. Built on LangChain + LangGraph.

## Tech stack

- **Flask** — HTTP server + blueprints (`/health`, chat, models, config, rag).
- **LangChain** (`langchain-core`, `langchain-openai`) — chat model wrappers.
- **LangGraph** (`langgraph`) — minimal `StateGraph` wrapping the model call.
- **`ddgs`** — DuckDuckGo search for the RAG web-search pipeline.
- **RAG retrieval** — a self-contained Okapi BM25 (`rag/index.py`) + lightweight
  semantic features (`rag/embed.py`); pages are crawled with the **stdlib**
  `urllib` + `html.parser` (`rag/web.py`) — no browser, no `crawl4ai`.
- **`pypdf` / `python-docx`** — text extraction for uploaded PDF/DOCX files.
- **`dart:io` on the client** consumes the SSE stream; the server just emits
  OpenAI-style `data: {...}` chunks.

> `requirements.txt` is committed. Install it with `python-serv/setup.sh`
> (see **Setup & running** below), or manually:
> `pip install -r requirements.txt`

## Project structure

```
python-serv/
├── main.py              # entrypoint: create_app() + app.run(port=8000)
├── app.py               # create_app(): registers blueprints, CORS, /health
├── config.py            # CONFIG loader (config.json + env), model map, provider map
├── config.example.json  # template for config.json
├── config.json          # live config (gitignored in practice)
├── routes/
│   ├── chat.py          # POST /v1/chat/completions  (SSE streaming)
│   ├── models.py        # GET  /v1/models
│   ├── config_routes.py # GET/POST /v1/config, /v1/config/reload, /v1/config/set
│   └── rag.py           # POST /v1/rag/search (SSE), upload/index/clear
├── providers/
│   ├── base.py          # ChatProvider ABC (build_model)
│   ├── factory.py       # api_type → provider instance
│   ├── ollama.py        # OllamaProvider
│   └── openai_compatible.py  # OpenAICompatibleProvider, OpenRouterProvider
├── graph/
│   └── chat_graph.py    # LangGraph StateGraph + stream_chat / invoke_chat
├── rag/
│   ├── pipeline.py      # RAG generator: search -> crawl -> index -> retrieve -> generate
│   ├── web.py           # DuckDuckGo search + stdlib HTML->markdown crawler
│   ├── index.py         # hierarchical chunking + self-contained BM25
│   ├── embed.py         # dependency-free semantic features (token + n-gram hashing)
│   └── paths.py         # data/rag/{uploaded,web} directories
├── uuid_utils/          # pure-Python shim for the Rust uuid-utils (see Termux)
│   └── compat/          # provides uuid7/uuid6 used by langchain-core
├── tiktoken/            # pure-Python shim shadowing the Rust tiktoken
└── utils.py             # message conversion, chunk extraction, SSE bridging
```

## API

### `GET /health`
Returns `{status, api_type, model}` (used by the client `ApiService.healthCheck`).

### `POST /v1/chat/completions`
OpenAI-compatible. Body: `{messages, model, temperature, stream}`.

- Defaults: `stream=true`, `temperature=0.7`, model = configured default.
- **Per-request auth**: a `Authorization: Bearer <key>` header overrides the
  server-side `api_key` for that upstream call.
- **Streaming** (`stream=true`): emits SSE `data: {…chat.completion.chunk…}`
  chunks, terminates with `data: [DONE]`. A chunk delta is wrapped via
  `utils.stream_to_queue` (async generator → background thread + queue) so the
  Flask thread can yield synchronously. Errors are emitted as an SSE error chunk.
- **Non-streaming** (`stream=false`): returns a single JSON
  `chat.completion` object.

### `GET /v1/models`
Lists models from `model_map` + default model, and (when reachable) merges the
upstream provider's model list (Ollama `/api/tags` or `/v1/models`).

### Config endpoints
- `GET  /v1/config` — returns masked config (api_key shown as `***xxxx`).
- `POST /v1/config/reload` — re-reads `config.json` + env.
- `POST /v1/config/set` — live update of `api_type`/`base_url`/`api_key`/`model`
  from the client's Connector (re-routes subsequent requests immediately).

### RAG endpoints (`/v1/rag/*`)
Used by the chat panel's web search. The pipeline generator
(`rag/pipeline.py::run_rag_pipeline`) runs:
**DuckDuckGo search → concurrent crawl → hierarchical+BM25 index → retrieve →
LLM generate → (retry if insufficient)** and streams every step as SSE.

- `POST /v1/rag/search` — body `{query, mode: "web"|"local", max_loops, model}`.
  Streams `data: {…}` events:
  - `stage` — `searching` / `crawling` / `indexing` / `retrieving` / `generating`
    (each with `message` + `attempt`).
  - `retry` — context wasn't useful; a broader query is tried next.
  - `done` — `{response, attempts, mode, sources}`.
  - `error` — pipeline/LLM failure.
  `mode=web` searches + crawls; `mode=local` only searches uploaded documents.
  An `Authorization: Bearer <key>` header overrides the configured `api_key`
  for the answer-generation call.
- `POST /v1/rag/upload` — multipart `files[]`; stores documents for `mode=local`.
- `GET  /v1/rag/index` — status `{uploaded_files, web_files, chunks}`.
- `DELETE /v1/rag/index` — clears crawled + uploaded files.

> **Crawl behaviour** (`rag/web.py`): pages are fetched concurrently
> (`MAX_CONCURRENT=8`, time-boxed), oversized/near-duplicate bodies are dropped,
> and per-page failures never abort the run. HTML is converted to clean markdown
> with a stdlib `html.parser` that keeps headings/lists/links and drops nav/
> branding subtrees — no browser is required. The web dir is cleared only on the
> first retry attempt, so retries add new pages instead of re-crawling. A hard
> **LLM failure** (auth/network/model missing) is detected by the `LLM_ERROR:`
> marker and stops the pipeline immediately instead of looping.

### Retrieval (`rag/index.py`)
Child chunks are ranked by a self-contained Okapi BM25 (`rag.index.BM25`,
k1=1.5, b=0.7) blended with cosine similarity over dependency-free semantic
features (`rag.embed.py`: hashed word tokens + character n-grams). Parent
chunks aggregate their children's scores; the best parents become the LLM
context.

## Configuration

`config.py` merges `config.json` with environment variables (env wins):

| Key             | Env              | Default              |
|-----------------|------------------|----------------------|
| `base_url`      | `KT_BASE_URL`    | `http://localhost:11434` |
| `api_type`      | `KT_API_TYPE`    | `ollama`             |
| `api_key`       | `KT_API_KEY`     | `""`                 |
| `timeout`       | `KT_TIMEOUT`     | `120`                |
| `default_model` | `KT_DEFAULT_MODEL` | `llama3.2`        |
| `model_map`     | —                | `{}`                 |

`api_type` ∈ `ollama | openai | openai_compatible | openrouter`. For OpenRouter
set `base_url` to `https://openrouter.ai/api/v1` and `api_type=openrouter`.

`model_map` remaps client-facing model names → upstream names, e.g.
`{"mini": "tencent/hy3:free"}`. `config._resolve_model` applies the map and
falls back to `default_model`.

## Provider system

`providers/factory.py` maps `api_type` → a `ChatProvider` subclass. Each
`build_model(...)` returns a LangChain `ChatOpenAI` (Ollama is reached via its
`/v1` OpenAI-compatible endpoint). `OpenRouterProvider` adds attribution
headers. New providers are registered via `register_provider(api_type, cls)`.

## Streaming internals

- `graph/chat_graph.py::stream_chat` picks a provider, builds the model, and
  streams tokens via `model.astream` (LangGraph 1.x removed the old
  `astream_events(v2)` API, so streaming goes straight to the model's native
  async stream).
- On a missing/unaffordable model it retries once with a `:free` suffix
  (e.g. `tencent/hy3` → `tencent/hy3:free`).
- `utils.stream_to_queue` bridges the async generator into the synchronous
  Flask response using a `queue.Queue` + daemon thread + private event loop.

## Running

```bash
cd python-serv
./setup.sh                           # creates ./env + installs requirements.txt
cp config.example.json config.json   # set api_key / base_url / api_type
./env/bin/python main.py             # http://0.0.0.0:8000
```

Or manually:

```bash
python -m venv env && source env/bin/activate
pip install -r requirements.txt
cp config.example.json config.json   # set api_key / base_url / api_type
python main.py                       # http://0.0.0.0:8000
```

> On a real Android phone use `python-serv/setup.sh` instead; it installs
> straight from `requirements.txt` and applies the shims below automatically.

### Running on the phone (Termux) — the RAG crash

The Rust packages `uuid-utils` (pulled in by `langchain-core`/`langsmith`)
and `tiktoken`/`tiktoken_ext` (by `langchain-openai`) link `ndk-context`. On
Termux the first LLM call that goes through the RAG `graph.invoke` path
(`POST /v1/rag/search`) calls `uuid4`/`uuid7`, which panics with
`android context was not initialized` and **`abort()`s the whole server**.
Plain `/v1/chat/completions` streams directly to the model and never touches it,
so only RAG crashes.

Fix, applied by `setup.sh` and kept in this repo:

- `python-serv/uuid_utils/` — a pure-Python shim providing the `uuid_utils.compat.uuid7`
  / `uuid4` API using the stdlib `uuid` + an RFC 9562 v6/v7 implementation.
  `main.py` puts this directory first on `sys.path`, so it shadows the Rust one.
- `python-serv/tiktoken/` — a pure-Python shim covering `tiktoken`'s import surface.
- These Rust packages **must not be installed** on Termux:
  `pip uninstall -y uuid-utils tiktoken tiktoken_ext`
  (`setup.sh` does the tiktoken uninstall; `uuid-utils` is satisfiable via the shim).

CORS is open (`Access-Control-Allow-Origin: *`) and `OPTIONS` preflight is
handled, so the Flutter app can call the gateway from any origin in dev.
