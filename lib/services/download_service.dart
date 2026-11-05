import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;

class DownloadService {
  static Future<bool> downloadFile({
    required String url,
    required String destinationDir,
    String? customFileName,
    void Function(double progress, String info, String speed)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 15);

    IOSink? sink;
    File? tempFile;

    try {
      final uri = Uri.parse(url.trim());
      final request = await client.getUrl(uri);
      final response = await request.close();

      if (response.statusCode >= 400) {
        return false;
      }

      // Determine file name
      String fileName = customFileName?.trim() ?? '';
      if (fileName.isEmpty) {
        final contentDisposition = response.headers.value('content-disposition');
        if (contentDisposition != null && contentDisposition.contains('filename=')) {
          final match = RegExp(r'filename="?([^"]+)"?').firstMatch(contentDisposition);
          if (match != null) {
            fileName = match.group(1) ?? '';
          }
        }
      }

      if (fileName.isEmpty) {
        fileName = p.basename(uri.path);
        if (fileName.isEmpty || !fileName.contains('.')) {
          fileName = 'download_${DateTime.now().millisecondsSinceEpoch}.bin';
        }
      }

      final targetPath = p.join(destinationDir, fileName);
      final tempPath = '$targetPath.downloading';
      tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }
      await tempFile.create(recursive: true);
      sink = tempFile.openWrite();

      final totalBytes = response.contentLength;
      int downloadedBytes = 0;
      final stopwatch = Stopwatch()..start();
      int lastCheckTime = 0;
      int lastCheckBytes = 0;
      String currentSpeed = '0 KB/s';

      await for (final chunk in response) {
        if (isCancelled?.call() == true) {
          await sink.close();
          await tempFile.delete();
          return false;
        }

        sink.add(chunk);
        downloadedBytes += chunk.length;

        final elapsedMs = stopwatch.elapsedMilliseconds;
        if (elapsedMs - lastCheckTime >= 300) {
          final diffBytes = downloadedBytes - lastCheckBytes;
          final diffTimeSec = (elapsedMs - lastCheckTime) / 1000.0;
          if (diffTimeSec > 0) {
            final bps = (diffBytes / diffTimeSec).round();
            currentSpeed = '${_formatBytes(bps)}/s';
          }
          lastCheckTime = elapsedMs;
          lastCheckBytes = downloadedBytes;
        }

        final progress = totalBytes > 0 ? (downloadedBytes / totalBytes).clamp(0.0, 1.0) : -1.0;
        final downloadedFormatted = _formatBytes(downloadedBytes);
        final totalFormatted = totalBytes > 0 ? _formatBytes(totalBytes) : 'Unknown size';
        onProgress?.call(
          progress > 0 ? progress : 0.0,
          '$fileName ($downloadedFormatted / $totalFormatted)',
          currentSpeed,
        );
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // Rename temp file to final target
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(targetPath);
      onProgress?.call(1.0, '$fileName (Complete)', currentSpeed);
      return true;
    } catch (e) {
      try {
        await sink?.close();
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
        }
      } catch (_) {}
      return false;
    } finally {
      client.close();
    }
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
