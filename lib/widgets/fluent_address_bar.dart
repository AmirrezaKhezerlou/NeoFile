import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/explorer_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/fluent_theme.dart';

class FluentAddressBar extends StatefulWidget {
  const FluentAddressBar({super.key});

  @override
  State<FluentAddressBar> createState() => _FluentAddressBarState();
}

class _FluentAddressBarState extends State<FluentAddressBar> {
  bool _isEditingPath = false;
  bool _isSearching = false;
  late final TextEditingController _pathController;
  late final TextEditingController _searchController;
  late final FocusNode _pathFocus;
  late final FocusNode _searchFocus;

  @override
  void initState() {
    super.initState();
    _pathController = TextEditingController();
    _searchController = TextEditingController();
    _pathFocus = FocusNode();
    _searchFocus = FocusNode();
  }

  @override
  void dispose() {
    _pathController.dispose();
    _searchController.dispose();
    _pathFocus.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final explorer = context.watch<ExplorerProvider>();
    final settings = context.watch<SettingsProvider>();

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        border: Border(
          bottom: BorderSide(color: colors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Navigation Buttons
          _buildNavBtn(
            context,
            icon: Icons.arrow_back,
            enabled: explorer.activeTab.canGoBack,
            tooltip: 'Back (Alt+Left)',
            onTap: () => explorer.goBack(),
            colors: colors,
          ),
          _buildNavBtn(
            context,
            icon: Icons.arrow_forward,
            enabled: explorer.activeTab.canGoForward,
            tooltip: 'Forward (Alt+Right)',
            onTap: () => explorer.goForward(),
            colors: colors,
          ),
          _buildNavBtn(
            context,
            icon: Icons.arrow_upward,
            enabled: !explorer.isHome,
            tooltip: 'Up to parent folder (Alt+Up)',
            onTap: () => explorer.goUp(),
            colors: colors,
          ),
          _buildNavBtn(
            context,
            icon: Icons.refresh,
            enabled: true,
            tooltip: 'Refresh (F5)',
            onTap: () => explorer.refresh(showHidden: settings.showHiddenFiles),
            colors: colors,
          ),
          const SizedBox(width: 4),

          // Breadcrumb Address Bar or Manual Path Input
          Expanded(
            child: _isSearching
                ? _buildSearchField(explorer, settings, colors)
                : _isEditingPath
                    ? _buildManualPathInput(explorer, colors)
                    : _buildBreadcrumbs(explorer, colors),
          ),

          const SizedBox(width: 4),

          // Search Toggle Button
          _buildNavBtn(
            context,
            icon: _isSearching ? Icons.close : Icons.search,
            enabled: true,
            tooltip: _isSearching ? 'Close search' : 'Search folder',
            onTap: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  explorer.clearSearch();
                } else {
                  _isEditingPath = false;
                  _searchFocus.requestFocus();
                }
              });
            },
            colors: colors,
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumbs(ExplorerProvider explorer, FluentColors colors) {
    final path = explorer.currentPath;

    // Check if path is inside internal storage
    const storageRoot = '/storage/emulated/0';
    final isUnderStorage = path.startsWith(storageRoot);

    List<_BreadcrumbSegment> displaySegments = [];
    bool showDirectHomeIcon = false;
    bool showEllipsis = false;

    if (path.isEmpty) {
      displaySegments = [_BreadcrumbSegment(title: 'This PC', path: '')];
    } else if (path == storageRoot) {
      displaySegments = [
        _BreadcrumbSegment(title: 'This PC', path: ''),
        _BreadcrumbSegment(title: 'Internal Storage', path: storageRoot),
      ];
    } else if (isUnderStorage) {
      final sub = path.substring(storageRoot.length + 1);
      final parts = sub.split('/').where((p) => p.isNotEmpty).toList();

      if (parts.length > 2) {
        showDirectHomeIcon = true;
        showEllipsis = true;
        // Take the last 2 parts
        final secondToLastParts = parts.sublist(0, parts.length - 1);
        final secondToLastPath = '$storageRoot/${secondToLastParts.join('/')}';
        displaySegments = [
          _BreadcrumbSegment(title: parts[parts.length - 2], path: secondToLastPath),
          _BreadcrumbSegment(title: parts.last, path: path),
        ];
      } else {
        showDirectHomeIcon = true;
        String accum = storageRoot;
        for (final part in parts) {
          accum = '$accum/$part';
          displaySegments.add(_BreadcrumbSegment(title: part, path: accum));
        }
      }
    } else {
      // Other mount point (e.g. SD Card or root)
      final parts = path.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.length > 2) {
        showDirectHomeIcon = true;
        showEllipsis = true;
        final secondToLast = '/${parts.sublist(0, parts.length - 1).join('/')}';
        displaySegments = [
          _BreadcrumbSegment(title: parts[parts.length - 2], path: secondToLast),
          _BreadcrumbSegment(title: parts.last, path: path),
        ];
      } else {
        String accum = '';
        for (final part in parts) {
          accum = '$accum/$part';
          displaySegments.add(_BreadcrumbSegment(title: part, path: accum));
        }
      }
    }

