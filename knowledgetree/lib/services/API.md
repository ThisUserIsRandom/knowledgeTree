# API Endpoints

The backend server must expose these endpoints:

## Health Check
```
GET /health
```
Returns 200 OK when the server is running.

## Chat Completion (OpenAI-compatible)
```
POST {api_url}/v1/chat/completions
Content-Type: application/json
Authorization: Bearer {api_key}

{
  "model": "model-name",
  "messages": [
    {"role": "user", "content": "Hello"},
    {"role": "assistant", "content": "Hi!"}
  ],
  "stream": true
}
```
Streams SSE `data: {...}` lines with delta content in `choices[0].delta.content`.
Terminates with `data: [DONE]`.

## RAG Web Search (SSE)
Used by the chat panel's "Search the web" action (`RagApiService.search`).
```
POST {api_url}/v1/rag/search
Content-Type: application/json
Authorization: Bearer {api_key}      # optional; falls back to server api_key

{
  "query": "what is today's date",
  "mode": "web",                     // "web" = search+crawl | "local" = uploaded docs
  "model": "model-name",
  "max_loops": 2
}
```
Streams SSE `data: {...}` events:
- `{"event":"stage","stage":"searching","message":"...","attempt":1}`
  (also `crawling`, `indexing`, `retrieving`, `generating`)
- `{"event":"retry","attempt":1,"message":"..."}`
- `{"event":"done","response":"...","attempts":1,"mode":"web","sources":[...]}`
- `{"event":"error","message":"..."}`
Terminates with `data: [DONE]`. The client can abort mid-stream by force-closing
the connection (`RagApiService.cancel()`).

## RAG Upload / Index
```
POST   {api_url}/v1/rag/upload    # multipart form-data, field "files" (multiple)
GET    {api_url}/v1/rag/index     # -> {uploaded_files, web_files, chunks}
DELETE {api_url}/v1/rag/index     # clears crawled + uploaded files
```
