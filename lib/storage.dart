import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Local prototype storage. Do not store sensitive production customer data here.
class LocalStorage {
  static const _key = 'bizpilot_draft_data_v1';

  static Future<Map<String, dynamic>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {'customers': [], 'documents': []};
    try {
      final data = jsonDecode(raw);
      if (data is Map<String, dynamic>) return data;
    } catch (_) {
      // Malformed local data is ignored in this prototype.
    }
    return {'customers': [], 'documents': []};
  }

  static Future<void> save(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final saved = await prefs.setString(_key, jsonEncode(data));
    if (!saved) throw StateError('Lokale Speicherung fehlgeschlagen');
  }
}
