import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/explorer_provider.dart';
import '../providers/settings_provider.dart';
import '../services/file_service.dart';
import '../theme/fluent_theme.dart';

class FluentCommandRibbon extends StatelessWidget {
  const FluentCommandRibbon({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final explorer = context.watch<ExplorerProvider>();
    final settings = context.watch<SettingsProvider>();

    final hasSelection = explorer.hasSelection;
    final canPaste = explorer.clipboard != null && !explorer.isHome;

    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: colors.cardSurface,
        border: Border(
          bottom: BorderSide(color: colors.border, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 1. New
          _buildNewMenu(context, explorer, settings, colors),
          _buildVerticalDivider(colors),

          // 2. Cut
          _buildRibbonBtn(
            context,
            icon: Icons.content_cut,
            label: 'Cut',
            enabled: hasSelection && !explorer.isHome,
            onTap: () => explorer.cutSelected(),
            colors: colors,
          ),

          // 3. Copy
          _buildRibbonBtn(
            context,
            icon: Icons.content_copy,
            label: 'Copy',
            enabled: hasSelection && !explorer.isHome,
            onTap: () => explorer.copySelected(),
            colors: colors,
          ),

          // 4. Paste
          _buildRibbonBtn(
            context,
            icon: Icons.content_paste,
            label: 'Paste',
            enabled: canPaste,
            badgeCount: explorer.clipboard?.count,
            onTap: () => explorer.paste(showHidden: settings.showHiddenFiles),
            colors: colors,
          ),
          _buildVerticalDivider(colors),

          // 5. More (Floating Dropdown)
          _buildMoreMenu(context, explorer, settings, colors),
        ],
      ),
    );
  }

