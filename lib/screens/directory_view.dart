import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/file_item.dart';
import '../providers/explorer_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/fluent_theme.dart';
import '../widgets/fluent_context_menu.dart';
import '../widgets/fluent_file_icons.dart';
import '../widgets/fluent_marquee_text.dart';

class DirectoryView extends StatelessWidget {
  const DirectoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final explorer = context.watch<ExplorerProvider>();
    final settings = context.watch<SettingsProvider>();

    if (explorer.isLoading) {
      return Center(
        child: CircularProgressIndicator(
          color: colors.primary,
          strokeWidth: 2.5,
        ),
      );
    }

    if (explorer.errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: colors.error),
              const SizedBox(height: 12),
              Text(
                'Folder Access Error',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: colors.textPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                explorer.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.textSecondary),
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () => explorer.refresh(showHidden: settings.showHiddenFiles),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final items = explorer.currentItems;

    return Column(
      children: [
        // Animated Clipboard Active & Notification Banner
        AnimatedSize(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
          child: explorer.bannerVisible
              ? AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: child,
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(explorer.clipboardNotification ??
                        (explorer.clipboard != null
                            ? explorer.clipboard!.paths.join()
                            : 'banner')),
                    child: _buildClipboardBanner(context, explorer, colors),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Main Viewport
        Expanded(
          child: items.isEmpty
              ? _buildEmptyState(colors)
              : RefreshIndicator(
                  onRefresh: () async {
                    explorer.refresh(showHidden: settings.showHiddenFiles);
                  },
                  color: colors.primary,
                  backgroundColor: colors.cardSurface,
                  child: explorer.viewMode == ViewMode.details
                      ? _buildDetailsView(context, items, explorer, settings, colors)
                      : (explorer.viewMode == ViewMode.tiles
                          ? _buildTilesView(context, items, explorer, settings, colors)
                          : _buildGridView(context, items, explorer, settings, colors)),
                ),
        ),
      ],
    );
  }

