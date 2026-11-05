import 'package:flutter/material.dart';
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
      if (prefStr == 'amoled') {
        _themePreference = AppThemePreference.amoled;
      } else if (prefStr == 'dark') {
        _themePreference = AppThemePreference.dark;
      } else if (prefStr == 'light') {
        _themePreference = AppThemePreference.light;
      } else {
        _themePreference = AppThemePreference.system;
      }
    } else {
      final themeStr = prefs.getString('theme_mode');
      if (themeStr == 'dark') {
        _themePreference = AppThemePreference.dark;
      } else if (themeStr == 'light') {
        _themePreference = AppThemePreference.light;
      } else {
        _themePreference = AppThemePreference.system;
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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _applyPrefs(prefs);
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

  Future<void> clearRecentFiles() async {
    _recentFiles.clear();
    notifyListeners();
    final prefs = await _getPrefs();
    await prefs.remove('recent_files');
  }
}
