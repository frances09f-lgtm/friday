import 'dart:async';

import 'llm_types.dart';

/// Tries providers in order. Falls through to the next provider only when the
/// current one fails before producing any text; a failure after partial text
/// is surfaced so the user never sees two answers glued together.
class LlmRouter {
  LlmRouter(this.providers);
  final List<LlmProvider> providers;

  /// [onFailure] is called for each provider that was skipped or failed
  /// before a later one answered.
  Stream<LlmChunk> streamChat(
    List<LlmMessage> messages, {
    void Function(ProviderFailure failure)? onFailure,
  }) async* {
    final failures = <ProviderFailure>[];
    for (final p in providers) {
      if (!p.isConfigured) {
        failures.add(ProviderFailure(
            p.id,
            LlmException(LlmErrorKind.notConfigured, '${p.displayName} is not set up.',
                providerId: p.id)));
        continue;
      }
      var started = false;
      try {
        await for (final text in p.streamChat(messages)) {
          started = true;
          yield LlmChunk(text, p.id);
        }
        return; // success
      } on LlmException catch (e) {
        if (started) rethrow;
        failures.add(ProviderFailure(p.id, e));
        onFailure?.call(failures.last);
      }
    }
    // Everyone failed. Surface the most informative error.
    final real = failures.where((f) => f.error.kind != LlmErrorKind.notConfigured &&
        f.error.kind != LlmErrorKind.unavailable);
    if (real.isNotEmpty) {
      throw LlmException(
        real.first.error.kind,
        real.map((f) => f.error.message).join('\n'),
        providerId: real.first.providerId,
      );
    }
    throw LlmException(LlmErrorKind.notConfigured,
        'No AI provider is set up. Add an OpenRouter or Groq key in Settings.');
  }
}
