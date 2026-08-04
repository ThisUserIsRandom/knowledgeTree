# Frontend — Knowledge Tree (Flutter)

Flutter client for Knowledge Tree AI. Renders a hierarchical knowledge tree,
lets each node own a chat conversation, and connects to the Python gateway at
`python-serv`.

## Tech stack

| Concern        | Choice |
|----------------|--------|
| UI             | Flutter 3 (SDK `^3.3.0`) |
| State          | `flutter_riverpod` (Riverpod 2) |
| Routing        | in-app router (`app.dart`); `go_router` is a dependency but not the primary router |
| Tree layout    | `graphview` (`GraphView.builder` + `BuchheimWalkerAlgorithm`) |
| Markdown       | `flutter_markdown` |
| Fonts          | `google_fonts` |
| Storage        | `shared_preferences`, `path_provider` |
| HTTP/SSE       | `dart:io` `HttpClient` (raw SSE parsing) |

## Project structure

```
lib/
├── main.dart                      # entrypoint: ProviderScope → KnowledgeTreeApp
├── app.dart                       # MaterialApp + connector/main-menu router
├── core/
│   ├── theme/                     # AppTheme, AppColors, typography
│   └── utils/logger.dart
├── features/
│   ├── chat/                      # ChatMessage model, ChatPanel, MessageBubble
│   ├── connector/                 # Provider "Connector" + Profiles screens
│   │   ├── domain/ai_profile.dart
│   │   ├── data/profile_store.dart, profile_provider.dart
│   │   └── presentation/screens/{connector_screen,profiles_screen}.dart
│   ├── knowledge_tree/            # THE tree
│   │   ├── domain/models/{knowledge_node,tree_project}.dart
│   │   └── presentation/
│   │       ├── screens/knowledge_tree_screen.dart
│   │       └── widgets/tree_view.dart
│   ├── main_menu/                 # MainMenuScreen
│   └── search/                    # SearchOverlay
├── providers/                     # Riverpod notifiers / status providers
│   ├── api_provider.dart
│   ├── backend_status_provider.dart
│   └── tree_project_provider.dart
└── services/                      # persistence + network
    ├── api_service.dart           # generic health + chat stream (HttpClient)
    ├── chat_api_service.dart      # cancellable SSE chat stream + error types
    ├── rag_api_service.dart       # SSE RAG search (stages + final answer), upload, cancellable
    ├── chat_storage.dart          # per-node chat history on disk
    ├── tree_storage.dart          # tree projects persistence
    ├── file_store.dart
    ├── backend_config_service.dart
    └── content_sanitizer.dart     # sanitize/encode request bodies
```

## Chat panel (per node)

Opened via `buildChatSheet` (`chat_panel.dart`). It has a three-page layout
(**Notes | Chat | Index**) and these message actions:

- **Copy** — every message (user *and* assistant) shows a copy button
  (`MessageBubble.onCopy`), so a user's question can be copied too.
- **Delete** — removes a message (and its paired answer if deleting a question).
- **Note** — assistant messages can carry a sticky note (`NoteEditor`).

### Web search (RAG)

The `travel_explore` icon runs `RagApiService.search` against
`POST /v1/rag/search`. Stage events (`searching` / `crawling` / `indexing` /
`retrieving` / `generating`) drive the animated **`WebSearchAnimation`** banner,
and the final answer (with `Sources:` from the returned URL list) is appended as
an assistant message.

- **Stop search** — while a search is running, the send button becomes a red
  **stop** control and the banner shows a **Stop search** button. Both call
  `RagApiService.cancel()` (force-closes the SSE `HttpClient`), and the panel
  recovers immediately without adding an error bubble.
- `max_loops` is capped at 2 for faster worst-case feedback.

## Knowledge tree

- **`TreeView`** (`features/knowledge_tree/presentation/widgets/tree_view.dart`)
  builds a `graphview` `Graph` from `KnowledgeNode` roots and renders it with
  `BuchheimWalkerAlgorithm` (top→bottom orientation). `graphview`'s built-in
  `InteractiveViewer` handles pan + pinch-zoom; `autoZoomToFit` frames the tree
  on first build and after every data change.
- Each node card supports: tap title to **rename**, **add child**, **delete
  node**, and **open chat** (opens `ChatPanel` for that node id).
- The parent `KnowledgeTreeScreen` owns the chat overlay state
  (`_chatNodeId`) and wires the node callbacks to the `TreeProjectsNotifier`
  (add/delete/rename) and `ChatStorage` (delete chat history).

## State management (Riverpod)

- `treeProjectsProvider` → `TreeProjectsNotifier` (`providers/tree_project_provider.dart`)
  holds the list of `TreeProject`s and mutates nodes (add child with fanned-out
  child positions, delete, rename). All mutations persist via `TreeStorage`.
- `backendStatusProvider` tracks gateway reachability.
- `apiProvider` / connector profile providers drive the Connector flow and the
  per-profile provider selection sent to `POST /v1/config/set`.

## Connector & profiles

- `ConnectorScreen` collects the upstream provider, base URL, API key and model,
  persists them, and calls `POST /v1/config/set` so the backend re-routes.
- `ProfilesScreen` + `AiProfile` / `ProfileStore` manage multiple saved
  provider profiles (`features/connector/`).

## Persistence

- Tree projects & node chats are stored on disk (`tree_storage.dart`,
  `chat_storage.dart`). Connector config is kept in `shared_preferences`
  (key `model_name` gates whether the Connector shows on launch — see
  `app.dart::_checkConfig`).

## Build & run

```bash
cd knowledgetree
flutter pub get
flutter analyze      # should report no errors
flutter run
```

The app boots into `ConnectorScreen` on first launch (no saved `model_name`),
then into `MainMenuScreen` afterwards.

## Talking to the gateway from a real device

- `localhost` / `127.0.0.1` on a **physical** phone refers to the phone
  itself — use the computer's **LAN IP** (e.g. `http://192.168.1.x:8000`) in the
  Connector's base URL, and have the gateway bind `0.0.0.0`.
- `10.0.2.2:8000` is the emulator-only alias for the host's loopback; it does
  not work on a real device.
- The gateway speaks plain HTTP, which Android blocks by default for apps
  targeting API 28+. The main manifest therefore sets
  `android:usesCleartextTraffic="true"` and declares the `INTERNET` permission
  (formerly only present in the debug/profile manifests, which is why a release
  build couldn't reach any server).
