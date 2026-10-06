import 'dart:math';

enum MessageRole { user, assistant }

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.providerId,
    this.error,
    this.note,
  });

  final String id;
  final MessageRole role;
  String content;
  final DateTime createdAt;

  /// Which provider produced an assistant reply.
  String? providerId;

  /// Set when generation failed. The partial [content] is kept.
  String? error;

  /// Soft info, e.g. "OpenRouter hit its limit, answered by Groq".
  String? note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.name,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        if (providerId != null) 'providerId': providerId,
        if (error != null) 'error': error,
        if (note != null) 'note': note,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as String,
        role: MessageRole.values.firstWhere((r) => r.name == j['role'],
            orElse: () => MessageRole.assistant),
        content: (j['content'] as String?) ?? '',
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
        providerId: j['providerId'] as String?,
        error: j['error'] as String?,
        note: j['note'] as String?,
      );
}

class Conversation {
  Conversation({
    required this.id,
    this.title = 'New chat',
    DateTime? updatedAt,
    List<ChatMessage>? messages,
  })  : updatedAt = updatedAt ?? DateTime.now(),
        messages = messages ?? [];

  final String id;
  String title;
  DateTime updatedAt;
  final List<ChatMessage> messages;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'updatedAt': updatedAt.toIso8601String(),
        'messages': [for (final m in messages) m.toJson()],
      };

  factory Conversation.fromJson(Map<String, dynamic> j) => Conversation(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? 'New chat',
        updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ?? DateTime.now(),
        messages: [
          for (final m in (j['messages'] as List? ?? const []))
            ChatMessage.fromJson(Map<String, dynamic>.from(m as Map)),
        ],
      );
}

final _rng = Random();
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}${_rng.nextInt(1 << 20).toRadixString(36)}';
