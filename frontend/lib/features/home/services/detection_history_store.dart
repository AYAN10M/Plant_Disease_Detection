import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/detection_record.dart';

/// Persists detection history to SharedPreferences as a JSON list.
///
/// All I/O is hardened: corrupt entries are skipped rather than crashing the
/// app, and the list is capped at [_maxEntries] to keep storage small.
class DetectionHistoryStore {
  static const _historyKey  = 'detection_history';
  static const _maxEntries  = 50; // matches constants.MAX_DETECTION_HISTORY

  Future<List<DetectionHistoryEntry>> loadEntries() async {
    final prefs   = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_historyKey);
    if (encoded == null || encoded.isEmpty) return [];

    List<dynamic> raw;
    try {
      raw = jsonDecode(encoded) as List<dynamic>;
    } catch (_) {
      // Stored JSON is corrupt — start fresh rather than crashing.
      await prefs.remove(_historyKey);
      return [];
    }

    final entries = <DetectionHistoryEntry>[];
    for (final item in raw) {
      try {
        if (item is Map<String, dynamic>) {
          entries.add(DetectionHistoryEntry.fromJson(item));
        }
      } catch (_) {
        // Skip any individual corrupt entry silently.
      }
    }
    return entries;
  }

  Future<void> saveEntry(DetectionHistoryEntry entry) async {
    final entries = await loadEntries();
    entries.insert(0, entry);

    final prefs   = await SharedPreferences.getInstance();
    final limited = entries.take(_maxEntries).map((e) => e.toJson()).toList();
    await prefs.setString(_historyKey, jsonEncode(limited));
  }

  Future<void> deleteEntry(DetectionHistoryEntry entry) async {
    final entries = await loadEntries();
    final key     = entry.createdAt.toIso8601String();
    entries.removeWhere((e) => e.createdAt.toIso8601String() == key);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(
      entries.map((e) => e.toJson()).toList(),
    ));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
  }
}
