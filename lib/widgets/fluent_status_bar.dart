import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/explorer_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/fluent_theme.dart';

class FluentStatusBar extends StatelessWidget {
  const FluentStatusBar({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final explorer = context.watch<ExplorerProvider>();

    final totalItems = explorer.currentItems.length;
    final selCount = explorer.selectionCount;
    final selBytes = explorer.selectedTotalBytes;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: colors.container,
        border: Border(
          top: BorderSide(color: colors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Items count & Selection
          Expanded(
            child: Row(
              children: [
                Text(
                  '$totalItems items',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: colors.textSecondary,
                  ),
                ),
                if (selCount > 0) ...[
                  Container(
                    width: 1,
                    height: 14,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    color: colors.border,
                  ),
                  Flexible(
                    child: Text(
                      '$selCount selected (${_formatBytes(selBytes)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Quick View Toggles
          _buildViewToggle(
            context,
            icon: Icons.view_list,
            tooltip: 'Details',
            isSelected: explorer.viewMode == ViewMode.details,
            onTap: () => explorer.setViewMode(ViewMode.details),
            colors: colors,
          ),
          const SizedBox(width: 2),
          _buildViewToggle(
            context,
            icon: Icons.grid_view,
            tooltip: 'Large icons',
            isSelected: explorer.viewMode == ViewMode.grid,
            onTap: () => explorer.setViewMode(ViewMode.grid),
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggle(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required bool isSelected,
    required VoidCallback onTap,
    required FluentColors colors,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(3),
        child: Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: isSelected ? Border.all(color: colors.primary.withOpacity(0.4), width: 1) : null,
          ),
          child: Icon(
            icon,
            size: 13,
            color: isSelected ? colors.primary : colors.textMuted,
          ),
        ),
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
