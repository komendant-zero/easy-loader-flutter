import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_item.dart';
import '../services/download_service.dart';
import '../services/notification_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

final downloadServiceProvider = Provider((ref) => DownloadService());

class DownloadState {
  final bool isDownloading;
  final double progress;
  final Video? currentVideo;
  final StreamManifest? manifest;
  final Map<String, dynamic>? tiktokData;
  final bool isTikTok;
  final String error;
  final String? lastDownloadedPath;

  DownloadState({
    this.isDownloading = false,
    this.progress = 0.0,
    this.currentVideo,
    this.manifest,
    this.tiktokData,
    this.isTikTok = false,
    this.error = '',
    this.lastDownloadedPath,
  });

  DownloadState copyWith({
    bool? isDownloading,
    double? progress,
    Video? currentVideo,
    StreamManifest? manifest,
    Map<String, dynamic>? tiktokData,
    bool? isTikTok,
    String? error,
    String? lastDownloadedPath,
  }) {
    return DownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      progress: progress ?? this.progress,
      currentVideo: currentVideo ?? this.currentVideo,
      manifest: manifest ?? this.manifest,
      tiktokData: tiktokData ?? this.tiktokData,
      isTikTok: isTikTok ?? this.isTikTok,
      error: error ?? this.error,
      lastDownloadedPath: lastDownloadedPath ?? this.lastDownloadedPath,
    );
  }
}

class DownloadNotifier extends StateNotifier<DownloadState> {
  final DownloadService _service;
  final Ref ref;

  DownloadNotifier(this._service, this.ref) : super(DownloadState());

  Future<void> fetchInfo(String url) async {
    try {
      if (url.contains('tiktok.com')) {
        final data = await _service.getTikTokInfo(url);
        state = state.copyWith(
          tiktokData: data, 
          isTikTok: true, 
          currentVideo: null, 
          manifest: null, 
          error: ''
        );
      } else {
        final video = await _service.getVideoInfo(url);
        final manifest = await _service.getManifest(video.id);
        state = state.copyWith(
          currentVideo: video, 
          manifest: manifest, 
          isTikTok: false,
          tiktokData: null,
          error: ''
        );
      }
    } catch (e) {
      state = state.copyWith(error: 'Не удалось получить информацию.', currentVideo: null, manifest: null, tiktokData: null);
    }
  }

  Future<void> startDownload({StreamInfo? streamInfo, bool isThumbnail = false, String? customTitle, String? customAuthor, bool isTikTokAudio = false, String? tiktokQuality, String? tiktokCodec, String? tiktokAudioCodec, String? targetQuality, num? targetFps, String? targetVideoCodec, int? targetBitrate, String? targetAudioCodec}) async {
    if (state.currentVideo == null && state.tiktokData == null) return;
    if (!state.isTikTok && !isThumbnail && streamInfo == null) return;
    
    state = state.copyWith(isDownloading: true, progress: 0.0, error: '', lastDownloadedPath: null);
    
    final notifId = DateTime.now().millisecondsSinceEpoch % 100000;
    final videoTitle = state.isTikTok ? (state.tiktokData!['title'] ?? 'TikTok') : (state.currentVideo?.title ?? 'Загрузка');
    
    void updateProgress(double p) {
      state = state.copyWith(progress: p);
      NotificationService().showProgress(id: notifId, title: videoTitle, progressPercent: (p * 100).toInt());
    }
    
    String? path;
    try {
      if (state.isTikTok) {
        if (isThumbnail) {
          path = await _service.downloadTikTokThumbnailAndSaveToGallery(
            state.tiktokData!,
            updateProgress,
          );
        } else {
          path = await _service.downloadTikTokAndSaveToGallery(
            state.tiktokData!,
            isTikTokAudio,
            updateProgress,
            customTitle: customTitle,
            customAuthor: customAuthor,
            tiktokQuality: tiktokQuality,
            tiktokCodec: tiktokCodec,
            tiktokAudioCodec: tiktokAudioCodec,
            targetQuality: targetQuality,
            targetFps: targetFps,
            targetVideoCodec: targetVideoCodec,
            targetAudioBitrate: targetBitrate,
            targetAudioCodec: targetAudioCodec,
          );
        }
      } else {
        if (isThumbnail) {
          path = await _service.downloadThumbnailAndSaveToGallery(
            state.currentVideo!, 
            updateProgress
          );
        } else {
          path = await _service.downloadAndSaveToGallery(
            state.currentVideo!, 
            streamInfo!, 
            updateProgress,
            customTitle: customTitle,
            customAuthor: customAuthor,
            targetQuality: targetQuality,
            targetFps: targetFps,
            targetVideoCodec: targetVideoCodec,
            targetAudioBitrate: targetBitrate,
            targetAudioCodec: targetAudioCodec
          );
        }
      }

      if (path != null) {
        // add to history
        final type = isThumbnail ? 'image' : ((streamInfo is AudioOnlyStreamInfo || isTikTokAudio) ? 'audio' : 'video');
        final id = state.isTikTok ? state.tiktokData!['id'] : state.currentVideo!.id.value;
        final title = state.isTikTok ? (state.tiktokData!['title'] ?? 'TikTok') : state.currentVideo!.title;
        final cover = state.isTikTok ? state.tiktokData!['cover'] : state.currentVideo!.thumbnails.highResUrl;
        
        final item = DownloadItem(
          id: id,
          title: title,
          thumbnailUrl: cover,
          type: type,
          downloadedAt: DateTime.now(),
          path: path,
        );
        ref.read(historyProvider.notifier).add(item);
        state = state.copyWith(isDownloading: false, progress: 1.0, lastDownloadedPath: path);
        NotificationService().showComplete(id: notifId, title: videoTitle);
      } else {
        state = state.copyWith(isDownloading: false, error: 'Ошибка загрузки (неизвестная причина)');
        NotificationService().showError(id: notifId, title: videoTitle, error: 'Неизвестная причина');
      }
    } catch (e) {
      state = state.copyWith(isDownloading: false, error: e.toString());
      NotificationService().showError(id: notifId, title: videoTitle, error: e.toString());
    }
  }
  
  void clear() {
    state = DownloadState();
  }
}

final downloadProvider = StateNotifierProvider<DownloadNotifier, DownloadState>((ref) {
  return DownloadNotifier(ref.read(downloadServiceProvider), ref);
});

class HistoryNotifier extends StateNotifier<List<DownloadItem>> {
  HistoryNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('history');
    if (data != null) {
      final List<dynamic> list = jsonDecode(data);
      state = list.map((e) => DownloadItem.fromJson(e)).toList();
    }
  }

  Future<void> add(DownloadItem item) async {
    state = [item, ...state];
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('history', jsonEncode(state.map((e) => e.toJson()).toList()));
  }

  Future<void> clear() async {
    state = [];
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('history');
  }
}

final historyProvider = StateNotifierProvider<HistoryNotifier, List<DownloadItem>>((ref) {
  return HistoryNotifier();
});
