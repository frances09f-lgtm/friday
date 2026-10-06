import 'dart:convert';
import 'dart:io';

import 'models.dart';

abstract class ConversationStore {
  Future<List<Conversation>> loadAll();
  Future<void> saveAll(List<Conversation> conversations);
}

/// Keeps every conversation in one JSON file. Writes go to a temp file first
/// and are renamed, so a crash mid-write cannot corrupt history.
class FileConversationStore implements ConversationStore {
  FileConversationStore(this.file);
  final File file;

  @override
  Future<List<Conversation>> loadAll() async {
    if (!await file.exists()) return [];
    try {
      final raw = jsonDecode(await file.readAsString());
      final list = raw is Map ? raw['conversations'] : raw;
      return [
        for (final c in (list as List))
          Conversation.fromJson(Map<String, dynamic>.from(c as Map)),
      ];
    } catch (_) {
      // Corrupt file: keep a copy for debugging and start fresh.
      try {
        await file.rename('${file.path}.corrupt');
      } catch (_) {}
      return [];
    }
  }

  @override
  Future<void> saveAll(List<Conversation> conversations) async {
    await file.parent.create(recursive: true);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode({
      'version': 1,
      'conversations': [for (final c in conversations) c.toJson()],
    }), flush: true);
    await tmp.rename(file.path);
  }
}

class MemoryConversationStore implements ConversationStore {
  List<Conversation> saved = [];
  @override
  Future<List<Conversation>> loadAll() async => saved;
  @override
  Future<void> saveAll(List<Conversation> conversations) async =>
      saved = List.of(conversations);
}
