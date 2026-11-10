import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'file_service.dart';

enum StorageCategory {
  videos,
  images,
  audio,
  documents,
  archives,
  apps,
  others,
}

extension StorageCategoryX on StorageCategory {
  String get displayName {
    switch (this) {
      case StorageCategory.videos:
        return 'Videos';
      case StorageCategory.images:
        return 'Images';
      case StorageCategory.audio:
        return 'Audio & Music';
      case StorageCategory.documents:
        return 'Documents';
      case StorageCategory.archives:
        return 'Archives';
      case StorageCategory.apps:
        return 'APKs / Installers';
      case StorageCategory.others:
        return 'Other Files';
    }
  }

  IconData get icon {
    switch (this) {
      case StorageCategory.videos:
        return Icons.videocam_outlined;
      case StorageCategory.images:
        return Icons.image_outlined;
      case StorageCategory.audio:
        return Icons.music_note_outlined;
      case StorageCategory.documents:
        return Icons.description_outlined;
      case StorageCategory.archives:
        return Icons.folder_zip_outlined;
      case StorageCategory.apps:
        return Icons.android_outlined;
      case StorageCategory.others:
        return Icons.insert_drive_file_outlined;
    }
  }

  Color get color {
    switch (this) {
      case StorageCategory.videos:
        return const Color(0xFF0078D4); // Fluent Windows Blue
      case StorageCategory.images:
        return const Color(0xFFE36A00); // Fluent Warm Amber/Orange
      case StorageCategory.audio:
        return const Color(0xFF107C41); // Fluent Forest Green
      case StorageCategory.documents:
        return const Color(0xFF5C2D91); // Fluent Deep Purple
      case StorageCategory.archives:
        return const Color(0xFFB146C2); // Fluent Magenta
      case StorageCategory.apps:
        return const Color(0xFF008272); // Fluent Teal
      case StorageCategory.others:
        return const Color(0xFF797775); // Fluent Slate
    }
  }
}

class StorageAnalyzedFile {
  final String path;
  final String name;
  final int size;
  final DateTime modified;
  final StorageCategory category;
  final String extension;

  StorageAnalyzedFile({
    required this.path,
    required this.name,
    required this.size,
    required this.modified,
    required this.category,
    required this.extension,
  });

  String get formattedSize => StorageAnalyzerService.formatSize(size);
}

class StorageCategoryData {
  final StorageCategory category;
  int totalBytes;
  int fileCount;
  final List<StorageAnalyzedFile> files;

  StorageCategoryData({
    required this.category,
    this.totalBytes = 0,
    this.fileCount = 0,
    List<StorageAnalyzedFile>? files,
  }) : files = files ?? [];

  String get formattedTotal => StorageAnalyzerService.formatSize(totalBytes);
}

class StorageAnalysisSnapshot {
  final int totalStorageBytes;
  final int usedStorageBytes;
  final int freeStorageBytes;
  int totalAnalyzedBytes;
  int totalAnalyzedFiles;
  final Map<StorageCategory, StorageCategoryData> categories;
  final List<StorageAnalyzedFile> largeFiles; // Files >= 50 MB

  StorageAnalysisSnapshot({
    required this.totalStorageBytes,
    required this.usedStorageBytes,
    required this.freeStorageBytes,
    this.totalAnalyzedBytes = 0,
    this.totalAnalyzedFiles = 0,
    required this.categories,
    required this.largeFiles,
  });

  String get formattedTotalStorage => StorageAnalyzerService.formatSize(totalStorageBytes);
  String get formattedUsedStorage => StorageAnalyzerService.formatSize(usedStorageBytes);
  String get formattedFreeStorage => StorageAnalyzerService.formatSize(freeStorageBytes);
  String get formattedAnalyzedBytes => StorageAnalyzerService.formatSize(totalAnalyzedBytes);

  double get usedPercentage => totalStorageBytes > 0 ? (usedStorageBytes / totalStorageBytes).clamp(0.0, 1.0) : 0.0;
}

