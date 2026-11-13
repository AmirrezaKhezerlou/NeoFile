import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum VaultAuthType { password, pattern }

class VaultService {
  VaultService._();
  static final VaultService instance = VaultService._();

  static const String prefVaultInitialized = 'neofile_vault_initialized';
  static const String prefVaultAuthType = 'neofile_vault_auth_type';
  static const String prefVaultSalt = 'neofile_vault_salt';
  static const String prefVaultHash = 'neofile_vault_hash';
  static const String prefVaultHint = 'neofile_vault_hint';

  static const List<String> defaultCategories = ['Images', 'Videos', 'Files'];

  bool _isUnlocked = false;
  bool get isUnlocked => _isUnlocked;

  void lock() {
    _isUnlocked = false;
  }

  void forceUnlockForTesting() {
    _isUnlocked = true;
  }

  Future<bool> isInitialized([SharedPreferences? customPrefs]) async {
    final prefs = customPrefs ?? await SharedPreferences.getInstance();
    return prefs.getBool(prefVaultInitialized) ?? false;
  }

  Future<VaultAuthType> getAuthType([SharedPreferences? customPrefs]) async {
    final prefs = customPrefs ?? await SharedPreferences.getInstance();
    final typeStr = prefs.getString(prefVaultAuthType);
    return typeStr == 'pattern' ? VaultAuthType.pattern : VaultAuthType.password;
  }

  Future<String?> getHint([SharedPreferences? customPrefs]) async {
    final prefs = customPrefs ?? await SharedPreferences.getInstance();
    return prefs.getString(prefVaultHint);
  }

  String _hashSecret(String secret, String salt) {
    final bytes = utf8.encode('$salt:$secret');
    return sha256.convert(bytes).toString();
  }

  String _generateSalt() {
    final rnd = Random.secure();
    final values = List<int>.generate(16, (i) => rnd.nextInt(256));
    return base64Url.encode(values);
  }

  Future<void> setupVault({
    required VaultAuthType authType,
    required String secret,
    String? hint,
    SharedPreferences? customPrefs,
  }) async {
    final prefs = customPrefs ?? await SharedPreferences.getInstance();
    final salt = _generateSalt();
    final hash = _hashSecret(secret, salt);

    await prefs.setBool(prefVaultInitialized, true);
    await prefs.setString(prefVaultAuthType, authType.name);
    await prefs.setString(prefVaultSalt, salt);
    await prefs.setString(prefVaultHash, hash);
    if (hint != null && hint.trim().isNotEmpty) {
      await prefs.setString(prefVaultHint, hint.trim());
    } else {
      await prefs.remove(prefVaultHint);
    }

    _isUnlocked = true;
    await ensureVaultStorageInitialized();
  }

  Future<bool> verifySecret(String secret, [SharedPreferences? customPrefs]) async {
    final prefs = customPrefs ?? await SharedPreferences.getInstance();
    final salt = prefs.getString(prefVaultSalt);
    final savedHash = prefs.getString(prefVaultHash);

    if (salt == null || savedHash == null) {
      return false;
    }

    final computedHash = _hashSecret(secret, salt);
    final isValid = computedHash == savedHash;
    if (isValid) {
      _isUnlocked = true;
      await ensureVaultStorageInitialized();
    }
    return isValid;
  }

  Future<void> changeSecret({
    required VaultAuthType authType,
    required String newSecret,
    String? hint,
    SharedPreferences? customPrefs,
  }) async {
    final prefs = customPrefs ?? await SharedPreferences.getInstance();
    final salt = _generateSalt();
    final hash = _hashSecret(newSecret, salt);

    await prefs.setString(prefVaultAuthType, authType.name);
    await prefs.setString(prefVaultSalt, salt);
    await prefs.setString(prefVaultHash, hash);
    if (hint != null && hint.trim().isNotEmpty) {
      await prefs.setString(prefVaultHint, hint.trim());
    } else {
      await prefs.remove(prefVaultHint);
    }
  }

  String? _customBasePath;
  void setCustomBasePathForTesting(String? path) {
    _customBasePath = path;
  }

