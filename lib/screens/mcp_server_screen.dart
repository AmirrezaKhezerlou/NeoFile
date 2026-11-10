import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/mcp_server_service.dart';
import '../theme/fluent_theme.dart';
import '../widgets/fluent_folder_picker.dart';

class McpServerScreen extends StatefulWidget {
  const McpServerScreen({super.key});

  @override
  State<McpServerScreen> createState() => _McpServerScreenState();
}

class _McpServerScreenState extends State<McpServerScreen> {
  final McpServerService _mcpService = McpServerService.instance;
  late TextEditingController _portController;
  late TextEditingController _tokenController;
  String? _portCheckMessage;
  bool? _isPortFree;
  bool _showQrCode = false;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController(text: _mcpService.config.port.toString());
    _tokenController = TextEditingController(text: _mcpService.config.authToken);
    _mcpService.addListener(_onServiceUpdate);
    _autoCheckPortOnStart();
  }

  void _onServiceUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _mcpService.removeListener(_onServiceUpdate);
    _portController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _autoCheckPortOnStart() async {
    final available = await McpServerService.isPortAvailable(_mcpService.config.port);
    if (!available) {
      final freePort = await McpServerService.findAvailablePort(_mcpService.config.port);
      if (mounted) {
        setState(() {
          _mcpService.config.port = freePort;
          _portController.text = freePort.toString();
          _isPortFree = true;
          _portCheckMessage = 'Auto-assigned free port $freePort';
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isPortFree = true;
          _portCheckMessage = 'Port ${_mcpService.config.port} is available';
        });
      }
    }
  }

  Future<void> _onPortChanged(String val) async {
    final port = int.tryParse(val.trim());
    if (port == null || port < 1024 || port > 65535) {
      setState(() {
        _isPortFree = false;
        _portCheckMessage = 'Port must be between 1024 and 65535';
      });
      return;
    }

    final available = await McpServerService.isPortAvailable(port);
    if (mounted) {
      setState(() {
        _isPortFree = available;
        _portCheckMessage = available ? 'Port $port is available' : 'Port $port is in use or blocked!';
        if (available) {
          _mcpService.config.port = port;
        }
      });
    }
  }

  Future<void> _pickRootDirectory() async {
    final picked = await FluentFolderPicker.show(context, initialPath: _mcpService.config.rootDirectory);
    if (picked != null && mounted) {
      setState(() {
        _mcpService.config.rootDirectory = picked;
      });
    }
  }

  void _toggleServer() async {
    if (_mcpService.isRunning || _mcpService.isPaused) {
      await _mcpService.stop();
    } else {
      if (_isPortFree != true) {
        await _onPortChanged(_portController.text);
        if (_isPortFree != true) return;
      }
      final port = int.tryParse(_portController.text.trim()) ?? 8080;
      _mcpService.config.port = port;
      _mcpService.config.authToken = _tokenController.text.trim();
      await _mcpService.start();
    }
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
    final isRunning = _mcpService.isRunning;
    final isPaused = _mcpService.isPaused;
    final isActive = isRunning || isPaused;

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: const Text('Local MCP Server', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
              color: isRunning
                  ? colors.success.withOpacity(0.15)
                  : (isPaused ? colors.warning.withOpacity(0.15) : colors.container),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isRunning
                    ? colors.success
                    : (isPaused ? colors.warning : colors.borderSubtle),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isRunning ? colors.success : (isPaused ? colors.warning : colors.textMuted),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isRunning ? 'RUNNING' : (isPaused ? 'PAUSED' : 'STOPPED'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isRunning ? colors.success : (isPaused ? colors.warning : colors.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        children: [
          // 1. Status & Control Banner Card
          _buildControlCard(context, colors, isRunning, isPaused, isActive),

          const SizedBox(height: 16),

          // 2. Claude Desktop & Cursor JSON Configuration Card
          _buildClaudeConfigCard(context, colors),

          const SizedBox(height: 16),

          // 3. Direct Connection & Endpoints (with QR Code toggle)
          _buildConnectionEndpointsCard(context, colors),

          const SizedBox(height: 16),

          // 4. MCP Permissions & Configuration Options
          _buildOptionsCard(context, colors, isActive),

          const SizedBox(height: 16),

          // 5. Request Logs
          _buildLogsCard(context, colors),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildControlCard(
    BuildContext context,
    FluentColors colors,
    bool isRunning,
    bool isPaused,
    bool isActive,
  ) {
    return Container(
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
                child: Icon(Icons.smart_toy_outlined, color: colors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Model File Bridge',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isActive ? 'Server active on ${_mcpService.serverUrl}' : 'Expose files safely to local LLMs via MCP',
                      style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: isActive ? colors.error : colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: (!isActive && _isPortFree != true) ? null : _toggleServer,
                  icon: Icon(isActive ? Icons.stop : Icons.play_arrow),
                  label: Text(isActive ? 'Stop MCP Server' : 'Start MCP Server'),
                ),
              ),
              if (isActive) ...[
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onPressed: () {
                    if (isPaused) {
                      _mcpService.resume();
                    } else {
                      _mcpService.pause();
                    }
                  },
                  icon: Icon(isPaused ? Icons.play_arrow : Icons.pause),
                  label: Text(isPaused ? 'Resume' : 'Pause'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClaudeConfigCard(BuildContext context, FluentColors colors) {
    final configJson = _mcpService.generateClaudeConfigJson();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.primary.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.terminal_rounded, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Claude Desktop & Cursor Config (JSON)',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Complete configuration with token and URL pre-configured. Paste directly into your claude_desktop_config.json or Cursor mcp.json:',
            style: TextStyle(fontSize: 11.5, color: colors.textSecondary),
          ),
          const SizedBox(height: 10),

          // Code Container with formatted JSON
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.container,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: colors.borderSubtle),
            ),
            child: SelectableText(
              configJson,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11.5,
                height: 1.45,
                color: colors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // One-click Copy Full Config Button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _copyToClipboard(
                configJson,
                'Full configuration JSON copied to clipboard!',
              ),
              icon: const Icon(Icons.copy_all_rounded, size: 18),
              label: const Text(
                'Copy Complete Configuration JSON',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionEndpointsCard(
    BuildContext context,
    FluentColors colors,
  ) {
    final sseUrl = _mcpService.fullSseUrl;

    return Container(
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
              Row(
                children: [
                  Icon(Icons.link_rounded, size: 18, color: colors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Direct Connection & Endpoints',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => setState(() => _showQrCode = !_showQrCode),
                icon: Icon(_showQrCode ? Icons.qr_code_2 : Icons.qr_code, size: 16),
                label: Text(
                  _showQrCode ? 'Hide QR' : 'Show QR',
                  style: const TextStyle(fontSize: 11.5),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ],
          ),
          if (_showQrCode) ...[
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
                  data: sseUrl,
                  version: QrVersions.auto,
                  size: 160.0,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: Text(
                'Scan to connect directly to MCP SSE endpoint',
                style: TextStyle(fontSize: 11, color: colors.textMuted),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // SSE Endpoint row (contains auth token)
          _buildInfoRow(
            'SSE Endpoint',
            sseUrl,
            colors,
            () => _copyToClipboard(sseUrl, 'Full SSE Endpoint URL copied!'),
          ),
          const SizedBox(height: 6),
          _buildInfoRow(
            'Direct JSON',
            '${_mcpService.serverUrl}/api/status',
            colors,
            () => _copyToClipboard('${_mcpService.serverUrl}/api/status', 'Direct JSON URL copied!'),
          ),
          const SizedBox(height: 6),
          _buildInfoRow(
            'Direct RPC',
            '${_mcpService.serverUrl}/api/rpc',
            colors,
            () => _copyToClipboard('${_mcpService.serverUrl}/api/rpc', 'RPC URL copied!'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, FluentColors colors, VoidCallback onCopy) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colors.container,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, fontFamily: 'monospace', color: colors.textPrimary),
            ),
          ),
          InkWell(
            onTap: onCopy,
            child: Icon(Icons.copy, size: 14, color: colors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionsCard(
    BuildContext context,
    FluentColors colors,
    bool isActive,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.cardSurface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Options & Security Permissions', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
          const SizedBox(height: 14),

          // Port Field with real-time automatic availability verification
          TextField(
            controller: _portController,
            enabled: !isActive,
            keyboardType: TextInputType.number,
            onChanged: _onPortChanged,
            decoration: InputDecoration(
              labelText: 'Server Port',
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: _isPortFree == true
                  ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                  : (_isPortFree == false
                      ? const Icon(Icons.cancel, color: Colors.red, size: 20)
                      : null),
              helperText: _portCheckMessage,
              helperStyle: TextStyle(
                color: _isPortFree == true ? colors.success : (_isPortFree == false ? colors.error : null),
                fontSize: 11,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Authentication switch & read-only token
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Require Authentication', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
            subtitle: Text('Enforce Bearer token or x-api-key header', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
            value: _mcpService.config.requireAuth,
            activeColor: colors.primary,
            onChanged: isActive
                ? null
                : (val) {
                    setState(() => _mcpService.config.requireAuth = val);
                  },
          ),
          if (_mcpService.config.requireAuth) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.container,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: colors.borderSubtle),
              ),
              child: Row(
                children: [
                  Icon(Icons.vpn_key_outlined, size: 18, color: colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Authentication Token', style: TextStyle(fontSize: 10.5, color: colors.textSecondary)),
                        Text(
                          _mcpService.config.authToken,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Generate new token',
                    onPressed: isActive
                        ? null
                        : () {
                            final newToken = McpServerConfig.generateToken();
                            _tokenController.text = newToken;
                            _mcpService.config.authToken = newToken;
                            setState(() {});
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 18),
                    tooltip: 'Copy Token',
                    onPressed: () => _copyToClipboard(_mcpService.config.authToken, 'Token copied to clipboard'),
                  ),
                ],
              ),
            ),
          ],

          const Divider(height: 24),

          // Root Directory with Browse Folder Button (no manual typing)
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
                        'Root Directory Restriction',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _mcpService.config.rootDirectory,
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
                  onPressed: isActive ? null : _pickRootDirectory,
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
            title: Text('Allow Write Operations', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
            subtitle: Text('Permits writing files and creating folders', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
            value: _mcpService.config.allowWrite,
            activeColor: colors.primary,
            onChanged: (val) {
              setState(() => _mcpService.config.allowWrite = val);
            },
          ),

          // Allow Delete
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Allow Delete Operations', style: TextStyle(fontSize: 13, color: colors.textPrimary)),
            subtitle: Text('Permits deleting files through MCP tool calls', style: TextStyle(fontSize: 11, color: colors.textSecondary)),
            value: _mcpService.config.allowDelete,
            activeColor: colors.error,
            onChanged: _mcpService.config.allowWrite
                ? (val) {
                    setState(() => _mcpService.config.allowDelete = val);
                  }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildLogsCard(BuildContext context, FluentColors colors) {
    final logs = _mcpService.logs;

    return Container(
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
              Text('Live Request Activity (${_mcpService.requestCount})', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colors.textPrimary)),
              Text('Real-time', style: TextStyle(fontSize: 11, color: colors.primary)),
            ],
          ),
          const SizedBox(height: 10),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text('No requests received yet', style: TextStyle(fontSize: 12, color: colors.textMuted)),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length > 10 ? 10 : logs.length,
              separatorBuilder: (_, _) => Divider(height: 1, color: colors.borderSubtle),
              itemBuilder: (ctx, i) {
                final log = logs[i];
                final isOk = log.statusCode >= 200 && log.statusCode < 300;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: isOk ? colors.success.withOpacity(0.15) : colors.error.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.statusCode.toString(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: isOk ? colors.success : colors.error),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        log.method,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          log.endpoint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: colors.textSecondary),
                        ),
                      ),
                      Text(
                        '${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}:${log.timestamp.second.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 10, color: colors.textMuted),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