class StorageAnalyzerService with ChangeNotifier {
  static final StorageAnalyzerService _instance = StorageAnalyzerService._internal();
  factory StorageAnalyzerService() => _instance;
  static StorageAnalyzerService get instance => _instance;

  StorageAnalyzerService._internal();

  bool _isScanning = false;
  bool _isCancelled = false;
  double _scanProgress = 0.0;
  String _currentScanningPath = '';
  int _scannedFilesCount = 0;
  StorageAnalysisSnapshot? _lastSnapshot;

  bool get isScanning => _isScanning;
  double get scanProgress => _scanProgress;
  String get currentScanningPath => _currentScanningPath;
  int get scannedFilesCount => _scannedFilesCount;
  StorageAnalysisSnapshot? get lastSnapshot => _lastSnapshot;

  static const _videoExts = {
    'mp4', 'mkv', 'avi', 'mov', 'flv', 'wmv', 'webm', '3gp', 'm4v', 'ts', 'mpg', 'mpeg'
  };
  static const _imageExts = {
    'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'svg', 'heic', 'heif', 'ico', 'tiff'
  };
  static const _audioExts = {
    'mp3', 'wav', 'aac', 'flac', 'ogg', 'm4a', 'wma', 'opus', 'mid', 'amr'
  };
  static const _docExts = {
    'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'md', 'epub', 'csv', 'rtf', 'log', 'json', 'xml'
  };
  static const _archiveExts = {
    'zip', 'rar', '7z', 'tar', 'gz', 'bz2', 'xz', 'iso', 'tgz'
  };
  static const _appExts = {
    'apk', 'xapk', 'apks'
  };

  static const int largeFileThreshold = 50 * 1024 * 1024; // 50 MB

  static StorageCategory classifyExtension(String ext) {
    final clean = ext.toLowerCase().replaceAll('.', '');
    if (_videoExts.contains(clean)) return StorageCategory.videos;
    if (_imageExts.contains(clean)) return StorageCategory.images;
    if (_audioExts.contains(clean)) return StorageCategory.audio;
    if (_docExts.contains(clean)) return StorageCategory.documents;
    if (_archiveExts.contains(clean)) return StorageCategory.archives;
    if (_appExts.contains(clean)) return StorageCategory.apps;
    return StorageCategory.others;
  }

  static String formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  void cancelScan() {
    _isCancelled = true;
    _isScanning = false;
    notifyListeners();
  }