  Future<String> getVaultBasePath() async {
    if (_customBasePath != null) {
      final dir = Directory(_customBasePath!);
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    }
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final vaultDir = Directory(p.join(docDir.path, '.neofile_vault'));
      if (!await vaultDir.exists()) {
        await vaultDir.create(recursive: true);
      }
      return vaultDir.path;
    } catch (_) {
      final fallbackDir = Directory(p.join(Directory.systemTemp.path, '.neofile_vault_test'));
      if (!await fallbackDir.exists()) {
        await fallbackDir.create(recursive: true);
      }
      return fallbackDir.path;
    }
  }

  Future<void> ensureVaultStorageInitialized() async {
    final basePath = await getVaultBasePath();
    final baseDir = Directory(basePath);
    if (!await baseDir.exists()) {
      await baseDir.create(recursive: true);
    }

    // Write .nomedia file in base directory to hide from Android media scanner
    final baseNoMedia = File(p.join(basePath, '.nomedia'));
    if (!await baseNoMedia.exists()) {
      await baseNoMedia.writeAsString('');
    }

    // Ensure default categories: Images, Videos, Files
    for (final cat in defaultCategories) {
      final catDir = Directory(p.join(basePath, cat));
      if (!await catDir.exists()) {
        await catDir.create(recursive: true);
      }
      final catNoMedia = File(p.join(catDir.path, '.nomedia'));
      if (!await catNoMedia.exists()) {
        await catNoMedia.writeAsString('');
      }
    }
  }

  static String detectCategory(String filePath) {
    final ext = p.extension(filePath).toLowerCase().replaceAll('.', '');
    const imageExts = {'jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'svg', 'heic'};
    const videoExts = {'mp4', 'mkv', 'mov', 'avi', 'webm', 'flv', '3gp', 'wmv'};

    if (imageExts.contains(ext)) return 'Images';
    if (videoExts.contains(ext)) return 'Videos';
    return 'Files';
  }

  Future<List<String>> importFiles(
    List<String> sourcePaths, {
    String? targetCategory,
    String? targetSubdir,
  }) async {
    await ensureVaultStorageInitialized();
    final basePath = await getVaultBasePath();
    final importedPaths = <String>[];

    for (final src in sourcePaths) {
      final entity = FileSystemEntity.typeSync(src);
      if (entity == FileSystemEntityType.notFound) continue;

      final category = targetCategory ?? (entity == FileSystemEntityType.directory ? 'Files' : detectCategory(src));
      final catPath = targetSubdir != null && targetSubdir.isNotEmpty
          ? p.join(basePath, category, targetSubdir)
          : p.join(basePath, category);

      final catDir = Directory(catPath);
      if (!await catDir.exists()) {
        await catDir.create(recursive: true);
      }

      final fileName = p.basename(src);
      String destPath = p.join(catPath, fileName);

      // Handle duplicate names
      int counter = 1;
      final nameWithoutExt = p.basenameWithoutExtension(fileName);
      final ext = p.extension(fileName);
      while (await FileSystemEntity.type(destPath) != FileSystemEntityType.notFound) {
        destPath = p.join(catPath, '$nameWithoutExt ($counter)$ext');
        counter++;
      }

      if (entity == FileSystemEntityType.directory) {
        await _moveDirectory(Directory(src), Directory(destPath));
      } else {
        await _moveFile(File(src), File(destPath));
      }

      importedPaths.add(destPath);
    }

    return importedPaths;
  }

  Future<void> _moveFile(File src, File dest) async {
    try {
      await src.rename(dest.path);
    } catch (_) {
      // Cross-filesystem move: stream copy and delete source
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
      // Cross-filesystem directory move
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

  Future<List<String>> exportFiles(List<String> vaultPaths, String destinationDir) async {
    final destDir = Directory(destinationDir);
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final exportedPaths = <String>[];
    for (final path in vaultPaths) {
      final entity = FileSystemEntity.typeSync(path);
      if (entity == FileSystemEntityType.notFound) continue;

      final name = p.basename(path);
      String destPath = p.join(destinationDir, name);
      int counter = 1;
      final nameWithoutExt = p.basenameWithoutExtension(name);
      final ext = p.extension(name);
      while (await FileSystemEntity.type(destPath) != FileSystemEntityType.notFound) {
        destPath = p.join(destinationDir, '$nameWithoutExt ($counter)$ext');
        counter++;
      }

      if (entity == FileSystemEntityType.directory) {
        await _moveDirectory(Directory(path), Directory(destPath));
      } else {
        await _moveFile(File(path), File(destPath));
      }
      exportedPaths.add(destPath);
    }
    return exportedPaths;
  }

  Future<int> getTotalVaultSize() async {
    try {
      final basePath = await getVaultBasePath();
      final dir = Directory(basePath);
      if (!await dir.exists()) return 0;

      int total = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name != '.nomedia') {
            try {
              total += await entity.length();
            } catch (_) {}
          }
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<int> getTotalVaultItemCount() async {
    try {
      final basePath = await getVaultBasePath();
      final dir = Directory(basePath);
      if (!await dir.exists()) return 0;

      int count = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          final name = p.basename(entity.path);
          if (name != '.nomedia') {
            count++;
          }
        }
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<void> createFolder(String parentPath, String folderName) async {
    final newDir = Directory(p.join(parentPath, folderName));
    if (!await newDir.exists()) {
      await newDir.create(recursive: true);
      final noMedia = File(p.join(newDir.path, '.nomedia'));
      if (!await noMedia.exists()) {
        await noMedia.writeAsString('');
      }
    }
  }

  Future<void> deleteVaultItems(List<String> paths) async {
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
}
