import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/clipboard_item.dart';
import '../models/explorer_tab.dart';
import '../models/file_item.dart';
import '../services/archive_service.dart';
import '../services/download_service.dart';
import '../services/file_service.dart';
import 'settings_provider.dart';

class ExplorerProvider with ChangeNotifier {
  final List<ExplorerTab> _tabs = [
    ExplorerTab(id: 'tab_1', currentPath: ''),
  ];
  int _activeTabIndex = 0;

  List<FileItem> _currentItems = [];
  List<StorageVolumeInfo> _storageVolumes = [];
  bool _isLoading = false;
  String? _errorMessage;

  SortField _sortField = SortField.name;
  bool _sortAscending = true;
  ViewMode _viewMode = ViewMode.details;
  bool _showHiddenFiles = false;

  final Set<String> _selectedPaths = {};
  ClipboardItem? _clipboard;
  String _searchQuery = '';
  String? _clipboardNotification;
  Timer? _notificationTimer;
  bool _bannerVisible = false;

  bool _isTransferring = false;
  double _transferProgress = 0.0;
  String _transferTitle = '';
  String _transferSpeed = '';
  bool _transferCancelled = false;

  bool _isGlobalSearching = false;
  List<FileItem> _globalSearchResults = [];

  StreamSubscription? _storageSubscription;
  StreamSubscription? _intentSubscription;
  Timer? _autoRefreshTimer;
  bool _isAutoRefreshing = false;

  // Getters
  List<ExplorerTab> get tabs => _tabs;
  int get activeTabIndex => _activeTabIndex;
  ExplorerTab get activeTab => _tabs[_activeTabIndex];
  String get currentPath => activeTab.currentPath;
  bool get isHome => currentPath.isEmpty;

  bool get isTransferring => _isTransferring;
  double get transferProgress => _transferProgress;
  String get transferTitle => _transferTitle;
  String get transferSpeed => _transferSpeed;

  bool get isGlobalSearching => _isGlobalSearching;
  List<FileItem> get globalSearchResults => _globalSearchResults;

