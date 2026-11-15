import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/download_task.dart';

class DownloadManagerService with ChangeNotifier {
  DownloadManagerService._();
  static final DownloadManagerService instance = DownloadManagerService._();

  static const String prefDownloadsKey = 'neofile_download_tasks';
  static const String prefSystemProxyKey = 'neofile_download_system_proxy';
  static const String prefCustomProxyKey = 'neofile_download_custom_proxy';

  final List<DownloadTask> _tasks = [];
  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  final Map<String, HttpClient> _activeClients = {};
  final Map<String, Completer<void>> _activeCompleters = {};

  bool _isInitialized = false;
  String? _customBasePath;

  void setCustomBasePathForTesting(String? path) {
    _customBasePath = path;
  }

  int get activeDownloadsCount =>
      _tasks.where((t) => t.status == DownloadStatus.downloading).length;

  Future<void> init() async {
    if (_isInitialized) return;
    _isInitialized = true;
    await _loadTasks();
  }

  Future<String> getBaseDownloadDir() async {
    if (_customBasePath != null) {
      final dir = Directory(_customBasePath!);
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    }
    const standardDownload = '/storage/emulated/0/Download/NeoFile';
    final dir = Directory(standardDownload);
    if (await Directory('/storage/emulated/0').exists()) {
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    }
    try {
      final docs = await getApplicationDocumentsDirectory();
      final fallback = Directory(p.join(docs.path, 'Downloads'));
      if (!await fallback.exists()) await fallback.create(recursive: true);
      return fallback.path;
    } catch (_) {
      final temp = Directory(p.join(Directory.systemTemp.path, 'NeoFile_Downloads'));
      if (!await temp.exists()) await temp.create(recursive: true);
      return temp.path;
    }
  }

  Future<String> getDefaultCategoryFolder(DownloadCategory category) async {
    final base = await getBaseDownloadDir();
    final sub = category.displayName;
    final folder = Directory(p.join(base, sub));
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return folder.path;
  }

  Future<void> _loadTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(prefDownloadsKey);
      if (jsonStr == null || jsonStr.trim().isEmpty) return;

