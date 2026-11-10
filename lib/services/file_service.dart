import 'dart:io';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'permission_service.dart';
import '../models/file_item.dart';

enum SortField { name, dateModified, type, size }

class StorageVolumeInfo {
  final String title;
  final String path;
  final int totalBytes;
  final int freeBytes;
  final bool isRemovable;

  const StorageVolumeInfo({
    required this.title,
    required this.path,
    required this.totalBytes,
    required this.freeBytes,
    this.isRemovable = false,
  });

  int get usedBytes => totalBytes > freeBytes ? totalBytes - freeBytes : 0;
  double get usedPercentage => totalBytes > 0 ? (usedBytes / totalBytes) : 0.0;
  String get freeFormatted => formatBytes(freeBytes);
  String get totalFormatted => formatBytes(totalBytes);

  static String formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class FileService {
  static const String internalStoragePath = '/storage/emulated/0';
  static const MethodChannel _storageChannel = MethodChannel('com.neofile.app/storage');
  static const EventChannel _storageEventChannel = EventChannel('com.neofile.app/storage_events');
  static const EventChannel _intentEventChannel = EventChannel('com.neofile.app/file_intent_events');
  static VoidCallback? onCancelTransferRequested;
  static VoidCallback? onShowTransferSheetRequested;
  static VoidCallback? onMcpStop;
  static VoidCallback? onMcpPause;
  static VoidCallback? onMcpResume;
  static VoidCallback? onFtpStop;
  static void Function(String action)? onOpenAction;

  static bool _handlerInitialized = false;

  static void ensureHandlerInitialized() {
    if (_handlerInitialized) return;
    _handlerInitialized = true;
    _storageChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'cancelTransfer':
          onCancelTransferRequested?.call();
          break;
        case 'showTransferSheet':
          onShowTransferSheetRequested?.call();
          break;
        case 'mcpStop':
          onMcpStop?.call();
          break;
        case 'mcpPause':
          onMcpPause?.call();
          break;
        case 'mcpResume':
          onMcpResume?.call();
          break;
        case 'ftpStop':
          onFtpStop?.call();
          break;
        case 'openAction':
          final action = call.arguments as String?;
          if (action != null) onOpenAction?.call(action);
          break;
        case 'requestFrame':
          // Warm up frame if binding available
          break;
      }
    });
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static Stream get storageEventsStream => _storageEventChannel.receiveBroadcastStream();
  static Stream<String> get fileIntentStream => _intentEventChannel.receiveBroadcastStream().cast<String>();

  static Future<String?> getInitialIntentPath() async {
    try {
      return await _storageChannel.invokeMethod<String>('getInitialIntentPath');
    } catch (_) {
      return null;
    }
  }

  static Future<void> showNotification({
    required String title,
    required String message,
    int progress = 0,
    bool isIndeterminate = false,
  }) async {
    try {
      await _storageChannel.invokeMethod('showNotification', {
        'title': title,
        'message': message,
        'progress': progress,
        'isIndeterminate': isIndeterminate,
      });
    } catch (_) {}
  }

  static Future<void> cancelNotification() async {
    try {
      await _storageChannel.invokeMethod('cancelNotification');
    } catch (_) {}
  }

  static Future<void> showFtpNotification({
    required String title,
    required String message,
  }) async {
    try {
      await _storageChannel.invokeMethod('showFtpNotification', {
        'title': title,
        'message': message,
      });
    } catch (_) {}
  }

  static Future<void> cancelFtpNotification() async {
    try {
      await _storageChannel.invokeMethod('cancelFtpNotification');
    } catch (_) {}
  }

  static Future<void> updateWidgetData(Map<String, dynamic> data) async {
    try {
      await _storageChannel.invokeMethod('updateWidgetData', data);
    } catch (_) {}
  }

  static Future<bool> pinWidget(String type) async {
    try {
      final res = await _storageChannel.invokeMethod<bool>('pinWidget', {'type': type});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openUrl(String url) async {
    try {
      await _storageChannel.invokeMethod('openUrl', {'url': url});
    } catch (_) {}
  }

  static Future<List<StorageVolumeInfo>> getStorageVolumes() async {
    final volumes = <StorageVolumeInfo>[];

    // 1. Try native Android StorageManager via MethodChannel (detects OTG, USB & SD card)
    try {
      final List? raw = await _storageChannel.invokeMethod<List>('getStorageVolumes');
      if (raw != null && raw.isNotEmpty) {
        for (final item in raw) {
          if (item is Map) {
            volumes.add(
              StorageVolumeInfo(
                title: item['title'] as String? ?? 'Storage',
                path: item['path'] as String? ?? '',
                totalBytes: (item['totalBytes'] as num?)?.toInt() ?? 0,
                freeBytes: (item['freeBytes'] as num?)?.toInt() ?? 0,
                isRemovable: item['isRemovable'] as bool? ?? false,
              ),
            );
          }
        }
        if (volumes.isNotEmpty) return volumes;
      }
    } catch (_) {}

    // 2. Fallback to manual directory scan
    final primaryDir = Directory(internalStoragePath);
    if (await primaryDir.exists()) {
      volumes.add(
        const StorageVolumeInfo(
          title: 'Internal Storage',
          path: internalStoragePath,
          totalBytes: 128 * 1024 * 1024 * 1024,
          freeBytes: 78 * 1024 * 1024 * 1024,
        ),
      );
    }

    try {
      final storageRoot = Directory('/storage');
      if (await storageRoot.exists()) {
        final entries = storageRoot.listSync(followLinks: false);
        for (final entry in entries) {
          if (entry is Directory &&
              !entry.path.contains('emulated') &&
              !entry.path.contains('self') &&
              p.basename(entry.path) != 'knox') {
            final name = p.basename(entry.path);
            final isUsb = name.contains('usb') || name.contains('otg');
            volumes.add(
              StorageVolumeInfo(
                title: isUsb ? 'External Storage ($name)' : 'SD Card ($name)',
                path: entry.path,
                totalBytes: 64 * 1024 * 1024 * 1024,
                freeBytes: 42 * 1024 * 1024 * 1024,
                isRemovable: true,
              ),
            );
          }
        }
      }
    } catch (_) {}

    return volumes;
  }

  static Future<List<FileItem>> listDirectory({
    required String path,
    bool showHidden = false,
    SortField sortBy = SortField.name,
    bool ascending = true,
  }) async {
    final dir = Directory(path);
    if (!await dir.exists()) return [];

    final List<FileItem> items = [];
    try {
      final entities = dir.listSync(followLinks: false);
      for (final entity in entities) {
        final name = p.basename(entity.path);
        if (!showHidden && name.startsWith('.')) continue;

        try {
          items.add(FileItem.fromFileSystemEntity(entity));
        } catch (_) {
          // Skip inaccessible individual nodes
        }
      }
    } catch (e) {
      // Permission or I/O error
      return [];
    }

    // Sort items: folders always first, then by field
    items.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;

      int cmp = 0;
      switch (sortBy) {
        case SortField.name:
          cmp = a.name.toLowerCase().compareTo(b.name.toLowerCase());
          break;
        case SortField.dateModified:
          cmp = a.modified.compareTo(b.modified);
          break;
        case SortField.type:
          cmp = a.extension.compareTo(b.extension);
          if (cmp == 0) cmp = a.name.compareTo(b.name);
          break;
        case SortField.size:
          cmp = a.size.compareTo(b.size);
          break;
      }
      return ascending ? cmp : -cmp;
    });

    return items;
  }

  static Future<bool> createFolder(String parentPath, String folderName) async {
    final newPath = p.join(parentPath, folderName.trim());
    final dir = Directory(newPath);
    if (await dir.exists()) return false;
    await dir.create(recursive: true);
    return true;
  }

  static Future<bool> createFile(String parentPath, String fileName) async {
    final newPath = p.join(parentPath, fileName.trim());
    final file = File(newPath);
    if (await file.exists()) return false;
    await file.create(recursive: true);
    return true;
  }

  static Future<bool> rename(String oldPath, String newName) async {
    final parent = p.dirname(oldPath);
    final targetPath = p.join(parent, newName.trim());
    if (await FileSystemEntity.isDirectory(oldPath)) {
      await Directory(oldPath).rename(targetPath);
    } else {
      await File(oldPath).rename(targetPath);
    }
    return true;
  }

  static Future<void> deleteItems(List<String> paths) async {
    for (final path in paths) {
      try {
        if (await FileSystemEntity.isDirectory(path)) {
          await Directory(path).delete(recursive: true);
        } else {
          await File(path).delete();
        }
      } catch (_) {}
    }
  }

  static Future<int> calculateTotalBytes(List<String> paths) async {
    int total = 0;
    for (final path in paths) {
      try {
        final type = await FileSystemEntity.type(path);
        if (type == FileSystemEntityType.directory) {
          final dir = Directory(path);
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              total += await entity.length();
            }
          }
        } else if (type == FileSystemEntityType.file) {
          total += await File(path).length();
        }
      } catch (_) {}
    }
    return total;
  }

  static Future<void> _streamCopyFile(
    File source,
    File target, {
    required void Function(int bytesCopied) onChunk,
    bool Function()? isCancelled,
  }) async {
    final reader = source.openRead();
    final writer = target.openWrite();
    await for (final chunk in reader) {
      if (isCancelled?.call() == true) {
        await writer.close();
        if (await target.exists()) await target.delete();
        return;
      }
      writer.add(chunk);
      onChunk(chunk.length);
    }
    await writer.flush();
    await writer.close();
  }

  static Future<void> copyItems(
    List<String> sourcePaths,
    String destDir, {
    void Function(double progress, String currentItem, String speed)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final totalBytes = await calculateTotalBytes(sourcePaths);
    int transferredBytes = 0;
    final stopwatch = Stopwatch()..start();
    int lastCheckTime = 0;
    int lastCheckBytes = 0;
    String currentSpeed = '0 KB/s';

    void updateProgress(String currentName) {
      final elapsedMs = stopwatch.elapsedMilliseconds;
      if (elapsedMs - lastCheckTime >= 300 || transferredBytes == totalBytes) {
        final diffBytes = transferredBytes - lastCheckBytes;
        final diffTimeSec = (elapsedMs - lastCheckTime) / 1000.0;
        if (diffTimeSec > 0) {
          final bps = (diffBytes / diffTimeSec).round();
          currentSpeed = '${formatBytes(bps)}/s';
        }
        lastCheckTime = elapsedMs;
        lastCheckBytes = transferredBytes;
      }
      final prog = totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : 1.0;
      onProgress?.call(
        prog,
        '$currentName (${formatBytes(transferredBytes)} / ${formatBytes(totalBytes)})',
        currentSpeed,
      );
    }

    for (final src in sourcePaths) {
      if (isCancelled?.call() == true) break;
      final name = p.basename(src);
      final destPath = p.join(destDir, name);

      if (await FileSystemEntity.isDirectory(src)) {
        await _copyDirectoryStreaming(
          Directory(src),
          Directory(destPath),
          onChunk: (chunk) {
            transferredBytes += chunk;
            updateProgress(name);
          },
          isCancelled: isCancelled,
        );
      } else {
        await _streamCopyFile(
          File(src),
          File(destPath),
          onChunk: (chunk) {
            transferredBytes += chunk;
            updateProgress(name);
          },
          isCancelled: isCancelled,
        );
      }
    }
    onProgress?.call(1.0, 'Complete (${formatBytes(totalBytes)})', currentSpeed);
  }

  static Future<void> moveItems(
    List<String> sourcePaths,
    String destDir, {
    void Function(double progress, String currentItem, String speed)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final totalBytes = await calculateTotalBytes(sourcePaths);
    int transferredBytes = 0;
    final stopwatch = Stopwatch()..start();
    int lastCheckTime = 0;
    int lastCheckBytes = 0;
    String currentSpeed = '0 KB/s';

    void updateProgress(String currentName) {
      final elapsedMs = stopwatch.elapsedMilliseconds;
      if (elapsedMs - lastCheckTime >= 300 || transferredBytes == totalBytes) {
        final diffBytes = transferredBytes - lastCheckBytes;
        final diffTimeSec = (elapsedMs - lastCheckTime) / 1000.0;
        if (diffTimeSec > 0) {
          final bps = (diffBytes / diffTimeSec).round();
          currentSpeed = '${formatBytes(bps)}/s';
        }
        lastCheckTime = elapsedMs;
        lastCheckBytes = transferredBytes;
      }
      final prog = totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : 1.0;
      onProgress?.call(
        prog,
        '$currentName (${formatBytes(transferredBytes)} / ${formatBytes(totalBytes)})',
        currentSpeed,
      );
    }

    for (final src in sourcePaths) {
      if (isCancelled?.call() == true) break;
      final name = p.basename(src);
      final destPath = p.join(destDir, name);

      bool movedFast = false;
      try {
        if (await FileSystemEntity.isDirectory(src)) {
          await Directory(src).rename(destPath);
        } else {
          await File(src).rename(destPath);
        }
        movedFast = true;
        transferredBytes += await calculateTotalBytes([destPath]);
        updateProgress(name);
      } catch (_) {
        movedFast = false;
      }

      if (!movedFast) {
        if (await FileSystemEntity.isDirectory(src)) {
          await _copyDirectoryStreaming(
            Directory(src),
            Directory(destPath),
            onChunk: (chunk) {
              transferredBytes += chunk;
              updateProgress(name);
            },
            isCancelled: isCancelled,
          );
          if (isCancelled?.call() != true) {
            await Directory(src).delete(recursive: true);
          }
        } else {
          await _streamCopyFile(
            File(src),
            File(destPath),
            onChunk: (chunk) {
              transferredBytes += chunk;
              updateProgress(name);
            },
            isCancelled: isCancelled,
          );
          if (isCancelled?.call() != true) {
            await File(src).delete();
          }
        }
      }
    }
    onProgress?.call(1.0, 'Complete', currentSpeed);
  }

  static Future<void> _copyDirectoryStreaming(
    Directory source,
    Directory destination, {
    required void Function(int bytes) onChunk,
    bool Function()? isCancelled,
  }) async {
    await destination.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      if (isCancelled?.call() == true) break;
      final name = p.basename(entity.path);
      final newDest = p.join(destination.path, name);
      if (entity is Directory) {
        await _copyDirectoryStreaming(entity, Directory(newDest), onChunk: onChunk, isCancelled: isCancelled);
      } else if (entity is File) {
        await _streamCopyFile(entity, File(newDest), onChunk: onChunk, isCancelled: isCancelled);
      }
    }
  }

  static Future<List<FileItem>> searchFilesRecursively({
    required List<String> roots,
    required String query,
    bool showHidden = false,
    bool Function()? isCancelled,
    int maxResults = 100,
  }) async {
    final lowerQuery = query.toLowerCase();
    final results = <FileItem>[];

    for (final root in roots) {
      if (isCancelled?.call() == true || results.length >= maxResults) break;
      final rootDir = Directory(root);
      if (!rootDir.existsSync()) continue;

      try {
        await for (final entity in rootDir.list(recursive: true, followLinks: false)) {
          if (isCancelled?.call() == true || results.length >= maxResults) break;
          final name = p.basename(entity.path);
          if (!showHidden && name.startsWith('.')) continue;

          if (name.toLowerCase().contains(lowerQuery)) {
            try {
              results.add(FileItem.fromFileSystemEntity(entity));
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    return results;
  }

  static String? getMimeType(String path) {
    final ext = p.extension(path).toLowerCase().replaceAll('.', '');
    switch (ext) {
      // Videos
      case 'mp4':
      case 'm4v':
        return 'video/mp4';
      case 'mkv':
        return 'video/x-matroska';
      case 'mov':
        return 'video/quicktime';
      case 'avi':
        return 'video/x-msvideo';
      case 'wmv':
        return 'video/x-ms-wmv';
      case 'flv':
      case 'f4v':
        return 'video/x-flv';
      case 'webm':
        return 'video/webm';
      case '3gp':
      case '3gpp':
        return 'video/3gpp';
      case '3g2':
        return 'video/3gpp2';
      case 'ts':
      case 'mts':
      case 'm2ts':
        return 'video/mp2t';
      case 'vob':
        return 'video/x-ms-vob';
      case 'ogv':
        return 'video/ogg';
      case 'asf':
        return 'video/x-ms-asf';
      case 'mpg':
      case 'mpeg':
        return 'video/mpeg';
      case 'divx':
        return 'video/divx';

      // Audio
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
      case 'oga':
        return 'audio/ogg';
      case 'm4a':
      case 'aac':
        return 'audio/aac';
      case 'flac':
        return 'audio/flac';
      case 'wma':
        return 'audio/x-ms-wma';
      case 'opus':
        return 'audio/opus';
      case 'amr':
        return 'audio/amr';
      case 'mid':
      case 'midi':
        return 'audio/midi';
      case 'aif':
      case 'aiff':
        return 'audio/x-aiff';
      case 'alac':
        return 'audio/alac';
      case 'mka':
        return 'audio/x-matroska';

      // Images
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';

      // Documents
      case 'pdf':
        return 'application/pdf';
      case 'doc':
      case 'dot':
        return 'application/msword';
      case 'docx':
      case 'dotx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
      case 'xlt':
        return 'application/vnd.ms-excel';
      case 'xlsx':
      case 'xltx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
      case 'pot':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
      case 'potx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';

      // Archives
      case 'zip':
        return 'application/zip';
      case 'rar':
        return 'application/x-rar-compressed';
      case '7z':
        return 'application/x-7z-compressed';
      case 'tar':
        return 'application/x-tar';
      case 'gz':
        return 'application/gzip';
      case 'apk':
        return 'application/vnd.android.package-archive';

      // Text & Code
      case 'txt':
      case 'log':
        return 'text/plain';
      case 'html':
      case 'htm':
        return 'text/html';
      case 'xml':
        return 'text/xml';
      case 'json':
        return 'application/json';
      case 'csv':
        return 'text/csv';
      default:
        return null;
    }
  }

  static Future<OpenResult?> openFile(String path, {bool useChooser = false}) async {
    final mime = getMimeType(path);
    if (Platform.isAndroid && (path.toLowerCase().endsWith('.apk') || mime == 'application/vnd.android.package-archive')) {
      bool isGranted = await PermissionService.isInstallPackagesPermissionGranted();
      if (!isGranted) {
        final requested = await PermissionService.requestInstallPackagesPermission();
        if (!requested) {
          isGranted = await PermissionService.isInstallPackagesPermissionGranted();
        } else {
          isGranted = true;
        }
      }
      if (!isGranted) {
        return null;
      }
    }

    if (Platform.isAndroid) {
      try {
        final opened = await _storageChannel.invokeMethod<bool>('openFile', {
          'path': path,
          'mimeType': mime,
          'useChooser': useChooser,
        });
        if (opened == true) return null;
      } catch (_) {}
    }

    return await OpenFilex.open(path, type: mime);
  }

  static Future<void> shareFiles(List<String> paths) async {
    final xfiles = paths.map((p) => XFile(p, mimeType: getMimeType(p))).toList();
    await Share.shareXFiles(xfiles);
  }
}
