import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/file_item.dart';
import '../services/file_service.dart';
import '../services/media_launcher.dart';
import '../services/vault_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/fluent_file_icons.dart';
import '../widgets/vault/vault_auth_dialog.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  static Future<void> open(BuildContext context) async {
    final unlocked = await VaultAuthDialog.requestAuth(
      context,
      title: 'File Vault',
      description: 'Enter credentials to open your protected vault',
    );
    if (unlocked && context.mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const VaultScreen()),
      );
    }
  }

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> {
  final VaultService _vault = VaultService.instance;
  String _basePath = '';
  String _currentPath = '';
  List<FileItem> _items = [];
  bool _isLoading = true;
  final Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    _initVault();
  }

  @override
  void dispose() {
    _vault.lock();
    super.dispose();
  }

  Future<void> _initVault() async {
    setState(() => _isLoading = true);
    await _vault.ensureVaultStorageInitialized();
    final base = await _vault.getVaultBasePath();
    _basePath = base;
    _currentPath = base;
    await _loadCurrentDirectory();
  }

  Future<void> _loadCurrentDirectory() async {
    setState(() => _isLoading = true);
    final dir = Directory(_currentPath);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final List<FileItem> loaded = [];
    try {
      final entities = dir.listSync(followLinks: false);
      for (final entity in entities) {
        final name = p.basename(entity.path);
        if (name == '.nomedia') continue;
        try {
          loaded.add(FileItem.fromFileSystemEntity(entity));
        } catch (_) {}
      }
    } catch (_) {}

    loaded.sort((a, b) {
      if (a.isDirectory && !b.isDirectory) return -1;
      if (!a.isDirectory && b.isDirectory) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    if (mounted) {
      setState(() {
        _items = loaded;
        _selectedPaths.clear();
        _isLoading = false;
      });
    }
  }

  bool get _isAtRoot => _currentPath == _basePath;

  String _getRelativeBreadcrumb() {
    if (_isAtRoot) return 'Vault Home';
    final rel = p.relative(_currentPath, from: _basePath);
    return 'Vault > ${rel.replaceAll(Platform.pathSeparator, ' > ')}';
  }

  void _navigateUp() {
    if (_isAtRoot) {
      Navigator.of(context).pop();
      return;
    }
    final parent = p.dirname(_currentPath);
    if (parent.startsWith(_basePath)) {
      setState(() => _currentPath = parent);
      _loadCurrentDirectory();
    } else {
      setState(() => _currentPath = _basePath);
      _loadCurrentDirectory();
    }
  }

  Future<void> _showCreateFolderDialog() async {
    final colors = FluentColors.of(context);
    final controller = TextEditingController();

    final folderName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('New Folder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(fontSize: 14, color: colors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Folder name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: colors.primary),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (folderName != null && folderName.isNotEmpty) {
      await _vault.createFolder(_currentPath, folderName);
      await _loadCurrentDirectory();
    }
  }

  Future<void> _importFilesFlow() async {
    // Pick files using FilePicker or allow browsing from NeoFile storage
    final colors = FluentColors.of(context);
    // Ask user to pick from device
    final extDir = Directory('/storage/emulated/0');
    if (!await extDir.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Storage not accessible')),
        );
      }
      return;
    }

    // Show category / folder target
    String? targetCategory;
    if (!mounted) return;
    if (_isAtRoot) {
      targetCategory = await showDialog<String>(
        context: context,
        builder: (ctx) => SimpleDialog(
          backgroundColor: colors.cardSurface,
          title: Text('Select Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          children: VaultService.defaultCategories.map((cat) {
            return SimpleDialogOption(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              onPressed: () => Navigator.pop(ctx, cat),
              child: Row(
                children: [
                  Icon(
                    cat == 'Images' ? Icons.image_outlined : (cat == 'Videos' ? Icons.videocam_outlined : Icons.insert_drive_file_outlined),
                    size: 20,
                    color: colors.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(cat, style: TextStyle(fontSize: 14, color: colors.textPrimary)),
                ],
              ),
            );
          }).toList(),
        ),
      );
      if (targetCategory == null) return;
    }

    // Launch picker or NeoFile file selection
    if (!mounted) return;
    _showStoragePickerAndImport(targetCategory);
  }

  void _showStoragePickerAndImport(String? category) {
    // Let user browse storage and pick items to import into Vault
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VaultImportPicker(
        initialPath: '/storage/emulated/0',
        onImportSelected: (selectedFiles) async {
          Navigator.pop(ctx);
          if (selectedFiles.isEmpty) return;

          setState(() => _isLoading = true);
          String? targetSubdir;
          if (!_isAtRoot) {
            final rel = p.relative(_currentPath, from: _basePath);
            final parts = p.split(rel);
            if (parts.length > 1) {
              targetSubdir = parts.sublist(1).join('/');
            }
          }

          await _vault.importFiles(
            selectedFiles,
            targetCategory: category ?? (_isAtRoot ? 'Files' : p.split(p.relative(_currentPath, from: _basePath)).first),
            targetSubdir: targetSubdir,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${selectedFiles.length} item(s) safely moved to File Vault')),
            );
            await _loadCurrentDirectory();
          }
        },
      ),
    );
  }

  Future<void> _exportSelectedFiles() async {
    if (_selectedPaths.isEmpty) return;
    final colors = FluentColors.of(context);

    // Export to Download/NeoFile Vault Restored
    final exportDir = Directory('/storage/emulated/0/Download/NeoFile Vault Restored');
    if (!await exportDir.exists()) {
      await exportDir.create(recursive: true);
    }
    if (!mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('Export to Storage', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        content: Text(
          'Export ${_selectedPaths.length} item(s) to:\n${exportDir.path}\n\nFiles will be accessible from normal gallery and file managers.',
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: colors.primary),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await _vault.exportFiles(_selectedPaths.toList(), exportDir.path);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported ${_selectedPaths.length} item(s) successfully')),
        );
        await _loadCurrentDirectory();
      }
    }
  }

  Future<void> _deleteSelectedFiles() async {
    if (_selectedPaths.isEmpty) return;
    final colors = FluentColors.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Text('Permanently Delete', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
        content: Text(
          'Are you sure you want to permanently delete ${_selectedPaths.length} item(s)? This cannot be undone.',
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await _vault.deleteVaultItems(_selectedPaths.toList());
      if (mounted) {
        await _loadCurrentDirectory();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.cardSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(_isAtRoot ? Icons.arrow_back : Icons.arrow_upward, color: colors.textPrimary),
          onPressed: _navigateUp,
          tooltip: _isAtRoot ? 'Back' : 'Up one level',
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: colors.primary),
                const SizedBox(width: 6),
                Text(
                  'File Vault',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
              ],
            ),
            Text(
              _getRelativeBreadcrumb(),
              style: TextStyle(fontSize: 11, color: colors.textMuted),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.create_new_folder_outlined, color: colors.textPrimary),
            tooltip: 'New Folder',
            onPressed: _showCreateFolderDialog,
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: colors.primary),
            tooltip: 'Import Files',
            onPressed: _importFilesFlow,
          ),
          IconButton(
            icon: Icon(Icons.lock_outline, color: colors.textPrimary),
            tooltip: 'Lock Vault',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: colors.borderSubtle, height: 1),
        ),
      ),
      bottomNavigationBar: _selectedPaths.isNotEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: colors.cardSurface,
                border: Border(top: BorderSide(color: colors.borderSubtle)),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Text(
                      '${_selectedPaths.length} selected',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      icon: const Icon(Icons.unarchive_outlined, size: 18),
                      label: const Text('Export'),
                      onPressed: _exportSelectedFiles,
                      style: TextButton.styleFrom(foregroundColor: colors.primary),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.delete_forever_outlined, size: 18),
                      label: const Text('Delete'),
                      onPressed: _deleteSelectedFiles,
                      style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    ),
                  ],
                ),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _items.isEmpty
              ? _buildEmptyState(colors)
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: _items.length,
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final isSelected = _selectedPaths.contains(item.path);

                    return Container(
                      color: isSelected ? colors.primary.withOpacity(0.08) : Colors.transparent,
                      child: ListTile(
                        leading: _buildLeadingIcon(item, colors),
                        title: Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: item.isDirectory ? FontWeight.w600 : FontWeight.normal,
                            color: colors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.isDirectory
                              ? 'Folder'
                              : '${item.formatSize()} • ${item.modified.toString().split('.').first}',
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedPaths.add(item.path);
                              } else {
                                _selectedPaths.remove(item.path);
                              }
                            });
                          },
                        ),
                        onTap: () {
                          if (_selectedPaths.isNotEmpty) {
                            setState(() {
                              if (isSelected) {
                                _selectedPaths.remove(item.path);
                              } else {
                                _selectedPaths.add(item.path);
                              }
                            });
                          } else if (item.isDirectory) {
                            setState(() => _currentPath = item.path);
                            _loadCurrentDirectory();
                          } else {
                            MediaLauncher.openItem(context, item, siblings: _items);
                          }
                        },
                        onLongPress: () {
                          setState(() {
                            if (isSelected) {
                              _selectedPaths.remove(item.path);
                            } else {
                              _selectedPaths.add(item.path);
                            }
                          });
                        },
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildLeadingIcon(FileItem item, FluentColors colors) {
    if (item.isDirectory) {
      final name = item.name;
      IconData icon = Icons.folder;
      Color col = Colors.amber.shade700;
      if (name == 'Images') {
        icon = Icons.photo_library_outlined;
        col = Colors.blue;
      } else if (name == 'Videos') {
        icon = Icons.video_collection_outlined;
        col = Colors.purple;
      } else if (name == 'Files') {
        icon = Icons.folder_special_outlined;
        col = Colors.teal;
      }
      return Icon(icon, size: 28, color: col);
    }
    return FluentFileIcon(item: item, size: 28);
  }

  Widget _buildEmptyState(FluentColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 64, color: colors.textMuted.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'This folder is empty',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            'Add photos, videos or confidential documents here',
            style: TextStyle(fontSize: 12, color: colors.textMuted),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text('Add Files to Vault'),
            onPressed: _importFilesFlow,
            style: FilledButton.styleFrom(
              backgroundColor: colors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}

class _VaultImportPicker extends StatefulWidget {
  final String initialPath;
  final ValueChanged<List<String>> onImportSelected;

  const _VaultImportPicker({
    required this.initialPath,
    required this.onImportSelected,
  });

  @override
  State<_VaultImportPicker> createState() => _VaultImportPickerState();
}

class _VaultImportPickerState extends State<_VaultImportPicker> {
  late String _currentPath;
  List<FileItem> _items = [];
  final Set<String> _selectedPaths = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.initialPath;
    _loadDir();
  }

  Future<void> _loadDir() async {
    setState(() => _isLoading = true);
    final items = await FileService.listDirectory(path: _currentPath, showHidden: false);
    if (mounted) {
      setState(() {
        _items = items;
        _isLoading = false;
      });
    }
  }

  void _navigateUp() {
    if (_currentPath == '/storage/emulated/0' || _currentPath == '/' || _currentPath.isEmpty) {
      return;
    }
    _currentPath = p.dirname(_currentPath);
    _loadDir();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final isRoot = _currentPath == '/storage/emulated/0';

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(isRoot ? Icons.close : Icons.arrow_back, color: colors.textPrimary),
                  onPressed: isRoot ? () => Navigator.pop(context) : _navigateUp,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select items to import',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                      Text(
                        _currentPath.replaceAll('/storage/emulated/0', 'Internal Storage'),
                        style: TextStyle(fontSize: 11, color: colors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _selectedPaths.isEmpty
                      ? null
                      : () => widget.onImportSelected(_selectedPaths.toList()),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: Text('Import (${_selectedPaths.length})'),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colors.borderSubtle),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : ListView.builder(
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final isSelected = _selectedPaths.contains(item.path);

                      return ListTile(
                        leading: item.isDirectory
                            ? const Icon(Icons.folder, color: Colors.amber, size: 28)
                            : FluentFileIcon(item: item, size: 28),
                        title: Text(
                          item.name,
                          style: TextStyle(fontSize: 13, color: colors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          item.isDirectory ? 'Folder' : item.formatSize(),
                          style: TextStyle(fontSize: 11, color: colors.textMuted),
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedPaths.add(item.path);
                              } else {
                                _selectedPaths.remove(item.path);
                              }
                            });
                          },
                        ),
                        onTap: () {
                          if (item.isDirectory) {
                            setState(() => _currentPath = item.path);
                            _loadDir();
                          } else {
                            setState(() {
                              if (isSelected) {
                                _selectedPaths.remove(item.path);
                              } else {
                                _selectedPaths.add(item.path);
                              }
                            });
                          }
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
