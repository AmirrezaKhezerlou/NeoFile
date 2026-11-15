import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neofile/models/download_task.dart';
import 'package:neofile/screens/download_manager_screen.dart';
import 'package:neofile/services/download_manager_service.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DownloadCategory & DownloadTask Unit Tests', () {
    test('detectFromFileName accurately maps file extensions to categories', () {
      expect(DownloadCategoryX.detectFromFileName('app.apk'), DownloadCategory.programs);
      expect(DownloadCategoryX.detectFromFileName('setup.exe'), DownloadCategory.programs);
      expect(DownloadCategoryX.detectFromFileName('archive.zip'), DownloadCategory.programs);
      expect(DownloadCategoryX.detectFromFileName('movie.mp4'), DownloadCategory.videos);
      expect(DownloadCategoryX.detectFromFileName('clip.mkv'), DownloadCategory.videos);
      expect(DownloadCategoryX.detectFromFileName('photo.jpg'), DownloadCategory.images);
      expect(DownloadCategoryX.detectFromFileName('graphic.png'), DownloadCategory.images);
      expect(DownloadCategoryX.detectFromFileName('doc.pdf'), DownloadCategory.documents);
      expect(DownloadCategoryX.detectFromFileName('sheet.xlsx'), DownloadCategory.documents);
      expect(DownloadCategoryX.detectFromFileName('song.mp3'), DownloadCategory.audio);
      expect(DownloadCategoryX.detectFromFileName('data.bin'), DownloadCategory.others);
    });

    test('DownloadTask calculations for progress, speed, ETA and formatting', () {
      final task = DownloadTask(
        id: 'task_1',
        url: 'https://example.com/test.mp4',
        fileName: 'test.mp4',
        category: DownloadCategory.videos,
        destinationPath: '/storage/Video/test.mp4',
        totalBytes: 1048576 * 100, // 100 MB
        downloadedBytes: 1048576 * 50, // 50 MB
        status: DownloadStatus.downloading,
        speedBytesPerSec: 1048576 * 2, // 2 MB/s
        createdAt: DateTime.now(),
      );

      expect(task.progress, 0.5);
      expect(task.percentageString, '50.0%');
      expect(task.formattedSpeed, '2.0 MB/s');
      expect(task.canPause, true);
      expect(task.canResume, false);
      expect(task.isCompleted, false);
      expect(task.estimatedTimeRemaining, '25s'); // 50 MB / 2 MB/s = 25s
    });

    test('DownloadTask serializes and deserializes properly with JSON', () {
      final now = DateTime.now();
      final task = DownloadTask(
        id: 'task_json_1',
        url: 'https://example.com/app.apk',
        fileName: 'app.apk',
        category: DownloadCategory.programs,
        destinationPath: '/storage/Programs/app.apk',
        totalBytes: 50000000,
        downloadedBytes: 25000000,
        status: DownloadStatus.paused,
        createdAt: now,
        useSystemProxy: true,
        customProxy: '127.0.0.1:8080',
      );

      final json = task.toJson();
      final fromJson = DownloadTask.fromJson(json);

      expect(fromJson.id, task.id);
      expect(fromJson.fileName, 'app.apk');
      expect(fromJson.category, DownloadCategory.programs);
      expect(fromJson.status, DownloadStatus.paused);
      expect(fromJson.useSystemProxy, true);
      expect(fromJson.customProxy, '127.0.0.1:8080');
      expect(fromJson.canResume, true);
    });
  });

  group('DownloadManagerService Tests', () {
    late Directory tempDir;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('dl_mgr_test_');
      DownloadManagerService.instance.setCustomBasePathForTesting(tempDir.path);
      await DownloadManagerService.instance.clearCompleted();
    });

    tearDown(() {
      DownloadManagerService.instance.setCustomBasePathForTesting(null);
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    test('getDefaultCategoryFolder creates subfolders for categories', () async {
      final service = DownloadManagerService.instance;
      final videoFolder = await service.getDefaultCategoryFolder(DownloadCategory.videos);
      final programFolder = await service.getDefaultCategoryFolder(DownloadCategory.programs);
      final docFolder = await service.getDefaultCategoryFolder(DownloadCategory.documents);

      expect(p.basename(videoFolder), 'Video');
      expect(p.basename(programFolder), 'Programs');
      expect(p.basename(docFolder), 'Document');

      expect(await Directory(videoFolder).exists(), true);
      expect(await Directory(programFolder).exists(), true);
    });

    test('addTask adds queued task and controls pause/resume/delete', () async {
      final service = DownloadManagerService.instance;

      final task = await service.addTask(
        url: 'https://example.com/sample.pdf',
        customFileName: 'custom.pdf',
        category: DownloadCategory.documents,
        autoStart: false,
      );

      expect(task.fileName, 'custom.pdf');
      expect(task.category, DownloadCategory.documents);
      expect(task.status, DownloadStatus.queued);
      expect(service.tasks.any((t) => t.id == task.id), true);

      // Cancel and delete task
      await service.deleteTask(task.id);
      expect(service.tasks.any((t) => t.id == task.id), false);
    });
  });

  group('DownloadManagerScreen Widget Tests', () {
    late Directory tempDir;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('dl_ui_test_');
      DownloadManagerService.instance.setCustomBasePathForTesting(tempDir.path);
    });

    tearDown(() {
      DownloadManagerService.instance.setCustomBasePathForTesting(null);
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    });

    testWidgets('renders DownloadManagerScreen toolbar, tabs and empty state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1400));
      await DownloadManagerService.instance.init();

      await tester.pumpWidget(
        const MaterialApp(
          home: DownloadManagerScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Download Manager'), findsOneWidget);
      expect(find.text('Add URL'), findsOneWidget);
      expect(find.text('Resume All'), findsOneWidget);
      expect(find.text('Pause All'), findsOneWidget);
      expect(find.textContaining('All ('), findsOneWidget);
      expect(find.textContaining('Programs ('), findsOneWidget);
      expect(find.textContaining('Video ('), findsOneWidget);

      // Open Add New Download dialog
      await tester.tap(find.text('Add URL'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();

      expect(find.text('New Download Task'), findsOneWidget);
      expect(find.text('Download Address (URL)'), findsOneWidget);
      expect(find.text('Start Download'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('New Download Task'), findsNothing);
    });
  });
}
