import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/file_item.dart';
import '../providers/explorer_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/fluent_theme.dart';
import 'file_properties_sheet.dart';

class FluentContextMenu {
  static void show(BuildContext context, FileItem item) {
    final colors = FluentColors.of(context);
    final explorer = context.read<ExplorerProvider>();
    final settings = context.read<SettingsProvider>();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.cardSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: colors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Item Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    explorer.openFile(item.path);
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
              const SizedBox(height: 4),
            ],
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
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = FluentColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text('Delete item', style: TextStyle(fontSize: 16, color: colors.textPrimary)),
          content: Text('Are you sure you want to delete "${item.name}"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: colors.error),
              onPressed: () async {
                Navigator.pop(ctx);
                await explorer.deleteSelected(showHidden: settings.showHiddenFiles);
              },
              child: const Text('Delete'),
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
