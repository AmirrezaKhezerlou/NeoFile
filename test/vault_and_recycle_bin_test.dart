import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:neofile/models/file_item.dart';
import 'package:neofile/models/recycle_bin_item.dart';
import 'package:neofile/providers/settings_provider.dart';
import 'package:neofile/services/recycle_bin_service.dart';
import 'package:neofile/services/vault_service.dart';
import 'package:neofile/widgets/fluent_delete_dialog.dart';
import 'package:neofile/widgets/vault/fluent_media_picker.dart';
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

    test('importFiles records metadata and restoreFiles restores to original path', () async {
      final tempDir = Directory.systemTemp.createTempSync('vault_test_');
      final vaultDir = Directory.systemTemp.createTempSync('vault_storage_');
      final vault = VaultService.instance;
      vault.setCustomBasePathForTesting(vaultDir.path);

      try {
        final originalFile = File(p.join(tempDir.path, 'secret_doc.pdf'));
        await originalFile.writeAsString('Confidential data');
        final originalPath = originalFile.path;

        // Import into vault
        final imported = await vault.importFiles([originalPath]);
        expect(imported.length, 1);
        expect(await originalFile.exists(), false);
        expect(await File(imported.first).exists(), true);

        // Check original path mapping
        final trackedOriginal = await vault.getOriginalPath(imported.first);
        expect(trackedOriginal != null && p.normalize(trackedOriginal) == p.normalize(originalPath), true);

        // Restore back
        final restored = await vault.restoreFiles([imported.first]);
        expect(restored.length, 1);
        expect(p.normalize(restored.first), p.normalize(originalPath));
        expect(await File(originalPath).exists(), true);
        expect(await File(originalPath).readAsString(), 'Confidential data');
        expect(await File(imported.first).exists(), false);

        // Metadata cleaned up
        final afterRestoreTracked = await vault.getOriginalPath(imported.first);
        expect(afterRestoreTracked, null);
      } finally {
        vault.setCustomBasePathForTesting(null);
        try {
          tempDir.deleteSync(recursive: true);
          vaultDir.deleteSync(recursive: true);
        } catch (_) {}
      }
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

  group('FluentDeleteDialog Widget Tests', () {
    testWidgets('renders options and selects Recycle Bin by default', (tester) async {
      DeleteAction? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await FluentDeleteDialog.show(
                    ctx,
                    itemCount: 2,
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete 2 Items'), findsOneWidget);
      expect(find.text('Move to Recycle Bin'), findsOneWidget);
      expect(find.text('Permanently Delete'), findsOneWidget);
      expect(find.text('Move to Bin'), findsOneWidget);

      // Confirm with default Recycle Bin option
      await tester.tap(find.text('Move to Bin'));
      await tester.pumpAndSettle();

      expect(result, DeleteAction.recycle);
    });

    testWidgets('allows selecting Permanently Delete option', (tester) async {
      DeleteAction? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await FluentDeleteDialog.show(
                    ctx,
                    itemCount: 1,
                    singleItemName: 'photo.jpg',
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Item'), findsOneWidget);

      // Select Permanently Delete
      await tester.tap(find.text('Permanently Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Now'), findsOneWidget);

      await tester.tap(find.text('Delete Now'));
      await tester.pumpAndSettle();

      expect(result, DeleteAction.permanent);
    });
  });

  group('FluentMediaPicker Widget Tests', () {
    testWidgets('FluentMediaPicker renders items and selects files', (tester) async {
      final docItem = FileItem(
        path: '/storage/emulated/0/Download/document.pdf',
        name: 'document.pdf',
        isDirectory: false,
        size: 2048,
        modified: DateTime.now(),
        isHidden: false,
        extension: 'pdf',
      );

      List<String>? chosenFiles;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FluentMediaPicker(
              mediaType: VaultMediaType.documents,
              initialFiles: [docItem],
              onImportSelected: (files) {
                chosenFiles = files;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Select Documents & Files'), findsOneWidget);
      expect(find.textContaining('1 item found'), findsOneWidget);

      // Tap on document item to select it
      await tester.tap(find.text('document.pdf'));
      await tester.pumpAndSettle();

      expect(find.text('1 item selected'), findsOneWidget);

      // Tap Import button
      await tester.tap(find.text('Import (1)'));
      await tester.pumpAndSettle();

      expect(chosenFiles, isNotNull);
      expect(chosenFiles!.length, 1);
      expect(chosenFiles!.first, docItem.path);
    });
  });
}
