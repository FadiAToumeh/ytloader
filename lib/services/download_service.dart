import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/video_info.dart';

class DownloadProgress {
  final int received;
  final int total;

  const DownloadProgress({required this.received, required this.total});

  double get percentage => total > 0 ? received / total : 0.0;
  String get percentageText => '${(percentage * 100).toStringAsFixed(0)}%';
}

class DownloadService {
  final Dio _dio = Dio();
  static const _channel = MethodChannel(
    'com.example.youtube_downloader/downloads',
  );

  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  bool _isValidYouTubeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('youtube-nocookie.com');
  }

  Future<VideoInfo> getVideoInfo(String url) async {
    final trimmedUrl = url.trim();

    if (!_isValidYouTubeUrl(trimmedUrl)) {
      throw Exception('Please enter a valid YouTube URL');
    }

    final videoId = VideoId.parseVideoId(trimmedUrl);
    if (videoId == null) {
      throw Exception(
        'Could not extract a video ID from this URL.\n'
        'Try a format like: https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
    }

    final metadata = await _fetchMetadata(videoId);
    final manifest = await _fetchManifest(videoId);

    final muxedStreams = manifest.muxed;
    StreamInfo? bestStream;

    if (muxedStreams.isNotEmpty) {
      bestStream = muxedStreams.last;
    } else {
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isNotEmpty) {
        bestStream = audioStreams.last;
      }
    }

    return VideoInfo(
      title: metadata['title'] ?? 'Unknown Title',
      author: metadata['author'] ?? 'Unknown Author',
      duration: Duration.zero,
      thumbnailUrl: metadata['thumbnailUrl'] ?? '',
      streamUrl: bestStream?.url.toString(),
      fileSizeBytes: bestStream?.size.totalBytes.toInt(),
      quality: bestStream != null
          ? '${bestStream.qualityLabel} ${bestStream is AudioOnlyStreamInfo ? "Audio" : ""}'
          : 'Unknown',
    );
  }

  Future<Map<String, String>> _fetchMetadata(String videoId) async {
    final oEmbedUrl =
        'https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json';
    try {
      final response = await _dio.get(oEmbedUrl);
      if (response.statusCode == 200) {
        final data = response.data;
        return {
          'title': data['title']?.toString() ?? 'Unknown Title',
          'author': data['author_name']?.toString() ?? 'Unknown Author',
          'thumbnailUrl': 'https://img.youtube.com/vi/$videoId/0.jpg',
        };
      }
    } catch (_) {}
    return {
      'title': 'Unknown Title',
      'author': 'Unknown Author',
      'thumbnailUrl': 'https://img.youtube.com/vi/$videoId/0.jpg',
    };
  }

  Future<StreamManifest> _fetchManifest(String videoId) async {
    final clients = [
      YoutubeApiClient.androidVr,
      YoutubeApiClient.ios,
      YoutubeApiClient.androidSdkless,
      YoutubeApiClient.tv,
    ];

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      final yt = YoutubeExplode();
      try {
        final manifest = await yt.videos.streamsClient.getManifest(
          videoId,
          ytClients: clients,
          requireWatchPage: false,
        );
        return manifest;
      } on RequestLimitExceededException {
        throw Exception(
          'YouTube is limiting requests. Please wait a few minutes and try again.',
        );
      } catch (e) {
        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay * attempt);
          continue;
        }
      } finally {
        yt.close();
      }
    }

    throw Exception(
      'Failed to load video after $_maxRetries attempts.\n'
      'This video may be restricted or unavailable.',
    );
  }

  Future<String> downloadVideo(
    VideoInfo videoInfo,
    void Function(DownloadProgress)? onProgress,
  ) async {
    if (videoInfo.streamUrl == null) {
      throw Exception('No download URL available');
    }

    final tempDir = await getTemporaryDirectory();
    final safeTitle = videoInfo.title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');
    final tempPath = '${tempDir.path}/$safeTitle.mp4';

    await _dio.download(
      videoInfo.streamUrl!,
      tempPath,
      onReceiveProgress: (received, total) {
        onProgress?.call(DownloadProgress(received: received, total: total));
      },
      options: Options(headers: {'User-Agent': 'Mozilla/5.0'}),
    );

    try {
      final savedPath = await _channel.invokeMethod<String>('saveToDownloads', {
        'filePath': tempPath,
        'fileName': '$safeTitle.mp4',
      });
      return savedPath ?? 'Downloads/$safeTitle.mp4';
    } catch (e) {
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        return tempPath;
      }
      throw Exception('Failed to save to Downloads and temp file missing');
    }
  }

  void dispose() {
    _dio.close();
  }
}
