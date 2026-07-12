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