      final list = jsonDecode(jsonStr) as List<dynamic>;
      _tasks.clear();
      for (final item in list) {
        try {
          final task = DownloadTask.fromJson(item as Map<String, dynamic>);
          _tasks.add(task);
        } catch (_) {}
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _saveTasks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _tasks.map((t) => t.toJson()).toList();
      await prefs.setString(prefDownloadsKey, jsonEncode(list));
    } catch (_) {}
  }

  Future<DownloadTask> addTask({
    required String url,
    String? customFileName,
    String? customDestinationDir,
    DownloadCategory? category,
    bool useSystemProxy = false,
    String? customProxy,
    bool autoStart = true,
  }) async {
    await init();

    final uri = Uri.parse(url.trim());
    String detectedName = customFileName?.trim() ?? '';
    if (detectedName.isEmpty) {
      detectedName = p.basename(uri.path);
      if (detectedName.isEmpty || !detectedName.contains('.')) {
        detectedName = 'download_${DateTime.now().millisecondsSinceEpoch}.bin';
      }
    }
    detectedName = p.basename(detectedName.replaceAll(RegExp(r'[\\/]'), '_')).trim();

    final cat = category ?? DownloadCategoryX.detectFromFileName(detectedName);
    final targetDir = customDestinationDir ?? await getDefaultCategoryFolder(cat);
    final targetPath = p.join(targetDir, detectedName);

    final id = '${DateTime.now().millisecondsSinceEpoch}_${_tasks.length + 1}';

    final task = DownloadTask(
      id: id,
      url: url.trim(),
      fileName: detectedName,
      category: cat,
      destinationPath: targetPath,
      status: autoStart ? DownloadStatus.downloading : DownloadStatus.queued,
      createdAt: DateTime.now(),
      useSystemProxy: useSystemProxy,
      customProxy: customProxy,
    );

    _tasks.insert(0, task);
    await _saveTasks();
    notifyListeners();

    if (autoStart) {
      _startDownload(task);
    }

    return task;
  }

  void pauseTask(String id) {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final task = _tasks[idx];
    if (task.status == DownloadStatus.downloading) {
      task.status = DownloadStatus.paused;
      task.speedBytesPerSec = 0;
      _activeClients[id]?.close(force: true);
      _activeClients.remove(id);
      _activeCompleters[id]?.complete();
      _activeCompleters.remove(id);
      _saveTasks();
      notifyListeners();
    }
  }

  void resumeTask(String id) {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final task = _tasks[idx];
    if (task.canResume) {
      task.status = DownloadStatus.downloading;
      task.errorMessage = null;
      notifyListeners();
      _startDownload(task);
    }
  }

  void retryTask(String id) {
    resumeTask(id);
  }

  Future<void> cancelTask(String id, {bool deleteFile = true}) async {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx == -1) return;

    final task = _tasks[idx];
    task.status = DownloadStatus.cancelled;
    task.speedBytesPerSec = 0;
    _activeClients[id]?.close(force: true);
    _activeClients.remove(id);
    _activeCompleters[id]?.complete();
    _activeCompleters.remove(id);

    if (deleteFile) {
      try {
        final partFile = File('${task.destinationPath}.downloading');
        if (await partFile.exists()) await partFile.delete();
        final finalFile = File(task.destinationPath);
        if (await finalFile.exists()) await finalFile.delete();
      } catch (_) {}
    }

    await _saveTasks();
    notifyListeners();
  }

  Future<void> deleteTask(String id, {bool deleteFile = false}) async {
    await cancelTask(id, deleteFile: deleteFile);
    _tasks.removeWhere((t) => t.id == id);
    await _saveTasks();
    notifyListeners();
  }

  void pauseAll() {
    for (final task in _tasks) {
      if (task.status == DownloadStatus.downloading) {
        pauseTask(task.id);
      }
    }
  }

  void resumeAll() {
    for (final task in _tasks) {
      if (task.canResume) {
        resumeTask(task.id);
      }
    }
  }

  Future<void> clearCompleted() async {
    _tasks.removeWhere((t) => t.status == DownloadStatus.completed || t.status == DownloadStatus.cancelled);
    await _saveTasks();
    notifyListeners();
  }

  Future<void> _startDownload(DownloadTask task) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 20);
    _activeClients[task.id] = client;

    // Proxy configuration
    if (task.useSystemProxy) {
      client.findProxy = (uri) => HttpClient.findProxyFromEnvironment(uri);
    } else if (task.customProxy != null && task.customProxy!.trim().isNotEmpty) {
      var proxy = task.customProxy!.trim();
      proxy = proxy.replaceAll('http://', '').replaceAll('https://', '').replaceAll('/', '');
      client.findProxy = (uri) => 'PROXY $proxy;';
    }

    IOSink? sink;
    final tempPath = '${task.destinationPath}.downloading';
    final tempFile = File(tempPath);

    try {
      final uri = Uri.parse(task.url);
      final request = await client.getUrl(uri);

      // Check if partial file exists for resume
      int existingBytes = 0;
      if (await tempFile.exists()) {
        existingBytes = await tempFile.length();
        if (existingBytes > 0) {
          request.headers.set(HttpHeaders.rangeHeader, 'bytes=$existingBytes-');
        }
      }

      final response = await request.close();

      if (response.statusCode >= 400) {
        throw HttpException('HTTP Server Error: ${response.statusCode}');
      }

      // Check if resume accepted (206 Partial Content) or fresh start (200 OK)
      if (response.statusCode == HttpStatus.partialContent) {
        task.downloadedBytes = existingBytes;
        if (response.contentLength > 0) {
          task.totalBytes = existingBytes + response.contentLength;
        }
        sink = tempFile.openWrite(mode: FileMode.append);
      } else {
        // Fresh download
        task.downloadedBytes = 0;
        task.totalBytes = response.contentLength;
        if (!await tempFile.parent.exists()) {
          await tempFile.parent.create(recursive: true);
        }
        sink = tempFile.openWrite(mode: FileMode.write);
      }

      // Update filename if content-disposition presents better name
      final cd = response.headers.value('content-disposition');
      if (cd != null && cd.contains('filename=')) {
        final match = RegExp(r'filename="?([^"]+)"?').firstMatch(cd);
        if (match != null) {
          final cdName = p.basename(match.group(1) ?? '').trim();
          if (cdName.isNotEmpty) {
            task.fileName = cdName;
            task.category = DownloadCategoryX.detectFromFileName(cdName);
          }
        }
      }

      final stopwatch = Stopwatch()..start();
      int lastTimeMs = 0;
      int lastBytes = task.downloadedBytes;

      await for (final chunk in response) {
        if (task.status != DownloadStatus.downloading) {
          break;
        }

        sink.add(chunk);
        task.downloadedBytes += chunk.length;

        final elapsed = stopwatch.elapsedMilliseconds;
        if (elapsed - lastTimeMs >= 350) {
          final bytesDiff = task.downloadedBytes - lastBytes;
          final secDiff = (elapsed - lastTimeMs) / 1000.0;
          if (secDiff > 0) {
            task.speedBytesPerSec = (bytesDiff / secDiff).round();
          }
          lastTimeMs = elapsed;
          lastBytes = task.downloadedBytes;
          notifyListeners();
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      if (task.status == DownloadStatus.downloading) {
        // Rename .downloading file to destinationPath
        final finalFile = File(task.destinationPath);
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        if (!await finalFile.parent.exists()) {
          await finalFile.parent.create(recursive: true);
        }
        await tempFile.rename(task.destinationPath);

        task.status = DownloadStatus.completed;
        task.completedAt = DateTime.now();
        task.speedBytesPerSec = 0;
        await _saveTasks();
        notifyListeners();
      }
    } catch (e) {
      try {
        await sink?.close();
      } catch (_) {}

      if (task.status == DownloadStatus.downloading) {
        task.status = DownloadStatus.failed;
        task.errorMessage = e.toString().replaceAll('Exception: ', '');
        task.speedBytesPerSec = 0;
        await _saveTasks();
        notifyListeners();
      }
    } finally {
      client.close();
      _activeClients.remove(task.id);
    }
  }
}
