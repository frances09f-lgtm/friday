import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

String sseBody(List<String> deltas, {bool done = true}) {
  final b = StringBuffer();
  for (final d in deltas) {
    b.write('data: ${jsonEncode({
          'choices': [
            {'delta': {'content': d}}
          ]
        })}\n\n');
  }
  if (done) b.write('data: [DONE]\n\n');
  return b.toString();
}

MockClient streamClient(int status, String body, {void Function(http.BaseRequest)? onRequest}) =>
    MockClient.streaming((req, _) async {
      onRequest?.call(req);
      return http.StreamedResponse(
          Stream.value(utf8.encode(body)), status,
          headers: {'content-type': 'text/event-stream'});
    });
