import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models/stream_option.dart';
import '../models/video_info.dart';

class DownloadProgress {
  final int received;
  final int total;
  final String phase;

  const DownloadProgress({
    required this.received,
    required this.total,
    this.phase = '',
  });

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

    final streams = <StreamOption>[];

    for (final s in manifest.muxed) {
      streams.add(
        StreamOption(
          qualityLabel: s.qualityLabel,
          fileSizeBytes: s.size.totalBytes.toInt(),
          type: StreamType.muxed,
          streamUrl: s.url.toString(),
        ),
      );
    }

    final bestAudio = manifest.audioOnly.isNotEmpty
        ? manifest.audioOnly.withHighestBitrate()
        : null;

    for (final s in manifest.videoOnly) {
      final combinedSize =
          s.size.totalBytes.toInt() + (bestAudio?.size.totalBytes.toInt() ?? 0);
      streams.add(
        StreamOption(
          qualityLabel: s.qualityLabel,
          fileSizeBytes: combinedSize,
          type: StreamType.videoOnly,
          videoStreamUrl: s.url.toString(),
          audioStreamUrl: bestAudio?.url.toString(),
        ),
      );
    }

    if (manifest.audioOnly.isNotEmpty) {
      final best = manifest.audioOnly.withHighestBitrate();
      streams.add(
        StreamOption(
          qualityLabel: best.qualityLabel,
          fileSizeBytes: best.size.totalBytes.toInt(),
          type: StreamType.audioOnly,
          streamUrl: best.url.toString(),
        ),
      );
    }

    StreamOption bestDefault;
    if (streams.any((s) => s.type == StreamType.muxed)) {
      bestDefault = streams.firstWhere((s) => s.type == StreamType.muxed);
    } else if (streams.isNotEmpty) {
      bestDefault = streams.first;
    } else {
      throw Exception('No downloadable streams found for this video');
    }

    return VideoInfo(
      title: metadata['title'] ?? 'Unknown Title',
      author: metadata['author'] ?? 'Unknown Author',
      duration: Duration.zero,
      thumbnailUrl: metadata['thumbnailUrl'] ?? '',
      streamUrl: bestDefault.streamUrl ?? bestDefault.videoStreamUrl,
      fileSizeBytes: bestDefault.fileSizeBytes,
      quality: bestDefault.qualityLabel,
      availableStreams: streams,
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
    StreamOption selectedStream,
    void Function(DownloadProgress)? onProgress,
  ) async {
    final tempDir = await getTemporaryDirectory();
    final safeTitle = videoInfo.title
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_');

    if (selectedStream.type == StreamType.videoOnly &&
        selectedStream.videoStreamUrl != null &&
        selectedStream.audioStreamUrl != null) {
      return _downloadMuxed(
        safeTitle,
        selectedStream.videoStreamUrl!,
        selectedStream.audioStreamUrl!,
        tempDir.path,
        onProgress,
      );
    }

    final url = selectedStream.streamUrl;
    if (url == null) {
      throw Exception('No download URL available');
    }

    final ext = selectedStream.type == StreamType.audioOnly ? 'm4a' : 'mp4';
    final tempPath = '${tempDir.path}/$safeTitle.$ext';

    onProgress?.call(
      const DownloadProgress(received: 0, total: 0, phase: 'Downloading...'),
    );

    await _dio.download(
      url,
      tempPath,
      onReceiveProgress: (received, total) {
        onProgress?.call(
          DownloadProgress(
            received: received,
            total: total,
            phase: 'Downloading...',
          ),
        );
      },
      options: Options(headers: {'User-Agent': 'Mozilla/5.0'}),
    );

    return _saveToDownloads(tempPath, '$safeTitle.$ext');
  }

  Future<String> _downloadMuxed(
    String safeTitle,
    String videoUrl,
    String audioUrl,
    String tempDirPath,
    void Function(DownloadProgress)? onProgress,
  ) async {
    final videoPath = '$tempDirPath/${safeTitle}_video.mp4';
    final audioPath = '$tempDirPath/${safeTitle}_audio.m4a';
    final outputPath = '$tempDirPath/$safeTitle.mp4';

    try {
      onProgress?.call(
        const DownloadProgress(
          received: 0,
          total: 0,
          phase: 'Downloading video...',
        ),
      );

      await _dio.download(
        videoUrl,
        videoPath,
        onReceiveProgress: (received, total) {
          onProgress?.call(
            DownloadProgress(
              received: received,
              total: total,
              phase: 'Downloading video...',
            ),
          );
        },
        options: Options(headers: {'User-Agent': 'Mozilla/5.0'}),
      );

      onProgress?.call(
        const DownloadProgress(
          received: 0,
          total: 0,
          phase: 'Downloading audio...',
        ),
      );

      await _dio.download(
        audioUrl,
        audioPath,
        onReceiveProgress: (received, total) {
          onProgress?.call(
            DownloadProgress(
              received: received,
              total: total,
              phase: 'Downloading audio...',
            ),
          );
        },
        options: Options(headers: {'User-Agent': 'Mozilla/5.0'}),
      );

      onProgress?.call(
        const DownloadProgress(
          received: 0,
          total: 0,
          phase: 'Merging streams...',
        ),
      );

      final session = await FFmpegKit.execute(
        '-i "$videoPath" -i "$audioPath" -c:v copy -c:a aac "$outputPath"',
      );
      final returnCode = await session.getReturnCode();
      if (!ReturnCode.isSuccess(returnCode)) {
        throw Exception('Failed to merge video and audio streams');
      }

      return _saveToDownloads(outputPath, '$safeTitle.mp4');
    } finally {
      await _cleanupTempFiles([videoPath, audioPath]);
    }
  }

  Future<String> _saveToDownloads(String filePath, String fileName) async {
    try {
      final savedPath = await _channel.invokeMethod<String>('saveToDownloads', {
        'filePath': filePath,
        'fileName': fileName,
      });
      return savedPath ?? 'Downloads/$fileName';
    } catch (e) {
      final tempFile = File(filePath);
      if (await tempFile.exists()) {
        return filePath;
      }
      throw Exception('Failed to save to Downloads and temp file missing');
    }
  }

  Future<void> _cleanupTempFiles(List<String> paths) async {
    for (final path in paths) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  void dispose() {
    _dio.close();
  }
}
