import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:friday/data/conversation_store.dart';
import 'package:friday/data/models.dart';

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('friday_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('round trips conversations', () async {
    final store = FileConversationStore(File('${dir.path}/c.json'));
    final c = Conversation(id: 'c1', title: 'Hello');
    c.messages.add(ChatMessage(
        id: 'm1', role: MessageRole.user, content: 'हॅलो', createdAt: DateTime(2026, 10, 6)));
    c.messages.add(ChatMessage(
        id: 'm2',
        role: MessageRole.assistant,
        content: 'hi',
        createdAt: DateTime(2026, 10, 6),
        providerId: 'groq',
        error: 'cut off'));
    await store.saveAll([c]);
    final back = await store.loadAll();
    expect(back.single.title, 'Hello');
    expect(back.single.messages[0].content, 'हॅलो');
    expect(back.single.messages[1].providerId, 'groq');
    expect(back.single.messages[1].error, 'cut off');
  });

  test('missing file loads empty', () async {
    expect(await FileConversationStore(File('${dir.path}/none.json')).loadAll(), isEmpty);
  });

  test('corrupt file is set aside and loads empty', () async {
    final f = File('${dir.path}/c.json')..writeAsStringSync('{not json');
    final store = FileConversationStore(f);
    expect(await store.loadAll(), isEmpty);
    expect(File('${f.path}.corrupt').existsSync(), true);
    await store.saveAll([Conversation(id: 'x')]);
    expect((await store.loadAll()).length, 1);
  });
}
