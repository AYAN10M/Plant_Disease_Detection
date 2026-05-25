import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../models/detection_model.dart';

/// Persists detection history to SharedPreferences as a JSON list.
///
/// All I/O is hardened: corrupt entries are skipped rather than crashing the
/// app, and the list is capped at [AppConstants.maxHistoryEntries] to keep
/// storage small.
class DetectionHistoryStore {
  Future<List<DetectionHistoryEntry>> loadEntries() async {
    final prefs   = await SharedPreferences.getInstance();
    final encoded = prefs.getString(AppConstants.historyPrefsKey);
    if (encoded == null || encoded.isEmpty) return [];

    List<dynamic> raw;
    try {
      raw = jsonDecode(encoded) as List<dynamic>;
    } catch (_) {
      // Stored JSON is corrupt — start fresh rather than crashing.
      await prefs.remove(AppConstants.historyPrefsKey);
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
    final limited = entries
        .take(AppConstants.maxHistoryEntries)
        .map((e) => e.toJson())
        .toList();
    await prefs.setString(AppConstants.historyPrefsKey, jsonEncode(limited));
  }

  Future<void> deleteEntry(DetectionHistoryEntry entry) async {
    final entries = await loadEntries();
    final key     = entry.createdAt.toIso8601String();
    entries.removeWhere((e) => e.createdAt.toIso8601String() == key);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConstants.historyPrefsKey,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.historyPrefsKey);
  }
}
