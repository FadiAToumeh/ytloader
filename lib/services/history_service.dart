import 'package:shared_preferences/shared_preferences.dart';

import '../models/download_entry.dart';

class HistoryService {
  static const String _key = 'download_history';
  static const int _maxEntries = 100;

  Future<List<DownloadEntry>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_key);
    if (jsonString == null || jsonString.isEmpty) return [];
    try {
      return DownloadEntry.listFromJson(jsonString);
    } catch (_) {
      return [];
    }
  }

  Future<void> addEntry(DownloadEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getHistory();
    history.insert(0, entry);
    if (history.length > _maxEntries) {
      history.removeRange(_maxEntries, history.length);
    }
    await prefs.setString(_key, DownloadEntry.listToJson(history));
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
