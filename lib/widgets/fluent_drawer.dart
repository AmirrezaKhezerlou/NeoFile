import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../providers/explorer_provider.dart';
import '../providers/settings_provider.dart';
import '../screens/ftp_server_screen.dart';
import '../screens/mcp_server_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/storage_analyzer_screen.dart';
import '../screens/widgets_gallery_screen.dart';
import '../services/file_service.dart';
import '../services/ftp_server_service.dart';
import '../services/mcp_server_service.dart';
import '../theme/fluent_theme.dart';
import 'fluent_folder_picker.dart';

class FluentNavigationDrawer extends StatefulWidget {
  const FluentNavigationDrawer({super.key});

  @override
  State<FluentNavigationDrawer> createState() => _FluentNavigationDrawerState();
}

class _FluentNavigationDrawerState extends State<FluentNavigationDrawer> {
  String _appVersion = '1.1.1';

  @override
  void initState() {
    super.initState();
    _fetchAppVersion();
  }

  Future<void> _fetchAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted && info.version.isNotEmpty) {
        setState(() {
          _appVersion = info.version;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final explorer = context.watch<ExplorerProvider>();
    final settings = context.watch<SettingsProvider>();
    final mcpService = McpServerService.instance;
    final ftpService = FtpServerService.instance;

    final isMcpRunning = mcpService.isRunning || mcpService.isPaused;
    final isFtpRunning = ftpService.isRunning;
    final isCurrentFolderPinned = !explorer.isHome &&
        explorer.currentPath.isNotEmpty &&
        settings.pinnedPaths.contains(explorer.currentPath);

    return Drawer(
      backgroundColor: colors.cardSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        child: Column(
          children: [
            // 1. App Header with clean, professional slogan
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: colors.container,
                border: Border(bottom: BorderSide(color: colors.borderSubtle, width: 1)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colors.primary.withOpacity(0.3)),
                    ),
                    child: Icon(Icons.folder_copy_outlined, color: colors.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'NeoFile',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Fast, Private & Powerful',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // 2. Navigation Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                physics: const BouncingScrollPhysics(),
                children: [
                  // File Explorer / Home
                  _buildNavItem(
                    context,
                    icon: Icons.computer_outlined,
                    title: 'This PC / Home',
                    isSelected: explorer.isHome,
                    onTap: () {
                      Navigator.pop(context);
                      explorer.navigateTo('');
                    },
                    colors: colors,
                  ),

                  const SizedBox(height: 4),

                  // Storage Analyzer
                  _buildNavItem(
                    context,
                    icon: Icons.pie_chart_outline,
                    title: 'Storage Analyzer',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StorageAnalyzerScreen()),
                      );
                    },
                    colors: colors,
                  ),

                  const SizedBox(height: 4),

                  // Local MCP Server
                  _buildNavItem(
                    context,
                    icon: Icons.smart_toy_outlined,
                    title: 'Local MCP Server',
                    badge: isMcpRunning
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ON',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: colors.success),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const McpServerScreen()),
                      );
                    },
                    colors: colors,
                  ),

                  const SizedBox(height: 4),

                  // Local FTP Server
                  _buildNavItem(
                    context,
                    icon: Icons.wifi_tethering,
                    title: 'Local FTP Server',
                    badge: isFtpRunning
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: colors.success.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'ON',
                              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: colors.success),
                            ),
                          )
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FtpServerScreen()),
                      );
                    },
                    colors: colors,
                  ),

                  const SizedBox(height: 12),

                  // QUICK ACCESS Header with Pin Actions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    child: Row(
                      children: [
                        Text(
                          'QUICK ACCESS',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: colors.textMuted,
                          ),
                        ),
                        const Spacer(),
                        if (!explorer.isHome && explorer.currentPath.isNotEmpty)
                          IconButton(
                            icon: Icon(
                              isCurrentFolderPinned ? Icons.push_pin : Icons.push_pin_outlined,
                              size: 15,
                              color: isCurrentFolderPinned ? colors.primary : colors.textSecondary,
                            ),
                            tooltip: isCurrentFolderPinned ? 'Unpin current folder' : 'Pin current folder',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                            onPressed: () {
                              settings.togglePinPath(explorer.currentPath);
                            },
                          ),
                        IconButton(
                          icon: Icon(Icons.add, size: 16, color: colors.textSecondary),
                          tooltip: 'Pin a folder to Quick access',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: () async {
                            final chosen = await FluentFolderPicker.show(
                              context,
                              initialPath: explorer.isHome ? '/storage/emulated/0' : explorer.currentPath,
                            );
                            if (chosen != null && !settings.pinnedPaths.contains(chosen)) {
                              settings.togglePinPath(chosen);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Pinned Folders List
                  if (settings.pinnedPaths.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final chosen = await FluentFolderPicker.show(
                            context,
                            initialPath: explorer.isHome ? '/storage/emulated/0' : explorer.currentPath,
                          );
                          if (chosen != null && !settings.pinnedPaths.contains(chosen)) {
                            settings.togglePinPath(chosen);
                          }
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Pin a folder', style: TextStyle(fontSize: 11.5)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: colors.borderSubtle),
                          foregroundColor: colors.textSecondary,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    )
                  else
                    ...settings.pinnedPaths.map((p) {
                      final name = p.split('/').where((s) => s.isNotEmpty).lastOrNull ?? p;
                      final isCurrent = explorer.currentPath == p;

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isCurrent ? colors.primary.withOpacity(0.08) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  explorer.navigateTo(p);
                                },
                                borderRadius: BorderRadius.circular(6),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.folder_special_outlined,
                                        size: 17,
                                        color: isCurrent ? colors.primary : colors.textSecondary,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                                            color: isCurrent ? colors.primary : colors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, size: 14, color: colors.textMuted),
                              tooltip: 'Unpin folder',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              onPressed: () => settings.togglePinPath(p),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 12),
                  _buildSectionHeader('APPLICATION', colors),
                  const SizedBox(height: 6),

                  // Widgets Gallery
                  _buildNavItem(
                    context,
                    icon: Icons.widgets_outlined,
                    title: 'Home Screen Widgets',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WidgetsGalleryScreen()),
                      );
                    },
                    colors: colors,
                  ),

                  // Settings
                  _buildNavItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsScreen()),
                      );
                    },
                    colors: colors,
                  ),

                  // GitHub Repository (Open Source)
                  _buildNavItem(
                    context,
                    icon: Icons.code_rounded,
                    title: 'GitHub Repository',
                    badge: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: colors.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        'Open Source',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                          color: colors.primary,
                        ),
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      FileService.openUrl('https://github.com/AmirrezaKhezerlou/NeoFile');
                    },
                    colors: colors,
                  ),
                ],
              ),
            ),

            // 3. Automated App Version in Bottom Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: colors.borderSubtle, width: 1)),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 14, color: colors.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'NeoFile v$_appVersion • Fast & Private',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, color: colors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, FluentColors colors) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: colors.textMuted,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required FluentColors colors,
    bool isSelected = false,
    Widget? badge,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSelected
                ? Border(left: BorderSide(color: colors.primary, width: 3.5))
                : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? colors.primary : colors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? colors.primary : colors.textPrimary,
                  ),
                ),
              ),
              ?badge,
            ],
          ),
        ),
      ),
    );
  }
}
