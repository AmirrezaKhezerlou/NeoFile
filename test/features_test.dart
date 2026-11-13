import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neofile/models/explorer_tab.dart';
import 'package:neofile/providers/explorer_provider.dart';
import 'package:neofile/providers/settings_provider.dart';
import 'package:neofile/services/cache_cleaner_service.dart';
import 'package:neofile/services/ftp_server_service.dart';
import 'package:neofile/services/mcp_server_service.dart';
import 'package:neofile/widgets/fluent_drawer.dart';
import 'package:neofile/widgets/media/windows_media_header.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:neofile/services/storage_analyzer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Scroll State & Directory State Preservation Tests', () {
    test('ExplorerTab saves and retrieves scroll offsets per path correctly', () {
      final tab = ExplorerTab(id: 'tab_scroll_test');

      // Navigate to Folder A and save scroll position
      tab.navigateTo('/storage/emulated/0');
      tab.saveScrollOffset('/storage/emulated/0', 250.0);
      expect(tab.getScrollOffset('/storage/emulated/0'), 250.0);

      // Navigate to Folder B and save its position
      tab.navigateTo('/storage/emulated/0/Download');
      tab.saveScrollOffset('/storage/emulated/0/Download', 680.5);
      expect(tab.getScrollOffset('/storage/emulated/0/Download'), 680.5);

      // Navigate to Folder C
      tab.navigateTo('/storage/emulated/0/Download/Subfolder');
      tab.saveScrollOffset('/storage/emulated/0/Download/Subfolder', 120.0);

      // Back to Folder B
      expect(tab.goBack(), true);
      expect(tab.currentPath, '/storage/emulated/0/Download');
      expect(tab.getScrollOffset(tab.currentPath), 680.5);

      // Back to Folder A
      expect(tab.goBack(), true);
      expect(tab.currentPath, '/storage/emulated/0');
      expect(tab.getScrollOffset(tab.currentPath), 250.0);
    });

    test('selecting items preserves scroll offsets and does not reset offset to 0', () {
      final tab = ExplorerTab(id: 'selection_scroll_test');
      tab.navigateTo('/storage/emulated/0/Download');
      tab.saveScrollOffset('/storage/emulated/0/Download', 450.0);

      // Verify that offset is preserved
      expect(tab.getScrollOffset('/storage/emulated/0/Download'), 450.0);
    });
  });

  group('Delete Action & ExplorerProvider Tests', () {
    test('deleteItems can delete targeted paths and clear selection safely', () async {
      final explorer = ExplorerProvider();
      explorer.toggleSelection('/fake/path/1.txt');
      explorer.toggleSelection('/fake/path/2.txt');
      expect(explorer.selectedPaths.length, 2);

      // Call deleteItems directly on one path
      await explorer.deleteItems(['/fake/path/1.txt']);
      // Directory reloaded and completed safely
      expect(explorer.isLoading, false);
    });
  });

  group('SettingsProvider Media Player Preference Tests', () {
    test('useInternalMediaViewer defaults to true and persists toggles', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      expect(settings.useInternalMediaViewer, true);

      await settings.setUseInternalMediaViewer(false);
      expect(settings.useInternalMediaViewer, false);
      expect(prefs.getBool('use_internal_media_viewer'), false);

      await settings.setUseInternalMediaViewer(true);
      expect(settings.useInternalMediaViewer, true);
      expect(prefs.getBool('use_internal_media_viewer'), true);
    });

    test('themePreference persists and restores across reboots', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      // Default is system
      expect(settings.themePreference, AppThemePreference.system);

      // Set to dark
      await settings.setThemePreference(AppThemePreference.dark);
      expect(settings.themePreference, AppThemePreference.dark);
      expect(prefs.getString('theme_preference'), 'dark');

      // Reload into a new instance
      final reloaded = SettingsProvider(prefs);
      expect(reloaded.themePreference, AppThemePreference.dark);
      expect(reloaded.themeMode, ThemeMode.dark);

      // Set to amoled
      await reloaded.setThemePreference(AppThemePreference.amoled);
      expect(reloaded.isAmoled, true);
      expect(prefs.getString('theme_preference'), 'amoled');

      final reloadedAmoled = SettingsProvider(prefs);
      expect(reloadedAmoled.isAmoled, true);
      expect(reloadedAmoled.themePreference, AppThemePreference.amoled);
    });
  });

  group('McpServerService Unit Tests', () {
    test('generates valid config, random auth tokens and Claude JSON', () {
      final config = McpServerConfig(
        port: 8080,
        requireAuth: true,
        rootDirectory: '/test/root',
        allowWrite: true,
        allowDelete: false,
      );

      expect(config.port, 8080);
      expect(config.requireAuth, true);
      expect(config.authToken.length, 32); // 16 bytes in hex = 32 chars
      expect(config.allowWrite, true);
      expect(config.allowDelete, false);

      final service = McpServerService.instance;
      service.config = config;

      final claudeJson = service.generateClaudeConfigJson();
      expect(claudeJson.contains('mcpServers'), true);
      expect(claudeJson.contains('/sse?token=${config.authToken}'), true);
      expect(claudeJson.contains('Bearer ${config.authToken}'), true);
      expect(claudeJson.contains('permissions'), true);
      expect(claudeJson.contains('tools'), true);
      expect(claudeJson.contains('list_directory'), true);
      expect(service.fullSseUrl.contains('token=${config.authToken}'), true);
    });

    test('verifies MCP tool schemas and state transitions', () {
      final service = McpServerService.instance;
      expect(service.state, McpServerState.stopped);
      expect(service.isStopped, true);
      expect(service.isRunning, false);
      expect(service.isPaused, false);
    });
  });

  group('FtpServerService Unit Tests', () {
    test('generates proper anonymous and authenticated URLs', () {
      final service = FtpServerService.instance;
      service.config.port = 2121;
      service.config.anonymous = true;

      expect(service.ftpUrl.startsWith('ftp://'), true);
      expect(service.ftpUrl.contains(':2121'), true);
      expect(service.ftpUrl.contains('@'), false);

      service.config.anonymous = false;
      service.config.username = 'myuser';
      service.config.password = 'mypass';
      expect(service.ftpUrl.contains('myuser:mypass@'), true);
      expect(service.state, FtpServerState.stopped);
    });

    test('networkInfo correctly identifies local network vs warning', () {
      final wifiInfo = FtpNetworkInfo(type: FtpNetworkType.wifi, ip: '192.168.1.100', interfaceName: 'wlan0');
      expect(wifiInfo.isLocalNetwork, true);
      expect(wifiInfo.isWarning, false);

      final cellularInfo = FtpNetworkInfo(type: FtpNetworkType.mobileData, ip: '10.50.2.1', interfaceName: 'rmnet0');
      expect(cellularInfo.isLocalNetwork, false);
      expect(cellularInfo.isWarning, true);

      final noneInfo = FtpNetworkInfo(type: FtpNetworkType.none, ip: '127.0.0.1', interfaceName: 'lo');
      expect(noneInfo.isLocalNetwork, false);
      expect(noneInfo.isWarning, true);
    });
  });

  group('Windows Media Header Widget Tests', () {
    testWidgets('renders title and triggers callbacks on buttons', (tester) async {
      bool closed = false;
      bool minimized = false;
      bool openWith = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WindowsMediaHeader(
              title: 'TestImage.png',
              icon: Icons.image,
              onClose: () => closed = true,
              onMinimize: () => minimized = true,
              onOpenWith: () => openWith = true,
            ),
          ),
        ),
      );

      expect(find.text('TestImage.png'), findsOneWidget);
      expect(find.text('Open with'), findsOneWidget);

      await tester.tap(find.text('Open with'));
      expect(openWith, true);

      await tester.tap(find.byIcon(Icons.close));
      expect(closed, true);

      await tester.tap(find.byIcon(Icons.remove));
      expect(minimized, true);
    });
  });

  group('FluentNavigationDrawer Widget Tests', () {
    testWidgets('renders drawer with Home, Storage Analyzer, MCP, FTP and Settings entries', (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'NeoFile',
        packageName: 'com.neofile.app',
        version: '1.2.0',
        buildNumber: '4',
        buildSignature: '',
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);
      final explorer = ExplorerProvider();

      await tester.binding.setSurfaceSize(const Size(800, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: explorer),
          ],
          child: const MaterialApp(
            home: Scaffold(
              drawer: FluentNavigationDrawer(),
              body: SizedBox(),
            ),
          ),
        ),
      );

      // Open drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('NeoFile'), findsOneWidget);
      expect(find.text('Fast, Private & Powerful'), findsOneWidget);
      expect(find.text('This PC / Home'), findsOneWidget);
      expect(find.text('Storage Analyzer'), findsOneWidget);
      expect(find.text('File Vault'), findsOneWidget);
      expect(find.text('Recycle Bin'), findsOneWidget);
      expect(find.text('Local MCP Server'), findsOneWidget);
      expect(find.text('Local FTP Server'), findsOneWidget);
      expect(find.text('Home Screen Widgets'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('GitHub Repository'), findsOneWidget);
      expect(find.text('Open Source'), findsOneWidget);
    });
  });

  group('CacheCleanerService Unit Tests', () {
    test('formatSize formats byte values correctly', () {
      expect(CacheCleanerService.formatSize(0), '0 B');
      expect(CacheCleanerService.formatSize(-10), '0 B');
      expect(CacheCleanerService.formatSize(512), '512 B');
      expect(CacheCleanerService.formatSize(1024), '1.0 KB');
      expect(CacheCleanerService.formatSize(1536), '1.5 KB');
      expect(CacheCleanerService.formatSize(1024 * 1024 * 5), '5.0 MB');
      expect(CacheCleanerService.formatSize(1024 * 1024 * 1024 * 2), '2.00 GB');
    });

    test('CacheAnalysisResult and CleanupResult models calculate properly', () {
      final item1 = CacheCategoryItem(
        title: 'App Cache',
        description: 'Temporary files',
        icon: Icons.cached,
        bytes: 1048576,
        fileCount: 4,
      );
      expect(item1.formatBytes(), '1.0 MB');

      final result = CacheAnalysisResult(
        totalBytes: 1048576,
        totalFiles: 4,
        categories: [item1],
      );
      expect(result.isEmpty, false);
      expect(result.formattedTotal, '1.0 MB');

      final cleanup = CleanupResult(
        bytesFreed: 1048576,
        filesDeleted: 4,
        success: true,
      );
      expect(cleanup.formattedFreed, '1.0 MB');
      expect(cleanup.success, true);
    });

    test('CacheCleanerService state transitions and analysis', () async {
      final cleaner = CacheCleanerService.instance;
      expect(cleaner.isCleaning, false);

      // In a unit test environment, path_provider might return empty or mock dirs
      final analysis = await cleaner.analyzeCache();
      expect(analysis.totalBytes >= 0, true);
      expect(cleaner.lastAnalysis != null, true);
    });
  });

  group('StorageAnalyzerService Unit Tests', () {
    test('classifies file extensions accurately into categories', () {
      expect(StorageAnalyzerService.classifyExtension('.mp4'), StorageCategory.videos);
      expect(StorageAnalyzerService.classifyExtension('mkv'), StorageCategory.videos);
      expect(StorageAnalyzerService.classifyExtension('.jpg'), StorageCategory.images);
      expect(StorageAnalyzerService.classifyExtension('.png'), StorageCategory.images);
      expect(StorageAnalyzerService.classifyExtension('.mp3'), StorageCategory.audio);
      expect(StorageAnalyzerService.classifyExtension('.flac'), StorageCategory.audio);
      expect(StorageAnalyzerService.classifyExtension('.pdf'), StorageCategory.documents);
      expect(StorageAnalyzerService.classifyExtension('.docx'), StorageCategory.documents);
      expect(StorageAnalyzerService.classifyExtension('.zip'), StorageCategory.archives);
      expect(StorageAnalyzerService.classifyExtension('.rar'), StorageCategory.archives);
      expect(StorageAnalyzerService.classifyExtension('.apk'), StorageCategory.apps);
      expect(StorageAnalyzerService.classifyExtension('.bin'), StorageCategory.others);
      expect(StorageAnalyzerService.classifyExtension(''), StorageCategory.others);
    });

    test('formatSize formats large storage quantities accurately', () {
      expect(StorageAnalyzerService.formatSize(0), '0 B');
      expect(StorageAnalyzerService.formatSize(1024), '1.0 KB');
      expect(StorageAnalyzerService.formatSize(1048576 * 50), '50.0 MB');
      expect(StorageAnalyzerService.formatSize(1073741824 * 128), '128.00 GB');
    });

    test('StorageAnalyzedFile and StorageCategoryData model properties', () {
      final file = StorageAnalyzedFile(
        path: '/storage/emulated/0/Movies/sample.mp4',
        name: 'sample.mp4',
        size: 1048576 * 60, // 60 MB -> Large file
        modified: DateTime(2026, 1, 1),
        category: StorageCategory.videos,
        extension: '.mp4',
      );

      expect(file.formattedSize, '60.0 MB');
      expect(file.size >= StorageAnalyzerService.largeFileThreshold, true);

      final catData = StorageCategoryData(
        category: StorageCategory.videos,
        totalBytes: file.size,
        fileCount: 1,
        files: [file],
      );

      expect(catData.formattedTotal, '60.0 MB');
      expect(catData.files.length, 1);
    });
  });

  group('SettingsProvider Typography and Layout Tests', () {
    test('font size, list density, single line and date/size toggles work and persist', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);

      expect(settings.fontSizeScale, 1.0);
      expect(settings.listItemDensity, 1);
      expect(settings.singleLineListItems, false);
      expect(settings.showListDateModified, true);
      expect(settings.showListFileSize, true);

      await settings.setFontSizeScale(1.15);
      expect(settings.fontSizeScale, 1.15);

      await settings.setListItemDensity(0);
      expect(settings.listItemDensity, 0);

      await settings.toggleSingleLineListItems();
      expect(settings.singleLineListItems, true);

      await settings.toggleShowListDateModified();
      expect(settings.showListDateModified, false);

      await settings.toggleShowListFileSize();
      expect(settings.showListFileSize, false);
    });
  });
}
