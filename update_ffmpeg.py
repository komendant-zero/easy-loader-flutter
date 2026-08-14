import sys

def process_file(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # block 1: YouTube video
    old_yt_vid = """        if (isDesktop) {
          final ffmpegPath = await _getDesktopFfmpeg();
          final result = await Process.run(ffmpegPath, args);
          
          try {
            File(videoPath).deleteSync();
            File(audioPath).deleteSync();
          } catch (_) {}

          if (result.exitCode != 0) {
            throw Exception('Ошибка FFmpeg: ${result.stderr}');
          }
        } else {
          final session = await FFmpegKit.executeWithArguments(args);
          final returnCode = await session.getReturnCode();
          
          try {
            File(videoPath).deleteSync();
            File(audioPath).deleteSync();
          } catch (_) {}

          if (returnCode == null || !returnCode.isValueSuccess()) {
            final logs = await session.getLogsAsString();
            throw Exception('Ошибка FFmpeg: $logs');
          }
        }"""
        
    new_yt_vid = """        int totalDur = video.duration?.inSeconds ?? 0;
        if (isDesktop) {
          final ffmpegPath = await _getDesktopFfmpeg();
          final process = await Process.start(ffmpegPath, args);
          process.stderr.transform(utf8.decoder).listen((data) {
            if (totalDur > 0) {
              final match = RegExp(r'time=(\\d+):(\\d+):(\\d+\\.\\d+)').firstMatch(data);
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
        }"""
    
    # block 2: YouTube audio
    old_yt_aud = """        if (isDesktop) {
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
          
          final ffmpegPath = await _getDesktopFfmpeg();
          final result = await Process.run(ffmpegPath, args);
          try {
            File(tempAudioPath).deleteSync();
            if (File(thumbPath).existsSync()) File(thumbPath).deleteSync();
          } catch (_) {}
          
          if (result.exitCode != 0) {
            throw Exception('Ошибка FFmpeg: ${result.stderr}');
          }
        } else {
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

          final session = await FFmpegKit.executeWithArguments(args);
          final returnCode = await session.getReturnCode();
          
          try {
            File(tempAudioPath).deleteSync();
            if (File(thumbPath).existsSync()) File(thumbPath).deleteSync();
          } catch (_) {}
          
          if (returnCode == null || !returnCode.isValueSuccess()) {
            final logs = await session.getLogsAsString();
            throw Exception('Ошибка FFmpeg: $logs');
          }
        }"""
        
    new_yt_aud = """        int totalDur = video.duration?.inSeconds ?? 0;
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
              final match = RegExp(r'time=(\\d+):(\\d+):(\\d+\\.\\d+)').firstMatch(data);
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
        }"""
        
    # block 3: TikTok Mobile
    old_tk_mob = """      } else {
        await FFmpegKit.executeWithArguments(args);
      }"""
      
    new_tk_mob = """      } else {
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
      }"""

    content = content.replace(old_yt_vid, new_yt_vid)
    content = content.replace(old_yt_aud, new_yt_aud)
    content = content.replace(old_tk_mob, new_tk_mob)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
        
    print("Replacements done.")

if __name__ == '__main__':
    process_file(sys.argv[1])
