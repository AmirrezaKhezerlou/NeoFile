import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/explorer_provider.dart';
import '../providers/settings_provider.dart';
import '../services/file_service.dart';
import '../services/permission_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/fluent_address_bar.dart';
import '../widgets/fluent_command_ribbon.dart';
import '../widgets/fluent_status_bar.dart';
import '../widgets/fluent_tab_bar.dart';
import '../widgets/fluent_transfer_bar.dart';
import 'directory_view.dart';
import 'home_view.dart';
import 'permission_onboarding_screen.dart';
import 'settings_screen.dart';

class MainExplorerScreen extends StatefulWidget {
  const MainExplorerScreen({super.key});

  @override
  State<MainExplorerScreen> createState() => _MainExplorerScreenState();
}

class _MainExplorerScreenState extends State<MainExplorerScreen> with WidgetsBindingObserver {
  bool _checkedPermission = false;
  bool _hasPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();

    const MethodChannel('com.neofile.app/storage').setMethodCallHandler((call) async {
      if (call.method == 'showTransferSheet') {
        if (mounted) {
          TransferDetailsSheet.show(context);
        }
      } else if (call.method == 'cancelTransfer') {
        FileService.onCancelTransferRequested?.call();
        if (mounted) {
          context.read<ExplorerProvider>().cancelTransfer();
        }
      } else if (call.method == 'requestFrame') {
        WidgetsBinding.instance.scheduleWarmUpFrame();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.scheduleWarmUpFrame();
      _checkPermission();
    }
  }

  Future<void> _checkPermission() async {
    final granted = await PermissionService.isStoragePermissionGranted();
    if (mounted) {
      final wasGranted = _hasPermission;
      setState(() {
        _hasPermission = granted;
        _checkedPermission = true;
      });
      if (granted) {
        // Ensure notification permission is requested if on Android 13+
        PermissionService.requestNotificationPermission();

        final settings = context.read<SettingsProvider>();
        final explorer = context.read<ExplorerProvider>();
        explorer.syncSettings(settings);
        if (!wasGranted) {
          explorer.loadCurrentPath(showHidden: settings.showHiddenFiles);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checkedPermission) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasPermission) {
      return PermissionOnboardingScreen(
        onGranted: () {
          setState(() => _hasPermission = true);
          final settings = context.read<SettingsProvider>();
          context.read<ExplorerProvider>().loadCurrentPath(showHidden: settings.showHiddenFiles);
        },
      );
    }

    final colors = FluentColors.of(context);
    final explorer = context.watch<ExplorerProvider>();

    return PopScope(
      canPop: !explorer.hasSelection && !explorer.activeTab.canGoBack,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (explorer.hasSelection) {
          explorer.clearSelection();
        } else if (explorer.activeTab.canGoBack) {
          explorer.goBack();
        }
      },
      child: Scaffold(
        backgroundColor: colors.canvas,
        floatingActionButton: (explorer.clipboard != null && !explorer.isHome)
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'cancel_clipboard_fab',
                    onPressed: () => explorer.cancelClipboard(),
                    backgroundColor: colors.cardSurface,
                    foregroundColor: colors.error,
                    tooltip: 'Cancel Paste',
                    elevation: 3,
                    child: const Icon(Icons.close, size: 18),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.extended(
                    heroTag: 'paste_fab',
                    onPressed: () {
                      final settings = context.read<SettingsProvider>();
                      explorer.paste(showHidden: settings.showHiddenFiles);
                    },
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    icon: const Icon(Icons.content_paste, size: 18),
                    label: Text(
                      'Paste Here (${explorer.clipboard!.count})',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              )
            : null,
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Windows 11 Tabs
              FluentTabBar(
                onOpenSettings: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
                  );
                },
              ),

              // 2. Navigation & Breadcrumb Address Bar
              const FluentAddressBar(),

              // 3. Fluent Command Ribbon
              const FluentCommandRibbon(),

              // 4. Fluent Transfer Progress Bar (when copying/moving/archiving)
              const FluentTransferBar(),

              // 5. Main Viewport (Home / This PC or Directory)
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: explorer.isHome
                      ? const HomeView(key: ValueKey('home_view'))
                      : const DirectoryView(key: ValueKey('directory_view')),
                ),
              ),

              // 5. Windows Status Dock
              const FluentStatusBar(),
            ],
          ),
        ),
      ),
    );
  }
}
