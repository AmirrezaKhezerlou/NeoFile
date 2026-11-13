import 'dart:io';
import 'package:path/path.dart' as p;

class FileItem {
  final String path;
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime modified;
  final DateTime? created;
  final DateTime? accessed;
  final bool isHidden;
  final String extension;
  final int? itemCount;

  FileItem({
    required this.path,
    required this.name,
    required this.isDirectory,
    required this.size,
    required this.modified,
    this.created,
    this.accessed,
    required this.isHidden,
    required this.extension,
    this.itemCount,
  });

  factory FileItem.fromFileSystemEntity(FileSystemEntity entity) {
    final stat = entity.statSync();
    final name = p.basename(entity.path);
    final isDir = entity is Directory;
    final isHidden = name.startsWith('.');
    final ext = isDir ? '' : p.extension(entity.path).toLowerCase().replaceAll('.', '');

    int? childCount;
    // ponytail: count children for small folders, skip recursive depth for fast I/O
    if (isDir) {
      try {
        final list = entity.listSync(followLinks: false);
        childCount = list.length;
      } catch (_) {
        childCount = null;
      }
    }

    return FileItem(
      path: entity.path,
      name: name,
      isDirectory: isDir,
      size: isDir ? 0 : stat.size,
      modified: stat.modified,
      accessed: stat.accessed,
      isHidden: isHidden,
      extension: ext,
      itemCount: childCount,
    );
  }

  String formatSize() {
    if (isDirectory) {
      return itemCount != null ? '$itemCount items' : 'Folder';
    }
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  bool get isPdf => extension == 'pdf';
  bool get isWord => ['doc', 'docx', 'rtf'].contains(extension);
  bool get isExcel => ['xls', 'xlsx', 'csv'].contains(extension);
  bool get isPpt => ['ppt', 'pptx'].contains(extension);
  bool get isImage => ['png', 'jpg', 'jpeg', 'webp', 'gif', 'svg', 'bmp'].contains(extension);
  bool get isVideo => ['mp4', 'mkv', 'mov', 'avi', 'webm', 'flv'].contains(extension);
  bool get isAudio => ['mp3', 'wav', 'ogg', 'm4a', 'flac', 'aac'].contains(extension);
  bool get isArchive => ['zip', 'rar', '7z', 'tar', 'gz'].contains(extension);
  bool get isApk => extension == 'apk';
  bool get isText => ['txt', 'log', 'md', 'json', 'yaml', 'yml', 'xml', 'csv', 'ini', 'conf', 'dart', 'py', 'js', 'html', 'css', 'sql', 'sh', 'bat', 'properties'].contains(extension);
  bool get isCode => ['dart', 'py', 'js', 'html', 'css', 'json', 'yaml', 'xml', 'cpp', 'c', 'java', 'kt', 'txt', 'md'].contains(extension);

  String get typeDescription {
    if (isDirectory) return 'File folder';
    if (isPdf) return 'Adobe Acrobat Document (.pdf)';
    if (isWord) return 'Microsoft Word Document (.$extension)';
    if (isExcel) return 'Microsoft Excel Worksheet (.$extension)';
    if (isPpt) return 'Microsoft PowerPoint Presentation (.$extension)';
    if (isImage) return '${extension.toUpperCase()} Image File';
    if (isVideo) return '${extension.toUpperCase()} Video File';
    if (isAudio) return '${extension.toUpperCase()} Audio File';
    if (isArchive) return '${extension.toUpperCase()} Archive File';
    if (isApk) return 'Android Application Package (.apk)';
    if (isCode) return '${extension.toUpperCase()} Source File';
    return '${extension.toUpperCase()} File';
  }
}