  Widget _buildMoreMenu(
    BuildContext context,
    ExplorerProvider explorer,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    final hasSelection = explorer.hasSelection;
    final singleSelection = explorer.selectionCount == 1;
    final canShare = explorer.canShareSelected && !explorer.isHome;
    final isHome = explorer.isHome;

    return PopupMenuButton<String>(
      tooltip: 'More options',
      offset: const Offset(0, 38),
      color: colors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: colors.border, width: 1),
      ),
      onSelected: (val) {
        switch (val) {
          case 'cancel_clipboard':
            explorer.cancelClipboard();
            break;
          case 'download':
            _showDownloadDialog(context, explorer, settings);
            break;
          case 'rename':
            _showRenameDialog(context, explorer, settings);
            break;
          case 'share':
            explorer.shareSelected();
            break;
          case 'zip':
            _showCompressRibbonDialog(context, explorer, settings);
            break;
          case 'delete':
            _confirmDelete(context, explorer, settings);
            break;
          // Sort Options
          case 'sort_name':
            explorer.setSorting(SortField.name, explorer.sortAscending, showHidden: settings.showHiddenFiles, settings: settings);
            break;
          case 'sort_date':
            explorer.setSorting(SortField.dateModified, explorer.sortAscending, showHidden: settings.showHiddenFiles, settings: settings);
            break;
          case 'sort_type':
            explorer.setSorting(SortField.type, explorer.sortAscending, showHidden: settings.showHiddenFiles, settings: settings);
            break;
          case 'sort_size':
            explorer.setSorting(SortField.size, explorer.sortAscending, showHidden: settings.showHiddenFiles, settings: settings);
            break;
          case 'sort_asc':
            explorer.setSorting(explorer.sortField, true, showHidden: settings.showHiddenFiles, settings: settings);
            break;
          case 'sort_desc':
            explorer.setSorting(explorer.sortField, false, showHidden: settings.showHiddenFiles, settings: settings);
            break;
          // View Mode Options
          case 'view_details':
            explorer.setViewMode(ViewMode.details, settings: settings);
            break;
          case 'view_tiles':
            explorer.setViewMode(ViewMode.tiles, settings: settings);
            break;
          case 'view_grid':
            explorer.setViewMode(ViewMode.grid, settings: settings);
            break;
        }
      },
      itemBuilder: (ctx) => [
        if (explorer.clipboard != null) ...[
          _buildPopupItem('cancel_clipboard', Icons.cancel_outlined, 'Cancel Cut/Copy', true, colors, isDestructive: true),
          const PopupMenuDivider(height: 1),
        ],
        _buildPopupItem('download', Icons.download_outlined, 'Download from Link...', !isHome, colors),
        _buildPopupItem('rename', Icons.edit_outlined, 'Rename', singleSelection && !isHome, colors),
        _buildPopupItem('share', Icons.share_outlined, 'Share', canShare, colors),
        _buildPopupItem('zip', Icons.archive_outlined, 'Compress to ZIP...', hasSelection && !isHome, colors),
        _buildPopupItem('delete', Icons.delete_outline, 'Delete', hasSelection && !isHome, colors, isDestructive: true),
        const PopupMenuDivider(height: 1),
        _buildPopupHeader('Sort by', colors),
        _buildSortCheckItem('Name', 'sort_name', explorer.sortField == SortField.name, colors),
        _buildSortCheckItem('Date modified', 'sort_date', explorer.sortField == SortField.dateModified, colors),
        _buildSortCheckItem('Type', 'sort_type', explorer.sortField == SortField.type, colors),
        _buildSortCheckItem('Size', 'sort_size', explorer.sortField == SortField.size, colors),
        _buildSortCheckItem('Ascending', 'sort_asc', explorer.sortAscending, colors),
        _buildSortCheckItem('Descending', 'sort_desc', !explorer.sortAscending, colors),
        const PopupMenuDivider(height: 1),
        _buildPopupHeader('View mode', colors),
        _buildViewCheckItem('Details', ViewMode.details, 'view_details', Icons.view_list, explorer.viewMode == ViewMode.details, colors),
        _buildViewCheckItem('Tiles', ViewMode.tiles, 'view_tiles', Icons.view_compact, explorer.viewMode == ViewMode.tiles, colors),
        _buildViewCheckItem('Large icons', ViewMode.grid, 'view_grid', Icons.grid_view, explorer.viewMode == ViewMode.grid, colors),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz, size: 18, color: colors.textPrimary),
            const SizedBox(width: 4),
            Text('More', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: colors.textPrimary)),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(
    String value,
    IconData icon,
    String title,
    bool enabled,
    FluentColors colors, {
    bool isDestructive = false,
  }) {
    final color = !enabled
        ? colors.textMuted.withOpacity(0.4)
        : isDestructive
            ? colors.error
            : colors.textPrimary;
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Text(title, style: TextStyle(fontSize: 12.5, color: color)),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildPopupHeader(String text, FluentColors colors) {
    return PopupMenuItem<String>(
      enabled: false,
      height: 26,
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: colors.textMuted),
      ),
    );
  }

  PopupMenuItem<String> _buildSortCheckItem(
    String title,
    String value,
    bool isChecked,
    FluentColors colors,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 34,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: isChecked ? Icon(Icons.check, size: 14, color: colors.primary) : null,
          ),
          Text(title, style: TextStyle(fontSize: 12.5, color: colors.textPrimary)),
        ],
      ),
    );
  }

  PopupMenuItem<String> _buildViewCheckItem(
    String title,
    ViewMode mode,
    String value,
    IconData icon,
    bool isChecked,
    FluentColors colors,
  ) {
    return PopupMenuItem<String>(
      value: value,
      height: 34,
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: isChecked ? Icon(Icons.check, size: 14, color: colors.primary) : null,
          ),
          Icon(icon, size: 15, color: colors.textSecondary),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontSize: 12.5, color: colors.textPrimary)),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider(FluentColors colors) {
    return Container(
      width: 1,
      height: 22,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      color: colors.borderSubtle,
    );
  }

  Widget _buildNewMenu(
    BuildContext context,
    ExplorerProvider explorer,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    final enabled = !explorer.isHome;
    return PopupMenuButton<String>(
      enabled: enabled,
      tooltip: 'Create New item',
      offset: const Offset(0, 38),
      color: colors.cardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: BorderSide(color: colors.border, width: 1),
      ),
      onSelected: (val) {
        if (val == 'folder') {
          _showCreateDialog(context, explorer, settings, isFolder: true);
        } else if (val == 'file') {
          _showCreateDialog(context, explorer, settings, isFolder: false);
        }
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(
          value: 'folder',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.create_new_folder_outlined, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Text('Folder', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'file',
          height: 38,
          child: Row(
            children: [
              Icon(Icons.note_add_outlined, size: 16, color: colors.primary),
              const SizedBox(width: 8),
              Text('Text Document', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
            ],
          ),
        ),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: enabled ? colors.primary.withOpacity(0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: enabled ? colors.primary.withOpacity(0.3) : colors.borderSubtle,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add, size: 16, color: enabled ? colors.primary : colors.textMuted),
            const SizedBox(width: 4),
            Text(
              'New',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: enabled ? colors.primary : colors.textMuted,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 14, color: enabled ? colors.primary : colors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildRibbonBtn(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onTap,
    required FluentColors colors,
    bool isDestructive = false,
    int? badgeCount,
  }) {
    final iconColor = !enabled
        ? colors.textMuted.withOpacity(0.4)
        : isDestructive
            ? colors.error
            : colors.textPrimary;

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          alignment: Alignment.center,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: iconColor),
                  const SizedBox(width: 5),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: enabled ? colors.textPrimary : colors.textMuted.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
              if (badgeCount != null && badgeCount > 0)
                Positioned(
                  top: -4,
                  right: -8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDownloadDialog(
    BuildContext context,
    ExplorerProvider explorer,
    SettingsProvider settings,
  ) {
    final urlController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final colors = FluentColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Row(
            children: [
              Icon(Icons.download, size: 20, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                'Download from Link',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlController,
                autofocus: true,
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Download URL',
                  hintText: 'https://example.com/file.pdf',
                  isDense: true,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.content_paste_go, size: 18),
                    tooltip: 'Paste from clipboard',
                    onPressed: () async {
                      try {
                        final data = await Clipboard.getData(Clipboard.kTextPlain);
                        if (data != null && data.text != null && data.text!.isNotEmpty) {
                          urlController.text = data.text!.trim();
                        }
                      } catch (_) {}
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                style: TextStyle(fontSize: 13, color: colors.textPrimary),
                decoration: const InputDecoration(
                  labelText: 'Custom Filename (Optional)',
                  hintText: 'Leave empty to detect from URL',
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
                final url = urlController.text.trim();
                final name = nameController.text.trim();
                Navigator.pop(ctx);
                if (url.isNotEmpty) {
                  await explorer.downloadFileFromUrl(
                    url: url,
                    customFileName: name.isNotEmpty ? name : null,
                    showHidden: settings.showHiddenFiles,
                  );
                }
              },
              child: const Text('Download'),
            ),
          ],
        );
      },
    );
  }

  void _showCreateDialog(
    BuildContext context,
    ExplorerProvider explorer,
    SettingsProvider settings, {
    required bool isFolder,
  }) {
    final controller = TextEditingController(
      text: isFolder ? 'New folder' : 'New text document.txt',
    );

    showDialog(
      context: context,
      builder: (ctx) {
        final colors = FluentColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colors.border),
          ),
          title: Text(
            isFolder ? 'Create Folder' : 'Create File',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(fontSize: 13, color: colors.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
            ),
            FilledButton(
              onPressed: () async {
                final name = controller.text.trim();
                Navigator.pop(ctx);
                if (name.isNotEmpty) {
                  if (isFolder) {
                    await explorer.createFolder(name, showHidden: settings.showHiddenFiles);
                  } else {
                    await explorer.createFile(name, showHidden: settings.showHiddenFiles);
                  }
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showRenameDialog(
    BuildContext context,
    ExplorerProvider explorer,
    SettingsProvider settings,
  ) {
    final currentPath = explorer.selectedPaths.first;
    final oldName = currentPath.split('/').last;
    final controller = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (ctx) {
        final colors = FluentColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colors.border),
          ),
          title: Text('Rename', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: TextStyle(fontSize: 13, color: colors.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
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
                if (newName.isNotEmpty && newName != oldName) {
                  await explorer.renameItem(currentPath, newName, showHidden: settings.showHiddenFiles);
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    ExplorerProvider explorer,
    SettingsProvider settings,
  ) {
    final count = explorer.selectionCount;
    showDialog(
      context: context,
      builder: (ctx) {
        final colors = FluentColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.cardSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: colors.border),
          ),
          title: Text('Delete Confirmation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          content: Text(
            'Are you sure you want to permanently delete $count selected item(s)?',
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
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

  void _showCompressRibbonDialog(
    BuildContext context,
    ExplorerProvider explorer,
    SettingsProvider settings,
  ) {
    final firstPath = explorer.selectedPaths.first;
    final defaultBase = explorer.selectionCount == 1 ? firstPath.split('/').last : 'Archive';
    final nameController = TextEditingController(text: '$defaultBase.zip');
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        final colors = FluentColors.of(ctx);
        return AlertDialog(
          backgroundColor: colors.cardSurface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          title: Text(
            'Compress to ZIP',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: colors.textPrimary),
          ),
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
}
