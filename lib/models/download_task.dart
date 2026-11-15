import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

enum DownloadStatus {
  queued,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

enum DownloadCategory {
  programs,
  videos,
  images,
  documents,
  audio,
  others,
}

extension DownloadCategoryX on DownloadCategory {
  String get displayName {
    switch (this) {
      case DownloadCategory.programs:
        return 'Programs';
      case DownloadCategory.videos:
        return 'Video';
      case DownloadCategory.images:
        return 'Image';
      case DownloadCategory.documents:
        return 'Document';
      case DownloadCategory.audio:
        return 'Music';
      case DownloadCategory.others:
        return 'General';
    }
  }

  IconData get icon {
    switch (this) {
      case DownloadCategory.programs:
        return Icons.apps_rounded;
      case DownloadCategory.videos:
        return Icons.videocam_rounded;
      case DownloadCategory.images:
        return Icons.image_rounded;
      case DownloadCategory.documents:
        return Icons.description_rounded;
      case DownloadCategory.audio:
        return Icons.music_note_rounded;
      case DownloadCategory.others:
        return Icons.folder_zip_rounded;
    }
  }

  Color get color {
    switch (this) {
      case DownloadCategory.programs:
        return const Color(0xFF0078D4); // Fluent Blue
      case DownloadCategory.videos:
        return const Color(0xFF881798); // Fluent Purple
      case DownloadCategory.images:
        return const Color(0xFFD83B01); // Fluent Orange
      case DownloadCategory.documents:
        return const Color(0xFF107C41); // Fluent Green
      case DownloadCategory.audio:
        return const Color(0xFF008272); // Fluent Teal
      case DownloadCategory.others:
        return const Color(0xFF797775); // Fluent Slate
    }
  }

  static DownloadCategory detectFromFileName(String fileName) {
    final ext = p.extension(fileName).toLowerCase().replaceAll('.', '');
    const programExts = {'apk', 'exe', 'msi', 'zip', 'rar', '7z', 'tar', 'gz', 'iso', 'dmg', 'xapk'};
    const videoExts = {'mp4', 'mkv', 'mov', 'avi', 'webm', 'flv', '3gp', 'wmv', 'm4v', 'ts'};
    const imageExts = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'svg', 'heic', 'ico', 'tiff'};
    const docExts = {'pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx', 'txt', 'md', 'epub', 'rtf', 'csv'};
    const audioExts = {'mp3', 'wav', 'm4a', 'aac', 'flac', 'ogg', 'opus', 'wma', 'mid'};

    if (programExts.contains(ext)) return DownloadCategory.programs;
    if (videoExts.contains(ext)) return DownloadCategory.videos;
    if (imageExts.contains(ext)) return DownloadCategory.images;
    if (docExts.contains(ext)) return DownloadCategory.documents;
    if (audioExts.contains(ext)) return DownloadCategory.audio;
    return DownloadCategory.others;
  }
}

class DownloadTask {
  final String id;
  final String url;
  String fileName;
  DownloadCategory category;
  String destinationPath;
  int totalBytes;
  int downloadedBytes;
  DownloadStatus status;
  int speedBytesPerSec;
  final DateTime createdAt;
  DateTime? completedAt;
  String? errorMessage;
  bool useSystemProxy;
  String? customProxy;

  DownloadTask({
    required this.id,
    required this.url,
    required this.fileName,
    required this.category,
    required this.destinationPath,
    this.totalBytes = -1,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.queued,
    this.speedBytesPerSec = 0,
    required this.createdAt,
    this.completedAt,
    this.errorMessage,
    this.useSystemProxy = false,
    this.customProxy,
  });

  double get progress {
    if (totalBytes <= 0) return status == DownloadStatus.completed ? 1.0 : 0.0;
    return (downloadedBytes / totalBytes).clamp(0.0, 1.0);
  }

  String get percentageString {
    if (totalBytes <= 0) {
      return status == DownloadStatus.completed ? '100%' : '--%';
    }
    return '${(progress * 100).toStringAsFixed(1)}%';
  }

  String get formattedSpeed {
    if (status != DownloadStatus.downloading || speedBytesPerSec <= 0) {
      return '';
    }
    return '${formatBytes(speedBytesPerSec)}/s';
  }

  String get formattedSize {
    final down = formatBytes(downloadedBytes);
    if (totalBytes <= 0) return down;
    final total = formatBytes(totalBytes);
    return '$down / $total';
  }

  String get estimatedTimeRemaining {
    if (status != DownloadStatus.downloading || speedBytesPerSec <= 0 || totalBytes <= 0) {
      return '';
    }
    final remainingBytes = totalBytes - downloadedBytes;
    if (remainingBytes <= 0) return '00:00';

    final seconds = (remainingBytes / speedBytesPerSec).round();
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final m = seconds ~/ 60;
      final s = seconds % 60;
      return '${m}m ${s}s';
    } else {
      final h = seconds ~/ 3600;
      final m = (seconds % 3600) ~/ 60;
      return '${h}h ${m}m';
    }
  }

  bool get canPause => status == DownloadStatus.downloading;
  bool get canResume => status == DownloadStatus.paused || status == DownloadStatus.failed;
  bool get isCompleted => status == DownloadStatus.completed;

  static String formatBytes(int bytes) {
    if (bytes < 0) return 'Unknown';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'fileName': fileName,
        'category': category.name,
        'destinationPath': destinationPath,
        'totalBytes': totalBytes,
        'downloadedBytes': downloadedBytes,
        'status': status.name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'completedAt': completedAt?.millisecondsSinceEpoch,
        'errorMessage': errorMessage,
        'useSystemProxy': useSystemProxy,
        'customProxy': customProxy,
      };

  factory DownloadTask.fromJson(Map<String, dynamic> json) {
    DownloadCategory cat = DownloadCategory.others;
    try {
      cat = DownloadCategory.values.firstWhere((e) => e.name == json['category']);
    } catch (_) {}

    DownloadStatus st = DownloadStatus.queued;
    try {
      st = DownloadStatus.values.firstWhere((e) => e.name == json['status']);
    } catch (_) {}

    return DownloadTask(
      id: json['id'] as String,
      url: json['url'] as String,
      fileName: json['fileName'] as String,
      category: cat,
      destinationPath: json['destinationPath'] as String,
      totalBytes: json['totalBytes'] as int? ?? -1,
      downloadedBytes: json['downloadedBytes'] as int? ?? 0,
      status: st == DownloadStatus.downloading ? DownloadStatus.paused : st,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int? ?? 0),
      completedAt: json['completedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['completedAt'] as int)
          : null,
      errorMessage: json['errorMessage'] as String?,
      useSystemProxy: json['useSystemProxy'] as bool? ?? false,
      customProxy: json['customProxy'] as String?,
    );
  }
}
