import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/file_service.dart';

enum ViewMode { details, tiles, grid }
enum AppThemePreference { system, light, dark, amoled }

class SettingsProvider with ChangeNotifier {
  SharedPreferences? _prefs;

  AppThemePreference _themePreference = AppThemePreference.system;
  ThemeMode _themeMode = ThemeMode.system;
  ViewMode _defaultViewMode = ViewMode.details;
  SortField _sortField = SortField.name;
  bool _sortAscending = true;
  bool _showHiddenFiles = false;
  bool _showFileExtensions = true;
  bool _showCheckBoxes = true;
  bool _compactView = false;
  int _gridColumns = 3;
  bool _useInternalMediaViewer = true;
  double _fontSizeScale = 1.0;
  bool _showListDateModified = true;
  bool _showListFileSize = true;
  bool _singleLineListItems = false;
  int _listItemDensity = 1;
  Set<String> _pinnedPaths = {};
  List<String> _recentFiles = [];

  AppThemePreference get themePreference => _themePreference;
  bool get isAmoled => _themePreference == AppThemePreference.amoled;
  ThemeMode get themeMode => _themeMode;
  ViewMode get defaultViewMode => _defaultViewMode;
  SortField get sortField => _sortField;
  bool get sortAscending => _sortAscending;
  bool get showHiddenFiles => _showHiddenFiles;
  bool get showFileExtensions => _showFileExtensions;
  bool get showCheckBoxes => _showCheckBoxes;
  bool get compactView => _compactView;
  int get gridColumns => _gridColumns;
  bool get useInternalMediaViewer => _useInternalMediaViewer;
  double get fontSizeScale => _fontSizeScale;
  bool get showListDateModified => _showListDateModified;
  bool get showListFileSize => _showListFileSize;
  bool get singleLineListItems => _singleLineListItems;
  int get listItemDensity => _listItemDensity;
  Set<String> get pinnedPaths => _pinnedPaths;
  List<String> get recentFiles => _recentFiles;

  SettingsProvider([SharedPreferences? prefs]) : _prefs = prefs {
    if (_prefs != null) {
      _applyPrefs(_prefs!);
    } else {
      _loadSettings();
    }
  }

  void _applyPrefs(SharedPreferences prefs) {
    final prefStr = prefs.getString('theme_preference');
    if (prefStr != null) {
      final norm = prefStr.toLowerCase();
      if (norm.contains('amoled')) {
        _themePreference = AppThemePreference.amoled;
      } else if (norm.contains('dark')) {
        _themePreference = AppThemePreference.dark;
      } else if (norm.contains('light')) {
        _themePreference = AppThemePreference.light;
      } else {
        _themePreference = AppThemePreference.system;
      }
    } else {
      final themeStr = prefs.getString('theme_mode');
      if (themeStr != null) {
        final normTheme = themeStr.toLowerCase();
        if (normTheme.contains('dark')) {
          _themePreference = AppThemePreference.dark;
        } else if (normTheme.contains('light')) {
          _themePreference = AppThemePreference.light;
        } else {
          _themePreference = AppThemePreference.system;
        }
      }
    }
    _themeMode = _themePreference == AppThemePreference.system
        ? ThemeMode.system
        : (_themePreference == AppThemePreference.light ? ThemeMode.light : ThemeMode.dark);

    final viewStr = prefs.getString('default_view_mode');
    if (viewStr == 'tiles') {
      _defaultViewMode = ViewMode.tiles;
    } else if (viewStr == 'grid') {
      _defaultViewMode = ViewMode.grid;
    } else {
      _defaultViewMode = ViewMode.details;
    }

    _showHiddenFiles = prefs.getBool('show_hidden_files') ?? false;
    _showFileExtensions = prefs.getBool('show_file_extensions') ?? true;
    _showCheckBoxes = prefs.getBool('show_check_boxes') ?? true;
    _compactView = prefs.getBool('compact_view') ?? false;
    _gridColumns = prefs.getInt('grid_columns') ?? 3;
    _useInternalMediaViewer = prefs.getBool('use_internal_media_viewer') ?? true;
    _fontSizeScale = prefs.getDouble('font_size_scale') ?? 1.0;
    _showListDateModified = prefs.getBool('show_list_date_modified') ?? true;
    _showListFileSize = prefs.getBool('show_list_file_size') ?? true;
    _singleLineListItems = prefs.getBool('single_line_list_items') ?? false;
    _listItemDensity = prefs.getInt('list_item_density') ?? 1;

    final sortFieldStr = prefs.getString('sort_field');
    if (sortFieldStr == 'dateModified') {
      _sortField = SortField.dateModified;
    } else if (sortFieldStr == 'type') {
      _sortField = SortField.type;
    } else if (sortFieldStr == 'size') {
      _sortField = SortField.size;
    } else {
      _sortField = SortField.name;
    }
    _sortAscending = prefs.getBool('sort_ascending') ?? true;

    _pinnedPaths = (prefs.getStringList('pinned_paths') ?? []).toSet();
    _recentFiles = prefs.getStringList('recent_files') ?? [];
  }

