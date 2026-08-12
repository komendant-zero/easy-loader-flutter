import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:share_plus/share_plus.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'settings_screen.dart';
import '../providers/theme_provider.dart';
import '../providers/download_provider.dart';
import 'history_screen.dart';

enum DownloadFormat { video, audio, thumbnail }

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  AppThemeData get themeData => AppThemeData.fromPreset(ref.watch(themeProvider));
  final TextEditingController _urlController = TextEditingController();
  DownloadFormat _format = DownloadFormat.video;
  int _selectedIndex = 0;

  // Platform detection
  String? _detectedPlatform; // 'youtube' | 'tiktok' | null
  
  String? _selectedQuality;
  num? _selectedFps;
  String? _selectedCodec;

  // Audio selections
  int? _selectedBitrate;
  String? _selectedAudioCodec;

  // Custom metadata for Audio
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _authorController = TextEditingController();

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _format.index,
      viewportFraction: 0.4,
    );
  }

  void _onFormatChanged(DownloadFormat format) {
    if (_format == format) return;
    setState(() {
      _format = format;
      _selectedIndex = 0;
    });
  }

  List<StreamInfo> _getAvailableStreams(StreamManifest? manifest) {
    if (manifest == null || _format == DownloadFormat.thumbnail) return [];
    if (_format == DownloadFormat.audio) {
      final list = manifest.audioOnly.toList();
      list.sort((a, b) => b.bitrate.compareTo(a.bitrate));
      return list;
    } else {
      final list = <VideoStreamInfo>[...manifest.muxed, ...manifest.videoOnly];
      list.sort((a, b) {
        final cmp = b.videoResolution.height.compareTo(a.videoResolution.height);
        if (cmp != 0) return cmp;
        return b.framerate.framesPerSecond.compareTo(a.framerate.framesPerSecond);
      });
      return list;
    }
  }

  String _formatStream(StreamInfo info) {
    if (info is AudioOnlyStreamInfo) {
      return '${info.bitrate.kiloBitsPerSecond.round()} kbps • ${info.audioCodec} • ${info.container.name.toUpperCase()}';
    } else if (info is VideoOnlyStreamInfo) {
      return '${info.qualityLabel} (${info.framerate.framesPerSecond}fps) • ${info.videoCodec} • ${info.container.name.toUpperCase()}';
    } else if (info is MuxedStreamInfo) {
      return '${info.qualityLabel} (${info.framerate.framesPerSecond}fps) • ${info.videoCodec} (Muxed) • ${info.container.name.toUpperCase()}';
    }
    return '';
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String? _detectPlatform(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) return 'youtube';
    if (url.contains('tiktok.com')) return 'tiktok';
    return null;
  }

  void _onUrlChanged(String url) {
    setState(() {
      _selectedIndex = 0;
      _detectedPlatform = _detectPlatform(url);
    });
    if (url.contains('youtube.com') || url.contains('youtu.be') || url.contains('tiktok.com')) {
      ref.read(downloadProvider.notifier).fetchInfo(url).then((_) {
        final downloadState = ref.read(downloadProvider);
        if (downloadState.isTikTok && downloadState.tiktokData != null) {
          _titleController.text = downloadState.tiktokData!['title'] ?? 'TikTok Video';
          _authorController.text = downloadState.tiktokData!['author']?['nickname'] ?? 'TikTok User';
        } else if (downloadState.currentVideo != null) {
          _titleController.text = downloadState.currentVideo!.title;
          _authorController.text = downloadState.currentVideo!.author;
        }
        setState(() {
          _selectedQuality    = '1080p';
          _selectedFps        = 60;
          _selectedCodec      = 'H.264';
          _selectedBitrate    = 160;
          _selectedAudioCodec = 'AAC';
        });
      });
    } else {
      ref.read(downloadProvider.notifier).clear();
    }
  }

  String _simplifyCodecStatic(String codec) {
    codec = codec.toLowerCase();
    if (codec.contains('avc')) return 'H.264';
    if (codec.contains('vp9') || codec.contains('vp09')) return 'VP9';
    if (codec.contains('av01') || codec.contains('av1')) return 'AV1';
    if (codec.contains('mp4a')) return 'AAC';
    if (codec.contains('opus')) return 'Opus';
    if (codec.contains('vorbis')) return 'Vorbis';
    return codec.split('.').first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final preset = ref.watch(themeProvider);
    final downloadState = ref.watch(downloadProvider);
    final availableStreams = _getAvailableStreams(downloadState.manifest);
    StreamInfo? selectedStream;
    bool isExactVideoMatch = false;
    
    if (_format == DownloadFormat.thumbnail) {
      selectedStream = null;
    } else if (_format == DownloadFormat.audio) {
      if (availableStreams.isNotEmpty) {
        final audioStreams = availableStreams.whereType<AudioOnlyStreamInfo>().toList();
        
        if (_selectedBitrate != null && _selectedAudioCodec != null) {
          try {
            selectedStream = audioStreams.firstWhere(
              (e) => e.bitrate.kiloBitsPerSecond.round() == _selectedBitrate && _simplifyCodecStatic(e.audioCodec) == _selectedAudioCodec
            );
          } catch (_) {
            selectedStream = audioStreams.firstWhere(
              (e) => e.bitrate.kiloBitsPerSecond.round() == _selectedBitrate,
              orElse: () => audioStreams.first
            );
          }
        } else {
          selectedStream = audioStreams.first;
        }
      }
    } else if (_format == DownloadFormat.video) {
      if (availableStreams.isNotEmpty) {
        final videoStreams = availableStreams.whereType<VideoStreamInfo>().toList();
        if (_selectedQuality != null) {
          final q = _selectedQuality == '4K' ? '2160' : _selectedQuality!;
          final fps = _selectedFps?.round();
          final codec = _selectedCodec;

          // Пробуем точное совпадение качества + FPS + кодек
          selectedStream = videoStreams.cast<VideoStreamInfo?>().firstWhere(
            (e) => e!.qualityLabel.startsWith(q)
                && (fps == null || e.framerate.framesPerSecond.round() == fps)
                && (codec == null || _simplifyCodecStatic(e.videoCodec) == codec),
            orElse: () => null,
          );
          if (selectedStream != null) isExactVideoMatch = true;
          
          // Качество + FPS
          selectedStream ??= videoStreams.cast<VideoStreamInfo?>().firstWhere(
            (e) => e!.qualityLabel.startsWith(q)
                && (fps == null || e.framerate.framesPerSecond.round() == fps),
            orElse: () => null,
          );
          // Только качество
          selectedStream ??= videoStreams.cast<VideoStreamInfo?>().firstWhere(
            (e) => e!.qualityLabel.startsWith(q),
            orElse: () => null,
          );
          // Ближайшее по разрешению (если запрошенное недоступно)
          if (selectedStream == null) {
            final reqH = int.tryParse(q.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
            videoStreams.sort((a, b) {
              final aH = int.tryParse(a.qualityLabel.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              final bH = int.tryParse(b.qualityLabel.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
              return (aH - reqH).abs().compareTo((bH - reqH).abs());
            });
            selectedStream = videoStreams.first;
          }
        } else {
          selectedStream = videoStreams.first;
        }
      }
    }

    return Scaffold(
      backgroundColor: themeData.backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Easy Loader',
          style: GoogleFonts.outfit(
            color: themeData.textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.history, color: themeData.textColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => HistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: Icon(Icons.settings, color: themeData.textColor),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): () async {
            final data = await Clipboard.getData(Clipboard.kTextPlain);
            if (data != null && data.text != null) {
              _urlController.text = data.text!;
              _onUrlChanged(data.text!);
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 800;

            final leftPaneChildren = <Widget>[
              // URL Input with platform detection
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  color: themeData.backgroundColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _detectedPlatform == 'youtube'
                        ? Colors.white.withValues(alpha: 0.25)
                        : _detectedPlatform == 'tiktok'
                            ? const Color(0xFF69C9D0).withValues(alpha: 0.5)
                            : themeData.cardColor,
                    width: _detectedPlatform != null ? 1.5 : 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: TextField(
                  controller: _urlController,
                  onChanged: _onUrlChanged,
                  style: GoogleFonts.inter(color: themeData.textColor),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'https://youtube.com/watch?v=...',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF5A5A6E)),
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _detectedPlatform == 'youtube'
                          ? const FaIcon(FontAwesomeIcons.youtube,
                              key: ValueKey('yt'), color: Color(0xFFFF0000), size: 20)
                          : _detectedPlatform == 'tiktok'
                              ? const FaIcon(FontAwesomeIcons.tiktok,
                                  key: ValueKey('tt'), color: Color(0xFF69C9D0), size: 18)
                              : Icon(Icons.link,
                                  key: ValueKey('link'), color: Color(0xFF3B82F6)),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.paste, color: Color(0xFF8A8A9E)),
                      onPressed: () async {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data != null && data.text != null) {
                          _urlController.text = data.text!;
                          _onUrlChanged(data.text!);
                        }
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // YouTube — оригинальная иконка
                  _BrandIcon(
                    child: Container(
                      width: 40,
                      height: 40,
                      color: Colors.white,
                      child: Center(
                        child: FaIcon(FontAwesomeIcons.youtube, color: Color(0xFFFF0000), size: 26),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  // TikTok — оригинальная иконка
                  _BrandIcon(
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: FaIcon(FontAwesomeIcons.tiktok, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              SizedBox(
                height: 52,
                child: PageView.builder(
                  controller: _pageController,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    _onFormatChanged(DownloadFormat.values[index]);
                  },
                  itemCount: DownloadFormat.values.length,
                  itemBuilder: (context, index) {
                    final format = DownloadFormat.values[index];
                    return AnimatedBuilder(
                      animation: _pageController,
                      builder: (context, child) {
                        double value = 1.0;
                        if (_pageController.position.haveDimensions) {
                          value = (_pageController.page! - index).abs();
                        } else {
                          value = (_format.index - index).abs().toDouble();
                        }
                        final scale = (1 - (value * 0.15)).clamp(0.85, 1.0);
                        final opacity = (1 - (value * 0.5)).clamp(0.3, 1.0);
                        return Transform.scale(
                          scale: scale,
                          child: Opacity(
                            opacity: opacity,
                            child: child,
                          ),
                        );
                      },
                      child: _buildSliderItem(format),
                    );
                  },
                ),
              ),
              SizedBox(height: 32),
            ];

            final hasVideo = downloadState.currentVideo != null || (downloadState.isTikTok && downloadState.tiktokData != null);

            final rightPaneChildren = <Widget>[
              // Video Info Preview
              if (hasVideo)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    color: themeData.cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeData.cardColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: CachedNetworkImage(
                            imageUrl: downloadState.isTikTok 
                                ? downloadState.tiktokData!['cover'] 
                                : downloadState.currentVideo!.thumbnails.highResUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(color: themeData.primaryColor),
                            ),
                            errorWidget: (context, url, error) => Icon(Icons.error, color: themeData.textColor),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              downloadState.isTikTok 
                                ? (downloadState.tiktokData!['title'] ?? 'TikTok Video') 
                                : downloadState.currentVideo!.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: themeData.textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              downloadState.isTikTok 
                                ? (downloadState.tiktokData!['author']?['nickname'] ?? 'TikTok User') 
                                : downloadState.currentVideo!.author,
                              style: GoogleFonts.inter(
                                color: themeData.secondaryTextColor,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                )
              else if (isDesktop)
                // Placeholder when no video is selected (Only shown on Desktop to fill the right pane)
                Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    color: themeData.cardColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: themeData.cardColor, width: 2, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.video_library_rounded, size: 80, color: Color(0xFF3B82F6)),
                      SizedBox(height: 24),
                      Text(
                        'Ожидание ссылки',
                        style: GoogleFonts.outfit(
                          color: themeData.textColor,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Вставьте ссылку на видео в поле слева, чтобы начать скачивание.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: themeData.secondaryTextColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),

              if (downloadState.error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            downloadState.error,
                            style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
                          ),
                        ),
                        SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            final url = _urlController.text.trim();
                            if (url.isNotEmpty) {
                              ref.read(downloadProvider.notifier).fetchInfo(url);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: themeData.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Повторить',
                              style: GoogleFonts.inter(
                                color: themeData.textColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              SizedBox(height: 32),

              // Download Button & Progress
              if (hasVideo) ...[
                if (downloadState.isDownloading) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (downloadState.progress >= 0.85 && downloadState.progress < 1.0) ? null : downloadState.progress,
                      backgroundColor: themeData.cardColor,
                      valueColor: AlwaysStoppedAnimation<Color>(themeData.primaryColor),
                      minHeight: 12,
                    ),
                  ),
                  SizedBox(height: 12),
                  Center(
                    child: Text(
                      (downloadState.progress >= 0.85 && downloadState.progress < 1.0)
                          ? 'Обработка...'
                          : '${(downloadState.progress * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.outfit(
                        color: themeData.textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else ...[
                  if (!downloadState.isDownloading) ...[
                    _buildUnifiedSelectors(),
                    SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_format != DownloadFormat.thumbnail && selectedStream == null && !downloadState.isTikTok) ? null : () async {
                        await ref.read(downloadProvider.notifier).startDownload(
                          streamInfo: selectedStream,
                          isThumbnail: _format == DownloadFormat.thumbnail,
                          customTitle: _format == DownloadFormat.audio ? _titleController.text : null,
                          customAuthor: _format == DownloadFormat.audio ? _authorController.text : null,
                          isTikTokAudio: _format == DownloadFormat.audio,
                          tiktokQuality: _tikTokQualityMapped,
                          tiktokCodec: _tikTokCodecMapped,
                          tiktokAudioCodec: _tikTokAudioCodecMapped,
                          targetQuality: isExactVideoMatch ? null : _selectedQuality,
                          targetFps: isExactVideoMatch ? null : _selectedFps,
                          targetVideoCodec: isExactVideoMatch ? null : _selectedCodec,
                          targetBitrate: _selectedBitrate,
                          targetAudioCodec: _selectedAudioCodec,
                        );
                        if (mounted && ref.read(downloadProvider).error.isEmpty) {
                          String type = _format == DownloadFormat.video ? 'Видео' : _format == DownloadFormat.audio ? 'Аудио' : 'Превью';
                          bool isDesktopSys = !Platform.isAndroid && !Platform.isIOS;
                          String folderName = isDesktopSys ? 'Downloads' : 'галерею';
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('$type успешно сохранено в $folderName!', style: GoogleFonts.inter(color: themeData.textColor, fontWeight: FontWeight.bold)),
                            backgroundColor: const Color(0xFF10B981),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ));
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeData.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        (!Platform.isAndroid && !Platform.isIOS) ? 'СКАЧАТЬ' : 'СКАЧАТЬ В ГАЛЕРЕЮ',
                        style: GoogleFonts.outfit(
                          color: themeData.primaryButtonTextColor,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ),
                ]
              ],
            ];

            if (isDesktop) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: leftPaneChildren,
                      ),
                    ),
                  ),
                  Container(width: 1, color: themeData.cardColor),
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: rightPaneChildren,
                      ),
                    ),
                  ),
                ],
              );
            }

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...leftPaneChildren,
                  ...rightPaneChildren,
                ],
              ),
            );
          },
        ),
      ))),
    );
  }

  String _simplifyCodec(String codec) {
    codec = codec.toLowerCase();
    if (codec.contains('avc')) return 'H.264';
    if (codec.contains('vp9') || codec.contains('vp09')) return 'VP9';
    if (codec.contains('av01') || codec.contains('av1')) return 'AV1';
    if (codec.contains('mp4a')) return 'AAC';
    if (codec.contains('opus')) return 'Opus';
    if (codec.contains('vorbis')) return 'Vorbis';
    return codec.split('.').first.toUpperCase();
  }

  Widget _buildChipGroup<T>({
    required String title,
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required void Function(T) onSelected,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();
    if (value != null && !items.contains(value)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onSelected(items.first);
      });
    } else if (value == null && items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onSelected(items.first);
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            color: themeData.secondaryTextColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items.map((e) {
            final isSelected = e == value;
            return ChoiceChip(
              label: Text(labelBuilder(e)),
              selected: isSelected,
              onSelected: (_) => onSelected(e),
              backgroundColor: themeData.backgroundColor,
              selectedColor: themeData.primaryColor,
              labelStyle: GoogleFonts.inter(
                color: isSelected ? Colors.white : themeData.secondaryTextColor,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? themeData.primaryColor : themeData.cardColor,
                ),
              ),
              showCheckmark: false,
            );
          }).toList(),
        ),
        SizedBox(height: 16),
      ],
    );
  }

  String get _tikTokQualityMapped {
    const hd = {'4K', '1440p', '1080p', '720p'};
    return hd.contains(_selectedQuality) ? 'HD (Без водяного знака)' : 'SD (Без водяного знака)';
  }

  String get _tikTokCodecMapped =>
      _selectedCodec == 'H.265' ? 'H.265 (HEVC)' : 'H.264';

  String get _tikTokAudioCodecMapped {
    if (_selectedAudioCodec == 'FLAC') return 'FLAC';
    if (_selectedAudioCodec == 'MP3') return 'MP3';
    return 'AAC';
  }

  Widget _buildUnifiedSelectors() {
    if (_format == DownloadFormat.video) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChipGroup<String>(
            title: 'КАЧЕСТВО',
            value: _selectedQuality,
            items: ['4K', '1440p', '1080p', '720p', '480p', '360p'],
            labelBuilder: (q) => q,
            onSelected: (val) => setState(() => _selectedQuality = val),
          ),
          _buildChipGroup<num>(
            title: 'FPS',
            value: _selectedFps,
            items: [60, 30, 24],
            labelBuilder: (f) => f.toInt().toString(),
            onSelected: (val) => setState(() => _selectedFps = val),
          ),
          _buildChipGroup<String>(
            title: 'КОДЕК',
            value: _selectedCodec,
            items: ['H.264', 'H.265', 'VP9', 'AV1'],
            labelBuilder: (c) => c,
            onSelected: (val) => setState(() => _selectedCodec = val),
          ),
        ],
      );
    } else if (_format == DownloadFormat.audio) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildChipGroup<int>(
            title: 'БИТРЕЙТ',
            value: _selectedBitrate,
            items: [320, 256, 160, 128, 64],
            labelBuilder: (b) => '${b}k',
            onSelected: (val) => setState(() => _selectedBitrate = val),
          ),
          _buildChipGroup<String>(
            title: 'КОДЕК',
            value: _selectedAudioCodec,
            items: ['MP3', 'AAC', 'Opus', 'FLAC'],
            labelBuilder: (c) => c,
            onSelected: (val) => setState(() => _selectedAudioCodec = val),
          ),
          SizedBox(height: 16),
          Text(
            'ТЕГИ (ID3)',
            style: GoogleFonts.inter(
              color: themeData.secondaryTextColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: themeData.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeData.cardColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _titleController,
              style: GoogleFonts.inter(color: themeData.textColor, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Название',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF5A5A6E)),
              ),
            ),
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: themeData.backgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: themeData.cardColor),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _authorController,
              style: GoogleFonts.inter(color: themeData.textColor, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Исполнитель',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF5A5A6E)),
              ),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSliderItem(DownloadFormat format) {
    final title = format == DownloadFormat.video ? 'Видео' 
                : format == DownloadFormat.audio ? 'Аудио' : 'Превью';
    final isSelected = _format == format;

    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          format.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: isSelected ? themeData.primaryColor : themeData.backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? themeData.primaryColor : themeData.cardColor,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: themeData.primaryColor.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : [],
        ),
        child: Center(
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: isSelected ? Colors.white : themeData.secondaryTextColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

/// Иконка в стиле App Store — скруглённый квадрат с тенью
class _BrandIcon extends ConsumerWidget {
  final Widget child;
  const _BrandIcon({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preset = ref.watch(themeProvider);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: child,
      ),
    );
  }
}
