# knowledgetree

Flutter client for **Knowledge Tree AI** — an interactive, hierarchical AI chat
app. Knowledge is organized as a tree of nodes; each node owns its own chat
conversation with an LLM, and the panel can run a **web search (RAG)** that
searches the internet and answers from crawled pages.

The app talks to the Python gateway in `../python-serv` (see
[`docs/backend/README.md`](../docs/backend/README.md)); full frontend docs are
in [`docs/frontend/README.md`](../docs/frontend/README.md).

## Quick start

```bash
flutter pub get
flutter run          # or: flutter run -d <device>
```

On first launch the app opens the **Connector** screen — configure the backend
URL, API key and model there. Afterwards it opens the Main Menu → Knowledge Tree.

## Tests

```bash
flutter analyze
flutter test
```

## Layout

- `lib/app.dart` — `MaterialApp` + connector/main-menu router.
- `lib/features/knowledge_tree/` — `graphview`-based tree with per-node chat.
- `lib/features/chat/` — chat panel, message bubbles, web-search animation,
  notes and the question index.
- `lib/features/connector/` — provider setup + saved profiles.
- `lib/services/` — network (chat/RAG SSE) + persistence.
