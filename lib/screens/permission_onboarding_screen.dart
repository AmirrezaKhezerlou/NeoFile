import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import '../theme/fluent_theme.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  final VoidCallback onGranted;

  const PermissionOnboardingScreen({super.key, required this.onGranted});

  @override
  State<PermissionOnboardingScreen> createState() => _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends State<PermissionOnboardingScreen> {
  bool _isLoading = false;

  Future<void> _request() async {
    setState(() => _isLoading = true);
    final granted = await PermissionService.requestAllInitialPermissions();
    setState(() => _isLoading = false);
    if (granted) {
      widget.onGranted();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Storage access is required. Please enable it in Settings.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => PermissionService.openSystemSettings(),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);

    return Scaffold(
      backgroundColor: colors.canvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder_copy, size: 20, color: colors.primary),
                      const SizedBox(width: 8),
                      Text(
                        'NeoFile',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  TextButton(
                    onPressed: widget.onGranted,
                    child: Text('Skip', style: TextStyle(color: colors.textSecondary)),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // Visual Hero Graphic
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.primary.withOpacity(0.3), width: 2),
                ),
                child: Icon(Icons.sd_storage, size: 48, color: colors.primary),
              ),

              const SizedBox(height: 24),

              Text(
                'Full Storage Access Required',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'To browse, copy, cut, and manage files across internal storage and SD cards just like Windows File Explorer, grant file access permissions.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 32),

              // Feature cards
              _buildFeatureRow(
                Icons.admin_panel_settings_outlined,
                'All Files Access (Android 11+)',
                'Required to manage folders and documents outside sandbox boundaries.',
                colors,
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                Icons.notifications_active_outlined,
                'Background Transfers & Notifications',
                'Live progress for downloads, zip compression, and file operations.',
                colors,
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                Icons.sync_alt,
                'Direct Local Storage I/O',
                'Fast hardware-level file operations without background telemetry.',
                colors,
              ),
              const SizedBox(height: 10),
              _buildFeatureRow(
                Icons.lock_outline,
                '100% Offline & Private',
                'Direct device storage access. Your data never leaves your device.',
                colors,
              ),

              const Spacer(flex: 2),

              // Grant Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _isLoading ? null : _request,
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Grant Permission & Continue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward, size: 16),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureRow(
    IconData icon,
    String title,
    String subtitle,
    FluentColors colors,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.borderSubtle, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: colors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
