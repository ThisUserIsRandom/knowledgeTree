# Backend — Knowledge Tree Gateway (Python)

A thin Flask gateway that turns any OpenAI-compatible LLM (Ollama, OpenRouter,
OpenAI, …) into a single streaming `/v1/chat/completions` endpoint the Flutter
client can talk to. Built on LangChain + LangGraph.

## Tech stack

- **Flask** — HTTP server + blueprints (`/health`, chat, models, config).
- **LangChain** (`langchain-core`, `langchain-openai`) — chat model wrappers.
- **LangGraph** (`langgraph`) — minimal `StateGraph` wrapping the model call.
- **`dart:io` on the client** consumes the SSE stream; the server just emits
  OpenAI-style `data: {...}` chunks.

> No `requirements.txt` is committed. Install manually:
> `pip install flask langchain-core langchain-openai langgraph`

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
│   └── config_routes.py # GET/POST /v1/config, /v1/config/reload, /v1/config/set
├── providers/
│   ├── base.py          # ChatProvider ABC (build_model)
│   ├── factory.py       # api_type → provider instance
│   ├── ollama.py        # OllamaProvider
│   └── openai_compatible.py  # OpenAICompatibleProvider, OpenRouterProvider
├── graph/
│   └── chat_graph.py    # LangGraph StateGraph + stream_chat / invoke_chat
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
python -m venv env && source env/bin/activate
pip install flask langchain-core langchain-openai langgraph
cp config.example.json config.json   # set api_key / base_url / api_type
python main.py                       # http://0.0.0.0:8000
```

CORS is open (`Access-Control-Allow-Origin: *`) and `OPTIONS` preflight is
handled, so the Flutter app can call the gateway from any origin in dev.
