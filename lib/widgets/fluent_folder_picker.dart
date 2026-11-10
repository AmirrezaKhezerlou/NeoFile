import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../services/file_service.dart';
import '../theme/fluent_theme.dart';

class FluentFolderPicker extends StatefulWidget {
  final String initialPath;

  const FluentFolderPicker({super.key, required this.initialPath});

  static Future<String?> show(BuildContext context, {String? initialPath}) {
    final startPath = (initialPath != null && Directory(initialPath).existsSync())
        ? initialPath
        : FileService.internalStoragePath;

    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FluentFolderPicker(initialPath: startPath),
    );
  }

  @override
  State<FluentFolderPicker> createState() => _FluentFolderPickerState();
}

class _FluentFolderPickerState extends State<FluentFolderPicker> {
  late String _currentPath;
  List<Directory> _subDirectories = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _loadDirectories();
  }

  void _loadDirectories() {
    setState(() => _isLoading = true);
    final dirs = <Directory>[];
    try {
      final currentDir = Directory(_currentPath);
      if (currentDir.existsSync()) {
        for (final entity in currentDir.listSync(followLinks: false)) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            if (!name.startsWith('.')) {
              dirs.add(entity);
            }
          }
        }
        dirs.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
      }
    } catch (_) {}

    setState(() {
      _subDirectories = dirs;
      _isLoading = false;
    });
  }

  void _navigateUp() {
    final parent = p.dirname(_currentPath);
    if (parent != _currentPath && parent.length >= 4) {
      setState(() {
        _currentPath = parent;
        _loadDirectories();
      });
    }
  }

  void _enterFolder(String path) {
    setState(() {
      _currentPath = path;
      _loadDirectories();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final size = MediaQuery.of(context).size;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: size.height * 0.78,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.borderSubtle),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                children: [
                  // Top Drag Handle
                  Container(
                    width: 32,
                    height: 4,
                    margin: const EdgeInsets.only(top: 8, bottom: 6),
                    decoration: BoxDecoration(
                      color: colors.textMuted.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  // Header Title
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Icon(Icons.folder_shared_outlined, size: 20, color: colors.primary),
                        const SizedBox(width: 10),
                        Text(
                          'Select Root Directory',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () => Navigator.pop(context),
                          tooltip: 'Cancel',
                        ),
                      ],
                    ),
                  ),

                  // Current Path Bar with Up button
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.container,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_upward, size: 18),
                          tooltip: 'Go to parent directory',
                          onPressed: p.dirname(_currentPath) != _currentPath ? _navigateUp : null,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _currentPath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),
                  Divider(height: 1, color: colors.borderSubtle),

                  // Directory list
                  Expanded(
                    child: _isLoading
                        ? Center(child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2))
                        : _subDirectories.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.folder_open, size: 40, color: colors.textMuted),
                                    const SizedBox(height: 8),
                                    Text('No subdirectories found', style: TextStyle(fontSize: 12, color: colors.textSecondary)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                physics: const BouncingScrollPhysics(),
                                itemCount: _subDirectories.length,
                                separatorBuilder: (_, _) => Divider(height: 1, indent: 48, color: colors.borderSubtle.withOpacity(0.5)),
                                itemBuilder: (ctx, i) {
                                  final dir = _subDirectories[i];
                                  final name = p.basename(dir.path);
                                  return ListTile(
                                    visualDensity: VisualDensity.compact,
                                    leading: const Icon(Icons.folder, color: Color(0xFFFFB900), size: 24),
                                    title: Text(name, style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                                    trailing: const Icon(Icons.chevron_right, size: 18),
                                    onTap: () => _enterFolder(dir.path),
                                  );
                                },
                              ),
                  ),

                  Divider(height: 1, color: colors.borderSubtle),

                  // Bottom Action Buttons
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: colors.primary,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(context, _currentPath),
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text(
                              'Select This Folder',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
