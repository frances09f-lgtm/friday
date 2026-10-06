import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'llm_types.dart';
import 'sse.dart';

/// Chat-completions client for any OpenAI-compatible endpoint (OpenRouter, Groq).
class OpenAiCompatibleProvider implements LlmProvider {
  OpenAiCompatibleProvider({
    required this.id,
    required this.displayName,
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    http.Client? client,
    this.extraHeaders = const {},
    this.connectTimeout = const Duration(seconds: 20),
    this.idleTimeout = const Duration(seconds: 45),
  }) : _client = client ?? http.Client();

  @override
  final String id;
  @override
  final String displayName;

  final String baseUrl;
  final String apiKey;
  final String model;
  final Map<String, String> extraHeaders;
  final Duration connectTimeout;
  final Duration idleTimeout;
  final http.Client _client;

  @override
  bool get isConfigured => apiKey.trim().isNotEmpty && model.trim().isNotEmpty;

  @override
  Stream<String> streamChat(List<LlmMessage> messages) async* {
    if (!isConfigured) {
      throw LlmException(LlmErrorKind.notConfigured,
          '$displayName has no API key or model set.',
          providerId: id);
    }
    final request = http.Request('POST', Uri.parse('$baseUrl/chat/completions'))
      ..headers.addAll({
        'Authorization': 'Bearer ${apiKey.trim()}',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        ...extraHeaders,
      })
      ..body = jsonEncode({
        'model': model.trim(),
        'stream': true,
        'messages': [for (final m in messages) m.toJson()],
      });

    http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(connectTimeout);
    } on TimeoutException {
      throw LlmException(LlmErrorKind.timeout, '$displayName took too long to respond.',
          providerId: id);
    } on SocketException {
      throw LlmException(LlmErrorKind.network, 'No internet connection.',
          providerId: id);
    } on http.ClientException catch (e) {
      throw LlmException(LlmErrorKind.network, 'Network error: ${e.message}',
          providerId: id);
    }

    if (response.statusCode != 200) {
      final body = await response.stream.bytesToString().catchError((_) => '');
      throw _httpError(response.statusCode, body);
    }

    var gotAny = false;
    try {
      await for (final data in sseData(response.stream).timeout(idleTimeout)) {
        if (data.trim() == '[DONE]') break;
        Map<String, dynamic> json;
        try {
          json = jsonDecode(data) as Map<String, dynamic>;
        } catch (_) {
          continue; // ignore non-JSON keep-alives
        }
        final err = json['error'];
        if (err != null) {
          final msg = err is Map ? (err['message'] ?? err.toString()) : err.toString();
          throw LlmException(
              gotAny ? LlmErrorKind.server : LlmErrorKind.badResponse,
              '$displayName error: $msg',
              providerId: id);
        }
        final choices = json['choices'];
        if (choices is! List || choices.isEmpty) continue;
        final delta = (choices.first as Map)['delta'];
        final text = delta is Map ? delta['content'] : null;
        if (text is String && text.isNotEmpty) {
          gotAny = true;
          yield text;
        }
      }
    } on TimeoutException {
      throw LlmException(LlmErrorKind.timeout, '$displayName stopped responding.',
          providerId: id);
    } on SocketException {
      throw LlmException(LlmErrorKind.network, 'Connection dropped.', providerId: id);
    } on http.ClientException catch (e) {
      throw LlmException(LlmErrorKind.network, 'Connection dropped: ${e.message}',
          providerId: id);
    }
    if (!gotAny) {
      throw LlmException(LlmErrorKind.badResponse, '$displayName returned an empty reply.',
          providerId: id);
    }
  }

  LlmException _httpError(int code, String body) {
    var detail = '';
    try {
      final j = jsonDecode(body);
      final e = j is Map ? j['error'] : null;
      detail = e is Map ? '${e['message'] ?? ''}' : (e?.toString() ?? '');
    } catch (_) {}
    final suffix = detail.isEmpty ? '' : ': $detail';
    if (code == 401 || code == 403) {
      return LlmException(LlmErrorKind.auth,
          '$displayName rejected the API key (HTTP $code)$suffix',
          providerId: id, statusCode: code);
    }
    if (code == 402 || code == 429) {
      return LlmException(LlmErrorKind.rateLimit,
          '$displayName limit reached (HTTP $code)$suffix',
          providerId: id, statusCode: code);
    }
    if (code >= 500) {
      return LlmException(LlmErrorKind.server,
          '$displayName server error (HTTP $code)$suffix',
          providerId: id, statusCode: code);
    }
    return LlmException(LlmErrorKind.badResponse,
        '$displayName request failed (HTTP $code)$suffix',
        providerId: id, statusCode: code);
  }
}

OpenAiCompatibleProvider openRouterProvider({
  required String apiKey,
  required String model,
  http.Client? client,
}) =>
    OpenAiCompatibleProvider(
      id: 'openrouter',
      displayName: 'OpenRouter',
      baseUrl: 'https://openrouter.ai/api/v1',
      apiKey: apiKey,
      model: model,
      client: client,
      extraHeaders: const {'X-Title': 'Friday'},
    );

OpenAiCompatibleProvider groqProvider({
  required String apiKey,
  required String model,
  http.Client? client,
}) =>
    OpenAiCompatibleProvider(
      id: 'groq',
      displayName: 'Groq',
      baseUrl: 'https://api.groq.com/openai/v1',
      apiKey: apiKey,
      model: model,
      client: client,
    );
