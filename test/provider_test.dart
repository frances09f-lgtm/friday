import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:friday/llm/llm_types.dart';
import 'package:friday/llm/openai_compatible_provider.dart';
import 'package:friday/llm/sse.dart';

import 'helpers.dart';

void main() {
  group('sseData', () {
    test('splits events, handles chunk boundaries and comments', () async {
      final raw = ': ping\ndata: one\n\ndata: tw';
      final stream = Stream.fromIterable([utf8.encode(raw), utf8.encode('o\n\n')]);
      expect(await sseData(stream).toList(), ['one', 'two']);
    });
  });

  group('OpenAiCompatibleProvider', () {
    final msgs = [const LlmMessage(LlmRole.user, 'hi')];

    test('streams deltas and sends auth, model and messages', () async {
      http.BaseRequest? seen;
      final client = streamClient(200, sseBody(['Hel', 'lo']), onRequest: (r) => seen = r);
      final p = openRouterProvider(apiKey: ' sk-1 ', model: 'm/x', client: client);
      expect(await p.streamChat(msgs).toList(), ['Hel', 'lo']);
      expect(seen!.url.toString(), 'https://openrouter.ai/api/v1/chat/completions');
      expect(seen!.headers['Authorization'], 'Bearer sk-1');
      final body = jsonDecode((seen as http.Request).body) as Map;
      expect(body['model'], 'm/x');
      expect(body['stream'], true);
      expect(body['messages'], [
        {'role': 'user', 'content': 'hi'}
      ]);
    });

    test('groq uses its own endpoint', () async {
      http.BaseRequest? seen;
      final p = groqProvider(
          apiKey: 'k', model: 'm', client: streamClient(200, sseBody(['a']), onRequest: (r) => seen = r));
      await p.streamChat(msgs).toList();
      expect(seen!.url.host, 'api.groq.com');
    });

    test('not configured without key', () async {
      final p = groqProvider(apiKey: '', model: 'm');
      expect(p.isConfigured, false);
      expect(p.streamChat(msgs).toList(),
          throwsA(isA<LlmException>().having((e) => e.kind, 'kind', LlmErrorKind.notConfigured)));
    });

    for (final c in {
      401: LlmErrorKind.auth,
      403: LlmErrorKind.auth,
      429: LlmErrorKind.rateLimit,
      402: LlmErrorKind.rateLimit,
      503: LlmErrorKind.server,
      400: LlmErrorKind.badResponse,
    }.entries) {
      test('HTTP ${c.key} maps to ${c.value.name}', () async {
        final body = jsonEncode({'error': {'message': 'nope'}});
        final p = groqProvider(apiKey: 'k', model: 'm', client: streamClient(c.key, body));
        expect(
            p.streamChat(msgs).toList(),
            throwsA(isA<LlmException>()
                .having((e) => e.kind, 'kind', c.value)
                .having((e) => e.message, 'message', contains('nope'))));
      });
    }

    test('socket failure becomes network error', () async {
      final client = MockClient.streaming((_, __) async => throw const SocketException('x'));
      final p = groqProvider(apiKey: 'k', model: 'm', client: client);
      expect(p.streamChat(msgs).toList(),
          throwsA(isA<LlmException>().having((e) => e.kind, 'kind', LlmErrorKind.network)));
    });

    test('empty stream is an error, not a blank reply', () async {
      final p = groqProvider(apiKey: 'k', model: 'm', client: streamClient(200, 'data: [DONE]\n\n'));
      expect(p.streamChat(msgs).toList(),
          throwsA(isA<LlmException>().having((e) => e.kind, 'kind', LlmErrorKind.badResponse)));
    });

    test('error event in stream is reported', () async {
      final body = 'data: ${jsonEncode({'error': {'message': 'boom'}})}\n\n';
      final p = groqProvider(apiKey: 'k', model: 'm', client: streamClient(200, body));
      expect(p.streamChat(msgs).toList(),
          throwsA(isA<LlmException>().having((e) => e.message, 'message', contains('boom'))));
    });

    test('ignores junk lines and empty deltas', () async {
      final body = 'data: not json\n\n'
          'data: ${jsonEncode({'choices': [{'delta': {'role': 'assistant'}}]})}\n\n'
          '${sseBody(['ok'])}';
      final p = groqProvider(apiKey: 'k', model: 'm', client: streamClient(200, body));
      expect(await p.streamChat(msgs).toList(), ['ok']);
    });
  });
}
