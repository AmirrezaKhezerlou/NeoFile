import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/permission_service.dart';
import '../theme/fluent_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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

          // Section 3: Storage & Cache
          _buildSectionTitle('Storage & Cache', Icons.storage_outlined, colors),
          const SizedBox(height: 8),
          _buildCard(
            colors,
            children: [
              ListTile(
                leading: Icon(Icons.cleaning_services_outlined, color: colors.primary),
                title: Text('Clear temporary files', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                subtitle: Text('Wipe internal cache and thumbnail buffers', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                trailing: FilledButton.tonal(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Thumbnail cache cleared')),
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(60, 32),
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 11.5)),
                ),
              ),
            ],
          ),

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
}
