import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'file_service.dart';

class CacheCategoryItem {
  final String title;
  final String description;
  final IconData icon;
  final int bytes;
  final int fileCount;

  CacheCategoryItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.bytes,
    required this.fileCount,
  });

  String formatBytes() => CacheCleanerService.formatSize(bytes);
}

class CacheAnalysisResult {
  final int totalBytes;
  final int totalFiles;
  final List<CacheCategoryItem> categories;

  CacheAnalysisResult({
    required this.totalBytes,
    required this.totalFiles,
    required this.categories,
  });

  String get formattedTotal => CacheCleanerService.formatSize(totalBytes);
  bool get isEmpty => totalBytes == 0 && totalFiles == 0;
}

class CleanupResult {
  final int bytesFreed;
  final int filesDeleted;
  final bool success;

  CleanupResult({
    required this.bytesFreed,
    required this.filesDeleted,
    required this.success,
  });

  String get formattedFreed => CacheCleanerService.formatSize(bytesFreed);
}

class CacheCleanerService with ChangeNotifier {
  static final CacheCleanerService _instance = CacheCleanerService._internal();
  factory CacheCleanerService() => _instance;
  static CacheCleanerService get instance => _instance;

  CacheCleanerService._internal();

  CacheAnalysisResult? _lastAnalysis;
  bool _isAnalyzing = false;
  bool _isCleaning = false;
  double _cleanProgress = 0.0;
  String _currentCleaningItem = '';

  CacheAnalysisResult? get lastAnalysis => _lastAnalysis;
  bool get isAnalyzing => _isAnalyzing;
  bool get isCleaning => _isCleaning;
  double get cleanProgress => _cleanProgress;
  String get currentCleaningItem => _currentCleaningItem;