  Widget _buildClipboardBanner(
    BuildContext context,
    ExplorerProvider explorer,
    FluentColors colors,
  ) {
    final isClipboardActive = explorer.clipboard != null;
    final isCut = explorer.clipboard?.isCut ?? false;
    final count = explorer.clipboard?.count ?? 0;

    final text = isClipboardActive
        ? '${isCut ? "Cut" : "Copied"} $count item(s). Ready to paste.'
        : explorer.clipboardNotification!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.08),
        border: Border(bottom: BorderSide(color: colors.primary.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Icon(
            isClipboardActive
                ? (isCut ? Icons.content_cut : Icons.content_copy)
                : Icons.check_circle_outline,
            size: 16,
            color: colors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: colors.textPrimary),
            ),
          ),
          if (isClipboardActive) ...[
            TextButton(
              onPressed: () => explorer.cancelClipboard(),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Cancel', style: TextStyle(fontSize: 11.5, color: colors.error)),
            ),
            const SizedBox(width: 4),
          ],
          InkWell(
            onTap: () {
              if (isClipboardActive) {
                explorer.cancelClipboard();
              } else {
                explorer.dismissClipboardNotification();
              }
            },
            child: Icon(Icons.close, size: 15, color: colors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(FluentColors colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.folder_open_outlined, size: 54, color: colors.textMuted.withOpacity(0.5)),
          const SizedBox(height: 10),
          Text(
            'This folder is empty',
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsView(
    BuildContext context,
    List<FileItem> items,
    ExplorerProvider explorer,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    final dateFormat = DateFormat('MMM d, yyyy');

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.symmetric(vertical: settings.compactView ? 2 : 4),
      itemCount: items.length + 1, // +1 for table header
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return _buildTableHeader(explorer, settings, colors);
        }

        final item = items[i - 1];
        final isSelected = explorer.selectedPaths.contains(item.path);

        return InkWell(
          onTap: () {
            if (explorer.hasSelection) {
              explorer.toggleSelection(item.path);
            } else {
              if (item.isDirectory) {
                explorer.navigateTo(item.path);
              } else {
                settings.addRecentFile(item.path);
                explorer.openFile(item.path);
              }
            }
          },
          onLongPress: () {
            FluentContextMenu.show(context, item);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: settings.compactView ? 38 : 46,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: isSelected ? colors.selectionFill : Colors.transparent,
              border: Border(
                left: isSelected
                    ? BorderSide(color: colors.selectionStroke, width: 3.5)
                    : BorderSide.none,
                bottom: BorderSide(color: colors.borderSubtle.withOpacity(0.5), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                // Checkbox (if enabled in settings)
                if (settings.showCheckBoxes)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (val) => explorer.toggleSelection(item.path),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),

                // File/Folder Icon
                FluentFileIcon(item: item, size: settings.compactView ? 22 : 26),
                const SizedBox(width: 10),

                // Name Column
                Expanded(
                  flex: 5,
                  child: FluentMarqueeText(
                    item.name,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: colors.textPrimary,
                    ),
                  ),
                ),

                // Date Modified Column
                Expanded(
                  flex: 3,
                  child: Text(
                    dateFormat.format(item.modified),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: colors.textSecondary),
                  ),
                ),

                // Size Column
                SizedBox(
                  width: 65,
                  child: Text(
                    item.formatSize(),
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: colors.textSecondary,
                    ),
                  ),
                ),

                // 3-dot overflow
                InkWell(
                  onTap: () => FluentContextMenu.show(context, item),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.more_vert, size: 15, color: colors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableHeader(
    ExplorerProvider explorer,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: colors.container,
        border: Border(bottom: BorderSide(color: colors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          if (settings.showCheckBoxes)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: SizedBox(
                width: 22,
                height: 22,
                child: Checkbox(
                  value: explorer.selectionCount == explorer.currentItems.length &&
                      explorer.currentItems.isNotEmpty,
                  tristate: explorer.hasSelection &&
                      explorer.selectionCount < explorer.currentItems.length,
                  onChanged: (val) {
                    if (val == true) {
                      explorer.selectAll();
                    } else {
                      explorer.clearSelection();
                    }
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          const SizedBox(width: 36), // Align with icon + spacing
          Expanded(
            flex: 5,
            child: Text(
              'Name',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              'Date modified',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
          ),
          SizedBox(
            width: 75,
            child: Text(
              'Size',
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
          ),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildGridView(
    BuildContext context,
    List<FileItem> items,
    ExplorerProvider explorer,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800
            ? (settings.gridColumns + 1)
            : settings.gridColumns;

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 0.90,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            final isSelected = explorer.selectedPaths.contains(item.path);

            return Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InkWell(
                      onTap: () {
                        if (explorer.hasSelection) {
                          explorer.toggleSelection(item.path);
                        } else {
                          if (item.isDirectory) {
                            explorer.navigateTo(item.path);
                          } else {
                            settings.addRecentFile(item.path);
                            explorer.openFile(item.path);
                          }
                        }
                      },
                      onLongPress: () => explorer.toggleSelection(item.path),
                      borderRadius: BorderRadius.circular(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.selectionFill : colors.cardSurface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? colors.selectionStroke : colors.borderSubtle,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 10),
                            FluentFileIcon(item: item, size: 44),
                            const SizedBox(height: 8),
                            FluentMarqueeText(
                              item.name,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.formatSize(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, color: colors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Top-Left Checkbox / Selection Toggle
                  if (settings.showCheckBoxes || explorer.hasSelection || isSelected)
                    Positioned(
                      top: 4,
                      left: 4,
                      child: InkWell(
                        onTap: () => explorer.toggleSelection(item.path),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                            size: 18,
                            color: isSelected ? colors.primary : colors.textMuted.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ),

                  // Top-Right 3-Dots Vertical Menu Icon (more_vert)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: () => FluentContextMenu.show(context, item),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.more_vert,
                          size: 18,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTilesView(
    BuildContext context,
    List<FileItem> items,
    ExplorerProvider explorer,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 700 ? 3 : 2;

        return GridView.builder(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(10),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.7,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            final isSelected = explorer.selectedPaths.contains(item.path);

            return Material(
              color: Colors.transparent,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InkWell(
                      onTap: () {
                        if (explorer.hasSelection) {
                          explorer.toggleSelection(item.path);
                        } else {
                          if (item.isDirectory) {
                            explorer.navigateTo(item.path);
                          } else {
                            settings.addRecentFile(item.path);
                            explorer.openFile(item.path);
                          }
                        }
                      },
                      onLongPress: () => explorer.toggleSelection(item.path),
                      borderRadius: BorderRadius.circular(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? colors.selectionFill : colors.cardSurface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isSelected ? colors.selectionStroke : colors.borderSubtle,
                            width: isSelected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            if (settings.showCheckBoxes || explorer.hasSelection || isSelected)
                              Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: InkWell(
                                  onTap: () => explorer.toggleSelection(item.path),
                                  child: Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    size: 16,
                                    color: isSelected ? colors.primary : colors.textMuted.withOpacity(0.6),
                                  ),
                                ),
                              ),
                            FluentFileIcon(item: item, size: 30),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.formatSize(),
                                    style: TextStyle(fontSize: 10, color: colors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 4,
                    child: Center(
                      child: InkWell(
                        onTap: () => FluentContextMenu.show(context, item),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(
                            Icons.more_vert,
                            size: 18,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
