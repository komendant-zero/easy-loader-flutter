class DownloadItem {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String type; // 'video' or 'audio'
  final DateTime downloadedAt;
  final String path;

  DownloadItem({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.type,
    required this.downloadedAt,
    required this.path,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'thumbnailUrl': thumbnailUrl,
        'type': type,
        'downloadedAt': downloadedAt.toIso8601String(),
        'path': path,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
        id: json['id'],
        title: json['title'],
        thumbnailUrl: json['thumbnailUrl'],
        type: json['type'],
        downloadedAt: DateTime.parse(json['downloadedAt']),
        path: json['path'] ?? '',
      );
}
