import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_item.dart';
import '../providers/explorer_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/notepad_screen.dart';
import '../services/media_launcher.dart';
import '../theme/fluent_theme.dart';
import 'file_properties_sheet.dart';

class FluentContextMenu {
  static void show(BuildContext context, FileItem item) {
    final colors = FluentColors.of(context);
    final explorer = context.read<ExplorerProvider>();
    final settings = context.read<SettingsProvider>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.82,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.cardSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.border, width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Subtle drag indicator handle
                        Center(
                          child: Container(
                            width: 32,
                            height: 4,
                            margin: const EdgeInsets.only(top: 8, bottom: 2),
                            decoration: BoxDecoration(
                              color: colors.textMuted.withOpacity(0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        // Top Item Info
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            children: [
                              Icon(
                                item.isDirectory ? Icons.folder : Icons.insert_drive_file,
                                size: 20,
                                color: item.isDirectory ? const Color(0xFFFFB900) : colors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      item.formatSize(),
                                      style: TextStyle(fontSize: 11, color: colors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Divider(height: 1, color: colors.borderSubtle),

              // Action Buttons
              _buildMenuItem(
                ctx,
                icon: Icons.open_in_new,
                title: 'Open',
                onTap: () {
                  Navigator.pop(ctx);
                  if (item.isDirectory) {
                    explorer.navigateTo(item.path);
                  } else {
                    settings.addRecentFile(item.path);
                    MediaLauncher.openItem(context, item);
                  }
                },
                colors: colors,
              ),
              if (!item.isDirectory)
                _buildMenuItem(
                  ctx,
                  icon: Icons.open_with,
                  title: 'Open with...',
                  onTap: () {
                    Navigator.pop(ctx);
                    explorer.openFileWith(item.path);
                  },
                  colors: colors,
                ),
              if (!item.isDirectory && (item.isText || item.isCode))
                _buildMenuItem(
                  ctx,
                  icon: Icons.edit_note_outlined,
                  title: 'Edit in Notepad',
                  onTap: () {
                    Navigator.pop(ctx);
                    WindowsNotepadScreen.open(context, filePath: item.path, fileItem: item);
                  },
                  colors: colors,
                ),
              _buildMenuItem(
                ctx,
                icon: Icons.content_cut,
                title: 'Cut',
                onTap: () {
                  Navigator.pop(ctx);
                  explorer.clearSelection();
                  explorer.toggleSelection(item.path);
                  explorer.cutSelected();
                },
                colors: colors,
              ),
              _buildMenuItem(
                ctx,
                icon: Icons.content_copy,
                title: 'Copy',
                onTap: () {
                  Navigator.pop(ctx);
                  explorer.clearSelection();
                  explorer.toggleSelection(item.path);
                  explorer.copySelected();
                },
                colors: colors,
              ),
              if (item.isDirectory)
                _buildMenuItem(
                  ctx,
                  icon: settings.pinnedPaths.contains(item.path) ? Icons.push_pin : Icons.push_pin_outlined,
                  title: settings.pinnedPaths.contains(item.path)
                      ? 'Unpin from Quick access'
                      : 'Pin to Quick access',
                  onTap: () {
                    Navigator.pop(ctx);
                    settings.togglePinPath(item.path);
                  },
                  colors: colors,
                ),
              _buildMenuItem(
                ctx,
                icon: Icons.edit_outlined,
                title: 'Rename',
                onTap: () {
                  Navigator.pop(ctx);
                  _showRename(context, explorer, settings, item);
                },
                colors: colors,
              ),
              if (!item.isDirectory)
                _buildMenuItem(
                  ctx,
                  icon: Icons.share_outlined,
                  title: 'Share',
                  onTap: () {
                    Navigator.pop(ctx);
                    explorer.clearSelection();
                    explorer.toggleSelection(item.path);
                    explorer.shareSelected();
                  },
                  colors: colors,
                ),
              if (item.isArchive)
                _buildMenuItem(
                  ctx,
                  icon: Icons.unarchive_outlined,
                  title: 'Extract Archive...',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showExtractDialog(context, explorer, settings, item);
                  },
                  colors: colors,
                ),
              _buildMenuItem(
                ctx,
                icon: Icons.archive_outlined,
                title: 'Compress to ZIP...',
                onTap: () {
                  Navigator.pop(ctx);
                  _showCompressDialog(context, explorer, settings, [item.path], item.name);
                },
                colors: colors,
              ),
              _buildMenuItem(
                ctx,
                icon: Icons.shield_outlined,
                title: 'Move to File Vault...',
                onTap: () {
                  Navigator.pop(ctx);
                  final paths = explorer.selectedPaths.contains(item.path)
                      ? explorer.selectedPaths.toList()
                      : [item.path];
                  explorer.moveToVault(paths, context, showHidden: settings.showHiddenFiles);
                },
                colors: colors,
              ),
              _buildMenuItem(
                ctx,
                icon: Icons.delete_outline,
                title: 'Delete',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDelete(context, explorer, settings, item);
                },
                colors: colors,
              ),
              Divider(height: 1, color: colors.borderSubtle),
              _buildMenuItem(
                ctx,
                icon: Icons.info_outline,
                title: 'Properties',
                onTap: () {
                  Navigator.pop(ctx);
                  FilePropertiesSheet.show(context, item);
                },
                colors: colors,
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ),
  ),
),
);
      },
    );
  }

