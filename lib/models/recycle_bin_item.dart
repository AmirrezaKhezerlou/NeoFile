import 'package:intl/intl.dart';

class RecycleBinItem {
  final String id;
  final String originalPath;
  final String originalName;
  final String recycledPath;
  final DateTime deletedAt;
  final int size;
  final bool isDirectory;

  const RecycleBinItem({
    required this.id,
    required this.originalPath,
    required this.originalName,
    required this.recycledPath,
    required this.deletedAt,
    required this.size,
    required this.isDirectory,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'originalPath': originalPath,
        'originalName': originalName,
        'recycledPath': recycledPath,
        'deletedAt': deletedAt.toIso8601String(),
        'size': size,
        'isDirectory': isDirectory,
      };

  factory RecycleBinItem.fromJson(Map<String, dynamic> json) => RecycleBinItem(
        id: json['id'] as String,
        originalPath: json['originalPath'] as String,
        originalName: json['originalName'] as String,
        recycledPath: json['recycledPath'] as String,
        deletedAt: DateTime.parse(json['deletedAt'] as String),
        size: json['size'] as int? ?? 0,
        isDirectory: json['isDirectory'] as bool? ?? false,
      );

  String formatSize() {
    if (isDirectory) return 'Folder';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  String formatDeletedDate() {
    return DateFormat('yyyy-MM-dd HH:mm').format(deletedAt);
  }
}