  Future<StorageAnalysisSnapshot?> startAnalysis({bool forceRefresh = false}) async {
    if (_isScanning) return _lastSnapshot;
    if (!forceRefresh && _lastSnapshot != null) return _lastSnapshot;

    _isScanning = true;
    _isCancelled = false;
    _scanProgress = 0.0;
    _scannedFilesCount = 0;
    _currentScanningPath = 'Initializing storage scanner...';
    notifyListeners();

    // 1. Fetch system storage volume details
    int totalStorage = 0;
    int freeStorage = 0;
    try {
      final volumes = await FileService.getStorageVolumes();
      if (volumes.isNotEmpty) {
        totalStorage = volumes.first.totalBytes;
        freeStorage = volumes.first.freeBytes;
      }
    } catch (_) {}

    if (totalStorage == 0) {
      // Fallback sensible defaults if unavailable
      totalStorage = 64 * 1024 * 1024 * 1024;
      freeStorage = 20 * 1024 * 1024 * 1024;
    }

    final usedStorage = totalStorage > freeStorage ? totalStorage - freeStorage : 0;

    final categoryMap = <StorageCategory, StorageCategoryData>{
      for (final cat in StorageCategory.values)
        cat: StorageCategoryData(category: cat),
    };
    final largeFilesList = <StorageAnalyzedFile>[];

    final rootDir = Directory(FileService.internalStoragePath);
    if (!rootDir.existsSync()) {
      _isScanning = false;
      notifyListeners();
      return null;
    }

    // 2. Traversal queue
    final queue = <Directory>[rootDir];
    int analyzedBytes = 0;
    int processedCount = 0;

    while (queue.isNotEmpty && !_isCancelled) {
      final currentDir = queue.removeAt(0);
      _currentScanningPath = p.basename(currentDir.path);

      try {
        final entities = currentDir.listSync(followLinks: false);
        for (final entity in entities) {
          if (_isCancelled) break;

          final entityName = p.basename(entity.path);
          if (entityName.startsWith('.')) continue;

          if (entity is Directory) {
            // Skip Android system internal data/obb to avoid slow unauthorized access
            final norm = p.normalize(entity.path);
            if (norm.endsWith('/Android/data') || norm.endsWith('/Android/obb')) {
              continue;
            }
            queue.add(entity);
          } else if (entity is File) {
            processedCount++;
            _scannedFilesCount = processedCount;

            try {
              final stat = entity.statSync();
              final size = stat.size;
              final ext = p.extension(entity.path);
              final category = classifyExtension(ext);

              final analyzedFile = StorageAnalyzedFile(
                path: entity.path,
                name: entityName,
                size: size,
                modified: stat.modified,
                category: category,
                extension: ext,
              );

              categoryMap[category]!.files.add(analyzedFile);
              categoryMap[category]!.totalBytes += size;
              categoryMap[category]!.fileCount++;
              analyzedBytes += size;

              if (size >= largeFileThreshold) {
                largeFilesList.add(analyzedFile);
              }
            } catch (_) {}

            if (processedCount % 300 == 0) {
              _scanProgress = (processedCount / (processedCount + queue.length * 15)).clamp(0.05, 0.95);
              notifyListeners();
              await Future.delayed(Duration.zero);
            }
          }
        }
      } catch (_) {
        // Skip inaccessible subfolders
      }
    }

    if (_isCancelled) {
      _isScanning = false;
      notifyListeners();
      return null;
    }

    // Sort files by size descending by default in each category
    for (final catData in categoryMap.values) {
      catData.files.sort((a, b) => b.size.compareTo(a.size));
    }
    largeFilesList.sort((a, b) => b.size.compareTo(a.size));

    final snapshot = StorageAnalysisSnapshot(
      totalStorageBytes: totalStorage,
      usedStorageBytes: usedStorage,
      freeStorageBytes: freeStorage,
      totalAnalyzedBytes: analyzedBytes,
      totalAnalyzedFiles: processedCount,
      categories: categoryMap,
      largeFiles: largeFilesList,
    );

    _lastSnapshot = snapshot;
    _isScanning = false;
    _scanProgress = 1.0;
    _currentScanningPath = 'Analysis complete';
    notifyListeners();

    return snapshot;
  }

  /// Deletes given files from storage and updates the active snapshot in real time.
  Future<bool> deleteFiles(List<String> filePaths) async {
    if (filePaths.isEmpty || _lastSnapshot == null) return false;

    int freedBytes = 0;
    int deletedCount = 0;

    for (final path in filePaths) {
      try {
        final f = File(path);
        if (f.existsSync()) {
          final size = f.lengthSync();
          f.deleteSync();
          freedBytes += size;
          deletedCount++;

          // Update internal snapshot
          for (final cat in _lastSnapshot!.categories.values) {
            final idx = cat.files.indexWhere((item) => item.path == path);
            if (idx != -1) {
              cat.files.removeAt(idx);
              cat.totalBytes -= size;
              cat.fileCount--;
              break;
            }
          }

          _lastSnapshot!.largeFiles.removeWhere((item) => item.path == path);
        }
      } catch (_) {}
    }

    if (deletedCount > 0) {
      _lastSnapshot!.totalAnalyzedBytes -= freedBytes;
      _lastSnapshot!.totalAnalyzedFiles -= deletedCount;
      notifyListeners();
      return true;
    }

    return false;
  }
}
