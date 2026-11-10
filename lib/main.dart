import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/explorer_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/main_explorer_screen.dart';
import 'services/ftp_server_service.dart';
import 'services/mcp_server_service.dart';
import 'theme/fluent_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {}

  final settingsProvider = SettingsProvider(prefs);
  await settingsProvider.ensureLoaded();

  // Set immersive edge-to-edge system navigation style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  runApp(NeoFileApp(settingsProvider: settingsProvider, prefs: prefs));
}

class NeoFileApp extends StatelessWidget {
  final SettingsProvider? settingsProvider;
  final SharedPreferences? prefs;
  const NeoFileApp({super.key, this.settingsProvider, this.prefs});

  @override
  Widget build(BuildContext context) {
    final effectiveSettings = settingsProvider ?? SettingsProvider(prefs);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: effectiveSettings),
        ChangeNotifierProvider.value(value: McpServerService.instance),
        ChangeNotifierProvider.value(value: FtpServerService.instance),
        ChangeNotifierProxyProvider<SettingsProvider, ExplorerProvider>(
          create: (ctx) {
            final explorer = ExplorerProvider();
            final settings = ctx.read<SettingsProvider>();
            explorer.syncSettings(settings);
            return explorer;
          },
          update: (ctx, settings, explorer) {
            explorer ??= ExplorerProvider();
            explorer.syncSettings(settings);
            return explorer;
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'NeoFile',
            debugShowCheckedModeBanner: false,
            theme: FluentTheme.lightTheme(),
            darkTheme: settings.isAmoled
                ? FluentTheme.amoledTheme()
                : FluentTheme.darkTheme(),
            themeMode: settings.themeMode,
            home: const MainExplorerScreen(),
          );
        },
      ),
    );
  }
}

