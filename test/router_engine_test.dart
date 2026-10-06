import 'package:flutter_test/flutter_test.dart';
import 'package:friday/data/chat_engine.dart';
import 'package:friday/data/models.dart';
import 'package:friday/data/settings.dart';
import 'package:friday/llm/llm_router.dart';
import 'package:friday/llm/llm_types.dart';
import 'package:friday/llm/local_model_provider.dart';
import 'package:friday/llm/openai_compatible_provider.dart';

import 'helpers.dart';

class FakeProvider implements LlmProvider {
  FakeProvider(this.id, {this.configured = true, this.chunks = const [], this.failAfter, this.error});
  @override
  final String id;
  final bool configured;
  final List<String> chunks;
  final LlmException? error;
  final bool? failAfter;
  int calls = 0;

  @override
  String get displayName => id;
  @override
  bool get isConfigured => configured;
  @override
  Stream<String> streamChat(List<LlmMessage> messages) async* {
    calls++;
    for (final c in chunks) {
      yield c;
    }
    if (error != null) throw error!;
  }
}

LlmException err(String p, LlmErrorKind k, [String m = 'fail']) =>
    LlmException(k, '$p: $m', providerId: p);

Future<String> collect(LlmRouter r) async =>
    (await r.streamChat(const [LlmMessage(LlmRole.user, 'x')]).toList()).map((c) => c.text).join();

void main() {
  group('LlmRouter', () {
    test('uses first provider when it works', () async {
      final a = FakeProvider('a', chunks: ['hi']);
      final b = FakeProvider('b', chunks: ['no']);
      expect(await collect(LlmRouter([a, b])), 'hi');
      expect(b.calls, 0);
    });

    test('falls back when first fails before any text', () async {
      final a = FakeProvider('a', error: err('a', LlmErrorKind.rateLimit));
      final b = FakeProvider('b', chunks: ['from b']);
      final seen = <ProviderFailure>[];
      final out = await LlmRouter([a, b])
          .streamChat(const [], onFailure: seen.add)
          .map((c) => '${c.providerId}:${c.text}')
          .toList();
      expect(out, ['b:from b']);
      expect(seen.single.providerId, 'a');
    });

    test('skips unconfigured providers', () async {
      final a = FakeProvider('a', configured: false);
      final b = FakeProvider('b', chunks: ['ok']);
      expect(await collect(LlmRouter([a, b])), 'ok');
      expect(a.calls, 0);
    });

    test('does not fall back after partial output', () async {
      final a = FakeProvider('a', chunks: ['par'], error: err('a', LlmErrorKind.network));
      final b = FakeProvider('b', chunks: ['other']);
      final got = <String>[];
      await expectLater(
        LlmRouter([a, b]).streamChat(const []).map((c) {
          got.add(c.text);
          return c;
        }).drain(),
        throwsA(isA<LlmException>()),
      );
      expect(got, ['par']);
      expect(b.calls, 0);
    });

    test('all failed: combines real errors', () async {
      final a = FakeProvider('a', error: err('a', LlmErrorKind.auth, 'bad key'));
      final b = FakeProvider('b', error: err('b', LlmErrorKind.rateLimit, 'limit'));
      await expectLater(
        collect(LlmRouter([a, b, const LocalModelProvider()])),
        throwsA(isA<LlmException>()
            .having((e) => e.message, 'message', allOf(contains('bad key'), contains('limit')))),
      );
    });

    test('nothing configured gives a clear message', () async {
      await expectLater(
        collect(LlmRouter([FakeProvider('a', configured: false), const LocalModelProvider()])),
        throwsA(isA<LlmException>()
            .having((e) => e.kind, 'kind', LlmErrorKind.notConfigured)
            .having((e) => e.message, 'm', contains('Settings'))),
      );
    });
  });

  group('LocalModelProvider stub', () {
    test('is unconfigured and throws unavailable', () {
      const p = LocalModelProvider();
      expect(p.isConfigured, false);
      expect(p.streamChat(const []).toList(),
          throwsA(isA<LlmException>().having((e) => e.kind, 'k', LlmErrorKind.unavailable)));
    });
  });

  group('ChatEngine', () {
    ChatMessage msg(MessageRole r, String t) =>
        ChatMessage(id: newId(), role: r, content: t, createdAt: DateTime.now());

    test('prompt: system first, drops empty/failed blanks, caps context', () {
      final e = ChatEngine((_) => LlmRouter([]), maxContextMessages: 3);
      final hist = [
        msg(MessageRole.user, 'old1'),
        msg(MessageRole.assistant, 'old2'),
        msg(MessageRole.user, 'q'),
        msg(MessageRole.assistant, '')..error = 'failed',
        msg(MessageRole.user, 'q2'),
      ];
      final p = e.buildPrompt(hist, const AppSettings(systemPrompt: 'SYS'));
      expect(p.first.role, LlmRole.system);
      expect(p.skip(1).map((m) => m.content).toList(), ['old2', 'q', 'q2']);
    });

    test('streams into reply, notes fallback', () async {
      final a = FakeProvider('openrouter', error: err('openrouter', LlmErrorKind.rateLimit));
      final b = FakeProvider('groq', chunks: ['Hel', 'lo']);
      final e = ChatEngine((_) => LlmRouter([a, b]));
      final reply = msg(MessageRole.assistant, '');
      var updates = 0;
      await e.reply(
          history: [msg(MessageRole.user, 'hi')],
          reply: reply,
          settings: const AppSettings(),
          onUpdate: () => updates++);
      expect(reply.content, 'Hello');
      expect(reply.providerId, 'groq');
      expect(reply.note, contains('OpenRouter failed'));
      expect(reply.error, isNull);
      expect(updates, greaterThan(1));
    });

    test('records error and keeps partial text', () async {
      final a = FakeProvider('openrouter', chunks: ['par'], error: err('openrouter', LlmErrorKind.network, 'dropped'));
      final e = ChatEngine((_) => LlmRouter([a]));
      final reply = msg(MessageRole.assistant, '');
      await e.reply(history: [], reply: reply, settings: const AppSettings(), onUpdate: () {});
      expect(reply.content, 'par');
      expect(reply.error, contains('dropped'));
    });

    test('end to end with real providers over mock HTTP: 429 then Groq answers', () async {
      final or = streamClient(429, '{"error":{"message":"slow down"}}');
      final gq = streamClient(200, sseBody(['yo']));
      final e = ChatEngine((s) => LlmRouter([
            openRouterProvider(apiKey: 'a', model: 'm', client: or),
            groqProvider(apiKey: 'b', model: 'm', client: gq),
          ]));
      final reply = msg(MessageRole.assistant, '');
      await e.reply(
          history: [msg(MessageRole.user, 'hi')],
          reply: reply,
          settings: const AppSettings(),
          onUpdate: () {});
      expect(reply.content, 'yo');
      expect(reply.providerId, 'groq');
      expect(reply.note, contains('rateLimit'));
    });

    test('cancel stops appending', () async {
      final a = FakeProvider('a', chunks: ['1', '2', '3']);
      final e = ChatEngine((_) => LlmRouter([a]));
      final reply = msg(MessageRole.assistant, '');
      var n = 0;
      await e.reply(
          history: [],
          reply: reply,
          settings: const AppSettings(),
          onUpdate: () {},
          isCancelled: () => n++ >= 1);
      expect(reply.content, '1');
    });
  });
}
