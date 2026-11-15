import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import '../models/file_item.dart';
import '../services/file_service.dart';
import '../services/media_launcher.dart';
import '../services/vault_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/fluent_file_icons.dart';
import '../widgets/vault/fluent_media_picker.dart';
import '../widgets/vault/vault_auth_dialog.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  static Future<void> open(BuildContext context) async {
    final rootNav = Navigator.of(context, rootNavigator: true);
    final unlocked = await VaultAuthDialog.requestAuth(
      rootNav.context,
      title: 'File Vault',
      description: 'Enter credentials to open your protected vault',
    );
    if (unlocked && rootNav.context.mounted) {
      rootNav.push(
        MaterialPageRoute(builder: (_) => const VaultScreen()),
      );
    }
  }

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with WidgetsBindingObserver {
  final VaultService _vault = VaultService.instance;
  String _basePath = '';
  String _currentPath = '';
  List<FileItem> _items = [];
  bool _isLoading = true;
  final Set<String> _selectedPaths = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    VaultService.setWindowSecure(true);
    _initVault();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _vault.lock();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    VaultService.setWindowSecure(false);
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
    final colors = FluentColors.of(context);
    _showVaultAddTypeBottomSheet(colors);
  }

  void _showVaultAddTypeBottomSheet(FluentColors colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.only(top: 8, bottom: 20),
        decoration: BoxDecoration(
          color: colors.cardSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.add_moderator_rounded, size: 20, color: colors.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add to File Vault',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: colors.textPrimary),
                          ),
                          Text(
                            'Select how you want to pick files to encrypt',
                            style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: colors.borderSubtle),
              const SizedBox(height: 8),

              // 1. Photos & Images Grid Picker
              _buildAddTypeTile(
                colors: colors,
                icon: Icons.photo_library_outlined,
                accentColor: const Color(0xFF0078D4),
                title: 'Photos & Images',
                subtitle: 'Browse gallery photos with thumbnail grid',
                onTap: () {
                  Navigator.pop(ctx);
                  _openMediaPicker(VaultMediaType.images, defaultCategory: 'Images');
                },
              ),

              // 2. Videos Grid Picker
              _buildAddTypeTile(
                colors: colors,
                icon: Icons.video_library_outlined,
                accentColor: const Color(0xFF881798),
                title: 'Videos & Movies',
                subtitle: 'Browse clips, movies and camera recordings',
                onTap: () {
                  Navigator.pop(ctx);
                  _openMediaPicker(VaultMediaType.videos, defaultCategory: 'Videos');
                },
              ),

              // 3. Documents Picker
              _buildAddTypeTile(
                colors: colors,
                icon: Icons.description_outlined,
                accentColor: const Color(0xFF107C41),
                title: 'Documents & Files',
                subtitle: 'PDFs, Word docs, text notes and archives',
                onTap: () {
                  Navigator.pop(ctx);
                  _openMediaPicker(VaultMediaType.documents, defaultCategory: 'Files');
                },
              ),

              // 4. File Explorer / Raw Picker
              _buildAddTypeTile(
                colors: colors,
                icon: Icons.folder_open_outlined,
                accentColor: const Color(0xFFD83B01),
                title: 'Browse Folders (File Picker)',
                subtitle: 'Navigate full device storage and pick custom files',
                onTap: () {
                  Navigator.pop(ctx);
                  _showStoragePickerAndImport();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddTypeTile({
    required FluentColors colors,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 22, color: accentColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11.5, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  void _openMediaPicker(VaultMediaType mediaType, {required String defaultCategory}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FluentMediaPicker(
        mediaType: mediaType,
        onImportSelected: (selectedFiles) {
          Navigator.pop(ctx);
          _handleImportSelected(selectedFiles, defaultCategory: defaultCategory);
        },
      ),
    );
  }

  void _showStoragePickerAndImport([String? category]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _VaultImportPicker(
        initialPath: '/storage/emulated/0',
        onImportSelected: (selectedFiles) {
          Navigator.pop(ctx);
          _handleImportSelected(selectedFiles, defaultCategory: category ?? 'Files');
        },
      ),
    );
  }

  Future<void> _handleImportSelected(List<String> selectedFiles, {String? defaultCategory}) async {
    if (selectedFiles.isEmpty) return;

    setState(() => _isLoading = true);
    String? targetCategory;
    String? targetSubdir;

    if (_isAtRoot) {
      targetCategory = defaultCategory ?? 'Files';
    } else {
      final rel = p.relative(_currentPath, from: _basePath);
      final parts = p.split(rel);
      targetCategory = parts.first;
      if (parts.length > 1) {
        targetSubdir = parts.sublist(1).join('/');
      }
    }

    final imported = await _vault.importFiles(
      selectedFiles,
      targetCategory: targetCategory,
      targetSubdir: targetSubdir,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${imported.length} item(s) safely moved to File Vault'),
          duration: const Duration(seconds: 3),
        ),
      );
      await _loadCurrentDirectory();
    }
  }

  Future<void> _restoreSelectedFiles() async {
    if (_selectedPaths.isEmpty) return;
    final colors = FluentColors.of(context);

    final count = _selectedPaths.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        title: Row(
          children: [
            Icon(Icons.settings_backup_restore_rounded, color: colors.primary, size: 22),
            const SizedBox(width: 8),
            Text(
              'Restore $count Item${count > 1 ? 's' : ''}',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
            ),
          ],
        ),
        content: Text(
          'Restore $count selected item${count > 1 ? 's' : ''} back to their original folder location?\n\nFiles will be removed from File Vault and restored to where they were originally stored, making them accessible again in your gallery and apps.',
          style: TextStyle(fontSize: 13, color: colors.textSecondary, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.icon(
            icon: const Icon(Icons.settings_backup_restore_rounded, size: 16),
            label: const Text('Restore Files'),
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: colors.primary),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      final restored = await _vault.restoreFiles(_selectedPaths.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${restored.length} item(s) restored to original location'),
            duration: const Duration(seconds: 3),
          ),
        );
        await _loadCurrentDirectory();
      }
    }
  }

  Future<void> _exportSelectedFiles() async {
    await _restoreSelectedFiles();
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

  Future<void> _handleChangeCredentials() async {
    final verified = await VaultAuthDialog.requestAuth(
      context,
      title: 'Verify Identity',
      description: 'Enter current password or pattern to change credentials',
    );
    if (!verified || !mounted) return;

    final changed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const VaultAuthDialog(
        isSetupMode: true,
        title: 'Change Credentials',
        description: 'Choose a new password, PIN or pattern for File Vault',
      ),
    );

    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vault credentials updated successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);

    return PopScope(
      canPop: _isAtRoot,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _navigateUp();
        }
      },
      child: Scaffold(
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
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: colors.textPrimary),
              tooltip: 'Vault Options',
              onSelected: (val) {
                if (val == 'change_creds') {
                  _handleChangeCredentials();
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'change_creds',
                  child: Row(
                    children: [
                      Icon(Icons.password_outlined, size: 18, color: colors.primary),
                      const SizedBox(width: 10),
                      Text(
                        'Change Password / Pattern',
                        style: TextStyle(fontSize: 13, color: colors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ],
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
                    FilledButton.icon(
                      icon: const Icon(Icons.settings_backup_restore_rounded, size: 18),
                      label: const Text('Restore'),
                      onPressed: _restoreSelectedFiles,
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
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
      ),
    );
  }

  Widget _buildLeadingIcon(FileItem item, FluentColors colors) {
    if (item.isDirectory) {
      final name = item.name;
      IconData icon = Icons.folder_rounded;
      List<Color> gradientColors;

      if (name == 'Images') {
        icon = Icons.photo_size_select_actual_rounded;
        gradientColors = const [Color(0xFF0078D4), Color(0xFF005A9E)];
      } else if (name == 'Videos') {
        icon = Icons.smart_display_rounded;
        gradientColors = const [Color(0xFF8764B8), Color(0xFF5C2D91)];
      } else if (name == 'Files') {
        icon = Icons.description_rounded;
        gradientColors = const [Color(0xFF107C41), Color(0xFF0B5A2F)];
      } else {
        icon = Icons.folder_rounded;
        gradientColors = const [Color(0xFFFFB900), Color(0xFFD83B01)];
      }

      return Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(0.25),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Icon(icon, size: 20, color: Colors.white),
        ),
      );
    }
    return FluentFileIcon(item: item, size: 36);
  }

  Widget _buildEmptyState(FluentColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colors.primary.withOpacity(0.18),
                  colors.primary.withOpacity(0.06),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.primary.withOpacity(0.25), width: 1.5),
            ),
            child: Icon(Icons.shield_outlined, size: 38, color: colors.primary),
          ),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