  static String formatSize(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Future<List<Directory>> _getTempDirectories() async {
    final dirs = <Directory>[];
    try {
      final temp = await getTemporaryDirectory();
      dirs.add(temp);
    } catch (_) {}

    try {
      final extCaches = await getExternalCacheDirectories();
      if (extCaches != null) {
        dirs.addAll(extCaches);
      }
    } catch (_) {}

    // Android app external cache path fallback
    final androidDataCache = Directory('/storage/emulated/0/Android/data/com.neofile.app/cache');
    if (androidDataCache.existsSync() && !dirs.any((d) => d.path == androidDataCache.path)) {
      dirs.add(androidDataCache);
    }

    return dirs;
  }

  Future<CacheAnalysisResult> analyzeCache() async {
    _isAnalyzing = true;
    notifyListeners();

    int appCacheBytes = 0;
    int appCacheFiles = 0;

    int thumbBytes = 0;
    int thumbFiles = 0;

    int tempDownloadBytes = 0;
    int tempDownloadFiles = 0;

    try {
      final tempDirs = await _getTempDirectories();

      for (final dir in tempDirs) {
        if (!dir.existsSync()) continue;
        try {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              try {
                final size = entity.lengthSync();
                final name = p.basename(entity.path).toLowerCase();
                if (name.contains('thumb') || name.contains('.png') || name.contains('.jpg') || name.contains('image')) {
                  thumbBytes += size;
                  thumbFiles++;
                } else if (name.endsWith('.tmp') || name.endsWith('.downloading') || name.endsWith('.temp')) {
                  tempDownloadBytes += size;
                  tempDownloadFiles++;
                } else {
                  appCacheBytes += size;
                  appCacheFiles++;
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      // Also scan app internal storage / temp files in Download directory
      final downloadDir = Directory(p.join(FileService.internalStoragePath, 'Download'));
      if (downloadDir.existsSync()) {
        try {
          await for (final entity in downloadDir.list(recursive: false, followLinks: false)) {
            if (entity is File) {
              final name = p.basename(entity.path).toLowerCase();
              if (name.endsWith('.downloading') || name.endsWith('.tmp') || name.endsWith('.crdownload')) {
                try {
                  final size = entity.lengthSync();
                  tempDownloadBytes += size;
                  tempDownloadFiles++;
                } catch (_) {}
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    final categories = <CacheCategoryItem>[
      CacheCategoryItem(
        title: 'App & System Cache',
        description: 'Temporary files, network cache & cached web assets',
        icon: Icons.cached_rounded,
        bytes: appCacheBytes,
        fileCount: appCacheFiles,
      ),
      CacheCategoryItem(
        title: 'Thumbnails & Media Buffers',
        description: 'Cached image previews, video frames & album art',
        icon: Icons.photo_library_outlined,
        bytes: thumbBytes,
        fileCount: thumbFiles,
      ),
      CacheCategoryItem(
        title: 'Residual & Partial Downloads',
        description: 'Unfinished download files (.tmp, .downloading)',
        icon: Icons.file_download_off_outlined,
        bytes: tempDownloadBytes,
        fileCount: tempDownloadFiles,
      ),
    ];

    final totalBytes = appCacheBytes + thumbBytes + tempDownloadBytes;
    final totalFiles = appCacheFiles + thumbFiles + tempDownloadFiles;

    _lastAnalysis = CacheAnalysisResult(
      totalBytes: totalBytes,
      totalFiles: totalFiles,
      categories: categories,
    );

    _isAnalyzing = false;
    notifyListeners();
    return _lastAnalysis!;
  }

  Future<CleanupResult> cleanCache({Function(String status, double progress)? onProgress}) async {
    _isCleaning = true;
    _cleanProgress = 0.0;
    _currentCleaningItem = 'Preparing cleanup...';
    notifyListeners();

    int bytesFreed = 0;
    int filesDeleted = 0;

    try {
      // 1. Clear Flutter in-memory image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      _currentCleaningItem = 'Wiping memory image cache...';
      _cleanProgress = 0.10;
      onProgress?.call(_currentCleaningItem, _cleanProgress);
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 150));

      // 2. Collect all files to delete
      final filesToDelete = <File>[];
      final tempDirs = await _getTempDirectories();

      for (final dir in tempDirs) {
        if (!dir.existsSync()) continue;
        try {
          await for (final entity in dir.list(recursive: true, followLinks: false)) {
            if (entity is File) {
              filesToDelete.add(entity);
            }
          }
        } catch (_) {}
      }

      // Residual files in Download
      final downloadDir = Directory(p.join(FileService.internalStoragePath, 'Download'));
      if (downloadDir.existsSync()) {
        try {
          await for (final entity in downloadDir.list(recursive: false, followLinks: false)) {
            if (entity is File) {
              final name = p.basename(entity.path).toLowerCase();
              if (name.endsWith('.downloading') || name.endsWith('.tmp') || name.endsWith('.crdownload')) {
                filesToDelete.add(entity);
              }
            }
          }
        } catch (_) {}
      }

      final totalFiles = filesToDelete.length;
      for (int i = 0; i < totalFiles; i++) {
        final file = filesToDelete[i];
        final name = p.basename(file.path);
        _currentCleaningItem = 'Deleting $name...';
        _cleanProgress = 0.10 + (0.80 * ((i + 1) / (totalFiles > 0 ? totalFiles : 1)));
        onProgress?.call(_currentCleaningItem, _cleanProgress);
        notifyListeners();

        try {
          final size = file.lengthSync();
          await file.delete();
          bytesFreed += size;
          filesDeleted++;
        } catch (_) {}

        // Small pause for smooth visual animation if many files
        if (totalFiles < 50) {
          await Future.delayed(const Duration(milliseconds: 15));
        }
      }

      // Delete empty directories in temp
      for (final dir in tempDirs) {
        if (!dir.existsSync()) continue;
        try {
          await for (final entity in dir.list(recursive: false, followLinks: false)) {
            if (entity is Directory) {
              try {
                if (entity.listSync().isEmpty) {
                  await entity.delete();
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      _currentCleaningItem = 'Optimizing storage tables...';
      _cleanProgress = 1.0;
      onProgress?.call(_currentCleaningItem, _cleanProgress);
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 250));

      // Re-analyze to update state
      await analyzeCache();

      _isCleaning = false;
      notifyListeners();

      return CleanupResult(
        bytesFreed: bytesFreed,
        filesDeleted: filesDeleted,
        success: true,
      );
    } catch (e) {
      _isCleaning = false;
      notifyListeners();
      return CleanupResult(
        bytesFreed: bytesFreed,
        filesDeleted: filesDeleted,
        success: false,
      );
    }
  }
}
