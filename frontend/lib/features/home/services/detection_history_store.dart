import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/detection_record.dart';

class DetectionHistoryStore {
  static const _historyKey = 'detection_history';
  static const _maxEntries = 25;

  Future<List<DetectionHistoryEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_historyKey);
    if (encoded == null || encoded.isEmpty) {
      return [];
    }

    final decoded = jsonDecode(encoded) as List<dynamic>;
    return decoded
        .cast<Map<String, dynamic>>()
        .map(DetectionHistoryEntry.fromJson)
        .toList();
  }

  Future<void> saveEntry(DetectionHistoryEntry entry) async {
    final entries = await loadEntries();
    entries.insert(0, entry);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _historyKey,
      jsonEncode(
        entries.take(_maxEntries).map((item) => item.toJson()).toList(),
      ),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
