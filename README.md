# Friday - stage 1: chat base

Phone AI assistant for Android (Flutter). Stage 1 is a chat app with a
provider layer. No voice and no phone actions yet.

## What is in stage 1
- Dark, modern chat UI with streaming replies, stop button, retry on error, long-press to copy.
- Chat history stored on the phone (one JSON file, atomic writes), a drawer to switch or delete chats.
- LLM layer with providers behind one interface:
  1. OpenRouter (primary), default model `openai/gpt-oss-120b:free`
  2. Groq (fallback), default model `llama-3.3-70b-versatile`
  3. On-device model: a stub for now (`lib/llm/local_model_provider.dart`). It reports "not installed", so the router skips it. Stage N implements `LlmProvider` there.
- Fallback rule: if a provider fails before sending any text (no key, bad key, 429/402 limit, 5xx, timeout, offline), the next one is tried and the reply shows "OpenRouter failed (rateLimit), answered by Groq." If a stream breaks halfway, the partial text is kept and the error is shown with a Retry button, so you never get two answers glued together.
- Honest errors: wrong key, limit reached, no internet, empty reply and "nothing set up" each get their own message.
- Keys are entered in Settings and kept in Android Keystore (flutter_secure_storage). No key is bundled in the APK. Models and the system prompt are editable. If a free model id stops working, change it in Settings (free model names on OpenRouter change often).

## Layout
```
lib/llm/    pure Dart: types, SSE parser, OpenAI-compatible provider, router, local stub
lib/data/   models, file store, settings, ChatEngine (pure Dart), ChatController
lib/ui/     theme, chat screen, settings screen
test/       provider, router, engine and store tests
tool/setup_android.sh
```

## Build (CI)
This zip has no `android/` folder. CI should run:
```
tool/setup_android.sh      # flutter create --platforms=android + INTERNET permission + minSdk 26
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```
Needs Flutter 3.27 or newer (uses `Color.withValues`, `ListenableBuilder`).

## Tests
`flutter test` covers: SSE parsing, request shape (URL, auth header, model, messages), HTTP status to error mapping, network failure, empty stream, in-stream error, router fallback rules, prompt building and context cap, cancel, end-to-end 429 then Groq over a mock HTTP client, and storage round trip plus corrupt-file recovery.

## Not done / next stages
Voice, phone actions, the real on-device model, markdown rendering, and widget tests.
