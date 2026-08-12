enum QueueItemStatus { pending, downloading, done, error }

class QueueItem {
  final String id;
  final String url;
  final String title;
  final String thumbnailUrl;
  final String platform;
  final String format;
  final QueueItemStatus status;
  final double progress;
  final String? error;
  final String? outputPath;
  
  final String? quality;
  final num? fps;
  final String? codec;
  final int? bitrate;
  final String? audioCodec;
  final String? tiktokQuality;
  final String? tiktokCodec;
  final String? tiktokAudioCodec;
  final String? customTitle;
  final String? customAuthor;
  
  final Map<String, dynamic>? tiktokData;
  final String? streamUrl;
  final String? audioStreamUrl;
  final int? streamSizeBytes;
  final int? audioSizeBytes;
  final String? containerName;
  final String? audioContainerName;
  final bool isVideoOnly;
  final bool isAudioOnly;

  const QueueItem({
    required this.id,
    required this.url,
    required this.title,
    required this.thumbnailUrl,
    required this.platform,
    required this.format,
    this.status = QueueItemStatus.pending,
    this.progress = 0.0,
    this.error,
    this.outputPath,
    this.quality,
    this.fps,
    this.codec,
    this.bitrate,
    this.audioCodec,
    this.tiktokQuality,
    this.tiktokCodec,
    this.tiktokAudioCodec,
    this.customTitle,
    this.customAuthor,
    this.tiktokData,
    this.streamUrl,
    this.audioStreamUrl,
    this.streamSizeBytes,
    this.audioSizeBytes,
    this.containerName,
    this.audioContainerName,
    this.isVideoOnly = false,
    this.isAudioOnly = false,
  });

  QueueItem copyWith({
    String? id,
    String? url,
    String? title,
    String? thumbnailUrl,
    String? platform,
    String? format,
    QueueItemStatus? status,
    double? progress,
    String? error,
    String? outputPath,
    String? quality,
    num? fps,
    String? codec,
    int? bitrate,
    String? audioCodec,
    String? tiktokQuality,
    String? tiktokCodec,
    String? tiktokAudioCodec,
    String? customTitle,
    String? customAuthor,
    Map<String, dynamic>? tiktokData,
    String? streamUrl,
    String? audioStreamUrl,
    int? streamSizeBytes,
    int? audioSizeBytes,
    String? containerName,
    String? audioContainerName,
    bool? isVideoOnly,
    bool? isAudioOnly,
  }) {
    return QueueItem(
      id: id ?? this.id,
      url: url ?? this.url,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      platform: platform ?? this.platform,
      format: format ?? this.format,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      outputPath: outputPath ?? this.outputPath,
      quality: quality ?? this.quality,
      fps: fps ?? this.fps,
      codec: codec ?? this.codec,
      bitrate: bitrate ?? this.bitrate,
      audioCodec: audioCodec ?? this.audioCodec,
      tiktokQuality: tiktokQuality ?? this.tiktokQuality,
      tiktokCodec: tiktokCodec ?? this.tiktokCodec,
      tiktokAudioCodec: tiktokAudioCodec ?? this.tiktokAudioCodec,
      customTitle: customTitle ?? this.customTitle,
      customAuthor: customAuthor ?? this.customAuthor,
      tiktokData: tiktokData ?? this.tiktokData,
      streamUrl: streamUrl ?? this.streamUrl,
      audioStreamUrl: audioStreamUrl ?? this.audioStreamUrl,
      streamSizeBytes: streamSizeBytes ?? this.streamSizeBytes,
      audioSizeBytes: audioSizeBytes ?? this.audioSizeBytes,
      containerName: containerName ?? this.containerName,
      audioContainerName: audioContainerName ?? this.audioContainerName,
      isVideoOnly: isVideoOnly ?? this.isVideoOnly,
      isAudioOnly: isAudioOnly ?? this.isAudioOnly,
    );
  }
}