  List<FileItem> get currentItems {
    if (_searchQuery.isEmpty) return _currentItems;
    return _currentItems
        .where((item) =>
            item.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  List<StorageVolumeInfo> get storageVolumes => _storageVolumes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  SortField get sortField => _sortField;
  bool get sortAscending => _sortAscending;
  ViewMode get viewMode => _viewMode;
  bool get showHiddenFiles => _showHiddenFiles;

  Set<String> get selectedPaths => _selectedPaths;
  bool get hasSelection => _selectedPaths.isNotEmpty;
  int get selectionCount => _selectedPaths.length;

  bool get canShareSelected {
    if (_selectedPaths.isEmpty) return false;
    for (final path in _selectedPaths) {
      try {
        if (FileSystemEntity.isDirectorySync(path)) return false;
      } catch (_) {
        return false;
      }
    }
    return true;
  }
  ClipboardItem? get clipboard => _clipboard;
  String _lastCutOrCopyNotice = '';
  String? get clipboardNotification => _clipboardNotification;
  bool get bannerVisible => _bannerVisible && (_clipboardNotification != null || _clipboard != null);
  String get searchQuery => _searchQuery;

  int get selectedTotalBytes {
    int total = 0;
    for (final item in _currentItems) {
      if (_selectedPaths.contains(item.path)) {
        total += item.size;
      }
    }
    return total;
  }

  ExplorerProvider() {
    FileService.onCancelTransferRequested = cancelTransfer;
    init();
  }

  Future<void> init() async {
    await loadStorageVolumes();
    await loadCurrentPath();

    _setupListeners();
    _handleInitialIntent();
    _startAutoRefreshTimer();
  }

  void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      _checkDirectoryChangesInBackground();
    });
  }

  Future<void> _checkDirectoryChangesInBackground() async {
    if (_isDisposed || _isLoading || _isAutoRefreshing || _isTransferring) return;
    if (isHome || currentPath.isEmpty) return;
    // Don't interrupt user if they have active multi-selection
    if (hasSelection) return;

    _isAutoRefreshing = true;
    try {
      final dir = Directory(currentPath);
      if (!dir.existsSync()) {
        _isAutoRefreshing = false;
        return;
      }

      final latestItems = await FileService.listDirectory(
        path: currentPath,
        showHidden: _showHiddenFiles,
        sortBy: _sortField,
        ascending: _sortAscending,
      );

      if (!_isDisposed && !hasSelection && !_isLoading) {
        if (_hasDirectoryChanged(_currentItems, latestItems)) {
          _currentItems = latestItems;
          notifyListeners();
        }
      }
    } catch (_) {
      // Silently ignore background read errors
    } finally {
      _isAutoRefreshing = false;
    }
  }

  bool _hasDirectoryChanged(List<FileItem> oldItems, List<FileItem> newItems) {
    if (oldItems.length != newItems.length) return true;
    for (int i = 0; i < oldItems.length; i++) {
      final oldItem = oldItems[i];
      final newItem = newItems[i];
      if (oldItem.path != newItem.path ||
          oldItem.size != newItem.size ||
          oldItem.modified.millisecondsSinceEpoch != newItem.modified.millisecondsSinceEpoch) {
        return true;
      }
    }
    return false;
  }

  void _setupListeners() {
    _storageSubscription?.cancel();
    _storageSubscription = FileService.storageEventsStream.listen((event) async {
      await loadStorageVolumes();
      if (isHome) return;

      String? eventType;
      String? unmountedPath;
      if (event is Map) {
        eventType = event['event'] as String?;
        unmountedPath = event['path'] as String?;
      }

      // If OTG/SD was unmounted or removed while viewing its contents, kick out to Home
      if (eventType == 'unmounted' || eventType == 'usb_detached') {
        if (unmountedPath != null && unmountedPath.isNotEmpty && currentPath.startsWith(unmountedPath)) {
          navigateTo('');
          return;
        }
      }

      // Check if current directory still exists
      if (!Directory(currentPath).existsSync()) {
        navigateTo('');
      } else {
        await loadCurrentPath();
      }
    }, onError: (_) {});

    _intentSubscription?.cancel();
    _intentSubscription = FileService.fileIntentStream.listen((filePath) {
      _openTargetFileFromIntent(filePath);
    }, onError: (_) {});
  }

  Future<void> _handleInitialIntent() async {
    final initialPath = await FileService.getInitialIntentPath();
    if (initialPath != null && initialPath.isNotEmpty) {
      _openTargetFileFromIntent(initialPath);
    }
  }

  void _openTargetFileFromIntent(String filePath) {
    try {
      if (FileSystemEntity.isDirectorySync(filePath)) {
        navigateTo(filePath);
      } else {
        final parentDir = p.dirname(filePath);
        navigateTo(parentDir);
        clearSelection();
        toggleSelection(filePath);
      }
    } catch (_) {
      final parentDir = p.dirname(filePath);
      navigateTo(parentDir);
    }
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    _autoRefreshTimer?.cancel();
    _notificationTimer?.cancel();
    _storageSubscription?.cancel();
    _intentSubscription?.cancel();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  Future<void> loadStorageVolumes() async {
    _storageVolumes = await FileService.getStorageVolumes();
    notifyListeners();
  }

  Future<void> loadCurrentPath({bool? showHidden}) async {
    final effectiveShowHidden = showHidden ?? _showHiddenFiles;
    clearSelection();
    if (isHome) {
      _currentItems = [];
      _isLoading = false;
      await loadStorageVolumes();
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final items = await FileService.listDirectory(
        path: currentPath,
        showHidden: effectiveShowHidden,
        sortBy: _sortField,
        ascending: _sortAscending,
      );
      _currentItems = items;
      _isLoading = false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Could not access directory: $e';
    }
    notifyListeners();
  }

  // --- Tab Management ---
  void addTab([String path = '']) {
    final newId = 'tab_${DateTime.now().millisecondsSinceEpoch}';
    _tabs.add(ExplorerTab(id: newId, currentPath: path));
    _activeTabIndex = _tabs.length - 1;
    loadCurrentPath();
  }

  void closeTab(int index) {
    if (_tabs.length <= 1) return; // Keep at least one tab
    _tabs.removeAt(index);
    if (_activeTabIndex >= _tabs.length) {
      _activeTabIndex = _tabs.length - 1;
    }
    loadCurrentPath();
  }

  void selectTab(int index) {
    if (index >= 0 && index < _tabs.length && index != _activeTabIndex) {
      _activeTabIndex = index;
      loadCurrentPath();
    }
  }

  // --- Navigation ---
  void navigateTo(String path) {
    if (path == currentPath) return;
    activeTab.navigateTo(path);
    loadCurrentPath();
  }

  bool goBack() {
    if (activeTab.goBack()) {
      loadCurrentPath();
      return true;
    }
    return false;
  }

  bool goForward() {
    if (activeTab.goForward()) {
      loadCurrentPath();
      return true;
    }
    return false;
  }

  bool goUp() {
    if (activeTab.goUp()) {
      loadCurrentPath();
      return true;
    }
    return false;
  }

  void refresh({bool? showHidden}) {
    loadCurrentPath(showHidden: showHidden ?? _showHiddenFiles);
  }

  // --- Sorting & View Mode ---
  void syncSettings(SettingsProvider settings) {
    final sortChanged = _sortField != settings.sortField || _sortAscending != settings.sortAscending;
    final viewChanged = _viewMode != settings.defaultViewMode;
    final hiddenChanged = _showHiddenFiles != settings.showHiddenFiles;

    _sortField = settings.sortField;
    _sortAscending = settings.sortAscending;
    _viewMode = settings.defaultViewMode;
    _showHiddenFiles = settings.showHiddenFiles;

    if (sortChanged || hiddenChanged) {
      if (!isHome && currentPath.isNotEmpty) {
        loadCurrentPath();
      } else {
        notifyListeners();
      }
    } else if (viewChanged) {
      notifyListeners();
    }
  }

  void setSorting(SortField field, bool ascending, {bool? showHidden, SettingsProvider? settings}) {
    _sortField = field;
    _sortAscending = ascending;
    settings?.setSorting(field, ascending);
    loadCurrentPath(showHidden: showHidden ?? _showHiddenFiles);
  }

  void setViewMode(ViewMode mode, {SettingsProvider? settings}) {
    _viewMode = mode;
    settings?.setDefaultViewMode(mode);
    notifyListeners();
  }

  // --- Selection ---
  void toggleSelection(String path) {
    if (_selectedPaths.contains(path)) {
      _selectedPaths.remove(path);
    } else {
      _selectedPaths.add(path);
    }
    notifyListeners();
  }

  void selectAll() {
    _selectedPaths.clear();
    for (final item in _currentItems) {
      _selectedPaths.add(item.path);
    }
    notifyListeners();
  }

  void clearSelection() {
    if (_selectedPaths.isNotEmpty) {
      _selectedPaths.clear();
      notifyListeners();
    }
  }

  // --- Search ---
  void setSearchQuery(String query, {bool showHidden = false}) {
    _searchQuery = query;
    if (isHome) {
      runGlobalSearch(query, showHidden: showHidden);
    } else {
      notifyListeners();
    }
  }

  void clearSearch() {
    _searchQuery = '';
    _globalSearchResults = [];
    _isGlobalSearching = false;
    notifyListeners();
  }

  Future<void> runGlobalSearch(String query, {bool showHidden = false}) async {
    if (query.trim().isEmpty) {
      _globalSearchResults = [];
      _isGlobalSearching = false;
      notifyListeners();
      return;
    }

    _isGlobalSearching = true;
    notifyListeners();

    final roots = _storageVolumes.map((v) => v.path).toList();
    if (roots.isEmpty) roots.add('/storage/emulated/0');

    try {
      final results = await FileService.searchFilesRecursively(
        roots: roots,
        query: query.trim(),
        showHidden: showHidden,
      );
      _globalSearchResults = results;
    } catch (_) {
      _globalSearchResults = [];
    }

    _isGlobalSearching = false;
    notifyListeners();
  }

  // --- Notification Banner Control ---
  void showNotificationBanner(String message, {Duration duration = const Duration(seconds: 5)}) {
    _notificationTimer?.cancel();
    _clipboardNotification = message;
    _bannerVisible = true;
    notifyListeners();
    _notificationTimer = Timer(duration, () {
      dismissClipboardNotification();
    });
  }

  void dismissClipboardNotification() {
    _notificationTimer?.cancel();
    _bannerVisible = false;
    _clipboardNotification = null;
    notifyListeners();
  }

  // --- Transfer Control ---
  void cancelTransfer() {
    _transferCancelled = true;
    _isTransferring = false;
    _transferProgress = 0.0;
    FileService.cancelNotification();
    showNotificationBanner('Operation cancelled.');
  }

  // --- Clipboard Operations ---
  void cutSelected() {
    if (_selectedPaths.isEmpty) return;
    _clipboard = ClipboardItem(paths: _selectedPaths.toList(), isCut: true);
    _lastCutOrCopyNotice = 'Cut ${_selectedPaths.length} item(s). Navigate & Paste.';
    clearSelection();
    showNotificationBanner(_lastCutOrCopyNotice);
  }

  void copySelected() {
    if (_selectedPaths.isEmpty) return;
    _clipboard = ClipboardItem(paths: _selectedPaths.toList(), isCut: false);
    _lastCutOrCopyNotice = 'Copied ${_selectedPaths.length} item(s) to clipboard.';
    clearSelection();
    showNotificationBanner(_lastCutOrCopyNotice);
  }

  void clearClipboard() {
    cancelClipboard();
  }

  void cancelClipboard() {
    _notificationTimer?.cancel();
    _clipboard = null;
    _clipboardNotification = null;
    _bannerVisible = false;
    notifyListeners();
  }

  Future<bool> paste({bool showHidden = false}) async {
    if (_clipboard == null || _clipboard!.isEmpty || isHome) return false;

    final clip = _clipboard!;
    _clipboard = null; // Cleared immediately so Paste buttons disable & FAB disappears at once!
    _clipboardNotification = null;

    _isTransferring = true;
    _transferCancelled = false;
    _transferProgress = 0.0;
    _transferSpeed = '0 KB/s';
    _transferTitle = clip.isCut ? 'Moving items...' : 'Copying items...';
    notifyListeners();

    FileService.showNotification(
      title: clip.isCut ? 'Moving files' : 'Copying files',
      message: 'Starting transfer...',
      progress: 0,
    );

    try {
      if (clip.isCut) {
        await FileService.moveItems(
          clip.paths,
          currentPath,
          onProgress: (prog, item, speed) {
            _transferProgress = prog;
            _transferTitle = 'Moving: $item';
            _transferSpeed = speed;
            notifyListeners();
            FileService.showNotification(
              title: 'Moving files ($speed)',
              message: item,
              progress: (prog * 100).toInt(),
            );
          },
          isCancelled: () => _transferCancelled,
        );
        showNotificationBanner(_transferCancelled ? 'Move cancelled.' : 'Items moved successfully.');
      } else {
        await FileService.copyItems(
          clip.paths,
          currentPath,
          onProgress: (prog, item, speed) {
            _transferProgress = prog;
            _transferTitle = 'Copying: $item';
            _transferSpeed = speed;
            notifyListeners();
            FileService.showNotification(
              title: 'Copying files ($speed)',
              message: item,
              progress: (prog * 100).toInt(),
            );
          },
          isCancelled: () => _transferCancelled,
        );
        showNotificationBanner(_transferCancelled ? 'Copy cancelled.' : 'Items copied successfully.');
      }

      _isTransferring = false;
      FileService.cancelNotification();
      await loadCurrentPath(showHidden: showHidden);
      return !_transferCancelled;
    } catch (e) {
      _isTransferring = false;
      _errorMessage = 'Paste error: $e';
      FileService.cancelNotification();
      notifyListeners();
      return false;
    }
  }

  // --- Archive & Compression ---
  Future<bool> compressSelectedToZip({
    required String outputName,
    String? password,
    bool showHidden = false,
  }) async {
    if (_selectedPaths.isEmpty || isHome) return false;

    _isTransferring = true;
    _transferCancelled = false;
    _transferProgress = 0.0;
    _transferTitle = 'Compressing to ZIP...';
    notifyListeners();

    FileService.showNotification(
      title: 'Compressing archive',
      message: 'Starting ZIP compression...',
      progress: 0,
    );

    final zipName = outputName.toLowerCase().endsWith('.zip') ? outputName : '$outputName.zip';
    final outputZipPath = p.join(currentPath, zipName);

    try {
      final success = await ArchiveService.compressToZip(
        sourcePaths: _selectedPaths.toList(),
        outputZipPath: outputZipPath,
        password: password,
        onProgress: (prog, currentFile) {
          _transferProgress = prog;
          _transferTitle = 'Compressing: $currentFile';
          notifyListeners();
          FileService.showNotification(
            title: 'Compressing archive',
            message: currentFile,
            progress: (prog * 100).toInt(),
          );
        },
        isCancelled: () => _transferCancelled,
      );

      _isTransferring = false;
      FileService.cancelNotification();
      showNotificationBanner(
        success
            ? 'Created archive: ${p.basename(outputZipPath)}'
            : (_transferCancelled ? 'Compression cancelled.' : 'Compression failed.'),
      );
      clearSelection();
      await loadCurrentPath(showHidden: showHidden);
      return success;
    } catch (e) {
      _isTransferring = false;
      _errorMessage = 'Compression error: $e';
      FileService.cancelNotification();
      notifyListeners();
      return false;
    }
  }

  Future<bool> extractArchiveFile({
    required String archivePath,
    String? targetFolder,
    String? password,
    bool showHidden = false,
  }) async {
    _isTransferring = true;
    _transferCancelled = false;
    _transferProgress = 0.0;
    _transferTitle = 'Extracting archive...';
    notifyListeners();

    FileService.showNotification(
      title: 'Extracting archive',
      message: 'Unpacking files...',
      progress: 0,
    );

    final baseName = p.basenameWithoutExtension(archivePath);
    final destDir = p.join(currentPath, targetFolder ?? baseName);

    try {
      final success = await ArchiveService.extractArchive(
        archivePath: archivePath,
        destinationDir: destDir,
        password: password,
        onProgress: (prog, currentFile) {
          _transferProgress = prog;
          _transferTitle = 'Extracting: $currentFile';
          notifyListeners();
          FileService.showNotification(
            title: 'Extracting archive',
            message: currentFile,
            progress: (prog * 100).toInt(),
          );
        },
        isCancelled: () => _transferCancelled,
      );

      _isTransferring = false;
      FileService.cancelNotification();
      showNotificationBanner(
        success
            ? 'Extracted to: ${p.basename(destDir)}'
            : (_transferCancelled ? 'Extraction cancelled.' : 'Extraction failed (check password).'),
      );
      await loadCurrentPath(showHidden: showHidden);
      return success;
    } catch (e) {
      _isTransferring = false;
      _errorMessage = 'Extraction error: $e';
      FileService.cancelNotification();
      notifyListeners();
      return false;
    }
  }

  // --- Download from URL ---
  Future<bool> downloadFileFromUrl({
    required String url,
    String? customFileName,
    bool showHidden = false,
  }) async {
    if (url.trim().isEmpty || isHome) return false;

    _isTransferring = true;
    _transferCancelled = false;
    _transferProgress = 0.0;
    _transferSpeed = '0 KB/s';
    _transferTitle = 'Downloading from URL...';
    notifyListeners();

    FileService.showNotification(
      title: 'Downloading file',
      message: 'Connecting...',
      progress: 0,
    );

    try {
      final success = await DownloadService.downloadFile(
        url: url,
        destinationDir: currentPath,
        customFileName: customFileName,
        onProgress: (prog, info, speed) {
          _transferProgress = prog;
          _transferTitle = 'Downloading: $info';
          _transferSpeed = speed;
          notifyListeners();
          FileService.showNotification(
            title: 'Downloading file ($speed)',
            message: info,
            progress: (prog * 100).toInt(),
          );
        },
        isCancelled: () => _transferCancelled,
      );

      _isTransferring = false;
      FileService.cancelNotification();
      showNotificationBanner(
        success
            ? 'Download complete.'
            : (_transferCancelled ? 'Download cancelled.' : 'Download failed.'),
      );
      await loadCurrentPath(showHidden: showHidden);
      return success;
    } catch (e) {
      _isTransferring = false;
      _errorMessage = 'Download error: $e';
      FileService.cancelNotification();
      notifyListeners();
      return false;
    }
  }

  // --- File Actions ---
  Future<bool> createFolder(String name, {bool showHidden = false}) async {
    if (isHome) return false;
    final success = await FileService.createFolder(currentPath, name);
    if (success) {
      await loadCurrentPath(showHidden: showHidden);
    }
    return success;
  }

  Future<bool> createFile(String name, {bool showHidden = false}) async {
    if (isHome) return false;
    final success = await FileService.createFile(currentPath, name);
    if (success) {
      await loadCurrentPath(showHidden: showHidden);
    }
    return success;
  }

  Future<bool> renameItem(String oldPath, String newName, {bool showHidden = false}) async {
    final success = await FileService.rename(oldPath, newName);
    if (success) {
      await loadCurrentPath(showHidden: showHidden);
    }
    return success;
  }

  void saveCurrentScrollOffset(double offset) {
    activeTab.saveScrollOffset(currentPath, offset);
  }

  double getSavedScrollOffset([String? path]) {
    return activeTab.getScrollOffset(path ?? currentPath);
  }

  Future<void> deleteItems(List<String> paths, {bool showHidden = false}) async {
    if (paths.isEmpty) return;
    await FileService.deleteItems(paths);
    _selectedPaths.removeWhere((p) => paths.contains(p));
    await loadCurrentPath(showHidden: showHidden);
  }

  Future<void> deleteSelected({bool showHidden = false}) async {
    if (_selectedPaths.isEmpty) return;
    await deleteItems(_selectedPaths.toList(), showHidden: showHidden);
  }

  Future<void> shareSelected() async {
    if (_selectedPaths.isEmpty) return;
    await FileService.shareFiles(_selectedPaths.toList());
  }

  Future<void> openFile(String path) async {
    await FileService.openFile(path, useChooser: false);
  }

  Future<void> openFileWith(String path) async {
    await FileService.openFile(path, useChooser: true);
  }
}
