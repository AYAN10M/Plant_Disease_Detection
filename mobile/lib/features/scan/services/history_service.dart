import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/constants/app_constants.dart';
import '../models/detection_model.dart';

class DetectionHistoryStore {
  Future<List<DetectionHistoryEntry>> loadEntries() async {
    final prefs   = await SharedPreferences.getInstance();
    final encoded = prefs.getString(AppConstants.historyPrefsKey);
    if (encoded == null || encoded.isEmpty) return [];

    List<dynamic> raw;
    try {
      raw = jsonDecode(encoded) as List<dynamic>;
    } catch (_) {
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
