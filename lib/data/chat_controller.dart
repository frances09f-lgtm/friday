import 'package:flutter/foundation.dart';

import 'chat_engine.dart';
import 'conversation_store.dart';
import 'models.dart';
import 'settings.dart';

class ChatController extends ChangeNotifier {
  ChatController({
    required this.store,
    required this.settingsStore,
    required this.engine,
  });

  final ConversationStore store;
  final SettingsStore settingsStore;
  final ChatEngine engine;

  List<Conversation> conversations = [];
  Conversation? current;
  AppSettings settings = const AppSettings();
  bool loaded = false;
  bool sending = false;
  bool _cancel = false;

  bool get hasAnyKey =>
      settings.openRouterKey.trim().isNotEmpty || settings.groqKey.trim().isNotEmpty;

  Future<void> init() async {
    settings = await settingsStore.load();
    conversations = await store.loadAll();
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    current = conversations.isNotEmpty ? conversations.first : null;
    // A message left empty by a killed app is not a real reply.
    for (final c in conversations) {
      for (final m in c.messages) {
        if (m.role == MessageRole.assistant && m.content.isEmpty && m.error == null) {
          m.error = 'Interrupted';
        }
      }
    }
    loaded = true;
    notifyListeners();
  }

  Future<void> saveSettings(AppSettings s) async {
    settings = s;
    await settingsStore.save(s);
    notifyListeners();
  }

  void newChat() {
    if (sending) return;
    if (current != null && current!.messages.isEmpty) return;
    final c = Conversation(id: newId());
    conversations.insert(0, c);
    current = c;
    notifyListeners();
  }

  void select(Conversation c) {
    if (sending) return;
    current = c;
    notifyListeners();
  }

  Future<void> delete(Conversation c) async {
    if (sending && c == current) return;
    conversations.remove(c);
    if (current == c) current = conversations.isNotEmpty ? conversations.first : null;
    await store.saveAll(_persistable());
    notifyListeners();
  }

  void stop() => _cancel = true;

  Future<void> send(String text) async {
    final t = text.trim();
    if (t.isEmpty || sending) return;
    var c = current;
    if (c == null) {
      c = Conversation(id: newId());
      conversations.insert(0, c);
      current = c;
    }
    c.messages.add(ChatMessage(
        id: newId(), role: MessageRole.user, content: t, createdAt: DateTime.now()));
    if (c.title == 'New chat') {
      c.title = t.length > 40 ? '${t.substring(0, 40)}...' : t;
    }
    await _generate(c);
  }

  /// Re-runs the last user message (after an error).
  Future<void> retry() async {
    final c = current;
    if (c == null || sending || c.messages.isEmpty) return;
    if (c.messages.last.role == MessageRole.assistant) c.messages.removeLast();
    if (c.messages.isEmpty || c.messages.last.role != MessageRole.user) return;
    await _generate(c);
  }

  Future<void> _generate(Conversation c) async {
    final reply = ChatMessage(
        id: newId(), role: MessageRole.assistant, content: '', createdAt: DateTime.now());
    final history = List<ChatMessage>.of(c.messages);
    c.messages.add(reply);
    c.updatedAt = DateTime.now();
    sending = true;
    _cancel = false;
    notifyListeners();
    await store.saveAll(_persistable());
    await engine.reply(
      history: history,
      reply: reply,
      settings: settings,
      onUpdate: notifyListeners,
      isCancelled: () => _cancel,
    );
    sending = false;
    c.updatedAt = DateTime.now();
    await store.saveAll(_persistable());
    notifyListeners();
  }

  List<Conversation> _persistable() =>
      conversations.where((c) => c.messages.isNotEmpty).toList();
}
