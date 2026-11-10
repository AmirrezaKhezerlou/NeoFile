import 'package:flutter/material.dart';
import '../../theme/fluent_theme.dart';

class WindowsMediaHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onClose;
  final VoidCallback? onMinimize;
  final VoidCallback? onToggleFullscreen;
  final bool isFullscreen;
  final VoidCallback? onOpenWith;
  final List<Widget> extraActions;

  const WindowsMediaHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.onClose,
    this.onMinimize,
    this.onToggleFullscreen,
    this.isFullscreen = false,
    this.onOpenWith,
    this.extraActions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: colors.container.withOpacity(0.95),
        border: Border(
          bottom: BorderSide(color: colors.borderSubtle, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          ...extraActions,
          if (onOpenWith != null) ...[
            Tooltip(
              message: 'Open with another app...',
              child: InkWell(
                onTap: onOpenWith,
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.open_with, size: 14, color: colors.textSecondary),
                      const SizedBox(width: 4),
                      Text('Open with', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          if (onMinimize != null && !isFullscreen)
            _buildWindowButton(
              icon: Icons.remove,
              tooltip: 'Minimize',
              onTap: onMinimize!,
              colors: colors,
            ),
          if (onToggleFullscreen != null)
            _buildWindowButton(
              icon: isFullscreen ? Icons.fullscreen_exit : Icons.crop_square,
              tooltip: isFullscreen ? 'Restore' : 'Maximize',
              onTap: onToggleFullscreen!,
              colors: colors,
            ),
          _buildWindowButton(
            icon: Icons.close,
            tooltip: 'Close (Esc)',
            isClose: true,
            onTap: onClose,
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildWindowButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    required FluentColors colors,
    bool isClose = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        hoverColor: isClose ? colors.error : colors.container,
        child: Container(
          width: 32,
          height: 28,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: isClose ? 14 : 13,
            color: colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
