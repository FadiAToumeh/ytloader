enum StreamType { muxed, videoOnly, audioOnly }

class StreamOption {
  final String qualityLabel;
  final int fileSizeBytes;
  final StreamType type;
  final String? streamUrl;
  final String? videoStreamUrl;
  final String? audioStreamUrl;

  const StreamOption({
    required this.qualityLabel,
    required this.fileSizeBytes,
    required this.type,
    this.streamUrl,
    this.videoStreamUrl,
    this.audioStreamUrl,
  });

  String get fileSizeText {
    final mb = fileSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }

  String get typeLabel {
    switch (type) {
      case StreamType.muxed:
        return 'Video+Audio';
      case StreamType.videoOnly:
        return 'Video Only';
      case StreamType.audioOnly:
        return 'Audio Only';
    }
  }

  String get displayLabel => '$qualityLabel ($typeLabel)';

  bool get needsMuxing => type == StreamType.videoOnly;
}
