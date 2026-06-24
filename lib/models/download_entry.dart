import 'dart:convert';

class DownloadEntry {
  final String title;
  final String author;
  final String thumbnailUrl;
  final String quality;
  final String filePath;
  final DateTime timestamp;

  const DownloadEntry({
    required this.title,
    required this.author,
    required this.thumbnailUrl,
    required this.quality,
    required this.filePath,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'author': author,
    'thumbnailUrl': thumbnailUrl,
    'quality': quality,
    'filePath': filePath,
    'timestamp': timestamp.toIso8601String(),
  };

  factory DownloadEntry.fromJson(Map<String, dynamic> json) => DownloadEntry(
    title: json['title'] as String? ?? 'Unknown',
    author: json['author'] as String? ?? 'Unknown',
    thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
    quality: json['quality'] as String? ?? 'Unknown',
    filePath: json['filePath'] as String? ?? '',
    timestamp:
        DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
  );

  static List<DownloadEntry> listFromJson(String jsonString) {
    final List<dynamic> list = jsonDecode(jsonString);
    return list
        .map((e) => DownloadEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<DownloadEntry> entries) {
    return jsonEncode(entries.map((e) => e.toJson()).toList());
  }
}
