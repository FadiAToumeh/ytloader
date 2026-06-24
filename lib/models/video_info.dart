import 'stream_option.dart';

class VideoInfo {
  final String title;
  final String author;
  final Duration duration;
  final String thumbnailUrl;
  final String? streamUrl;
  final int? fileSizeBytes;
  final String quality;
  final List<StreamOption> availableStreams;

  const VideoInfo({
    required this.title,
    required this.author,
    required this.duration,
    required this.thumbnailUrl,
    this.streamUrl,
    this.fileSizeBytes,
    this.quality = 'Best Available',
    this.availableStreams = const [],
  });

  String get durationText {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String get fileSizeText {
    if (fileSizeBytes == null) return 'Unknown size';
    final mb = fileSizeBytes! / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}
