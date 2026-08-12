import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/queue_item.dart';
import '../models/download_item.dart';
import '../services/download_service.dart';
import '../services/notification_service.dart';
import 'download_provider.dart';

final queueProvider =
    StateNotifierProvider<QueueNotifier, List<QueueItem>>((ref) {
  return QueueNotifier(ref.read(downloadServiceProvider), ref);
});

class QueueNotifier extends StateNotifier<List<QueueItem>> {
  final DownloadService _service;
  final Ref _ref;
  bool _isProcessing = false;

  QueueNotifier(this._service, this._ref) : super([]);

  bool get isProcessing => _isProcessing;

  /// Добавить задачу в очередь и запустить обработку если нет активных.
  Future<void> enqueue(QueueItem item) async {
    state = [...state, item];
    _processNext();
  }

  /// Повторить загрузку с ошибкой.
  void retry(String id) {
    state = [
      for (final item in state)
        if (item.id == id)
          item.copyWith(status: QueueItemStatus.pending, progress: 0.0, error: null)
        else
          item
    ];
    _processNext();
  }

  /// Удалить элемент из очереди (только не загружаемый).
  void remove(String id) {
    state = state.where((e) => e.id != id || e.status == QueueItemStatus.downloading).toList();
  }

  /// Очистить завершённые задачи.
  void clearDone() {
    state = state.where((e) => e.status != QueueItemStatus.done).toList();
  }

  /// Запустить обработку следующего элемента очереди.
  void _processNext() {
    if (_isProcessing) return;
    final nextIndex = state.indexWhere((e) => e.status == QueueItemStatus.pending);
    if (nextIndex == -1) return;
    _processItem(nextIndex);
  }

  Future<void> _processItem(int index) async {
    if (_isProcessing) return;
    _isProcessing = true;

    final item = state[index];
    final notifId = int.parse(item.id.substring(item.id.length > 8 ? item.id.length - 8 : 0));

    // Mark as downloading
    _updateItem(item.id, (e) => e.copyWith(status: QueueItemStatus.downloading, progress: 0.0));

    await NotificationService().showProgress(
      id: notifId,
      title: item.title,
      progressPercent: 0,
    );

    try {
      String? path;

      if (item.platform == 'tiktok') {
        path = await _downloadTikTok(item, notifId);
      } else {
        path = await _downloadYouTube(item, notifId);
      }

      if (path != null) {
        _updateItem(item.id, (e) => e.copyWith(
          status: QueueItemStatus.done,
          progress: 1.0,
          outputPath: path,
        ));
        await NotificationService().showComplete(id: notifId, title: item.title);

        // Add to history
        final type = item.format == 'thumbnail'
            ? 'image'
            : item.format == 'audio'
                ? 'audio'
                : 'video';
        _ref.read(historyProvider.notifier).add(DownloadItem(
              id: item.id,
              title: item.title,
              thumbnailUrl: item.thumbnailUrl,
              type: type,
              downloadedAt: DateTime.now(),
              path: path,
            ));
      } else {
        _updateItem(item.id, (e) => e.copyWith(
          status: QueueItemStatus.error,
          error: 'Неизвестная ошибка',
        ));
        await NotificationService().showError(
          id: notifId,
          title: item.title,
          error: 'Неизвестная ошибка',
        );
      }
    } catch (e) {
      final errMsg = e.toString().replaceFirst('Exception: ', '');
      _updateItem(item.id, (e2) => e2.copyWith(
        status: QueueItemStatus.error,
        error: errMsg,
      ));
      await NotificationService().showError(
        id: notifId,
        title: item.title,
        error: errMsg,
      );
    } finally {
      _isProcessing = false;
      _processNext(); // Start next item
    }
  }

  Future<String?> _downloadTikTok(QueueItem item, int notifId) async {
    if (item.tiktokData == null) {
      // Re-fetch TikTok data
      final data = await _service.getTikTokInfo(item.url);
      final updated = item.copyWith(tiktokData: data);
      return _downloadTikTokWithData(updated, notifId);
    }
    return _downloadTikTokWithData(item, notifId);
  }

  Future<String?> _downloadTikTokWithData(QueueItem item, int notifId) async {
    final data = item.tiktokData!;
    if (item.format == 'thumbnail') {
      return _service.downloadTikTokThumbnailAndSaveToGallery(data, (p) {
        _updateProgress(item.id, p, notifId, item.title);
      });
    } else {
      return _service.downloadTikTokAndSaveToGallery(
        data,
        item.format == 'audio',
        (p) => _updateProgress(item.id, p, notifId, item.title),
        customTitle: item.customTitle,
        customAuthor: item.customAuthor,
        tiktokQuality: item.tiktokQuality,
        tiktokCodec: item.tiktokCodec,
        tiktokAudioCodec: item.tiktokAudioCodec,
      );
    }
  }

  Future<String?> _downloadYouTube(QueueItem item, int notifId) async {
    // Re-fetch video info and stream manifest
    final video = await _service.getVideoInfo(item.url);
    final manifest = await _service.getManifest(video.id);

    if (item.format == 'thumbnail') {
      return _service.downloadThumbnailAndSaveToGallery(
        video,
        (p) => _updateProgress(item.id, p, notifId, item.title),
      );
    } else if (item.format == 'audio') {
      final audioStreams = manifest.audioOnly.toList()
        ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

      var stream = audioStreams.first;
      if (item.bitrate != null) {
        try {
          stream = audioStreams.firstWhere(
            (e) => e.bitrate.kiloBitsPerSecond.round() == item.bitrate,
          );
        } catch (_) {}
      }

      return _service.downloadAndSaveToGallery(
        video,
        stream,
        (p) => _updateProgress(item.id, p, notifId, item.title),
        customTitle: item.customTitle,
        customAuthor: item.customAuthor,
      );
    } else {
      // Video
      final videoStreams = <dynamic>[...manifest.muxed, ...manifest.videoOnly]
        ..sort((a, b) {
          final cmp = b.videoResolution.height.compareTo(a.videoResolution.height);
          if (cmp != 0) return cmp;
          return b.framerate.framesPerSecond.compareTo(a.framerate.framesPerSecond);
        });

      var stream = videoStreams.first;
      if (item.quality != null) {
        try {
          stream = videoStreams.firstWhere(
            (e) => e.qualityLabel == item.quality,
          );
        } catch (_) {}
      }

      return _service.downloadAndSaveToGallery(
        video,
        stream,
        (p) => _updateProgress(item.id, p, notifId, item.title),
      );
    }
  }

  void _updateProgress(String id, double progress, int notifId, String title) {
    _updateItem(id, (e) => e.copyWith(progress: progress));
    final pct = (progress * 100).round();
    NotificationService().showProgress(id: notifId, title: title, progressPercent: pct);
  }

  void _updateItem(String id, QueueItem Function(QueueItem) updater) {
    state = [
      for (final item in state)
        if (item.id == id) updater(item) else item
    ];
  }
}
