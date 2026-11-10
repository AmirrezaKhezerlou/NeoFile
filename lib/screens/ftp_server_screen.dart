import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:qr_flutter/qr_flutter.dart';
import '../services/file_service.dart';
import '../services/ftp_client_service.dart';
import '../services/ftp_server_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/fluent_folder_picker.dart';

class FtpServerScreen extends StatefulWidget {
  const FtpServerScreen({super.key});

  @override
  State<FtpServerScreen> createState() => _FtpServerScreenState();
}

class _FtpServerScreenState extends State<FtpServerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FtpServerService _ftpServer = FtpServerService.instance;
  final FtpClientService _ftpClient = FtpClientService.instance;

  // Server Controllers
  late TextEditingController _serverPortController;
  late TextEditingController _serverUserController;
  late TextEditingController _serverPassController;
  String? _serverPortMessage;
  bool? _isServerPortFree;

  // Client Controllers
  late TextEditingController _clientHostController;
  late TextEditingController _clientPortController;
  late TextEditingController _clientUserController;
  late TextEditingController _clientPassController;
  bool _clientAnonymous = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    _serverPortController = TextEditingController(text: _ftpServer.config.port.toString());
    _serverUserController = TextEditingController(text: _ftpServer.config.username);
    _serverPassController = TextEditingController(text: _ftpServer.config.password);

    _clientHostController = TextEditingController(text: '192.168.1.');
    _clientPortController = TextEditingController(text: '2121');
    _clientUserController = TextEditingController(text: 'neofile');
    _clientPassController = TextEditingController(text: '123456');

    _ftpServer.addListener(_onServiceUpdate);
    _ftpClient.addListener(_onServiceUpdate);

    _initServerPortAndNetwork();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  Future<void> _initServerPortAndNetwork() async {
    await _ftpServer.updateNetworkStatus();

    final available = await FtpServerService.isPortAvailable(_ftpServer.config.port);
    if (!available) {
      final freePort = await FtpServerService.findAvailablePort(_ftpServer.config.port);
      if (mounted) {
        setState(() {
          _ftpServer.config.port = freePort;
          _serverPortController.text = freePort.toString();
          _isServerPortFree = true;
          _serverPortMessage = 'Auto-assigned free port $freePort';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isServerPortFree = true;
          _serverPortMessage = 'Port ${_ftpServer.config.port} is available';
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _ftpServer.removeListener(_onServiceUpdate);
    _ftpClient.removeListener(_onServiceUpdate);
    _serverPortController.dispose();
    _serverUserController.dispose();
    _serverPassController.dispose();
    _clientHostController.dispose();
    _clientPortController.dispose();
    _clientUserController.dispose();
    _clientPassController.dispose();
    super.dispose();
  }

  Future<void> _onServerPortChanged(String val) async {
    final port = int.tryParse(val.trim());
    if (port == null || port < 1024 || port > 65535) {
      setState(() {
        _isServerPortFree = false;
        _serverPortMessage = 'Port must be between 1024 and 65535';
      });
      return;
    }

    final available = await FtpServerService.isPortAvailable(port);
    if (mounted) {
      setState(() {
        _isServerPortFree = available;
        _serverPortMessage = available ? 'Port $port is available' : 'Port $port is in use!';
        if (available) {
          _ftpServer.config.port = port;
        }
      });
    }
  }

  Future<void> _pickServerRootDirectory() async {
    final picked = await FluentFolderPicker.show(context, initialPath: _ftpServer.config.rootDirectory);
    if (picked != null && mounted) {
      setState(() {
        _ftpServer.config.rootDirectory = picked;
      });
    }
  }

  void _toggleServer() async {
    if (_ftpServer.isRunning) {
      await _ftpServer.stop();
      return;
    }

    // Check network status before starting
    final net = await _ftpServer.updateNetworkStatus();
    if (!mounted) return;
    if (net.isWarning) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24),
              SizedBox(width: 8),
              Text('Network Warning', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(
            net.type == FtpNetworkType.none
                ? 'No Wi-Fi or Hotspot network detected (Airplane mode / Disconnected). Other devices cannot connect to this phone.\n\nDo you want to start anyway?'
                : 'Mobile Data is active. FTP file sharing requires a local Wi-Fi network or personal Hotspot so nearby devices can connect.\n\nDo you want to start anyway?',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Start Anyway'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final port = int.tryParse(_serverPortController.text.trim()) ?? 2121;
    _ftpServer.config.port = port;
    _ftpServer.config.username = _serverUserController.text.trim();
    _ftpServer.config.password = _serverPassController.text.trim();
    await _ftpServer.start();
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = FluentColors.of(context);
    final isRunning = _ftpServer.isRunning;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: const Text('FTP Wireless Transfer', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        backgroundColor: colors.cardSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isRunning ? colors.success.withOpacity(0.15) : colors.container,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isRunning ? colors.success : colors.borderSubtle,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isRunning ? colors.success : colors.textMuted,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isRunning ? 'SERVER ACTIVE' : 'SERVER STOPPED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isRunning ? colors.success : colors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: colors.primary,
          unselectedLabelColor: colors.textSecondary,
          indicatorColor: colors.primary,
          tabs: const [
            Tab(icon: Icon(Icons.wifi_tethering, size: 18), text: 'FTP Server (Host)'),
            Tab(icon: Icon(Icons.cloud_download_outlined, size: 18), text: 'FTP Client (Connect)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildServerTab(context, colors),
          _buildClientTab(context, colors),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: FTP SERVER
  // =========================================================================
  Widget _buildServerTab(BuildContext context, FluentColors colors) {
    final isRunning = _ftpServer.isRunning;
    final netInfo = _ftpServer.networkInfo;

    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Network Status & Warning Banner
        _buildNetworkStatusBanner(context, colors, netInfo),

        const SizedBox(height: 16),

        // 2. Server Control Card
        Container(
          padding: const EdgeInsets.all(16),
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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.wifi_tethering, color: colors.primary, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Host Local FTP Server',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isRunning ? 'Running on ${_ftpServer.ftpUrl}' : 'Access this phone files from PC or other devices over Wi-Fi',
                          style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isRunning ? colors.error : colors.primary,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: (!isRunning && _isServerPortFree != true) ? null : _toggleServer,
                icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
                label: Text(isRunning ? 'Stop FTP Server' : 'Start FTP Server'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Connection Address & QR Code
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.cardSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Connection Address', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8),
                    ],
                  ),
                  child: QrImageView(
                    data: _ftpServer.ftpUrl,
                    version: QrVersions.auto,
                    size: 150.0,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.container,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _ftpServer.ftpUrl,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: colors.textPrimary),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      color: colors.primary,
                      tooltip: 'Copy FTP Address',
                      onPressed: () => _copyToClipboard(_ftpServer.ftpUrl, 'FTP URL copied!'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 4. Server Configuration Options
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.cardSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Server Settings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
              const SizedBox(height: 14),

              // Port Field with real-time automatic verification
              TextField(
                controller: _serverPortController,
                enabled: !isRunning,
                keyboardType: TextInputType.number,
                onChanged: _onServerPortChanged,
                decoration: InputDecoration(
                  labelText: 'FTP Port',
                  isDense: true,
                  border: const OutlineInputBorder(),
                  suffixIcon: _isServerPortFree == true
                      ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                      : (_isServerPortFree == false
                          ? const Icon(Icons.cancel, color: Colors.red, size: 20)
                          : null),
                  helperText: _serverPortMessage,
                  helperStyle: TextStyle(
                    color: _isServerPortFree == true ? colors.success : (_isServerPortFree == false ? colors.error : null),
                    fontSize: 11,
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Anonymous Access
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Anonymous Login', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                subtitle: Text('Allow connection without username & password', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                value: _ftpServer.config.anonymous,
                activeColor: colors.primary,
                onChanged: isRunning
                    ? null
                    : (val) {
                        setState(() => _ftpServer.config.anonymous = val);
                      },
              ),

              if (!_ftpServer.config.anonymous) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _serverUserController,
                  enabled: !isRunning,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _serverPassController,
                  enabled: !isRunning,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const Divider(height: 24),

              // Root Directory with Folder Picker Button (No manual typing!)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colors.container,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_shared_outlined, color: Color(0xFFFFB900), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shared Root Directory',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _ftpServer.config.rootDirectory,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: colors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: isRunning ? null : _pickServerRootDirectory,
                      icon: const Icon(Icons.folder_open, size: 16),
                      label: const Text('Browse', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Allow Write
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Allow Write & Upload', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                subtitle: Text('Allow uploading, modifying, and deleting files via FTP', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                value: _ftpServer.config.allowWrite,
                activeColor: colors.primary,
                onChanged: (val) {
                  setState(() => _ftpServer.config.allowWrite = val);
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 5. Activity Logs
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.cardSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: colors.borderSubtle),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Active Sessions: ${_ftpServer.activeConnections}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                  Text('Activity Logs', style: TextStyle(fontSize: 11, color: colors.primary)),
                ],
              ),
              const SizedBox(height: 10),
              if (_ftpServer.logs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No FTP activity yet', style: TextStyle(fontSize: 12, color: colors.textMuted)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _ftpServer.logs.length > 8 ? 8 : _ftpServer.logs.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: colors.borderSubtle),
                  itemBuilder: (ctx, i) {
                    final item = _ftpServer.logs[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(
                            item.isError ? Icons.error_outline : Icons.check_circle_outline,
                            size: 14,
                            color: item.isError ? colors.error : colors.success,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: colors.textPrimary),
                            ),
                          ),
                          Text(
                            '${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}',
                            style: TextStyle(fontSize: 10, color: colors.textMuted),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildNetworkStatusBanner(BuildContext context, FluentColors colors, FtpNetworkInfo netInfo) {
    final isWarn = netInfo.isWarning;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isWarn ? colors.warning.withOpacity(0.12) : colors.success.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isWarn ? colors.warning : colors.success),
      ),
      child: Row(
        children: [
          Icon(
            isWarn ? Icons.warning_amber_rounded : Icons.wifi_rounded,
            color: isWarn ? colors.warning : colors.success,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWarn ? 'Network Notice' : 'Local Network Connected',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: isWarn ? colors.warning : colors.success,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  netInfo.userFriendlyMessage,
                  style: TextStyle(fontSize: 11, color: colors.textPrimary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: 'Refresh Network Status',
            onPressed: () async {
              await _ftpServer.updateNetworkStatus();
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: FTP CLIENT (Connect, Scan & Browse Remote FTP)
  // =========================================================================
  Widget _buildClientTab(BuildContext context, FluentColors colors) {
    if (_ftpClient.isConnected) {
      return _buildClientExplorerView(context, colors);
    }
    return _buildClientConnectView(context, colors);
  }

  Widget _buildClientConnectView(BuildContext context, FluentColors colors) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      children: [
        // Connection Form Card
        Container(
          padding: const EdgeInsets.all(16),
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
                  Icon(Icons.cloud_sync_outlined, color: colors.primary, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    'Connect to Remote FTP Server',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Host Field with Scan Button
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _clientHostController,
                      decoration: const InputDecoration(
                        labelText: 'FTP Server Host / IP',
                        hintText: '192.168.1.100',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                    onPressed: _ftpClient.isScanning ? null : _scanLocalNetwork,
                    icon: _ftpClient.isScanning
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.radar, size: 16),
                    label: Text(_ftpClient.isScanning ? 'Scanning...' : 'Scan LAN'),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Port Field
              TextField(
                controller: _clientPortController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Port (default 21 or 2121)',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 12),

              // Anonymous Switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Anonymous Login', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                value: _clientAnonymous,
                activeColor: colors.primary,
                onChanged: (val) => setState(() => _clientAnonymous = val),
              ),

              if (!_clientAnonymous) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _clientUserController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _clientPassController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  minimumSize: const Size.fromHeight(44),
                ),
                onPressed: _connectToFtpServer,
                icon: const Icon(Icons.login),
                label: const Text('Connect & Browse Files'),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Discovered Local FTP Servers Card
        if (_ftpClient.discoveredServers.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.cardSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.primary.withOpacity(0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.devices, size: 18, color: colors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Discovered Local FTP Servers (${_ftpClient.discoveredServers.length})',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ..._ftpClient.discoveredServers.map((s) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: colors.container,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: colors.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.dns, size: 20, color: Color(0xFFFFB900)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${s.host}:${s.port}', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: colors.textPrimary)),
                              Text(s.banner, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
                            ],
                          ),
                        ),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(visualDensity: VisualDensity.compact),
                          onPressed: () {
                            _clientHostController.text = s.host;
                            _clientPortController.text = s.port.toString();
                            _connectToFtpServer();
                          },
                          child: const Text('Connect'),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _scanLocalNetwork() async {
    final list = await _ftpClient.scanLocalNetworkForFtp();
    if (list.isEmpty && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active FTP servers found on local subnet.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _connectToFtpServer() async {
    final host = _clientHostController.text.trim();
    final port = int.tryParse(_clientPortController.text.trim()) ?? 21;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Connecting to $host:$port...'), duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating),
    );

    final ok = await _ftpClient.connect(
      host: host,
      port: port,
      isAnonymous: _clientAnonymous,
      username: _clientUserController.text.trim(),
      password: _clientPassController.text.trim(),
    );

    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection failed. Verify host, port and login credentials.'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  // Remote FTP Explorer View
  Widget _buildClientExplorerView(BuildContext context, FluentColors colors) {
    final files = _ftpClient.remoteFiles;

    return Column(
      children: [
        // Top Remote Host Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          color: colors.cardSurface,
          child: Row(
            children: [
              Icon(Icons.cloud_done, size: 18, color: colors.success),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Connected: ${_ftpClient.currentHost}:${_ftpClient.currentPort}',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: colors.textPrimary),
                ),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error.withOpacity(0.5)),
                ),
                onPressed: () => _ftpClient.disconnect(),
                icon: const Icon(Icons.power_settings_new, size: 14),
                label: const Text('Disconnect', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),

        // Transfer Progress Bar (if downloading or uploading)
        if (_ftpClient.isTransferring)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            color: colors.primary.withOpacity(0.12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_ftpClient.transferStatus, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textPrimary)),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(value: _ftpClient.transferProgress > 0 ? _ftpClient.transferProgress : null, minHeight: 3),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Breadcrumb Address Bar & Action Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: colors.container,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 18),
                tooltip: 'Up to parent folder',
                onPressed: _ftpClient.currentRemoteDir != '/' ? () => _ftpClient.navigateUp() : null,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _ftpClient.currentRemoteDir,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontFamily: 'monospace', fontWeight: FontWeight.w500, color: colors.textPrimary),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.upload_file, size: 18),
                tooltip: 'Upload File to Remote FTP',
                onPressed: _showUploadDialog,
              ),
              IconButton(
                icon: const Icon(Icons.create_new_folder_outlined, size: 18),
                tooltip: 'New Remote Folder',
                onPressed: _showCreateFolderDialog,
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 18),
                tooltip: 'Refresh',
                onPressed: () => _ftpClient.refreshDirectory(),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: colors.borderSubtle),

        // Remote Files List
        Expanded(
          child: files.isEmpty
              ? Center(
                  child: Text('This remote folder is empty', style: TextStyle(fontSize: 13, color: colors.textMuted)),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  physics: const BouncingScrollPhysics(),
                  itemCount: files.length,
                  separatorBuilder: (_, _) => Divider(height: 1, indent: 48, color: colors.borderSubtle.withOpacity(0.5)),
                  itemBuilder: (ctx, i) {
                    final item = files[i];
                    return ListTile(
                      leading: Icon(
                        item.isDirectory ? Icons.folder : Icons.insert_drive_file_outlined,
                        color: item.isDirectory ? const Color(0xFFFFB900) : colors.primary,
                        size: 24,
                      ),
                      title: Text(item.name, style: TextStyle(fontSize: 13, color: colors.textPrimary)),
                      subtitle: Text(item.formatSize(), style: TextStyle(fontSize: 11, color: colors.textSecondary)),
                      trailing: item.isDirectory
                          ? const Icon(Icons.chevron_right, size: 18)
                          : IconButton(
                              icon: const Icon(Icons.download, size: 18),
                              tooltip: 'Download to phone',
                              onPressed: () => _downloadRemoteFile(item),
                            ),
                      onTap: () {
                        if (item.isDirectory) {
                          final newPath = _ftpClient.currentRemoteDir == '/'
                              ? '/${item.name}'
                              : '${_ftpClient.currentRemoteDir}/${item.name}';
                          _ftpClient.refreshDirectory(newPath);
                        } else {
                          _showRemoteFileOptions(item);
                        }
                      },
                      onLongPress: () => _confirmDeleteRemoteItem(item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _showRemoteFileOptions(FtpRemoteFile item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = FluentColors.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Container(
              decoration: BoxDecoration(
                color: colors.cardSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Download to Phone (Downloads folder)'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _downloadRemoteFile(item);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.delete_outline, color: colors.error),
                    title: Text('Delete from FTP Server', style: TextStyle(color: colors.error)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _confirmDeleteRemoteItem(item);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadRemoteFile(FtpRemoteFile item) async {
    final destFolder = p.join(FileService.internalStoragePath, 'Download');
    final success = await _ftpClient.downloadFile(item, destFolder);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Downloaded ${item.name} to Download folder' : 'Download failed'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showUploadDialog() async {
    // Pick folder on phone
    final pickedFolder = await FluentFolderPicker.show(context, initialPath: FileService.internalStoragePath);
    if (pickedFolder == null) return;

    // List files inside picked folder to select one to upload
    final dir = Directory(pickedFolder);
    final files = dir.listSync(followLinks: false).whereType<File>().toList();

    if (files.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No files found in selected folder to upload'), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final colors = FluentColors.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.70),
              child: Container(
                decoration: BoxDecoration(
                  color: colors.cardSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: colors.borderSubtle),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text('Select File to Upload', style: TextStyle(fontWeight: FontWeight.w600, color: colors.textPrimary)),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.separated(
                        itemCount: files.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (c, i) {
                          final f = files[i];
                          final name = p.basename(f.path);
                          return ListTile(
                            leading: Icon(Icons.insert_drive_file, color: colors.primary),
                            title: Text(name, style: TextStyle(fontSize: 12.5, color: colors.textPrimary)),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final ok = await _ftpClient.uploadFile(f);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(ok ? 'Uploaded $name' : 'Upload failed'), behavior: SnackBarBehavior.floating),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreateFolderDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Remote Folder', style: TextStyle(fontSize: 15)),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Folder Name', isDense: true, border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final name = textController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                await _ftpClient.createRemoteFolder(name);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteRemoteItem(FtpRemoteFile item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${item.name}?', style: const TextStyle(fontSize: 15)),
        content: Text('Are you sure you want to delete "${item.name}" from the FTP server?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _ftpClient.deleteRemoteItem(item);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
