import 'llm_types.dart';

/// Stage 1 stub for the on-device fallback model (llama.cpp etc. lands in a
/// later stage). Reports itself as unconfigured so the router skips it and
/// the UI can say so honestly.
class LocalModelProvider implements LlmProvider {
  const LocalModelProvider();

  @override
  String get id => 'local';
  @override
  String get displayName => 'On-device model';
  @override
  bool get isConfigured => false;

  @override
  Stream<String> streamChat(List<LlmMessage> messages) async* {
    throw LlmException(LlmErrorKind.unavailable,
        'The on-device model is not installed yet (coming in a later stage).',
        providerId: id);
  }
}
