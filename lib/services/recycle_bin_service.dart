import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/recycle_bin_item.dart';

class RecycleBinService {
  RecycleBinService._();
  static final RecycleBinService instance = RecycleBinService._();

  static const String metadataFileName = 'recycle_bin_metadata.json';

  String? _customBasePath;
  void setCustomBasePathForTesting(String? path) {
    _customBasePath = path;
  }

  Future<String> getBinBasePath() async {
    if (_customBasePath != null) {
      final dir = Directory(_customBasePath!);
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    }
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final binDir = Directory(p.join(docDir.path, '.neofile_recycle_bin'));
      if (!await binDir.exists()) {
        await binDir.create(recursive: true);
      }
      final noMedia = File(p.join(binDir.path, '.nomedia'));
      if (!await noMedia.exists()) {
        await noMedia.writeAsString('');
      }
      return binDir.path;
    } catch (_) {
      final fallback = Directory(p.join(Directory.systemTemp.path, '.neofile_recycle_bin_test'));
      if (!await fallback.exists()) {
        await fallback.create(recursive: true);
      }
      return fallback.path;
    }
  }

  Future<File> _getMetadataFile() async {
    final basePath = await getBinBasePath();
    return File(p.join(basePath, metadataFileName));
  }

  Future<List<RecycleBinItem>> getItems() async {
    try {
      final metaFile = await _getMetadataFile();
      if (!await metaFile.exists()) return [];

      final content = await metaFile.readAsString();
      if (content.trim().isEmpty) return [];

      final list = jsonDecode(content) as List<dynamic>;
      final items = list
          .map((e) => RecycleBinItem.fromJson(e as Map<String, dynamic>))
          .where((item) => FileSystemEntity.typeSync(item.recycledPath) != FileSystemEntityType.notFound)
          .toList();

      items.sort((a, b) => b.deletedAt.compareTo(a.deletedAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveItems(List<RecycleBinItem> items) async {
    final metaFile = await _getMetadataFile();
    final jsonList = items.map((e) => e.toJson()).toList();
    await metaFile.writeAsString(jsonEncode(jsonList));
  }

  String _generateId() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final rnd = Random().nextInt(999999);
    return '${now}_$rnd';
  }

  Future<List<RecycleBinItem>> moveToBin(List<String> paths) async {
    final basePath = await getBinBasePath();
    final currentItems = await getItems();
    final newItems = <RecycleBinItem>[];

    for (final path in paths) {
      final entityType = FileSystemEntity.typeSync(path);
      if (entityType == FileSystemEntityType.notFound) continue;

      final isDir = entityType == FileSystemEntityType.directory;
      final originalName = p.basename(path);
      final id = _generateId();
      final recycledPath = p.join(basePath, id);

      int size = 0;
      if (!isDir) {
        try {
          size = await File(path).length();
        } catch (_) {}
      }

      if (isDir) {
        await _moveDirectory(Directory(path), Directory(recycledPath));
      } else {
        await _moveFile(File(path), File(recycledPath));
      }

      final item = RecycleBinItem(
        id: id,
        originalPath: path,
        originalName: originalName,
        recycledPath: recycledPath,
        deletedAt: DateTime.now(),
        size: size,
        isDirectory: isDir,
      );

      newItems.add(item);
      currentItems.add(item);
    }

    await _saveItems(currentItems);
    return newItems;
  }

  Future<void> _moveFile(File src, File dest) async {
    try {
      await src.rename(dest.path);
    } catch (_) {
      await src.copy(dest.path);
      try {
        await src.delete();
      } catch (_) {}
    }
  }

  Future<void> _moveDirectory(Directory src, Directory dest) async {
    try {
      await src.rename(dest.path);
    } catch (_) {
      if (!await dest.exists()) {
        await dest.create(recursive: true);
      }
      final entities = src.listSync(recursive: false);
      for (final entity in entities) {
        final newPath = p.join(dest.path, p.basename(entity.path));
        if (entity is Directory) {
          await _moveDirectory(entity, Directory(newPath));
        } else if (entity is File) {
          await _moveFile(entity, File(newPath));
        }
      }
      try {
        await src.delete(recursive: true);
      } catch (_) {}
    }
  }

  Future<void> restoreItems(List<String> itemIds) async {
    final currentItems = await getItems();
    final remainingItems = <RecycleBinItem>[];

    for (final item in currentItems) {
      if (itemIds.contains(item.id)) {
        // Restore
        final parentDir = Directory(p.dirname(item.originalPath));
        if (!await parentDir.exists()) {
          await parentDir.create(recursive: true);
        }

        String destPath = item.originalPath;
        int counter = 1;
        final nameWithoutExt = p.basenameWithoutExtension(item.originalName);
        final ext = p.extension(item.originalName);

        while (await FileSystemEntity.type(destPath) != FileSystemEntityType.notFound) {
          destPath = p.join(parentDir.path, '$nameWithoutExt ($counter)$ext');
          counter++;
        }

        if (item.isDirectory) {
          await _moveDirectory(Directory(item.recycledPath), Directory(destPath));
        } else {
          await _moveFile(File(item.recycledPath), File(destPath));
        }
      } else {
        remainingItems.add(item);
      }
    }

    await _saveItems(remainingItems);
  }

  Future<void> restoreAll() async {
    final items = await getItems();
    await restoreItems(items.map((e) => e.id).toList());
  }

  Future<void> deletePermanently(List<String> itemIds) async {
    final currentItems = await getItems();
    final remainingItems = <RecycleBinItem>[];

    for (final item in currentItems) {
      if (itemIds.contains(item.id)) {
        try {
          if (item.isDirectory) {
            final dir = Directory(item.recycledPath);
            if (await dir.exists()) await dir.delete(recursive: true);
          } else {
            final file = File(item.recycledPath);
            if (await file.exists()) await file.delete();
          }
        } catch (_) {}
      } else {
        remainingItems.add(item);
      }
    }

    await _saveItems(remainingItems);
  }

  Future<void> emptyBin() async {
    final currentItems = await getItems();
    for (final item in currentItems) {
      try {
        if (item.isDirectory) {
          final dir = Directory(item.recycledPath);
          if (await dir.exists()) await dir.delete(recursive: true);
        } else {
          final file = File(item.recycledPath);
          if (await file.exists()) await file.delete();
        }
      } catch (_) {}
    }
    await _saveItems([]);
  }

  Future<int> cleanupExpiredItems(int retentionDays) async {
    if (retentionDays <= 0) return 0; // 0 means keep indefinitely

    final currentItems = await getItems();
    final now = DateTime.now();
    final expiredIds = <String>[];

    for (final item in currentItems) {
      final daysOld = now.difference(item.deletedAt).inDays;
      if (daysOld >= retentionDays) {
        expiredIds.add(item.id);
      }
    }

    if (expiredIds.isNotEmpty) {
      await deletePermanently(expiredIds);
    }
    return expiredIds.length;
  }

  Future<int> getTotalBinSize() async {
    final items = await getItems();
    int total = 0;
    for (final item in items) {
      total += item.size;
    }
    return total;
  }
}
