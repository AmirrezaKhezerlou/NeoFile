import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/file_item.dart';
import '../providers/explorer_provider.dart';
import '../providers/settings_provider.dart';
import '../services/media_launcher.dart';
import '../theme/fluent_theme.dart';
import '../widgets/fluent_context_menu.dart';
import '../widgets/fluent_file_icons.dart';
import '../widgets/fluent_marquee_text.dart';

class DirectoryView extends StatefulWidget {
  const DirectoryView({super.key});

  @override
  State<DirectoryView> createState() => _DirectoryViewState();
}

class _DirectoryViewState extends State<DirectoryView> {
  final ScrollController _scrollController = ScrollController();
  String? _lastLoadedPath;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final explorer = context.read<ExplorerProvider>();
      explorer.saveCurrentScrollOffset(_scrollController.offset);
    }
  }

  void _restoreScrollOffset(ExplorerProvider explorer) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final savedOffset = explorer.getSavedScrollOffset();
      if (savedOffset > 0) {
        final maxExtent = _scrollController.position.maxScrollExtent;
        final target = savedOffset > maxExtent ? maxExtent : savedOffset;
        if ((_scrollController.offset - target).abs() > 1.0) {
          _scrollController.jumpTo(target);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

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

    // Restore scroll position only when navigating to a new directory path
    if (_lastLoadedPath != explorer.currentPath) {
      _lastLoadedPath = explorer.currentPath;
      _restoreScrollOffset(explorer);
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
              : NotificationListener<ScrollNotification>(
                  onNotification: (notification) {
                    if (notification.depth == 0 &&
                        (notification is ScrollUpdateNotification || notification is ScrollEndNotification)) {
                      explorer.saveCurrentScrollOffset(notification.metrics.pixels);
                    }
                    return false;
                  },
                  child: RefreshIndicator(
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

    final bool isSingleLine = settings.singleLineListItems;
    final int density = settings.listItemDensity;
    final double fontScale = settings.fontSizeScale;

    // Density-based dimensions
    final double rowHeight = isSingleLine
        ? (density == 0
            ? (settings.compactView ? 34.0 : 38.0)
            : density == 1
                ? (settings.compactView ? 40.0 : 46.0)
                : (settings.compactView ? 48.0 : 54.0))
        : (density == 0
            ? (settings.compactView ? 46.0 : 50.0)
            : density == 1
                ? (settings.compactView ? 52.0 : 58.0)
                : (settings.compactView ? 62.0 : 68.0));

    final double iconSize = density == 0 ? 22.0 : (density == 1 ? 28.0 : 34.0);

    return ListView.builder(
      key: PageStorageKey('details_${explorer.currentPath}'),
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: EdgeInsets.symmetric(vertical: settings.compactView ? 2 : 4),
      itemExtentBuilder: (index, _) => index == 0 ? 32.0 : rowHeight,
      itemCount: items.length + 1, // +1 for table header
      itemBuilder: (ctx, i) {
        if (i == 0) {
          return _buildTableHeader(explorer, settings, colors);
        }

        final item = items[i - 1];
        final isSelected = explorer.selectedPaths.contains(item.path);

        final subtitleParts = <String>[];
        if (settings.showListDateModified) {
          subtitleParts.add(dateFormat.format(item.modified));
        }
        if (settings.showListFileSize) {
          subtitleParts.add(item.formatSize());
        }
        final subtitleText = subtitleParts.join('  •  ');

        return InkWell(
          onTap: () {
            if (explorer.hasSelection) {
              explorer.toggleSelection(item.path);
            } else {
              if (item.isDirectory) {
                if (_scrollController.hasClients) {
                  explorer.saveCurrentScrollOffset(_scrollController.offset);
                }
                explorer.navigateTo(item.path);
              } else {
                settings.addRecentFile(item.path);
                MediaLauncher.openItem(context, item, siblings: items);
              }
            }
          },
          onLongPress: () {
            FluentContextMenu.show(context, item);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: rowHeight,
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
                FluentFileIcon(item: item, size: iconSize),
                const SizedBox(width: 10),

                // Layout: Single-Line vs Two-Line
                if (isSingleLine) ...[
                  // Name Column
                  Expanded(
                    flex: 5,
                    child: isSelected
                        ? FluentMarqueeText(
                            item.name,
                            style: TextStyle(
                              fontSize: 12.5 * fontScale,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          )
                        : Text(
                            item.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5 * fontScale,
                              fontWeight: FontWeight.w400,
                              color: colors.textPrimary,
                            ),
                          ),
                  ),

                  // Date Modified Column
                  if (settings.showListDateModified)
                    Expanded(
                      flex: 3,
                      child: Text(
                        dateFormat.format(item.modified),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.0 * fontScale,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),

                  // Size Column
                  if (settings.showListFileSize)
                    SizedBox(
                      width: 65,
                      child: Text(
                        item.formatSize(),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.0 * fontScale,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                ] else ...[
                  // Two-line layout (Name on top, Date & Size in subtitle)
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        isSelected
                            ? FluentMarqueeText(
                                item.name,
                                style: TextStyle(
                                  fontSize: 13.0 * fontScale,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              )
                            : Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.0 * fontScale,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textPrimary,
                                ),
                              ),
                        if (subtitleText.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitleText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.0 * fontScale,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

                const SizedBox(width: 4),

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
    final double headerFontSize = 11.0 * settings.fontSizeScale;
    final bool isSingleLine = settings.singleLineListItems;

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
            flex: isSingleLine ? 5 : 1,
            child: Text(
              'Name',
              style: TextStyle(fontSize: headerFontSize, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
          ),
          if (isSingleLine && settings.showListDateModified)
            Expanded(
              flex: 3,
              child: Text(
                'Date modified',
                style: TextStyle(fontSize: headerFontSize, fontWeight: FontWeight.w600, color: colors.textSecondary),
              ),
            ),
          if (isSingleLine && settings.showListFileSize)
            SizedBox(
              width: 75,
              child: Text(
                'Size',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: headerFontSize, fontWeight: FontWeight.w600, color: colors.textSecondary),
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
          key: PageStorageKey('grid_${explorer.currentPath}'),
          controller: _scrollController,
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
                            if (_scrollController.hasClients) {
                              explorer.saveCurrentScrollOffset(_scrollController.offset);
                            }
                            explorer.navigateTo(item.path);
                          } else {
                            settings.addRecentFile(item.path);
                            MediaLauncher.openItem(context, item, siblings: items);
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
                                fontSize: 11.5 * settings.fontSizeScale,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.formatSize(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10 * settings.fontSizeScale, color: colors.textMuted),
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
          key: PageStorageKey('tiles_${explorer.currentPath}'),
          controller: _scrollController,
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
                            if (_scrollController.hasClients) {
                              explorer.saveCurrentScrollOffset(_scrollController.offset);
                            }
                            explorer.navigateTo(item.path);
                          } else {
                            settings.addRecentFile(item.path);
                            MediaLauncher.openItem(context, item, siblings: items);
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
                                      fontSize: 12 * settings.fontSizeScale,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.formatSize(),
                                    style: TextStyle(fontSize: 10 * settings.fontSizeScale, color: colors.textMuted),
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
