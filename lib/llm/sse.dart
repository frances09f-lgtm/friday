import 'dart:convert';

/// Turns a byte stream of Server-Sent Events into the `data:` payloads.
Stream<String> sseData(Stream<List<int>> bytes) async* {
  final lines = bytes.map<List<int>>((b) => b).transform(utf8.decoder).transform(const LineSplitter());
  final buffer = StringBuffer();
  await for (final line in lines) {
    if (line.isEmpty) {
      if (buffer.isNotEmpty) {
        yield buffer.toString();
        buffer.clear();
      }
      continue;
    }
    if (line.startsWith(':')) continue; // comment / keep-alive
    if (line.startsWith('data:')) {
      var v = line.substring(5);
      if (v.startsWith(' ')) v = v.substring(1);
      if (buffer.isNotEmpty) buffer.write('\n');
      buffer.write(v);
    }
  }
  if (buffer.isNotEmpty) yield buffer.toString();
}
