import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../models/download_entry.dart';
import '../models/stream_option.dart';
import '../models/video_info.dart';
import '../services/download_service.dart';
import '../services/history_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  final DownloadService _downloadService = DownloadService();
  final HistoryService _historyService = HistoryService();

  VideoInfo? _videoInfo;
  StreamOption? _selectedStream;
  bool _isLoadingInfo = false;
  bool _isDownloading = false;
  DownloadProgress? _downloadProgress;
  String? _errorMessage;
  String? _savedPath;
  List<DownloadEntry> _history = [];
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.getHistory();
    setState(() => _history = history);
  }

  bool _isValidYouTubeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    return host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        host.contains('youtube-nocookie.com');
  }

  Future<void> _fetchVideoInfo() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _errorMessage = 'Please enter a YouTube URL');
      return;
    }

    if (!_isValidYouTubeUrl(url)) {
      setState(
        () => _errorMessage =
            'Not a YouTube URL. Use links from youtube.com or youtu.be',
      );
      return;
    }

    setState(() {
      _isLoadingInfo = true;
      _errorMessage = null;
      _videoInfo = null;
      _savedPath = null;
    });

    try {
      final info = await _downloadService.getVideoInfo(url);
      setState(() {
        _videoInfo = info;
        _selectedStream = info.availableStreams.isNotEmpty
            ? info.availableStreams.first
            : null;
        _isLoadingInfo = false;
      });
    } catch (e) {
      setState(() {
        final msg = e.toString();
        final prefix = msg.startsWith('Exception: ')
            ? msg.substring('Exception: '.length)
            : msg;
        _errorMessage = prefix;
        _isLoadingInfo = false;
      });
    }
  }

  Future<void> _downloadVideo() async {
    if (_videoInfo == null || _selectedStream == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = null;
      _errorMessage = null;
      _savedPath = null;
    });

    try {
      final savedPath = await _downloadService.downloadVideo(
        _videoInfo!,
        _selectedStream!,
        (progress) {
          setState(() => _downloadProgress = progress);
        },
      );

      final entry = DownloadEntry(
        title: _videoInfo!.title,
        author: _videoInfo!.author,
        thumbnailUrl: _videoInfo!.thumbnailUrl,
        quality: _selectedStream!.displayLabel,
        filePath: savedPath,
        timestamp: DateTime.now(),
      );
      await _historyService.addEntry(entry);
      await _loadHistory();

      setState(() {
        _isDownloading = false;
        _savedPath = savedPath;
        _downloadProgress = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Download failed: ${e.toString()}';
        _isDownloading = false;
        _downloadProgress = null;
      });
    }
  }

  Future<void> _shareFile() async {
    if (_savedPath == null) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(_savedPath!)]));
  }

  @override
  void dispose() {
    _urlController.dispose();
    _downloadService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('YT Downloader'),
        centerTitle: true,
        actions: [
          if (_currentTab == 1 && _history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              tooltip: 'Clear history',
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear History'),
                    content: const Text('Remove all download history?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true) {
                  await _historyService.clearHistory();
                  await _loadHistory();
                }
              },
            ),
        ],
      ),
      body: _currentTab == 0 ? _buildHomeTab() : _buildHistoryTab(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (index) => setState(() => _currentTab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'History',
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildUrlInput(),
          const SizedBox(height: 12),
          if (_isLoadingInfo) _buildLoadingIndicator(),
          if (_errorMessage != null) _buildErrorMessage(),
          if (_videoInfo != null) ...[
            const SizedBox(height: 12),
            _buildVideoCard(),
          ],
          if (_savedPath != null) ...[
            const SizedBox(height: 12),
            _buildSuccessMessage(),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No downloads yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final entry = _history[index];
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (entry.thumbnailUrl.isNotEmpty)
                SizedBox(
                  width: 120,
                  height: 68,
                  child: Image.network(
                    entry.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) => Container(
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.broken_image, size: 24),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${entry.author} • ${entry.quality}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        _formatTimestamp(entry.timestamp),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () async {
                  await SharePlus.instance.share(
                    ShareParams(files: [XFile(entry.filePath)]),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUrlInput() {
    return TextField(
      controller: _urlController,
      decoration: InputDecoration(
        labelText: 'YouTube URL',
        hintText: 'https://www.youtube.com/watch?v=...',
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => _urlController.clear(),
        ),
      ),
      keyboardType: TextInputType.url,
      onSubmitted: (_) => _fetchVideoInfo(),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 8),
            Text('Loading video info...'),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          _errorMessage!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_videoInfo!.thumbnailUrl.isNotEmpty)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                _videoInfo!.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stack) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(Icons.broken_image, size: 48),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _videoInfo!.title,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _videoInfo!.author,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _videoInfo!.durationText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.high_quality, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _videoInfo!.quality,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    Icon(Icons.storage, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _videoInfo!.fileSizeText,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_videoInfo!.availableStreams.isNotEmpty)
                  _buildQualitySelector(),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: _isDownloading
                      ? _buildDownloadProgress()
                      : _buildDownloadButton(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualitySelector() {
    return DropdownButtonFormField<StreamOption>(
      initialValue: _selectedStream,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Quality',
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: _videoInfo!.availableStreams.map((stream) {
        return DropdownMenuItem<StreamOption>(
          value: stream,
          child: Text(
            '${stream.displayLabel} (${stream.fileSizeText})',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          setState(() => _selectedStream = value);
        }
      },
    );
  }

  Widget _buildDownloadButton() {
    final label = _selectedStream != null
        ? 'Download ${_selectedStream!.qualityLabel}'
        : 'Download Video';
    return FilledButton.icon(
      onPressed: _downloadVideo,
      icon: const Icon(Icons.download),
      label: Text(label),
    );
  }

  Widget _buildDownloadProgress() {
    final progress = _downloadProgress;
    final phase = progress?.phase ?? 'Starting download...';
    final hasProgress = progress != null && progress.total > 0;
    return Column(
      children: [
        LinearProgressIndicator(
          value: hasProgress ? progress.percentage : null,
          minHeight: 6,
        ),
        const SizedBox(height: 8),
        Text(
          hasProgress
              ? '$phase ${progress.percentageText} (${_formatBytes(progress.received)} / ${_formatBytes(progress.total)})'
              : phase,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildSuccessMessage() {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: 8),
                Text(
                  'Saved to Downloads',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _savedPath!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontSize: 12,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: _shareFile,
                icon: const Icon(Icons.share),
                label: const Text('Share Video'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
