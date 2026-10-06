/// Pure Dart (no Flutter imports) so the provider layer is unit-testable.

enum LlmRole { system, user, assistant }

class LlmMessage {
  const LlmMessage(this.role, this.content);
  final LlmRole role;
  final String content;

  Map<String, String> toJson() => {'role': role.name, 'content': content};
}

enum LlmErrorKind {
  notConfigured,
  auth,
  rateLimit,
  network,
  timeout,
  server,
  badResponse,
  unavailable,
}

class LlmException implements Exception {
  LlmException(this.kind, this.message, {this.providerId, this.statusCode});
  final LlmErrorKind kind;
  final String message;
  final String? providerId;
  final int? statusCode;

  @override
  String toString() => 'LlmException(${kind.name}, $message)';
}

/// One streamed piece of a reply, tagged with the provider that produced it.
class LlmChunk {
  const LlmChunk(this.text, this.providerId);
  final String text;
  final String providerId;
}

/// A provider that failed before the reply was produced by someone else.
class ProviderFailure {
  const ProviderFailure(this.providerId, this.error);
  final String providerId;
  final LlmException error;
}

abstract class LlmProvider {
  String get id;
  String get displayName;

  /// False when the provider cannot be used at all (no key, no model file).
  bool get isConfigured;

  /// Streams reply text. Throws [LlmException] (via the stream) on failure.
  Stream<String> streamChat(List<LlmMessage> messages);
}
