import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DownloadService {

  Future<Directory> _getTargetDir(Directory tempDir, bool isDesktop) async {
    Directory targetDir = isDesktop ? ((await getDownloadsDirectory()) ?? tempDir) : tempDir;
    if (isDesktop) {
      final prefs = await SharedPreferences.getInstance();
      final customPath = prefs.getString('custom_save_path');
      if (customPath != null && Directory(customPath).existsSync()) {
        targetDir = Directory(customPath);
      }
    }
    return targetDir;
  }

  List<String> _buildFfmpegArgs({
    required String? videoPath,
    required String? audioPath,
    required String outPath,
    String? thumbPath,
    String? title,
    String? artist,
    String? targetQuality,
    num? targetFps,
    String? targetVideoCodec,
    int? targetAudioBitrate,
    String? targetAudioCodec,
    bool isAudioOnly = false,
  }) {
    List<String> args = ['-y'];
    
    if (videoPath != null) args.addAll(['-i', videoPath]);
    if (audioPath != null) args.addAll(['-i', audioPath]);
    
    if (isAudioOnly) {
      if (thumbPath != null) {
        args.addAll(['-i', thumbPath, '-map', '0:a', '-map', '1:v', '-disposition:v:0', 'attached_pic', '-c:v', 'copy']);
      } else {
        args.addAll(['-map', '0:a']);
      }
      String acodec = 'copy';
      if (targetAudioCodec == 'MP3') acodec = 'libmp3lame';
      else if (targetAudioCodec == 'AAC') acodec = 'aac';
      else if (targetAudioCodec == 'Opus') acodec = 'libopus';
      else if (targetAudioCodec == 'FLAC') acodec = 'flac';
      else if (targetAudioCodec == 'WAV') acodec = 'pcm_s16le';
      args.addAll(['-c:a', acodec]);
      
      if (targetAudioBitrate != null && acodec != 'copy') {
        args.addAll(['-b:a', '${targetAudioBitrate}k']);
      }
    } else {
      if (videoPath != null && audioPath != null) {
        args.addAll(['-map', '0:v', '-map', '1:a']);
      }
      
      bool encodeV = targetQuality != null || targetFps != null || (targetVideoCodec != null && targetVideoCodec != 'copy');
      if (encodeV) {
        String vcodec = 'libx264';
        if (targetVideoCodec == 'H.265' || targetVideoCodec == 'H.265 (HEVC)') vcodec = 'libx265';
        else if (targetVideoCodec == 'VP9') vcodec = 'libvpx-vp9';
        else if (targetVideoCodec == 'AV1') vcodec = 'libsvtav1';
        args.addAll(['-c:v', vcodec, '-crf', '28', '-preset', 'fast']);
        
        List<String> vf = [];
        if (targetQuality != null) {
          String h = targetQuality.replaceAll(RegExp(r'[^0-9]'), '');
          if (targetQuality.contains('4K') || targetQuality.contains('2160')) h = '2160';
          if (h.isNotEmpty) vf.add('scale=-2:' + h);
        }
        if (vf.isNotEmpty) args.addAll(['-vf', vf.join(',')]);
        if (targetFps != null) args.addAll(['-r', targetFps.toString()]);
      } else {
        args.addAll(['-c:v', 'copy']);
      }
      
      if (audioPath != null || (videoPath != null && targetAudioCodec != null)) {
        String acodec = 'copy';
        if (targetAudioCodec == 'MP3') acodec = 'libmp3lame';
        else if (targetAudioCodec == 'AAC') acodec = 'aac';
        else if (targetAudioCodec == 'Opus') acodec = 'libopus';
        else if (targetAudioCodec == 'FLAC') acodec = 'flac';
        args.addAll(['-c:a', acodec]);
        if (targetAudioBitrate != null && acodec != 'copy') {
          args.addAll(['-b:a', '${targetAudioBitrate}k']);
        }
      } else {
        args.addAll(['-c:a', 'copy']);
      }
    }
    
    if (title != null && title.isNotEmpty) args.addAll(['-metadata', 'title=' + title]);
    if (artist != null && artist.isNotEmpty) args.addAll(['-metadata', 'artist=' + artist]);
    
    args.add(outPath);
    return args;
  }

  final YoutubeExplode _yt = YoutubeExplode();
  final Dio _dio = Dio();
  
  Future<Map<String, dynamic>> getTikTokInfo(String url) async {
    final formData = FormData.fromMap({'url': url});
    final response = await _dio.post(
      'https://tikwm.com/api/',
      data: formData,
    );
    if (response.data['code'] == 0) {
      return response.data['data'];
    } else {
      throw Exception(response.data['msg'] ?? 'Ошибка получения TikTok видео');
    }
  }
  
  String? _desktopFfmpegPath;

  Future<String> _getDesktopFfmpeg() async {
    if (_desktopFfmpegPath != null) return _desktopFfmpegPath!;
    
    // Check if system ffmpeg exists
    try {
      final res = await Process.run('ffmpeg', ['-version']);
      if (res.exitCode == 0) {
        _desktopFfmpegPath = 'ffmpeg';
        return 'ffmpeg';
      }
    } catch (_) {}

    // Download FFmpeg for Windows/Linux if missing
    final supportDir = await getApplicationSupportDirectory();
    final ext = Platform.isWindows ? '.exe' : '';
    final exePath = '${supportDir.path}/ffmpeg$ext';
    
    if (File(exePath).existsSync()) {
      _desktopFfmpegPath = exePath;
      return exePath;
    }

    try {
      final zipPath = '${supportDir.path}/ffmpeg.zip';
      String url = '';
      if (Platform.isWindows) {
        url = 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip';
      } else if (Platform.isLinux) {
        url = 'https://johnvansickle.com/ffmpeg/releases/ffmpeg-release-amd64-static.tar.xz';
      }
      
      if (url.isEmpty) return 'ffmpeg';
      
      await _dio.download(url, zipPath);
      
      if (Platform.isWindows) {
        final bytes = File(zipPath).readAsBytesSync();
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final file in archive) {
          if (file.name.endsWith('ffmpeg.exe')) {
            File(exePath)
              ..createSync(recursive: true)
              ..writeAsBytesSync(file.content as List<int>);
            break;
          }
        }
      } else {
        // Fallback for linux, just use system ffmpeg or assume user installs it
        await Process.run('tar', ['-xf', zipPath, '-C', supportDir.path]);
        final dirs = supportDir.listSync().whereType<Directory>().where((e) => e.path.contains('ffmpeg-'));
        if (dirs.isNotEmpty) {
          final linuxFfmpeg = '${dirs.first.path}/ffmpeg';
          File(linuxFfmpeg).copySync(exePath);
          await Process.run('chmod', ['+x', exePath]);
        }
      }
      
      try { File(zipPath).deleteSync(); } catch (_) {}
      
      _desktopFfmpegPath = exePath;
      return exePath;
    } catch (e) {
      return 'ffmpeg'; // fallback to system and pray
    }
  }

  String _sanitizeYoutubeUrl(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtube') && uri.pathSegments.contains('shorts')) {
        final shortsIndex = uri.pathSegments.indexOf('shorts');
        if (shortsIndex != -1 && shortsIndex + 1 < uri.pathSegments.length) {
          final videoId = uri.pathSegments[shortsIndex + 1];
          return 'https://www.youtube.com/watch?v=$videoId';
        }
      }
    } catch (_) {}
    return url;
  }

  Future<Video> getVideoInfo(String url) async {
    return await _yt.videos.get(_sanitizeYoutubeUrl(url));
  }

  Future<StreamManifest> getManifest(dynamic videoId) async {
    return await _yt.videos.streamsClient.getManifest(videoId);
  }

  Future<String?> downloadAndSaveToGallery(
    Video video, 
    StreamInfo streamInfo, 
    Function(double) onProgress,
    {String? customTitle,
    String? customAuthor,
    String? targetQuality,
    num? targetFps,
    String? targetVideoCodec,
    int? targetAudioBitrate,
    String? targetAudioCodec}
  ) async {
    try {
      final isAudio = streamInfo is AudioOnlyStreamInfo;
      final isVideoOnly = streamInfo is VideoOnlyStreamInfo;
      final tempDir = await getTemporaryDirectory();
      
      String baseName = video.title;
      if (customTitle != null && customTitle.isNotEmpty) {
        baseName = customTitle;
      }
      
      final safeTitle = baseName
          .replaceAll(RegExp(r'[^\p{L}\p{N}\s\-_]+', unicode: true), '')
          .replaceAll(RegExp(r'\s+'), '_');

      String finalPath = '';
      String fileExt = streamInfo.container.name;
      
      // Determine final folder (Downloads on Desktop, temp on Mobile before Gal)
      final bool isDesktop = !Platform.isAndroid && !Platform.isIOS;
      final Directory targetDir = await _getTargetDir(tempDir, isDesktop);

      Future<void> downloadStream(StreamInfo info, String savePath, double progressStart, double progressLength) async {
        final total = info.size.totalBytes;
        
        int chunkSize = 10485760; // 10MB chunks
        int numChunks = (total / chunkSize).ceil();
        if (numChunks == 0) numChunks = 1;
        
        List<int> chunkProgress = List.filled(numChunks, 0);
        int nextChunkIndex = 0;
        
        Future<void> worker() async {
          while (nextChunkIndex < numChunks) {
            int chunkIndex = nextChunkIndex++;
            int start = chunkIndex * chunkSize;
            int end = start + chunkSize - 1;
            if (end >= total) end = total - 1;
            
            // YouTube requires the range in the URL query for Web clients, NOT as an HTTP header!
            String requestUrl = info.url.toString();
            if (requestUrl.contains('?')) {
              requestUrl += '&range=$start-$end';
            } else {
              requestUrl += '?range=$start-$end';
            }
            
            String chunkPath = '${savePath}_chunk_$chunkIndex';
            File chunkFile = File(chunkPath);
            
            int retries = 0;
            while (retries < 10) {
              try {
                chunkProgress[chunkIndex] = 0;
                final response = await _dio.get(
                  requestUrl,
                  onReceiveProgress: (count, _) {
                    chunkProgress[chunkIndex] = count;
                    int totalReceived = chunkProgress.fold(0, (sum, element) => sum + element);
                    if (total > 0) {
                      onProgress(progressStart + (totalReceived / total) * progressLength);
                    }
                  },
                  options: Options(
                    responseType: ResponseType.bytes,
                    receiveTimeout: const Duration(seconds: 120),
                    sendTimeout: const Duration(seconds: 120),
                    validateStatus: (status) => status! >= 200 && status < 400,
                    headers: {
                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
                      'Accept': '*/*',
                      'Referer': 'https://www.youtube.com/',
                      'Origin': 'https://www.youtube.com',
                    },
                  ),
                );
                
                final List<int> bytes = response.data;
                chunkFile.writeAsBytesSync(bytes);
                break;
              } catch (e) {
                retries++;
                if (retries >= 10) throw Exception("Сбой сети: ${e.toString()}");
                await Future.delayed(const Duration(seconds: 3));
              }
            }
          }
        }
        
        // Use 4 concurrent connections
        List<Future<void>> workers = [];
        int concurrency = 4;
        for (int i = 0; i < concurrency; i++) {
          workers.add(worker());
        }
        await Future.wait(workers);
        
        // Merge chunks
        final file = File(savePath);
        final raf = file.openSync(mode: FileMode.write);
        try {
          for (int i = 0; i < numChunks; i++) {
            String chunkPath = '${savePath}_chunk_$i';
            File chunkFile = File(chunkPath);
            if (chunkFile.existsSync()) {
              raf.writeFromSync(chunkFile.readAsBytesSync());
              chunkFile.deleteSync();
            }
          }
        } finally {
          raf.closeSync();
        }
      }

      if (isVideoOnly) {
        final manifest = await _yt.videos.streamsClient.getManifest(video.id);
        final audioStream = manifest.audioOnly.withHighestBitrate();
        
        final videoExt = streamInfo.container.name;
        var audioExt = audioStream.container.name;
        
        final videoPath = '${tempDir.path}/video_temp_${DateTime.now().millisecondsSinceEpoch}.$videoExt';
        var audioPath = '${tempDir.path}/audio_temp_${DateTime.now().millisecondsSinceEpoch}.$audioExt';
        
        fileExt = videoExt == 'webm' ? 'mkv' : 'mp4';
        finalPath = '${targetDir.path}/${safeTitle.take(30)}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        bool videoFailed = false;
        try {
          await downloadStream(streamInfo, videoPath, 0.0, 0.4);
        } catch (e) {
          if (e.toString().contains('403') || e.toString().contains('Сбой сети')) {
            videoFailed = true;
          } else {
            throw e;
          }
        }
        
        if (videoFailed) {
          // If 1080p video itself fails with 403, fallback to a Muxed stream entirely!
          if (manifest.muxed.isNotEmpty) {
            final fallbackStream = manifest.muxed.withHighestBitrate();
            fileExt = fallbackStream.container.name;
            finalPath = '${targetDir.path}/${safeTitle.take(30)}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
            try {
              await downloadStream(fallbackStream, finalPath, 0.0, 1.0);
              return await _saveFile(finalPath, fileExt, safeTitle, false, isDesktop);
            } catch (e) {
              if (e.toString().contains('403')) throw Exception('YouTube временно заблокировал скачивание видео в этом качестве. Выберите другое качество.');
              throw e;
            }
          } else {
            throw Exception('YouTube временно заблокировал скачивание видео в этом качестве. Выберите другое качество.');
          }
        }

        try {
          await downloadStream(audioStream, audioPath, 0.4, 0.4);
        } catch (e) {
          if (e.toString().contains('403') || e.toString().contains('Сбой сети')) {
            if (manifest.muxed.isNotEmpty) {
              final fallbackStream = manifest.muxed.withHighestBitrate();
              audioExt = fallbackStream.container.name;
              final newAudioPath = '${tempDir.path}/audio_temp_${DateTime.now().millisecondsSinceEpoch}.$audioExt';
              await downloadStream(fallbackStream, newAudioPath, 0.4, 0.4);
              audioPath = newAudioPath;
            } else {
              throw e;
            }
          } else {
            throw e;
          }
        }
        
        onProgress(0.85); // Muxing...
        
        String audioCodec = fileExt == 'mkv' ? 'copy' : 'aac';
        
        final args = _buildFfmpegArgs(
          videoPath: videoPath,
          audioPath: audioPath,
          outPath: finalPath,
          targetQuality: targetQuality,
          targetFps: targetFps,
          targetVideoCodec: targetVideoCodec,
          targetAudioBitrate: targetAudioBitrate,
          targetAudioCodec: targetAudioCodec ?? (audioCodec == 'copy' ? null : 'AAC'),
        );
        int totalDur = video.duration?.inSeconds ?? 0;
        if (isDesktop) {
          final ffmpegPath = await _getDesktopFfmpeg();
          final process = await Process.start(ffmpegPath, args);
          process.stderr.transform(utf8.decoder).listen((data) {
            if (totalDur > 0) {
              final match = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)').firstMatch(data);
              if (match != null) {
                final h = int.parse(match.group(1)!);
                final m = int.parse(match.group(2)!);
                final s = double.parse(match.group(3)!);
                final seconds = h * 3600 + m * 60 + s;
                double p = seconds / totalDur;
                if (p > 1.0) p = 1.0;
                onProgress(0.85 + (p * 0.14));
              }
            }
          });
          final exitCode = await process.exitCode;
          
          try {
            File(videoPath).deleteSync();
            File(audioPath).deleteSync();
          } catch (_) {}

          if (exitCode != 0) throw Exception('Ошибка FFmpeg');
        } else {
          final session = await FFmpegKit.executeWithArgumentsAsync(args, (s) {}, (l) {}, (statistics) {
             int timeMs = statistics.getTime();
             if (totalDur > 0 && timeMs > 0) {
               double p = (timeMs / 1000) / totalDur;
               if (p > 1.0) p = 1.0;
               onProgress(0.85 + p * 0.14);
             }
          });
          
          while (await session.getReturnCode() == null) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          final returnCode = await session.getReturnCode();
          
          try {
            File(videoPath).deleteSync();
            File(audioPath).deleteSync();
          } catch (_) {}

          if (returnCode == null || !returnCode.isValueSuccess()) {
            final logs = await session.getLogsAsString();
            throw Exception('Ошибка FFmpeg: $logs');
          }
        }
      } else if (isAudio) {
        bool isSourceMp4 = streamInfo.container.name == 'mp4';
        String tempAudioPath = '${tempDir.path}/audio_temp_${DateTime.now().millisecondsSinceEpoch}.${streamInfo.container.name}';
        
        try {
          await downloadStream(streamInfo, tempAudioPath, 0.0, 0.8);
        } catch (e) {
          if (e.toString().contains('403') || e.toString().contains('Сбой сети')) {
            // Fallback to Muxed stream because YouTube blocks audio-only streams often
            final manifest = await _yt.videos.streamsClient.getManifest(video.id);
            if (manifest.muxed.isNotEmpty) {
              final fallbackStream = manifest.muxed.withHighestBitrate();
              isSourceMp4 = fallbackStream.container.name == 'mp4';
              tempAudioPath = '${tempDir.path}/audio_temp_${DateTime.now().millisecondsSinceEpoch}.${fallbackStream.container.name}';
              await downloadStream(fallbackStream, tempAudioPath, 0.0, 0.8);
            } else {
              throw e;
            }
          } else {
            throw e;
          }
        }
        
        fileExt = 'm4a';
        if (targetAudioCodec == 'MP3') fileExt = 'mp3';
        else if (targetAudioCodec == 'FLAC') fileExt = 'flac';
        else if (targetAudioCodec == 'Opus') fileExt = 'opus';
        else if (targetAudioCodec == 'WAV') fileExt = 'wav';
        
        finalPath = '${targetDir.path}/${safeTitle.take(30)}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

        // Download thumbnail for cover
        final thumbPath = '${tempDir.path}/thumb_${DateTime.now().millisecondsSinceEpoch}.jpg';
        String urlToDownload = video.thumbnails.highResUrl;
        try {
          await Dio().head(urlToDownload);
        } catch (_) {
          urlToDownload = video.thumbnails.standardResUrl;
        }
        try {
          await Dio().download(urlToDownload, thumbPath);
        } catch (_) {}

        onProgress(0.85); // Processing...

        final title = customTitle ?? video.title;
        final author = customAuthor ?? video.author;
        final audioCodec = isSourceMp4 ? 'copy' : 'aac';

        int totalDur = video.duration?.inSeconds ?? 0;
        final args = _buildFfmpegArgs(
          videoPath: null,
          audioPath: tempAudioPath,
          outPath: finalPath,
          thumbPath: File(thumbPath).existsSync() ? thumbPath : null,
          title: title,
          artist: author,
          targetAudioBitrate: targetAudioBitrate,
          targetAudioCodec: targetAudioCodec ?? (audioCodec == 'copy' ? null : 'AAC'),
          isAudioOnly: true,
        );
        
        if (isDesktop) {
          final ffmpegPath = await _getDesktopFfmpeg();
          final process = await Process.start(ffmpegPath, args);
          process.stderr.transform(utf8.decoder).listen((data) {
            if (totalDur > 0) {
              final match = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)').firstMatch(data);
              if (match != null) {
                final h = int.parse(match.group(1)!);
                final m = int.parse(match.group(2)!);
                final s = double.parse(match.group(3)!);
                final seconds = h * 3600 + m * 60 + s;
                double p = seconds / totalDur;
                if (p > 1.0) p = 1.0;
                onProgress(0.85 + (p * 0.14));
              }
            }
          });
          final exitCode = await process.exitCode;
          
          try {
            File(tempAudioPath).deleteSync();
            if (File(thumbPath).existsSync()) File(thumbPath).deleteSync();
          } catch (_) {}

          if (exitCode != 0) throw Exception('Ошибка FFmpeg');
        } else {
          final session = await FFmpegKit.executeWithArgumentsAsync(args, (s) {}, (l) {}, (statistics) {
             int timeMs = statistics.getTime();
             if (totalDur > 0 && timeMs > 0) {
               double p = (timeMs / 1000) / totalDur;
               if (p > 1.0) p = 1.0;
               onProgress(0.85 + p * 0.14);
             }
          });
          
          while (await session.getReturnCode() == null) {
            await Future.delayed(const Duration(milliseconds: 200));
          }
          final returnCode = await session.getReturnCode();
          
          try {
            File(tempAudioPath).deleteSync();
            if (File(thumbPath).existsSync()) File(thumbPath).deleteSync();
          } catch (_) {}

          if (returnCode == null || !returnCode.isValueSuccess()) {
            final logs = await session.getLogsAsString();
            throw Exception('Ошибка FFmpeg: $logs');
          }
        }
      } else {
        finalPath = '${targetDir.path}/${safeTitle.take(30)}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        try {
          await downloadStream(streamInfo, finalPath, 0.0, 1.0);
        } catch (e) {
          if (e.toString().contains('403')) throw Exception('YouTube временно заблокировал скачивание видео в этом качестве. Выберите другое качество.');
          throw e;
        }
      }

      return await _saveFile(finalPath, fileExt, safeTitle, isAudio, isDesktop);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<String?> downloadTikTokAndSaveToGallery(
    Map<String, dynamic> tiktokData,
    bool isAudio,
    Function(double) onProgress,
    {String? customTitle, String? customAuthor, String? tiktokQuality, String? tiktokCodec, String? tiktokAudioCodec, String? targetQuality, num? targetFps, String? targetVideoCodec, int? targetAudioBitrate, String? targetAudioCodec}
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      
      String baseName = tiktokData['title'] ?? 'tiktok_video';
      if (customTitle != null && customTitle.isNotEmpty) baseName = customTitle;
      
      final safeTitle = baseName
          .replaceAll(RegExp(r'[^\p{L}\p{N}\s\-_]+', unicode: true), '')
          .replaceAll(RegExp(r'\s+'), '_');

      final bool isDesktop = !Platform.isAndroid && !Platform.isIOS;
      final Directory targetDir = await _getTargetDir(tempDir, isDesktop);

      String finalPath = '';
      String fileExt = isAudio ? 'mp3' : 'mp4'; // tikwm audio is mp3
      
      finalPath = '${targetDir.path}/${safeTitle.take(30)}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      
      String downloadUrl = tiktokData['play'] ?? '';
      if (isAudio) {
        downloadUrl = tiktokData['music'] ?? '';
      } else {
        if (tiktokQuality == 'HD (Без водяного знака)' && tiktokData['hdplay'] != null) {
          downloadUrl = tiktokData['hdplay'];
        } else if (tiktokQuality == 'SD (С водяным знаком)' && tiktokData['wmplay'] != null) {
          downloadUrl = tiktokData['wmplay'];
        }
      }

      await _dio.download(
        downloadUrl,
        finalPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress((received / total) * 0.95); // up to 95% for download
          }
        },
      );
      
      String pathToSave = finalPath;
      String extToSave = fileExt;

      // Метаданные: берём из кастомных полей, иначе из данных TikTok
      final metaTitle = baseName; // уже содержит customTitle если задан
      final metaArtist = (customAuthor != null && customAuthor.isNotEmpty)
          ? customAuthor
          : (tiktokData['author'] is Map
              ? (tiktokData['author']['nickname'] ?? 'TikTok')
              : 'TikTok');

      String ext = isAudio ? (targetAudioCodec?.toLowerCase() ?? 'mp3') : 'mp4';
      final processedPath = '${targetDir.path}/${safeTitle.take(30)}_${DateTime.now().millisecondsSinceEpoch}_p.$ext';
      
      final args = _buildFfmpegArgs(
        videoPath: isAudio ? null : finalPath,
        audioPath: isAudio ? finalPath : null,
        outPath: processedPath,
        title: metaTitle,
        artist: metaArtist,
        targetQuality: targetQuality,
        targetFps: targetFps,
        targetVideoCodec: targetVideoCodec,
        targetAudioBitrate: targetAudioBitrate,
        targetAudioCodec: targetAudioCodec,
        isAudioOnly: isAudio,
      );
      
      onProgress(0.98);
      int totalDuration = 15; // default 15s for TikTok
      if (tiktokData['duration'] != null && tiktokData['duration'] is int) {
          totalDuration = tiktokData['duration'] as int;
      }
      
      if (isDesktop) {
        final ffmpegPath = await _getDesktopFfmpeg();
        final process = await Process.start(ffmpegPath, args);
        
        process.stderr.transform(utf8.decoder).listen((data) {
          if (totalDuration > 0) {
            final match = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)').firstMatch(data);
            if (match != null) {
              final h = int.parse(match.group(1)!);
              final m = int.parse(match.group(2)!);
              final s = double.parse(match.group(3)!);
              final seconds = h * 3600 + m * 60 + s;
              double ffmpegProgress = seconds / totalDuration;
              if (ffmpegProgress > 1.0) ffmpegProgress = 1.0;
              // Muxing is the last 10%
              onProgress(0.90 + (ffmpegProgress * 0.10));
            }
          }
        });
        await process.exitCode;
      } else {
        final session = await FFmpegKit.executeWithArgumentsAsync(args, (s) {}, (l) {}, (statistics) {
             int timeMs = statistics.getTime();
             if (totalDuration > 0 && timeMs > 0) {
               double p = (timeMs / 1000) / totalDuration;
               if (p > 1.0) p = 1.0;
               onProgress(0.90 + p * 0.08); // up to 0.98
             }
        });
        while (await session.getReturnCode() == null) {
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      try { File(finalPath).deleteSync(); } catch (_) {}
      
      return await _saveFile(processedPath, ext, safeTitle, isAudio, isDesktop);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<String?> downloadTikTokThumbnailAndSaveToGallery(
    Map<String, dynamic> tiktokData,
    Function(double) onProgress
  ) async {
    try {
      final tempDir = await getTemporaryDirectory();
      String baseName = tiktokData['title'] ?? 'tiktok_thumbnail';
      final safeTitle = baseName
          .replaceAll(RegExp(r'[^\p{L}\p{N}\s\-_]+', unicode: true), '')
          .replaceAll(RegExp(r'\s+'), '_');

      final bool isDesktop = !Platform.isAndroid && !Platform.isIOS;
      final Directory targetDir = await _getTargetDir(tempDir, isDesktop);

      final finalPath = '${targetDir.path}/${safeTitle.take(30)}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      String downloadUrl = tiktokData['cover'] ?? '';

      await _dio.download(
        downloadUrl,
        finalPath,
        onReceiveProgress: (received, total) {
          if (total != -1) onProgress(received / total);
        },
      );

      return await _saveFile(finalPath, 'jpg', safeTitle, false, isDesktop);
    } catch (e) {
      throw Exception('Ошибка скачивания превью: ${e.toString()}');
    }
  }

  Future<String> _saveFile(String finalPath, String fileExt, String safeTitle, bool isAudio, bool isDesktop) async {
      if (isDesktop) {
        return finalPath; // Already in downloads
      } else {
        // Mobile: Save to App's external directory first (guaranteed to work without permissions)
        final appDir = await getExternalStorageDirectory();
        if (appDir == null) throw Exception('Не удалось получить доступ к хранилищу');
        
        final finalSafePath = '${appDir.path}/${safeTitle.take(30)}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        File(finalPath).copySync(finalSafePath);
        
        // Try to save directly to Gallery to avoid duplicate in Downloads
        if (!isAudio) {
            try {
              bool hasAccess = await Gal.hasAccess();
              if (!hasAccess) hasAccess = await Gal.requestAccess();
              if (hasAccess) {
                if (fileExt == 'mp4' || fileExt == 'mkv') {
                  await Gal.putVideo(finalSafePath, album: 'EasyLoader');
                } else if (fileExt == 'jpg' || fileExt == 'png' || fileExt == 'webp') {
                  await Gal.putImage(finalSafePath, album: 'EasyLoader');
                }
                return finalSafePath;
              }
            } catch (_) {}
        }

        // Try to copy to public Downloads or Music
        try {
          final publicDir = isAudio ? Directory('/storage/emulated/0/Music') : Directory('/storage/emulated/0/Download');
          if (!publicDir.existsSync()) publicDir.createSync(recursive: true);
          final newPath = '${publicDir.path}/${safeTitle.take(30)}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
          File(finalSafePath).copySync(newPath);
          
          // Trigger media scanner so it shows up in Music apps
          try {
            await const MethodChannel('com.example.easy_loader_mobile/media_scanner').invokeMethod('scanFile', {'path': newPath});
          } catch (_) {}
          
          return newPath;
        } catch (e) {
          // For audio fallback, just scan the finalSafePath so it might appear
          if (isAudio) {
             try {
               await const MethodChannel('com.example.easy_loader_mobile/media_scanner').invokeMethod('scanFile', {'path': finalSafePath});
             } catch (_) {}
          }
          // If we reach here, we couldn't save to public folders, but it IS saved in appDir!
          throw Exception('Файл скачан, но Android заблокировал доступ. Ищите в: $finalSafePath');
        }
      }
  }

  Future<String?> downloadThumbnailAndSaveToGallery(
    Video video,
    Function(double) onProgress
  ) async {
    try {
      final isDesktop = !Platform.isAndroid && !Platform.isIOS;
      final tempDir = await getTemporaryDirectory();
      final Directory targetDir = await _getTargetDir(tempDir, isDesktop);
      final safeTitle = video.title
          .replaceAll(RegExp(r'[^\p{L}\p{N}\s\-_]+', unicode: true), '')
          .replaceAll(RegExp(r'\s+'), '_');
      final fileName = '${safeTitle.take(30)}_${DateTime.now().millisecondsSinceEpoch}_thumb.jpg';
      final savePath = '${targetDir.path}/$fileName';

      String urlToDownload = video.thumbnails.highResUrl;
      try {
        await _dio.head(urlToDownload);
      } catch (_) {
        urlToDownload = video.thumbnails.standardResUrl;
        try {
          await _dio.head(urlToDownload);
        } catch (_) {
          urlToDownload = video.thumbnails.mediumResUrl;
        }
      }

      await _dio.download(
        urlToDownload,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            onProgress(received / total);
          }
        },
      );

      if (!isDesktop) {
        bool hasAccess = await Gal.hasAccess();
        if (!hasAccess) hasAccess = await Gal.requestAccess();
        if (hasAccess) await Gal.putImage(savePath, album: 'EasyLoader');
      }

      return savePath;
    } catch (e) {
      throw Exception('Ошибка скачивания превью: $e');
    }
  }
  
  void dispose() {
    _yt.close();
  }
}

extension StringExtension on String {
  String take(int nbChars) => length > nbChars ? substring(0, nbChars) : this;
}
