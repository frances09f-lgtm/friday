import 'package:http/http.dart' as http;

import '../llm/llm_router.dart';
import '../llm/llm_types.dart';
import '../llm/local_model_provider.dart';
import '../llm/openai_compatible_provider.dart';
import 'models.dart';
import 'settings.dart';

typedef RouterFactory = LlmRouter Function(AppSettings settings);

/// Default order: OpenRouter, then Groq, then the on-device stub.
LlmRouter buildRouter(AppSettings s, {http.Client? client}) => LlmRouter([
      openRouterProvider(apiKey: s.openRouterKey, model: s.openRouterModel, client: client),
      groqProvider(apiKey: s.groqKey, model: s.groqModel, client: client),
      const LocalModelProvider(),
    ]);

String providerLabel(String id) => switch (id) {
      'openrouter' => 'OpenRouter',
      'groq' => 'Groq',
      'local' => 'On-device model',
      _ => id,
    };

/// Pure-Dart chat logic: builds the prompt, streams the reply into a message,
/// and records provider fallbacks and errors honestly on that message.
class ChatEngine {
  ChatEngine(this.routerFactory, {this.maxContextMessages = 30});
  final RouterFactory routerFactory;
  final int maxContextMessages;

  List<LlmMessage> buildPrompt(List<ChatMessage> history, AppSettings s) {
    final usable = history
        .where((m) => m.error == null || m.content.isNotEmpty)
        .where((m) => m.content.trim().isNotEmpty)
        .toList();
    final tail = usable.length > maxContextMessages
        ? usable.sublist(usable.length - maxContextMessages)
        : usable;
    return [
      if (s.systemPrompt.trim().isNotEmpty) LlmMessage(LlmRole.system, s.systemPrompt),
      for (final m in tail)
        LlmMessage(m.role == MessageRole.user ? LlmRole.user : LlmRole.assistant, m.content),
    ];
  }

  /// Fills [reply] (already appended to the conversation, empty) as chunks
  /// arrive. [onUpdate] fires after every change.
  Future<void> reply({
    required List<ChatMessage> history, // excludes [reply]
    required ChatMessage reply,
    required AppSettings settings,
    required void Function() onUpdate,
    bool Function()? isCancelled,
  }) async {
    final router = routerFactory(settings);
    final skipped = <ProviderFailure>[];
    try {
      await for (final chunk in router.streamChat(
        buildPrompt(history, settings),
        onFailure: skipped.add,
      )) {
        if (isCancelled?.call() ?? false) break;
        reply.content += chunk.text;
        if (reply.providerId == null) {
          reply.providerId = chunk.providerId;
          if (skipped.isNotEmpty) {
            reply.note = '${providerLabel(skipped.first.providerId)} failed '
                '(${skipped.first.error.kind.name}), answered by '
                '${providerLabel(chunk.providerId)}.';
          }
        }
        onUpdate();
      }
    } on LlmException catch (e) {
      reply.error = e.message;
    } catch (e) {
      reply.error = 'Something went wrong: $e';
    }
    onUpdate();
  }
}
