import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/explorer_provider.dart';
import '../services/file_service.dart';
import '../services/ftp_server_service.dart';
import '../services/mcp_server_service.dart';
import '../theme/fluent_theme.dart';

class WidgetsGalleryScreen extends StatelessWidget {
  const WidgetsGalleryScreen({super.key});

  Future<void> _pinWidget(BuildContext context, String type, String name) async {
    final success = await FileService.pinWidget(type);
    if (!context.mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Adding "$name" widget to your Home Screen...'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'To add the "$name" widget, long-press your Home Screen and select Widgets > NeoFile.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final explorer = context.watch<ExplorerProvider>();
    final mcpService = McpServerService.instance;
    final ftpService = FtpServerService.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([mcpService, ftpService]),
      builder: (context, _) {
        // Storage calculation
        int totalBytes = 0;
        int freeBytes = 0;
        if (explorer.storageVolumes.isNotEmpty) {
          totalBytes = explorer.storageVolumes.first.totalBytes;
          freeBytes = explorer.storageVolumes.first.freeBytes;
        }
        final int usedBytes = totalBytes > freeBytes ? totalBytes - freeBytes : 0;
        final int usedPercent = totalBytes > 0 ? ((usedBytes * 100) / totalBytes).round() : 0;
        final double totalGb = totalBytes / (1024 * 1024 * 1024);
        final double usedGb = usedBytes / (1024 * 1024 * 1024);
        final double freeGb = freeBytes / (1024 * 1024 * 1024);

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
              'Home Screen Widgets',
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            children: [
              // Introductory banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.container,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.widgets_outlined, size: 22, color: colors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Android App Widgets',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Place live Windows-styled widgets on your device home screen for real-time storage insights, MCP status, and FTP server control.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Widget 1: Storage Sense
              _buildWidgetCard(
                context,
                colors: colors,
                title: 'Storage Sense Widget',
                sizeBadge: '3 × 2',
                description:
                    'Shows real-time internal storage usage, used vs. total GB, and a color progress bar. Tap to open Storage Analyzer.',
                preview: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF202020),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF3A3A3C)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: colors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Icon(Icons.storage_rounded, size: 14, color: colors.primary),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Storage Sense',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Text(
                            '$usedPercent%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalBytes > 0 ? (usedBytes / totalBytes) : 0.0,
                          backgroundColor: const Color(0xFF333336),
                          valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Used: ${usedGb.toStringAsFixed(1)} / ${totalGb.toStringAsFixed(1)} GB',
                            style: const TextStyle(fontSize: 11, color: Color(0xFFCCCCCC)),
                          ),
                          Text(
                            'Free: ${freeGb.toStringAsFixed(1)} GB',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF888888)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to open Storage Analyzer →',
                        style: TextStyle(fontSize: 10.5, color: colors.primary),
                      ),
                    ],
                  ),
                ),
                onAddPressed: () => _pinWidget(context, 'storage', 'Storage Sense'),
              ),

              const SizedBox(height: 20),

              // Widget 2: Local MCP Server
              _buildWidgetCard(
                context,
                colors: colors,
                title: 'Local MCP Server Widget',
                sizeBadge: '3 × 2',
                description:
                    'Monitors your background Model Context Protocol server status, IP port, and SSE listeners. Tap to jump to MCP panel.',
                preview: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF202020),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF3A3A3C)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Icon(Icons.hub_outlined, size: 14, color: Colors.purpleAccent),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Local MCP Server',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (mcpService.isRunning
                                      ? (mcpService.isPaused ? Colors.orange : const Color(0xFF107C41))
                                      : const Color(0xFF555555))
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              mcpService.isRunning
                                  ? (mcpService.isPaused ? 'PAUSED' : 'RUNNING')
                                  : 'STOPPED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: mcpService.isRunning
                                    ? (mcpService.isPaused
                                        ? Colors.orange
                                        : const Color(0xFF52C41A))
                                    : const Color(0xFF888888),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        mcpService.isRunning ? mcpService.serverUrl : 'Server offline',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFFCCCCCC)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        mcpService.isRunning
                            ? '${mcpService.requestCount} requests handled'
                            : 'AI Model Bridge & SSE',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF888888)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap to open MCP Control Panel →',
                        style: TextStyle(fontSize: 10.5, color: colors.primary),
                      ),
                    ],
                  ),
                ),
                onAddPressed: () => _pinWidget(context, 'mcp', 'Local MCP Server'),
              ),

              const SizedBox(height: 20),

              // Widget 3: FTP Share Server
              _buildWidgetCard(
                context,
                colors: colors,
                title: 'FTP Share Server Widget',
                sizeBadge: '3 × 2',
                description:
                    'Displays current Wi-Fi/Hotspot FTP server URL and active connected client sessions. Tap to access FTP server controls.',
                preview: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF202020),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF3A3A3C)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Icon(Icons.wifi_tethering, size: 14, color: Colors.tealAccent),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'FTP Share Server',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: (ftpService.isRunning
                                      ? const Color(0xFF107C41)
                                      : const Color(0xFF555555))
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ftpService.isRunning ? 'RUNNING' : 'STOPPED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: ftpService.isRunning
                                    ? const Color(0xFF52C41A)
                                    : const Color(0xFF888888),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        ftpService.isRunning ? ftpService.ftpUrl : 'Server offline',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFFCCCCCC)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        ftpService.isRunning
                            ? (ftpService.activeConnections > 0
                                ? '${ftpService.activeConnections} active clients'
                                : 'Listening for incoming connections')
                            : 'Wi-Fi / Hotspot File Sharing',
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF888888)),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Tap to open FTP Server →',
                        style: TextStyle(fontSize: 10.5, color: colors.primary),
                      ),
                    ],
                  ),
                ),
                onAddPressed: () => _pinWidget(context, 'ftp', 'FTP Share Server'),
              ),

              const SizedBox(height: 24),

              // Manual Guide Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: colors.cardSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                  children: [
                    Icon(Icons.touch_app_outlined, size: 16, color: colors.textSecondary),
                    const SizedBox(width: 8),
                    Text(
                      'Manual Home Screen Placement',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '1. Long-press any empty space on your Android home screen.\n'
                  '2. Tap "Widgets" from the bottom drawer.\n'
                  '3. Scroll down and locate "NeoFile".\n'
                  '4. Touch and drag your desired widget to your home screen.',
                  style: TextStyle(fontSize: 11, color: colors.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
      },
    );
  }

  Widget _buildWidgetCard(
    BuildContext context, {
    required FluentColors colors,
    required String title,
    required String sizeBadge,
    required String description,
    required Widget preview,
    required VoidCallback onAddPressed,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.container,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: colors.borderSubtle),
                      ),
                      child: Text(
                        sizeBadge,
                        style: TextStyle(fontSize: 10, color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(fontSize: 11, color: colors.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),

          // Live Preview Area
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            color: colors.container.withOpacity(0.6),
            child: preview,
          ),

          // Action bar
          Padding(
            padding: const EdgeInsets.all(10),
            child: Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onAddPressed,
                icon: const Icon(Icons.add_to_home_screen, size: 15),
                label: const Text('Add to Home Screen', style: TextStyle(fontSize: 11.5)),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: const Size(0, 32),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
