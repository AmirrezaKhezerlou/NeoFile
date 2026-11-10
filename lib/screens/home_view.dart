import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import '../models/file_item.dart';
import '../providers/explorer_provider.dart';
import '../providers/settings_provider.dart';
import '../services/file_service.dart';
import '../services/media_launcher.dart';
import '../theme/fluent_theme.dart';
import '../widgets/fluent_context_menu.dart';
import '../widgets/fluent_file_icons.dart';
import '../widgets/fluent_marquee_text.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final explorer = context.watch<ExplorerProvider>();
    final settings = context.watch<SettingsProvider>();

    if (explorer.searchQuery.isNotEmpty) {
      return _buildGlobalSearchResults(context, explorer, settings, colors);
    }

    return RefreshIndicator(
      onRefresh: () async {
        await explorer.loadStorageVolumes();
      },
      color: colors.primary,
      backgroundColor: colors.cardSurface,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section 1: Devices and drives
          _buildSectionHeader(
            context,
            title: 'Devices and drives',
            icon: Icons.storage,
            colors: colors,
          ),
          const SizedBox(height: 8),
          ...explorer.storageVolumes.map((vol) => _buildStorageCard(context, vol, explorer, colors)),

          const SizedBox(height: 18),

          // Section 2: Quick access
          _buildSectionHeader(
            context,
            title: 'Quick access',
            icon: Icons.push_pin_outlined,
            colors: colors,
          ),
          const SizedBox(height: 8),
          _buildQuickAccessGrid(context, explorer, colors),

          // Section 3: Pinned Folders (if any)
          if (settings.pinnedPaths.isNotEmpty) ...[
            const SizedBox(height: 18),
            _buildSectionHeader(
              context,
              title: 'Favorites',
              icon: Icons.star_border,
              colors: colors,
            ),
            const SizedBox(height: 8),
            _buildPinnedList(context, explorer, settings, colors),
          ],

          // Section 4: Recent Files
          if (settings.recentFiles.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSectionHeader(
                  context,
                  title: 'Recent files',
                  icon: Icons.history,
                  colors: colors,
                ),
                TextButton(
                  onPressed: () => settings.clearRecentFiles(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Clear', style: TextStyle(fontSize: 11, color: colors.textMuted)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildRecentFilesList(context, explorer, settings, colors),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
    required IconData icon,
    required FluentColors colors,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStorageCard(
    BuildContext context,
    StorageVolumeInfo vol,
    ExplorerProvider explorer,
    FluentColors colors,
  ) {
    return InkWell(
      onTap: () => explorer.navigateTo(vol.path),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.cardSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.borderSubtle, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                (vol.title.toLowerCase().contains('external') ||
                 vol.title.toLowerCase().contains('usb') ||
                 vol.title.toLowerCase().contains('otg'))
                    ? Icons.usb
                    : vol.isRemovable
                        ? Icons.sd_card
                        : Icons.phone_android,
                size: 22,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        vol.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      Text(
                        '${(vol.usedPercentage * 100).toStringAsFixed(1)}% used',
                        style: TextStyle(fontSize: 11, color: colors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: vol.usedPercentage,
                      minHeight: 4,
                      backgroundColor: colors.container,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        vol.usedPercentage > 0.9 ? colors.error : colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${vol.freeFormatted} free of ${vol.totalFormatted}',
                    style: TextStyle(fontSize: 11, color: colors.textMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 16, color: colors.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessGrid(
    BuildContext context,
    ExplorerProvider explorer,
    FluentColors colors,
  ) {
    final standardFolders = [
      _QuickFolder(title: 'Downloads', path: '/storage/emulated/0/Download', icon: Icons.download, color: const Color(0xFF0078D4)),
      _QuickFolder(title: 'Documents', path: '/storage/emulated/0/Documents', icon: Icons.description, color: const Color(0xFF107C41)),
      _QuickFolder(title: 'Pictures', path: '/storage/emulated/0/Pictures', icon: Icons.photo_library, color: const Color(0xFF008378)),
      _QuickFolder(title: 'DCIM', path: '/storage/emulated/0/DCIM', icon: Icons.camera_alt, color: const Color(0xFFE3008C)),
      _QuickFolder(title: 'Music', path: '/storage/emulated/0/Music', icon: Icons.audio_file, color: const Color(0xFFB146C2)),
      _QuickFolder(title: 'Movies', path: '/storage/emulated/0/Movies', icon: Icons.movie, color: const Color(0xFFD83B01)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.8,
          ),
          itemCount: standardFolders.length,
          itemBuilder: (ctx, i) {
            final f = standardFolders[i];
            return InkWell(
              onTap: () => explorer.navigateTo(f.path),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.cardSurface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.borderSubtle, width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: f.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(f.icon, size: 18, color: f.color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPinnedList(
    BuildContext context,
    ExplorerProvider explorer,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    return Column(
      children: settings.pinnedPaths.map((path) {
        final name = p.basename(path);
        return InkWell(
          onTap: () => explorer.navigateTo(path),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.borderSubtle, width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_special, size: 18, color: Color(0xFFFFB900)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: colors.textPrimary),
                      ),
                      Text(
                        path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 14),
                  color: colors.textMuted,
                  onPressed: () => settings.togglePinPath(path),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecentFilesList(
    BuildContext context,
    ExplorerProvider explorer,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    return Column(
      children: settings.recentFiles.map((path) {
        final file = File(path);
        if (!file.existsSync()) return const SizedBox.shrink();
        final item = FileItem.fromFileSystemEntity(file);

        return InkWell(
          onTap: () => MediaLauncher.openItem(context, item),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.borderSubtle, width: 1),
            ),
            child: Row(
              children: [
                FluentFileIcon(item: item, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: FluentMarqueeText(
                    item.name,
                    style: TextStyle(fontSize: 12.5, color: colors.textPrimary),
                  ),
                ),
                Text(
                  item.formatSize(),
                  style: TextStyle(fontSize: 11, color: colors.textMuted),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGlobalSearchResults(
    BuildContext context,
    ExplorerProvider explorer,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    if (explorer.isGlobalSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: colors.primary, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text(
              'Searching across storage for "${explorer.searchQuery}"...',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    final results = explorer.globalSearchResults;

    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined, size: 48, color: colors.textMuted.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text(
              'No items found matching "${explorer.searchQuery}"',
              style: TextStyle(fontSize: 13.5, color: colors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: results.length + 1,
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Search Results (${results.length})',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
                TextButton(
                  onPressed: () => explorer.clearSearch(),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(40, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('Close search', style: TextStyle(fontSize: 11, color: colors.primary)),
                ),
              ],
            ),
          );
        }

        final item = results[i - 1];
        return InkWell(
          onTap: () {
            if (item.isDirectory) {
              explorer.clearSearch();
              explorer.navigateTo(item.path);
            } else {
              settings.addRecentFile(item.path);
              MediaLauncher.openItem(context, item);
            }
          },
          onLongPress: () => FluentContextMenu.show(context, item),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.borderSubtle, width: 1),
            ),
            child: Row(
              children: [
                FluentFileIcon(item: item, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FluentMarqueeText(
                        item.name,
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: colors.textPrimary),
                      ),
                      Text(
                        item.path,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 10.5, color: colors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  item.formatSize(),
                  style: TextStyle(fontSize: 11, color: colors.textSecondary),
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Go to folder',
                  icon: Icon(Icons.folder_open, size: 16, color: colors.primary),
                  onPressed: () {
                    explorer.clearSearch();
                    final targetDir = item.isDirectory ? item.path : p.dirname(item.path);
                    explorer.navigateTo(targetDir);
                    if (!item.isDirectory) {
                      explorer.toggleSelection(item.path);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _QuickFolder {
  final String title;
  final String path;
  final IconData icon;
  final Color color;
  const _QuickFolder({required this.title, required this.path, required this.icon, required this.color});
}