  static Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required FluentColors colors,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? colors.error : colors.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isDestructive ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static void _showRename(
    BuildContext context,
    ExplorerProvider explorer,
    SettingsProvider settings,
    FileItem item,
  ) {
    final controller = TextEditingController(text: item.name);
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = FluentColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text('Rename', style: TextStyle(fontSize: 16, color: colors.textPrimary)),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(isDense: true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            FilledButton(
              onPressed: () async {
                final newName = controller.text.trim();
                Navigator.pop(ctx);
                if (newName.isNotEmpty && newName != item.name) {
                  await explorer.renameItem(item.path, newName, showHidden: settings.showHiddenFiles);
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  static void _confirmDelete(
    BuildContext context,
    ExplorerProvider explorer,
    SettingsProvider settings,
    FileItem item,
  ) {
    final pathsToDelete = explorer.selectedPaths.contains(item.path)
        ? explorer.selectedPaths.toList()
        : [item.path];
    final isMultiple = pathsToDelete.length > 1;

    showDialog(
      context: context,
      builder: (ctx) {
        final colors = FluentColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            isMultiple ? 'Delete items' : 'Delete item',
            style: TextStyle(fontSize: 16, color: colors.textPrimary),
          ),
          content: Text(
            isMultiple
                ? 'Are you sure you want to delete ${pathsToDelete.length} selected items?'
                : 'Are you sure you want to delete "${item.name}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: colors.error,
                side: BorderSide(color: colors.error.withOpacity(0.5)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await explorer.deleteItems(pathsToDelete, showHidden: settings.showHiddenFiles);
              },
              child: const Text('Delete Permanently'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.delete_sweep_outlined, size: 16),
              style: FilledButton.styleFrom(backgroundColor: colors.primary),
              onPressed: () async {
                Navigator.pop(ctx);
                await explorer.moveToRecycleBin(pathsToDelete, showHidden: settings.showHiddenFiles);
              },
              label: const Text('Move to Recycle Bin'),
            ),
          ],
        );
      },
    );
  }

  static void _showCompressDialog(
    BuildContext context,
    ExplorerProvider explorer,
    SettingsProvider settings,
    List<String> paths,
    String defaultName,
  ) {
    final nameController = TextEditingController(
      text: defaultName.toLowerCase().endsWith('.zip')
          ? defaultName
          : '$defaultName.zip',
    );
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final colors = FluentColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text('Compress to ZIP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Archive Name',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Password (Optional)',
                  hintText: 'Leave empty for no encryption',
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final password = passwordController.text.isNotEmpty ? passwordController.text : null;
                Navigator.pop(ctx);
                if (name.isNotEmpty) {
                  explorer.clearSelection();
                  for (final p in paths) {
                    explorer.toggleSelection(p);
                  }
                  await explorer.compressSelectedToZip(
                    outputName: name,
                    password: password,
                    showHidden: settings.showHiddenFiles,
                  );
                }
              },
              child: const Text('Compress'),
            ),
          ],
        );
      },
    );
  }

  static void _showExtractDialog(
    BuildContext context,
    ExplorerProvider explorer,
    SettingsProvider settings,
    FileItem item,
  ) {
    final folderController = TextEditingController(
      text: item.name.split('.').first,
    );
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final colors = FluentColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text('Extract Archive', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: folderController,
                autofocus: true,
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Target Folder',
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Archive Password (if encrypted)',
                  hintText: 'Leave empty if no password',
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            FilledButton(
              onPressed: () async {
                final folder = folderController.text.trim();
                final password = passwordController.text.isNotEmpty ? passwordController.text : null;
                Navigator.pop(ctx);
                await explorer.extractArchiveFile(
                  archivePath: item.path,
                  targetFolder: folder.isNotEmpty ? folder : null,
                  password: password,
                  showHidden: settings.showHiddenFiles,
                );
              },
              child: const Text('Extract'),
            ),
          ],
        );
      },
    );
  }
}
