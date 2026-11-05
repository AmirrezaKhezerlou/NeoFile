import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class ArchiveService {
  static Future<bool> compressToZip({
    required List<String> sourcePaths,
    required String outputZipPath,
    String? password,
    void Function(double progress, String currentFile)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final archive = Archive();
    final allFiles = <File>[];

    // Collect all files to compress
    for (final path in sourcePaths) {
      if (isCancelled?.call() == true) return false;
      if (await FileSystemEntity.isDirectory(path)) {
        final dir = Directory(path);
        final list = dir.listSync(recursive: true, followLinks: false);
        for (final entity in list) {
          if (entity is File) allFiles.add(entity);
        }
      } else if (await FileSystemEntity.isFile(path)) {
        allFiles.add(File(path));
      }
    }

    if (allFiles.isEmpty) return false;

    // Determine common root to preserve relative folder structures
    final baseDir = p.dirname(sourcePaths.first);

    for (int i = 0; i < allFiles.length; i++) {
      if (isCancelled?.call() == true) return false;

      final file = allFiles[i];
      final relativePath = p.relative(file.path, from: baseDir).replaceAll('\\', '/');
      final bytes = await file.readAsBytes();

      archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      onProgress?.call((i + 1) / (allFiles.length + 1), p.basename(file.path));
    }

    if (isCancelled?.call() == true) return false;

    // Encode archive with optional password
    final zipEncoder = ZipEncoder(password: password);
    final encoded = zipEncoder.encode(archive);

    final outFile = File(outputZipPath);
    await outFile.writeAsBytes(encoded);
    onProgress?.call(1.0, p.basename(outputZipPath));

    return true;
  }

  static Future<bool> extractArchive({
    required String archivePath,
    required String destinationDir,
    String? password,
    void Function(double progress, String currentFile)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final file = File(archivePath);
    if (!await file.exists()) return false;

    final bytes = await file.readAsBytes();
    final ext = p.extension(archivePath).toLowerCase();

    Archive? archive;
    try {
      if (ext == '.zip') {
        archive = ZipDecoder().decodeBytes(bytes, password: password);
      } else if (ext == '.tar') {
        archive = TarDecoder().decodeBytes(bytes);
      } else if (ext == '.gz' || ext == '.tgz') {
        final decompressed = GZipDecoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(decompressed);
      } else if (ext == '.bz2') {
        final decompressed = BZip2Decoder().decodeBytes(bytes);
        archive = TarDecoder().decodeBytes(decompressed);
      } else {
        // Try ZipDecoder as fallback
        archive = ZipDecoder().decodeBytes(bytes, password: password);
      }
    } catch (_) {
      return false;
    }

    if (archive.isEmpty) return false;

    final dest = Directory(destinationDir);
    await dest.create(recursive: true);

    for (int i = 0; i < archive.length; i++) {
      if (isCancelled?.call() == true) return false;

      final item = archive[i];
      final itemPath = p.join(destinationDir, item.name);

      if (item.isFile) {
        final data = item.content as List<int>;
        final outFile = File(itemPath);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data);
      } else {
        await Directory(itemPath).create(recursive: true);
      }

      onProgress?.call((i + 1) / archive.length, item.name);
    }

    return true;
  }
}
