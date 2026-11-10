import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../services/file_service.dart';
import '../theme/fluent_theme.dart';

/// WinUI 3 Fluent File Picker designed specifically for selecting subtitle files (.srt, .vtt, .sub, .ass).
/// Keeps user entirely within the app experience without invoking external system file pickers.
class FluentSubtitlePicker extends StatefulWidget {
  final String initialPath;

  const FluentSubtitlePicker({super.key, required this.initialPath});

  static Future<File?> show(BuildContext context, {String? initialPath}) {
    final startPath = (initialPath != null && Directory(initialPath).existsSync())
        ? initialPath
        : FileService.internalStoragePath;

    return showModalBottomSheet<File>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FluentSubtitlePicker(initialPath: startPath),
    );
  }

  @override
  State<FluentSubtitlePicker> createState() => _FluentSubtitlePickerState();
}

class _FluentSubtitlePickerState extends State<FluentSubtitlePicker> {
  late String _currentPath;
  List<Directory> _directories = [];
  List<File> _subtitleFiles = [];
  bool _isLoading = false;
  String _searchFilter = '';

  static const List<String> _subExtensions = ['.srt', '.vtt', '.sub', '.ass', '.txt'];

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _loadDirectoryContents();
  }

  void _loadDirectoryContents() {
    setState(() => _isLoading = true);
    final dirs = <Directory>[];
    final files = <File>[];

    try {
      final dir = Directory(_currentPath);
      if (dir.existsSync()) {
        final entities = dir.listSync(followLinks: false);
        for (final entity in entities) {
          final baseName = p.basename(entity.path);
          if (baseName.startsWith('.')) continue;

          if (entity is Directory) {
            dirs.add(entity);
          } else if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (_subExtensions.contains(ext)) {
              files.add(entity);
            }
          }
        }

        dirs.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
        files.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
      }
    } catch (_) {}

    setState(() {
      _directories = dirs;
      _subtitleFiles = files;
      _isLoading = false;
    });
  }

  void _navigateUp() {
    final parent = p.dirname(_currentPath);
    if (parent != _currentPath && parent.length >= 4) {
      setState(() {
        _currentPath = parent;
        _loadDirectoryContents();
      });
    }
  }

  void _enterFolder(String path) {
    setState(() {
      _currentPath = path;
      _loadDirectoryContents();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final size = MediaQuery.of(context).size;

    final filteredDirs = _searchFilter.isEmpty
        ? _directories
        : _directories
            .where((d) => p.basename(d.path).toLowerCase().contains(_searchFilter.toLowerCase()))
            .toList();

    final filteredSubs = _searchFilter.isEmpty
        ? _subtitleFiles
        : _subtitleFiles
            .where((f) => p.basename(f.path).toLowerCase().contains(_searchFilter.toLowerCase()))
            .toList();

    final canGoUp = _currentPath != FileService.internalStoragePath &&
        p.dirname(_currentPath) != _currentPath &&
        p.dirname(_currentPath).length >= 4;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: size.height * 0.80,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                // 1. Drag Handle & Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: colors.textMuted.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.subtitles_outlined, color: colors.primary, size: 20),
                          const SizedBox(width: 10),
                          Text(
                            'Choose Subtitle File',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Supports .srt, .vtt, .sub, and .ass subtitle tracks',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // 2. Navigation & Breadcrumb Path Bar
                Container(
                  color: colors.container.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.arrow_upward,
                          size: 16,
                          color: canGoUp ? colors.textPrimary : colors.textMuted,
                        ),
                        onPressed: canGoUp ? _navigateUp : null,
                        tooltip: 'Parent folder',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: colors.cardSurface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: colors.borderSubtle),
                          ),
                          child: Text(
                            _currentPath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontFamily: 'monospace',
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 16),
                        onPressed: _loadDirectoryContents,
                        tooltip: 'Refresh',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),
                ),

                // 3. Search Filter
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Filter files & folders...',
                      hintStyle: TextStyle(fontSize: 12, color: colors.textMuted),
                      prefixIcon: const Icon(Icons.search, size: 16),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: colors.borderSubtle),
                      ),
                    ),
                    style: TextStyle(fontSize: 12, color: colors.textPrimary),
                    onChanged: (val) => setState(() => _searchFilter = val.trim()),
                  ),
                ),

                // 4. File / Directory List
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : (filteredDirs.isEmpty && filteredSubs.isEmpty)
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.folder_open, size: 40, color: colors.textMuted),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No subfolders or subtitle files found in this path',
                                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              children: [
                                // Subtitle Files Section
                                if (filteredSubs.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                                    child: Text(
                                      'SUBTITLE FILES (${filteredSubs.length})',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: colors.primary,
                                      ),
                                    ),
                                  ),
                                  ...filteredSubs.map((file) {
                                    final name = p.basename(file.path);
                                    final ext = p.extension(file.path).toUpperCase().replaceAll('.', '');
                                    return ListTile(
                                      dense: true,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      leading: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: colors.primary.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Icon(Icons.subtitles, size: 16, color: colors.primary),
                                      ),
                                      title: Text(
                                        name,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colors.container,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: colors.borderSubtle),
                                        ),
                                        child: Text(
                                          ext,
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: colors.primary),
                                        ),
                                      ),
                                      onTap: () => Navigator.pop(context, file),
                                    );
                                  }),
                                  const SizedBox(height: 8),
                                ],

                                // Subdirectories Section
                                if (filteredDirs.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                                    child: Text(
                                      'FOLDERS (${filteredDirs.length})',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: colors.textMuted,
                                      ),
                                    ),
                                  ),
                                  ...filteredDirs.map((dir) {
                                    final name = p.basename(dir.path);
                                    return ListTile(
                                      dense: true,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      leading: Icon(Icons.folder, color: Colors.amber.shade700, size: 20),
                                      title: Text(
                                        name,
                                        style: TextStyle(fontSize: 12.5, color: colors.textPrimary),
                                      ),
                                      trailing: Icon(Icons.chevron_right, size: 16, color: colors.textMuted),
                                      onTap: () => _enterFolder(dir.path),
                                    );
                                  }),
                                ],
                              ],
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
