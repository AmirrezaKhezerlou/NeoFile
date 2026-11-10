import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;

class ArchiveService {
  /// Compresses one or more files and/or directories into a standard ZIP archive.
  /// Handles nested directory structures, empty folders, and is resilient to
  /// permission restrictions during traversal.
  static Future<bool> compressToZip({
    required List<String> sourcePaths,
    required String outputZipPath,
    String? password,
    void Function(double progress, String currentFile)? onProgress,
    bool Function()? isCancelled,
  }) async {
    if (sourcePaths.isEmpty) return false;

    final archive = Archive();
    final directoriesToArchive = <Directory>[];
    final filesToArchive = <File>[];

    final normOutput = p.canonicalize(outputZipPath);

    // 1. Gather all files and directories safely using iterative traversal
    for (final rawPath in sourcePaths) {
      if (isCancelled?.call() == true) return false;
      final normalized = p.normalize(rawPath);

      bool isDir = false;
      try {
        isDir = FileSystemEntity.isDirectorySync(normalized);
      } catch (_) {
        isDir = Directory(normalized).existsSync();
      }

      if (isDir) {
        final rootDir = Directory(normalized);
        directoriesToArchive.add(rootDir);

        final queue = <Directory>[rootDir];
        while (queue.isNotEmpty) {
          if (isCancelled?.call() == true) return false;
          final current = queue.removeAt(0);

          try {
            final children = current.listSync(followLinks: false);
            for (final child in children) {
              if (isCancelled?.call() == true) return false;

              // Don't include the output zip file itself if placed inside the source tree
              if (p.canonicalize(child.path) == normOutput) continue;

              if (child is Directory) {
                directoriesToArchive.add(child);
                queue.add(child);
              } else if (child is File) {
                filesToArchive.add(child);
              }
            }
          } catch (_) {
            // Skip unreadable or permission-restricted subdirectories
          }
        }
      } else {
        bool isFile = false;
        try {
          isFile = FileSystemEntity.isFileSync(normalized);
        } catch (_) {
          isFile = File(normalized).existsSync();
        }

        if (isFile) {
          if (p.canonicalize(normalized) != normOutput) {
            filesToArchive.add(File(normalized));
          }
        }
      }
    }

    if (directoriesToArchive.isEmpty && filesToArchive.isEmpty) {
      return false;
    }

    // 2. Determine base directory for relative archive path resolution
    final baseDir = p.dirname(p.normalize(sourcePaths.first));

    // 3. Add directory entries to archive (preserves folder tree and empty folders)
    for (final dir in directoriesToArchive) {
      final relDir = p.relative(dir.path, from: baseDir).replaceAll('\\', '/');
      if (relDir.isNotEmpty && relDir != '.') {
        final entryName = relDir.endsWith('/') ? relDir : '$relDir/';
        archive.addFile(ArchiveFile.directory(entryName));
      }
    }

    // 4. Add file entries with progress callback
    final totalFiles = filesToArchive.length;
    for (int i = 0; i < totalFiles; i++) {
      if (isCancelled?.call() == true) return false;

      final file = filesToArchive[i];
      final relPath = p.relative(file.path, from: baseDir).replaceAll('\\', '/');

      try {
        final bytes = await file.readAsBytes();
        archive.addFile(ArchiveFile(relPath, bytes.length, bytes));
      } catch (_) {
        // Skip inaccessible single files
      }

      final progress = totalFiles > 0 ? (i + 1) / (totalFiles + 1) : 0.9;
      onProgress?.call(progress, p.basename(file.path));
    }

    if (isCancelled?.call() == true) return false;

    // 5. Encode archive with optional password
    try {
      final zipEncoder = ZipEncoder(password: password);
      final encoded = zipEncoder.encode(archive);

      final outFile = File(outputZipPath);
      await outFile.parent.create(recursive: true);
      await outFile.writeAsBytes(encoded);
      onProgress?.call(1.0, p.basename(outputZipPath));
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Extracts ZIP, TAR, GZ, TGZ, BZ2 archives to destination directory
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
        archive = ZipDecoder().decodeBytes(bytes, password: password);
      }
    } catch (_) {
      return false;
    }

    if (archive.isEmpty) return false;

    final canonicalDest = p.canonicalize(destinationDir);
    final dest = Directory(canonicalDest);
    await dest.create(recursive: true);

    for (int i = 0; i < archive.length; i++) {
      if (isCancelled?.call() == true) return false;

      final item = archive[i];
      // Sanitize item name: strip leading separators, resolve relative steps
      final safeName = p.normalize(item.name).replaceAll(RegExp(r'^(/|\\)+'), '');
      final itemPath = p.canonicalize(p.join(canonicalDest, safeName));

      // Security: Zip Slip path traversal mitigation
      if (!p.isWithin(canonicalDest, itemPath) && itemPath != canonicalDest) {
        // Skip entry attempting to escape destination directory
        continue;
      }

      if (!item.isFile) {
        await Directory(itemPath).create(recursive: true);
      } else {
        final outFile = File(itemPath);
        await outFile.parent.create(recursive: true);
        await outFile.writeAsBytes(item.content);
      }
      onProgress?.call((i + 1) / archive.length, p.basename(item.name));
    }

    return true;
  }
}