  Future<void> ensureLoaded() async {
    if (_prefs == null) {
      await _loadSettings();
    } else {
      _applyPrefs(_prefs!);
      await _applyBackupIfEmpty();
    }
  }

  static Future<File?> _getBackupFile() async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      return File(p.join(docDir.path, '.neofile_theme.txt'));
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveThemeBackup(String themeName) async {
    try {
      final file = await _getBackupFile();
      if (file != null) {
        await file.writeAsString(themeName);
      }
    } catch (_) {}
  }

  Future<void> _applyBackupIfEmpty() async {
    if (_themePreference == AppThemePreference.system) {
      try {
        final file = await _getBackupFile();
        if (file != null && file.existsSync()) {
          final content = file.readAsStringSync().trim().toLowerCase();
          if (content.contains('light')) {
            _themePreference = AppThemePreference.light;
            _themeMode = ThemeMode.light;
            notifyListeners();
          } else if (content.contains('amoled')) {
            _themePreference = AppThemePreference.amoled;
            _themeMode = ThemeMode.dark;
            notifyListeners();
          } else if (content.contains('dark')) {
            _themePreference = AppThemePreference.dark;
            _themeMode = ThemeMode.dark;
            notifyListeners();
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _applyPrefs(prefs);
    await _applyBackupIfEmpty();
    notifyListeners();
  }

  Future<SharedPreferences> _getPrefs() async => _prefs ??= await SharedPreferences.getInstance();

  Future<void> setThemePreference(AppThemePreference pref) async {
    _themePreference = pref;
    _themeMode = pref == AppThemePreference.system
        ? ThemeMode.system
        : (pref == AppThemePreference.light ? ThemeMode.light : ThemeMode.dark);
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setString('theme_preference', pref.name);
    await prefs.setString(
      'theme_mode',
      pref == AppThemePreference.dark || pref == AppThemePreference.amoled
          ? 'dark'
          : (pref == AppThemePreference.light ? 'light' : 'system'),
    );
    await _saveThemeBackup(pref.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    final pref = mode == ThemeMode.dark
        ? AppThemePreference.dark
        : (mode == ThemeMode.light ? AppThemePreference.light : AppThemePreference.system);
    await setThemePreference(pref);
  }

  Future<void> setDefaultViewMode(ViewMode mode) async {
    _defaultViewMode = mode;
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setString('default_view_mode', mode.name);
  }

  Future<void> setSorting(SortField field, bool ascending) async {
    _sortField = field;
    _sortAscending = ascending;
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setString('sort_field', field.name);
    await prefs.setBool('sort_ascending', ascending);
  }

  Future<void> toggleShowHiddenFiles() async {
    _showHiddenFiles = !_showHiddenFiles;
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setBool('show_hidden_files', _showHiddenFiles);
  }

  Future<void> toggleShowFileExtensions() async {
    _showFileExtensions = !_showFileExtensions;
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setBool('show_file_extensions', _showFileExtensions);
  }

  Future<void> toggleShowCheckBoxes() async {
    _showCheckBoxes = !_showCheckBoxes;
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setBool('show_check_boxes', _showCheckBoxes);
  }

  Future<void> toggleCompactView() async {
    _compactView = !_compactView;
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setBool('compact_view', _compactView);
  }

  Future<void> setGridColumns(int count) async {
    _gridColumns = count.clamp(2, 4);
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setInt('grid_columns', _gridColumns);
  }

  Future<void> setFontSizeScale(double scale) async {
    _fontSizeScale = scale.clamp(0.75, 1.4);
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setDouble('font_size_scale', _fontSizeScale);
  }

  Future<void> toggleShowListDateModified() async {
    _showListDateModified = !_showListDateModified;
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setBool('show_list_date_modified', _showListDateModified);
  }

  Future<void> toggleShowListFileSize() async {
    _showListFileSize = !_showListFileSize;
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setBool('show_list_file_size', _showListFileSize);
  }

  Future<void> toggleSingleLineListItems() async {
    _singleLineListItems = !_singleLineListItems;
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setBool('single_line_list_items', _singleLineListItems);
  }

  Future<void> setListItemDensity(int density) async {
    _listItemDensity = density.clamp(0, 2);
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setInt('list_item_density', _listItemDensity);
  }

  Future<void> togglePinPath(String path) async {
    if (_pinnedPaths.contains(path)) {
      _pinnedPaths.remove(path);
    } else {
      _pinnedPaths.add(path);
    }
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setStringList('pinned_paths', _pinnedPaths.toList());
  }

  Future<void> addRecentFile(String path) async {
    _recentFiles.remove(path);
    _recentFiles.insert(0, path);
    if (_recentFiles.length > 20) {
      _recentFiles = _recentFiles.sublist(0, 20);
    }
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setStringList('recent_files', _recentFiles);
  }

  Future<void> setUseInternalMediaViewer(bool value) async {
    _useInternalMediaViewer = value;
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.setBool('use_internal_media_viewer', value);
  }

  Future<void> clearRecentFiles() async {
    _recentFiles.clear();
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.remove('recent_files');
  }
}
