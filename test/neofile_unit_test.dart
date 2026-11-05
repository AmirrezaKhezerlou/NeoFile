import 'package:flutter_test/flutter_test.dart';
import 'package:neofile/models/explorer_tab.dart';
import 'package:neofile/models/file_item.dart';
import 'package:neofile/services/download_service.dart';
import 'package:neofile/services/file_service.dart';
import 'package:neofile/providers/explorer_provider.dart';
import 'package:neofile/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neofile/theme/fluent_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ExplorerTab Unit Tests', () {
    test('initializes with home', () {
      final tab = ExplorerTab(id: 'tab_test');
      expect(tab.currentPath, '');
      expect(tab.title, 'Home');
      expect(tab.canGoBack, false);
      expect(tab.canGoForward, false);
    });

    test('navigates through paths and maintains history stack', () {
      final tab = ExplorerTab(id: 'tab_test');
      tab.navigateTo('/storage/emulated/0');
      expect(tab.currentPath, '/storage/emulated/0');
      expect(tab.title, '0');
      expect(tab.canGoBack, true);
      expect(tab.canGoForward, false);

      tab.navigateTo('/storage/emulated/0/Download');
      expect(tab.currentPath, '/storage/emulated/0/Download');
      expect(tab.title, 'Download');

      expect(tab.goBack(), true);
      expect(tab.currentPath, '/storage/emulated/0');
      expect(tab.canGoForward, true);

      expect(tab.goForward(), true);
      expect(tab.currentPath, '/storage/emulated/0/Download');

      expect(tab.goUp(), true);
      expect(tab.currentPath, '/storage/emulated/0');

      expect(tab.goUp(), true);
      expect(tab.currentPath, ''); // Back to Home
    });
  });

  group('FileItem Model Tests', () {
    test('detects file types correctly and formats sizes', () {
      final pdfItem = FileItem(
        path: '/storage/emulated/0/doc.pdf',
        name: 'doc.pdf',
        isDirectory: false,
        size: 2 * 1024 * 1024,
        modified: DateTime.now(),
        isHidden: false,
        extension: 'pdf',
      );
      expect(pdfItem.isPdf, true);
      expect(pdfItem.formatSize(), '2.0 MB');
      expect(pdfItem.typeDescription, 'Adobe Acrobat Document (.pdf)');

      final folderItem = FileItem(
        path: '/storage/emulated/0/Projects',
        name: 'Projects',
        isDirectory: true,
        size: 0,
        modified: DateTime.now(),
        isHidden: false,
        extension: '',
        itemCount: 14,
      );
      expect(folderItem.isDirectory, true);
      expect(folderItem.formatSize(), '14 items');
      expect(folderItem.typeDescription, 'File folder');
    });
  });

  group('FluentColors Token Tests', () {
    test('provides distinct light, dark, and amoled tokens with correct primary accents', () {
      expect(FluentColors.light.primary.value, 0xFF0067B8);
      expect(FluentColors.dark.primary.value, 0xFF4CC2FF);
      expect(FluentColors.amoled.primary.value, 0xFF4CC2FF);
      expect(FluentColors.light.canvas.value, 0xFFF3F3F3);
      expect(FluentColors.dark.canvas.value, 0xFF1F1F1F);
      expect(FluentColors.amoled.canvas.value, 0xFF000000);
    });
  });

  group('MIME Type Resolution Tests', () {
    test('resolves correct Android MIME types by extension', () {
      expect(FileService.getMimeType('photo.png'), 'image/png');
      expect(FileService.getMimeType('photo.jpg'), 'image/jpeg');
      expect(FileService.getMimeType('doc.pdf'), 'application/pdf');
      expect(FileService.getMimeType('track.mp3'), 'audio/mpeg');
      expect(FileService.getMimeType('track.m4a'), 'audio/aac');
      expect(FileService.getMimeType('song.flac'), 'audio/flac');
      expect(FileService.getMimeType('voice.opus'), 'audio/opus');
      expect(FileService.getMimeType('video.mp4'), 'video/mp4');
      expect(FileService.getMimeType('video.mkv'), 'video/x-matroska');
      expect(FileService.getMimeType('movie.avi'), 'video/x-msvideo');
      expect(FileService.getMimeType('app.apk'), 'application/vnd.android.package-archive');
      expect(FileService.getMimeType('archive.zip'), 'application/zip');
      expect(FileService.getMimeType('notes.txt'), 'text/plain');
    });
  });

  group('DownloadService Tests', () {
    test('handles invalid URLs safely without throwing unhandled exceptions', () async {
      final res = await DownloadService.downloadFile(
        url: 'invalid_url',
        destinationDir: 'invalid_dir',
      );
      expect(res, false);
    });
  });

  group('SettingsProvider & ExplorerProvider Persistence Tests', () {
    test('persists view mode, hidden files, and sorting across settings updates', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final settings = SettingsProvider(prefs);
      final explorer = ExplorerProvider();

      // Initially synced
      explorer.syncSettings(settings);
      expect(explorer.viewMode, ViewMode.details);
      expect(explorer.showHiddenFiles, false);

      // Change settings
      await settings.setDefaultViewMode(ViewMode.grid);
      await settings.toggleShowHiddenFiles();
      await settings.setSorting(SortField.dateModified, false);

      expect(settings.defaultViewMode, ViewMode.grid);
      expect(settings.showHiddenFiles, true);
      expect(settings.sortField, SortField.dateModified);
      expect(settings.sortAscending, false);

      // Sync to explorer
      explorer.syncSettings(settings);
      expect(explorer.viewMode, ViewMode.grid);
      expect(explorer.showHiddenFiles, true);
      expect(explorer.sortField, SortField.dateModified);
      expect(explorer.sortAscending, false);

      // Verify that a brand new SettingsProvider restores these values from prefs
      final reloadedSettings = SettingsProvider(prefs);
      expect(reloadedSettings.defaultViewMode, ViewMode.grid);
      expect(reloadedSettings.showHiddenFiles, true);
      expect(reloadedSettings.sortField, SortField.dateModified);
      expect(reloadedSettings.sortAscending, false);

      explorer.dispose();
    });

    test('notification banner displays and dismisses correctly', () {
      final explorer = ExplorerProvider();
      expect(explorer.bannerVisible, false);

      explorer.showNotificationBanner('Items copied successfully.', duration: const Duration(milliseconds: 50));
      expect(explorer.bannerVisible, true);
      expect(explorer.clipboardNotification, 'Items copied successfully.');

      explorer.dismissClipboardNotification();
      expect(explorer.bannerVisible, false);
      expect(explorer.clipboardNotification, null);

      explorer.dispose();
    });
  });
}
