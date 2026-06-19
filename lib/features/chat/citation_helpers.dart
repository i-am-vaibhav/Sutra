import 'dart:convert';
import 'package:sutra/runtime/search/search_agent.dart';

/// Serialize a list of citations to a JSON string for DB storage.
String? encodeCitations(List<Citation>? citations) {
  if (citations == null || citations.isEmpty) return null;
  return jsonEncode(citations.map((c) => {
    'title': c.title,
    'url': c.url,
  }).toList());
}

/// Deserialize a JSON string from the DB into a list of Citation objects.
List<Citation>? decodeCitations(String? json) {
  if (json == null || json.isEmpty) return null;
  try {
    final list = jsonDecode(json) as List;
    return list.map((e) => Citation(
      title: e['title'] as String? ?? '',
      url: e['url'] as String? ?? '',
    )).toList();
  } catch (_) {
    return null;
  }
}
