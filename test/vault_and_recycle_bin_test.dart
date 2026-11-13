import 'package:flutter_test/flutter_test.dart';
import 'package:neofile/models/file_item.dart';
import 'package:neofile/models/recycle_bin_item.dart';
import 'package:neofile/providers/settings_provider.dart';
import 'package:neofile/services/recycle_bin_service.dart';
import 'package:neofile/services/vault_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaultService Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      VaultService.instance.lock();
    });

    test('isInitialized returns false initially and true after setup', () async {
      final vault = VaultService.instance;
      expect(await vault.isInitialized(), false);
      expect(vault.isUnlocked, false);

      await vault.setupVault(
        authType: VaultAuthType.password,
        secret: 'testPass123',
        hint: 'secret hint',
      );

      expect(await vault.isInitialized(), true);
      expect(vault.isUnlocked, true);
      expect(await vault.getAuthType(), VaultAuthType.password);
      expect(await vault.getHint(), 'secret hint');
    });

    test('verifySecret correctly validates password and pattern', () async {
      final vault = VaultService.instance;
      await vault.setupVault(
        authType: VaultAuthType.pattern,
        secret: '0,1,2,5,8',
      );
      vault.lock();
      expect(vault.isUnlocked, false);

      // Wrong pattern
      final wrongRes = await vault.verifySecret('0,1,2,3');
      expect(wrongRes, false);
      expect(vault.isUnlocked, false);

      // Correct pattern
      final rightRes = await vault.verifySecret('0,1,2,5,8');
      expect(rightRes, true);
      expect(vault.isUnlocked, true);
    });

    test('detectCategory classifies extensions properly', () {
      expect(VaultService.detectCategory('/path/photo.jpg'), 'Images');
      expect(VaultService.detectCategory('/path/image.PNG'), 'Images');
      expect(VaultService.detectCategory('/path/film.mp4'), 'Videos');
      expect(VaultService.detectCategory('/path/clip.mkv'), 'Videos');
      expect(VaultService.detectCategory('/path/document.pdf'), 'Files');
      expect(VaultService.detectCategory('/path/notes.txt'), 'Files');
      expect(VaultService.detectCategory('/path/archive.zip'), 'Files');
    });
  });

  group('RecycleBinItem & Retention Tests', () {
    test('RecycleBinItem serializes and deserializes properly', () {
      final now = DateTime.now();
      final item = RecycleBinItem(
        id: 'item_1',
        originalPath: '/storage/emulated/0/Download/test.pdf',
        originalName: 'test.pdf',
        recycledPath: '/data/app/.recycle_bin/item_1',
        deletedAt: now,
        size: 2048,
        isDirectory: false,
      );

      final json = item.toJson();
      final fromJson = RecycleBinItem.fromJson(json);

      expect(fromJson.id, item.id);
      expect(fromJson.originalPath, item.originalPath);
      expect(fromJson.originalName, item.originalName);
      expect(fromJson.size, 2048);
      expect(fromJson.formatSize(), '2.0 KB');
      expect(fromJson.isDirectory, false);
    });

    test('RecycleBin cleanupExpiredItems identifies expired items', () async {
      final bin = RecycleBinService.instance;
      // When retention is 0, nothing is cleaned up
      final cleanedZero = await bin.cleanupExpiredItems(0);
      expect(cleanedZero, 0);
    });
  });

  group('FileItem isText and Text Editor Detection', () {
    test('identifies text and code extensions for Notepad opening', () {
      final txtItem = FileItem(
        path: '/test/notes.txt',
        name: 'notes.txt',
        isDirectory: false,
        size: 100,
        modified: DateTime.now(),
        isHidden: false,
        extension: 'txt',
      );
      expect(txtItem.isText, true);

      final mdItem = FileItem(
        path: '/test/README.md',
        name: 'README.md',
        isDirectory: false,
        size: 200,
        modified: DateTime.now(),
        isHidden: false,
        extension: 'md',
      );
      expect(mdItem.isText, true);

      final jsonItem = FileItem(
        path: '/test/config.json',
        name: 'config.json',
        isDirectory: false,
        size: 300,
        modified: DateTime.now(),
        isHidden: false,
        extension: 'json',
      );
      expect(jsonItem.isText, true);

      final mp3Item = FileItem(
        path: '/test/song.mp3',
        name: 'song.mp3',
        isDirectory: false,
        size: 5000,
        modified: DateTime.now(),
        isHidden: false,
        extension: 'mp3',
      );
      expect(mp3Item.isText, false);
    });
  });

  group('SettingsProvider Vault & Recycle Bin Settings', () {
    test('manages vault home screen visibility and retention settings', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      expect(settings.showVaultOnHomeScreen, true);
      expect(settings.recycleBinRetentionDays, 30);

      await settings.setShowVaultOnHomeScreen(false);
      expect(settings.showVaultOnHomeScreen, false);
      expect(prefs.getBool('show_vault_on_home_screen'), false);

      await settings.setRecycleBinRetentionDays(14);
      expect(settings.recycleBinRetentionDays, 14);
      expect(prefs.getInt('recycle_bin_retention_days'), 14);
    });
  });
}
