import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/cache_cleaner_service.dart';
import '../services/permission_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/fluent_cache_cleanup_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final CacheCleanerService _cacheCleaner = CacheCleanerService.instance;

  @override
  void initState() {
    super.initState();
    _cacheCleaner.addListener(_onCacheChanged);
    _cacheCleaner.analyzeCache();
  }

  void _onCacheChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _cacheCleaner.removeListener(_onCacheChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        backgroundColor: colors.cardSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Explorer Settings',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: colors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: colors.border, height: 1),
        ),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Section 1: Appearance & Theme
          _buildSectionTitle('Personalization', Icons.palette_outlined, colors),
          const SizedBox(height: 8),
          _buildCard(
            colors,
            children: [
              _buildThemeSelector(context, settings, colors),
            ],
          ),

          const SizedBox(height: 18),

          // Section 2: View & Layout (Folder Options)
          _buildSectionTitle('View & Layout', Icons.view_quilt_outlined, colors),
          const SizedBox(height: 8),
          _buildCard(
            colors,
            children: [
              _buildViewModeSelector(context, settings, colors),
              _buildDivider(colors),
              _buildGridColumnsSelector(context, settings, colors),
              _buildDivider(colors),
              _buildFontSizeSelector(context, settings, colors),
              _buildDivider(colors),
              _buildListItemDensitySelector(context, settings, colors),
              _buildDivider(colors),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text('Single-line list view', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                subtitle: Text('Display name, date, and size inline on a single row (default: off)', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                value: settings.singleLineListItems,
                activeColor: colors.primary,
                onChanged: (_) => settings.toggleSingleLineListItems(),
              ),
              _buildDivider(colors),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text('Show Date modified in list', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                subtitle: Text('Show modification date and time on list rows', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                value: settings.showListDateModified,
                activeColor: colors.primary,
                onChanged: (_) => settings.toggleShowListDateModified(),
              ),
              _buildDivider(colors),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text('Show file size in list', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                subtitle: Text('Show byte size for files on list rows', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                value: settings.showListFileSize,
                activeColor: colors.primary,
                onChanged: (_) => settings.toggleShowListFileSize(),
              ),
              _buildDivider(colors),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text('Show hidden files and folders', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                subtitle: Text('Display .dotfiles and hidden system nodes', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                value: settings.showHiddenFiles,
                activeColor: colors.primary,
                onChanged: (_) => settings.toggleShowHiddenFiles(),
              ),
              _buildDivider(colors),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text('Show file name extensions', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                subtitle: Text('e.g. .pdf, .docx, .apk', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                value: settings.showFileExtensions,
                activeColor: colors.primary,
                onChanged: (_) => settings.toggleShowFileExtensions(),
              ),
              _buildDivider(colors),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text('Show item check boxes', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                subtitle: Text('Enables touch multi-selection on list rows', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                value: settings.showCheckBoxes,
                activeColor: colors.primary,
                onChanged: (_) => settings.toggleShowCheckBoxes(),
              ),
              _buildDivider(colors),
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text('Compact spacing', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                subtitle: Text('Reduce vertical row padding for dense viewing', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                value: settings.compactView,
                activeColor: colors.primary,
                onChanged: (_) => settings.toggleCompactView(),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Section 3: Media & Playback
          _buildSectionTitle('Media & Playback', Icons.play_circle_outline, colors),
          const SizedBox(height: 8),
          _buildCard(
            colors,
            children: [
              SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                title: Text('Use built-in Windows media players', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                subtitle: Text('Open Photos, Videos and Music inside NeoFile with Windows controls', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                value: settings.useInternalMediaViewer,
                activeColor: colors.primary,
                onChanged: (val) => settings.setUseInternalMediaViewer(val),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Section 3: Storage & Cache
          _buildSectionTitle('Storage & Cache', Icons.storage_outlined, colors),
          const SizedBox(height: 8),
          _buildStorageCacheCard(context, colors),

          const SizedBox(height: 18),

          // Section 4: Privacy & Permissions
          _buildSectionTitle('Permissions & Security', Icons.security_outlined, colors),
          const SizedBox(height: 8),
          _buildCard(
            colors,
            children: [
              ListTile(
                leading: Icon(Icons.verified_user_outlined, color: colors.success),
                title: Text('All Files Access (MANAGE_EXTERNAL_STORAGE)', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                subtitle: Text('Required to manage folders outside sandbox', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                trailing: TextButton(
                  onPressed: () => PermissionService.openSystemSettings(),
                  child: const Text('Open Settings', style: TextStyle(fontSize: 11.5)),
                ),
              ),
              _buildDivider(colors),
              ListTile(
                leading: Icon(Icons.install_mobile_outlined, color: colors.primary),
                title: Text('Install Unknown Apps (REQUEST_INSTALL_PACKAGES)', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                subtitle: Text('Required to open and install APK packages', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                trailing: TextButton(
                  onPressed: () => PermissionService.requestInstallPackagesPermission(),
                  child: const Text('Configure', style: TextStyle(fontSize: 11.5)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          // Section 5: About
          _buildSectionTitle('About NeoFile', Icons.info_outline, colors),
          const SizedBox(height: 8),
          _buildCard(
            colors,
            children: [
              ListTile(
                leading: Icon(Icons.laptop, color: colors.primary),
                title: Text('NeoFile for Android', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                subtitle: Text('WinUI 3 Fluent Design Architecture • 100% Offline Local', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                trailing: Text('v1.1.1', style: TextStyle(fontSize: 12, color: colors.textMuted)),
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, FluentColors colors) {
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

  Widget _buildCard(FluentColors colors, {required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.borderSubtle, width: 1),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildDivider(FluentColors colors) {
    return Divider(height: 1, color: colors.borderSubtle);
  }

  Widget _buildStorageCacheCard(BuildContext context, FluentColors colors) {
    final analysis = _cacheCleaner.lastAnalysis;
    final isAnalyzing = _cacheCleaner.isAnalyzing;
    final isCleaning = _cacheCleaner.isCleaning;

    final hasData = analysis != null && analysis.totalBytes > 0;
    final formattedSize = analysis?.formattedTotal ?? (isAnalyzing ? 'Scanning...' : '0 B');
    final fileCount = analysis?.totalFiles ?? 0;

    return _buildCard(
      colors,
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.cleaning_services_outlined, color: colors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Temporary Files & Cache',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: hasData ? colors.primary.withOpacity(0.15) : colors.container,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: hasData ? colors.primary.withOpacity(0.3) : colors.borderSubtle,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                isAnalyzing ? 'Scanning...' : (hasData ? '$formattedSize ($fileCount files)' : 'Clean (0 B)'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: hasData ? colors.primary : colors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Analyze and wipe internal image caches, thumbnail buffers, and residual temporary downloads.',
                          style: TextStyle(fontSize: 11.5, color: colors.textSecondary, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (analysis != null && analysis.categories.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: analysis.categories.map((cat) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.container,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colors.borderSubtle, width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(cat.icon, size: 12, color: colors.textSecondary),
                          const SizedBox(width: 5),
                          Text(
                            '${cat.title}: ${cat.formatBytes()}',
                            style: TextStyle(fontSize: 10.5, color: colors.textSecondary),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 12),
              _buildDivider(colors),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: isAnalyzing || isCleaning ? null : () => _cacheCleaner.analyzeCache(),
                    icon: isAnalyzing
                        ? SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(strokeWidth: 2, color: colors.textSecondary),
                          )
                        : Icon(Icons.refresh, size: 14, color: colors.textSecondary),
                    label: Text(
                      isAnalyzing ? 'Scanning' : 'Re-scan',
                      style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.borderSubtle),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: isCleaning
                        ? null
                        : () async {
                            await FluentCacheCleanupSheet.show(context);
                            _cacheCleaner.analyzeCache();
                          },
                    icon: const Icon(Icons.auto_delete_outlined, size: 14),
                    label: Text(
                      hasData ? 'Clean Storage ($formattedSize)' : 'Clean Storage',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSelector(
    BuildContext context,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'App Theme Mode',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colors.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildThemeOption(
                context,
                title: 'System',
                icon: Icons.brightness_auto,
                isSelected: settings.themePreference == AppThemePreference.system,
                onTap: () => settings.setThemePreference(AppThemePreference.system),
                colors: colors,
              ),
              const SizedBox(width: 6),
              _buildThemeOption(
                context,
                title: 'Light',
                icon: Icons.light_mode,
                isSelected: settings.themePreference == AppThemePreference.light,
                onTap: () => settings.setThemePreference(AppThemePreference.light),
                colors: colors,
              ),
              const SizedBox(width: 6),
              _buildThemeOption(
                context,
                title: 'Dark',
                icon: Icons.dark_mode,
                isSelected: settings.themePreference == AppThemePreference.dark,
                onTap: () => settings.setThemePreference(AppThemePreference.dark),
                colors: colors,
              ),
              const SizedBox(width: 6),
              _buildThemeOption(
                context,
                title: 'AMOLED',
                icon: Icons.brightness_2,
                isSelected: settings.themePreference == AppThemePreference.amoled,
                onTap: () => settings.setThemePreference(AppThemePreference.amoled),
                colors: colors,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context, {
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required FluentColors colors,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withOpacity(0.12) : colors.container,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? colors.primary : colors.borderSubtle,
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSelected ? colors.primary : colors.textSecondary),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? colors.primary : colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeSelector(
    BuildContext context,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Default Folder View Mode', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
          DropdownButton<ViewMode>(
            value: settings.defaultViewMode,
            underline: const SizedBox.shrink(),
            dropdownColor: colors.cardSurface,
            onChanged: (mode) {
              if (mode != null) settings.setDefaultViewMode(mode);
            },
            items: [
              DropdownMenuItem(
                value: ViewMode.details,
                child: Text('Details', style: TextStyle(fontSize: 12.5, color: colors.textPrimary)),
              ),
              DropdownMenuItem(
                value: ViewMode.tiles,
                child: Text('Tiles', style: TextStyle(fontSize: 12.5, color: colors.textPrimary)),
              ),
              DropdownMenuItem(
                value: ViewMode.grid,
                child: Text('Large icons', style: TextStyle(fontSize: 12.5, color: colors.textPrimary)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridColumnsSelector(
    BuildContext context,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Grid Columns Count', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
          DropdownButton<int>(
            value: settings.gridColumns,
            underline: const SizedBox.shrink(),
            dropdownColor: colors.cardSurface,
            onChanged: (val) {
              if (val != null) settings.setGridColumns(val);
            },
            items: const [
              DropdownMenuItem(
                value: 2,
                child: Text('2 columns', style: TextStyle(fontSize: 12.5)),
              ),
              DropdownMenuItem(
                value: 3,
                child: Text('3 columns', style: TextStyle(fontSize: 12.5)),
              ),
              DropdownMenuItem(
                value: 4,
                child: Text('4 columns', style: TextStyle(fontSize: 12.5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFontSizeSelector(
    BuildContext context,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Font Size Scale', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
              Text(
                '${(settings.fontSizeScale * 100).toInt()}%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colors.primary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPillOption(
                label: '85%',
                isSelected: (settings.fontSizeScale - 0.85).abs() < 0.04,
                onTap: () => settings.setFontSizeScale(0.85),
                colors: colors,
              ),
              const SizedBox(width: 6),
              _buildPillOption(
                label: '100%',
                isSelected: (settings.fontSizeScale - 1.0).abs() < 0.04,
                onTap: () => settings.setFontSizeScale(1.0),
                colors: colors,
              ),
              const SizedBox(width: 6),
              _buildPillOption(
                label: '115%',
                isSelected: (settings.fontSizeScale - 1.15).abs() < 0.04,
                onTap: () => settings.setFontSizeScale(1.15),
                colors: colors,
              ),
              const SizedBox(width: 6),
              _buildPillOption(
                label: '130%',
                isSelected: (settings.fontSizeScale - 1.30).abs() < 0.04,
                onTap: () => settings.setFontSizeScale(1.30),
                colors: colors,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListItemDensitySelector(
    BuildContext context,
    SettingsProvider settings,
    FluentColors colors,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('List Item Density / Size', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildPillOption(
                label: 'Compact',
                isSelected: settings.listItemDensity == 0,
                onTap: () => settings.setListItemDensity(0),
                colors: colors,
              ),
              const SizedBox(width: 6),
              _buildPillOption(
                label: 'Standard',
                isSelected: settings.listItemDensity == 1,
                onTap: () => settings.setListItemDensity(1),
                colors: colors,
              ),
              const SizedBox(width: 6),
              _buildPillOption(
                label: 'Comfortable',
                isSelected: settings.listItemDensity == 2,
                onTap: () => settings.setListItemDensity(2),
                colors: colors,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillOption({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required FluentColors colors,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? colors.primary.withOpacity(0.12) : colors.container,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isSelected ? colors.primary : colors.borderSubtle,
              width: 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? colors.primary : colors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