    return InkWell(
      onTap: () {
        setState(() {
          _isEditingPath = true;
          _pathController.text = explorer.currentPath;
          _pathFocus.requestFocus();
        });
      },
      borderRadius: BorderRadius.circular(4),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: colors.canvas,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.borderSubtle, width: 1),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showDirectHomeIcon) ...[
                Tooltip(
                  message: 'Internal Storage',
                  child: InkWell(
                    onTap: () => explorer.navigateTo(storageRoot),
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Icon(Icons.home_outlined, size: 16, color: colors.primary),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.chevron_right, size: 13, color: colors.textMuted),
                ),
              ] else if (path.isEmpty) ...[
                Icon(Icons.laptop, size: 14, color: colors.textSecondary),
                const SizedBox(width: 4),
              ],
              if (showEllipsis) ...[
                InkWell(
                  onTap: () => explorer.goUp(),
                  borderRadius: BorderRadius.circular(3),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      '...',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: colors.primary),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(Icons.chevron_right, size: 13, color: colors.textMuted),
                ),
              ],
              for (int i = 0; i < displaySegments.length; i++) ...[
                InkWell(
                  onTap: () => explorer.navigateTo(displaySegments[i].path),
                  borderRadius: BorderRadius.circular(3),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      displaySegments[i].title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: i == displaySegments.length - 1 ? FontWeight.w600 : FontWeight.w400,
                        color: i == displaySegments.length - 1 ? colors.textPrimary : colors.primary,
                      ),
                    ),
                  ),
                ),
                if (i < displaySegments.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(Icons.chevron_right, size: 13, color: colors.textMuted),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualPathInput(ExplorerProvider explorer, FluentColors colors) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.primary, width: 1.5),
      ),
      child: TextField(
        controller: _pathController,
        focusNode: _pathFocus,
        style: TextStyle(fontSize: 12.5, color: colors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: InputBorder.none,
          suffixIcon: IconButton(
            icon: const Icon(Icons.check, size: 16),
            onPressed: () {
              setState(() => _isEditingPath = false);
              explorer.navigateTo(_pathController.text.trim());
            },
          ),
        ),
        onSubmitted: (val) {
          setState(() => _isEditingPath = false);
          explorer.navigateTo(val.trim());
        },
      ),
    );
  }

  Widget _buildSearchField(
    ExplorerProvider explorer,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: colors.canvas,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colors.primary, width: 1.5),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocus,
        style: TextStyle(fontSize: 12.5, color: colors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: explorer.isHome ? 'Search all drives & storage...' : 'Search in folder...',
          hintStyle: TextStyle(fontSize: 12, color: colors.textMuted),
          prefixIcon: Icon(Icons.search, size: 16, color: colors.primary),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: InputBorder.none,
        ),
        onChanged: (val) => explorer.setSearchQuery(val.trim(), showHidden: settings.showHiddenFiles),
      ),
    );
  }

  Widget _buildNavBtn(
    BuildContext context, {
    required IconData icon,
    required bool enabled,
    required String tooltip,
    required VoidCallback onTap,
    required FluentColors colors,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 16,
            color: enabled ? colors.textPrimary : colors.textMuted.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}

class _BreadcrumbSegment {
  final String title;
  final String path;
  _BreadcrumbSegment({required this.title, required this.path});
}
