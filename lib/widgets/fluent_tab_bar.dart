import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/explorer_provider.dart';
import '../theme/fluent_theme.dart';

class FluentTabBar extends StatelessWidget {
  final VoidCallback onOpenSettings;

  const FluentTabBar({
    super.key,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final explorer = context.watch<ExplorerProvider>();

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: colors.container,
        border: Border(
          bottom: BorderSide(color: colors.border, width: 1),
        ),
      ),
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Scrollable Tabs
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: 44,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    for (int i = 0; i < explorer.tabs.length; i++) ...[
                      _buildTabItem(context, i, explorer, colors),
                      const SizedBox(width: 4),
                    ],
                    // Add Tab Button
                    _buildIconButton(
                      context,
                      icon: Icons.add,
                      tooltip: 'New Tab (Ctrl+T)',
                      onTap: () => explorer.addTab(''),
                      colors: colors,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // More / Settings Button
          _buildIconButton(
            context,
            icon: Icons.settings_outlined,
            tooltip: 'Settings',
            onTap: onOpenSettings,
            colors: colors,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildTabItem(
    BuildContext context,
    int index,
    ExplorerProvider explorer,
    FluentColors colors,
  ) {
    final tab = explorer.tabs[index];
    final isActive = index == explorer.activeTabIndex;

    return InkWell(
      onTap: () => explorer.selectTab(index),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        constraints: const BoxConstraints(minWidth: 100, maxWidth: 160),
        height: 36,
        decoration: BoxDecoration(
          color: isActive ? colors.cardSurface : Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          border: isActive ? Border.all(color: colors.border, width: 1) : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isActive)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  ),
                ),
              ),
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      tab.currentPath.isEmpty ? Icons.home : Icons.folder,
                      size: 15,
                      color: isActive ? colors.primary : colors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        tab.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive ? colors.textPrimary : colors.textSecondary,
                        ),
                      ),
                    ),
                    if (explorer.tabs.length > 1) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () => explorer.closeTab(index),
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.all(2),
                          child: Icon(
                            Icons.close,
                            size: 13,
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required FluentColors colors,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 17,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
