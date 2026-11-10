import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'file_service.dart';

enum McpServerState { stopped, running, paused }

class McpServerConfig {
  int port;
  bool requireAuth;
  String authToken;
  String rootDirectory;
  bool allowWrite;
  bool allowDelete;
  int maxFileSizeBytes; // e.g. 10MB

  McpServerConfig({
    this.port = 8080,
    this.requireAuth = true,
    String? authToken,
    String? rootDirectory,
    this.allowWrite = true,
    this.allowDelete = false,
    this.maxFileSizeBytes = 10 * 1024 * 1024,
  })  : authToken = authToken ?? generateToken(),
        rootDirectory = rootDirectory ?? FileService.internalStoragePath;

  static String generateToken() {
    final rand = Random.secure();
    final bytes = List<int>.generate(16, (_) => rand.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

class McpRequestLog {
  final DateTime timestamp;
  final String method;
  final String endpoint;
  final int statusCode;
  final String? clientIp;

  McpRequestLog({
    required this.timestamp,
    required this.method,
    required this.endpoint,
    required this.statusCode,
    this.clientIp,
  });
}

class McpServerService with ChangeNotifier {
  static final McpServerService _instance = McpServerService._internal();
  factory McpServerService() => _instance;
  static McpServerService get instance => _instance;

  McpServerService._internal() {
    _initNativeListeners();
  }

  static const MethodChannel _storageChannel = MethodChannel('com.neofile.app/storage');

  McpServerConfig config = McpServerConfig();
  McpServerState _state = McpServerState.stopped;
  HttpServer? _httpServer;
  String _localIp = '127.0.0.1';
  int _requestCount = 0;
  final List<McpRequestLog> _logs = [];
  final Map<String, StreamController<String>> _sseClients = {};

  McpServerState get state => _state;
  bool get isRunning => _state == McpServerState.running;
  bool get isPaused => _state == McpServerState.paused;
  bool get isStopped => _state == McpServerState.stopped;
  String get localIp => _localIp;
  int get port => _httpServer?.port ?? config.port;
  int get requestCount => _requestCount;
  List<McpRequestLog> get logs => List.unmodifiable(_logs);
  String get serverUrl => 'http://$localIp:$port';

  void _initNativeListeners() {
    FileService.ensureHandlerInitialized();
    FileService.onMcpStop = () async {
      await stop();
    };
    FileService.onMcpPause = () {
      pause();
    };
    FileService.onMcpResume = () {
      resume();
    };
  }

  static Future<bool> isPortAvailable(int port) async {
    try {
      final server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await server.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<int> findAvailablePort(int startingPort) async {
    int port = startingPort;
    for (int i = 0; i < 20; i++) {
      if (await isPortAvailable(port)) {
        return port;
      }
      port++;
    }
    return startingPort;
  }

  Future<void> _updateLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('10.0.2.')) {
            _localIp = addr.address;
            return;
          }
        }
      }
    } catch (_) {}
    _localIp = '127.0.0.1';
  }

  Future<bool> start() async {
    if (_state != McpServerState.stopped) return true;

    await _updateLocalIp();

    // Check if port is available
    final available = await isPortAvailable(config.port);
    if (!available) {
      final nextPort = await findAvailablePort(config.port);
      config.port = nextPort;
    }

    try {
      _httpServer = await HttpServer.bind(
        InternetAddress.anyIPv4,
        config.port,
        shared: true,
      );
      _httpServer!.listen(_handleHttpRequest);

      _state = McpServerState.running;
      notifyListeners();
      _syncNotification();
      return true;
    } catch (e) {
      _state = McpServerState.stopped;
      notifyListeners();
      return false;
    }
  }

  void pause() {
    if (_state == McpServerState.running) {
      _state = McpServerState.paused;
      notifyListeners();
      _syncNotification();
    }
  }

  void resume() {
    if (_state == McpServerState.paused) {
      _state = McpServerState.running;
      notifyListeners();
      _syncNotification();
    }
  }

  Future<void> stop() async {
    if (_state == McpServerState.stopped) return;

    for (final controller in _sseClients.values) {
      await controller.close();
    }
    _sseClients.clear();

    await _httpServer?.close(force: true);
    _httpServer = null;
    _state = McpServerState.stopped;
    notifyListeners();

    try {
      await _storageChannel.invokeMethod('cancelMcpNotification');
    } catch (_) {}
  }

  void _syncNotification() {
    try {
      if (_state == McpServerState.stopped) {
        _storageChannel.invokeMethod('cancelMcpNotification');
        FileService.updateWidgetData({
          'mcp_running': false,
          'mcp_paused': false,
        });
      } else {
        final isPausedState = _state == McpServerState.paused;
        _storageChannel.invokeMethod('showMcpNotification', {
          'title': isPausedState ? 'NeoFile MCP (Paused)' : 'NeoFile MCP Server Running',
          'message': '$serverUrl • ${isPausedState ? "Paused" : "Active"}',
          'isPaused': isPausedState,
        });
        FileService.updateWidgetData({
          'mcp_running': true,
          'mcp_paused': isPausedState,
          'mcp_url': serverUrl,
        });
      }
    } catch (_) {}
  }

  void _logRequest(String method, String endpoint, int code, String? ip) {
    _requestCount++;
    _logs.insert(
      0,
      McpRequestLog(
        timestamp: DateTime.now(),
        method: method,
        endpoint: endpoint,
        statusCode: code,
        clientIp: ip,
      ),
    );
    if (_logs.length > 100) {
      _logs.removeLast();
    }
    notifyListeners();
  }

  bool _isAuthorized(HttpRequest request) {
    if (!config.requireAuth) return true;

    final authHeader = request.headers.value('authorization');
    if (authHeader != null) {
      if (authHeader.startsWith('Bearer ') &&
          authHeader.substring(7).trim() == config.authToken) {
        return true;
      }
    }

    final apiKeyHeader = request.headers.value('x-api-key');
    if (apiKeyHeader != null && apiKeyHeader.trim() == config.authToken) {
      return true;
    }

    final queryToken = request.uri.queryParameters['token'];
    if (queryToken != null && queryToken.trim() == config.authToken) {
      return true;
    }

    return false;
  }

  bool _isPathWithinRoot(String path) {
    final canonicalTarget = p.canonicalize(path);
    final canonicalRoot = p.canonicalize(config.rootDirectory);
    return canonicalTarget.startsWith(canonicalRoot);
  }

  Future<void> _handleHttpRequest(HttpRequest request) async {
    final clientIp = request.connectionInfo?.remoteAddress.address;

    // CORS Headers
    request.response.headers.set('Access-Control-Allow-Origin', '*');
    request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, x-api-key');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    // Check pause state
    if (_state == McpServerState.paused) {
      _logRequest(request.method, request.uri.path, HttpStatus.serviceUnavailable, clientIp);
      request.response
        ..statusCode = HttpStatus.serviceUnavailable
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'error': 'MCP server is currently paused in NeoFile. Resume server to execute requests.'
        }));
      await request.response.close();
      return;
    }

    // Check Authentication
    if (!_isAuthorized(request)) {
      _logRequest(request.method, request.uri.path, HttpStatus.unauthorized, clientIp);
      request.response
        ..statusCode = HttpStatus.unauthorized
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'error': 'Unauthorized. Provide valid Bearer token or x-api-key header.'
        }));
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    try {
      // 1. Direct JSON status / info endpoint
      if (path == '/' || path == '/api/status' || path == '/api/info') {
        _logRequest(request.method, path, HttpStatus.ok, clientIp);
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(_getServerInfoJson()));
        await request.response.close();
        return;
      }

      // 2. Direct JSON directory listing: GET /api/files?path=...
      if (path == '/api/files' && request.method == 'GET') {
        await _handleDirectListFiles(request, clientIp);
        return;
      }

      // 3. Direct JSON file download / read: GET /api/file?path=...
      if (path == '/api/file' && request.method == 'GET') {
        await _handleDirectReadFile(request, clientIp);
        return;
      }

      // 4. MCP Server-Sent Events (SSE) endpoint: GET /sse
      if (path == '/sse' && request.method == 'GET') {
        await _handleSseConnect(request, clientIp);
        return;
      }

      // 5. MCP message / JSON-RPC endpoint: POST /message or POST /api/rpc or POST /rpc
      if ((path == '/message' || path == '/api/rpc' || path == '/rpc') && request.method == 'POST') {
        await _handleJsonRpcRequest(request, clientIp);
        return;
      }

      // 404 Not Found
      _logRequest(request.method, path, HttpStatus.notFound, clientIp);
      request.response
        ..statusCode = HttpStatus.notFound
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'Endpoint not found'}));
      await request.response.close();
    } catch (e) {
      _logRequest(request.method, path, HttpStatus.internalServerError, clientIp);
      request.response
        ..statusCode = HttpStatus.internalServerError
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': e.toString()}));
      await request.response.close();
    }
  }

  Map<String, dynamic> _getServerInfoJson() {
    return {
      'name': 'NeoFile MCP Server',
      'version': '1.0.0',
      'protocolVersion': '2024-11-05',
      'state': _state.name,
      'serverUrl': serverUrl,
      'authRequired': config.requireAuth,
      'rootDirectory': config.rootDirectory,
      'permissions': {
        'allowWrite': config.allowWrite,
        'allowDelete': config.allowDelete,
        'maxFileSizeBytes': config.maxFileSizeBytes,
      },
      'endpoints': {
        'status': '/api/status',
        'sse': '/sse',
        'jsonRpc': '/api/rpc',
        'directFiles': '/api/files?path=<path>',
        'directFile': '/api/file?path=<path>',
      },
      'tools': _getMcpTools(),
    };
  }

  List<Map<String, dynamic>> _getMcpTools() {
    return [
      {
        'name': 'list_directory',
        'description': 'List contents of a directory with file metadata (size, modified, isDirectory)',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Absolute directory path (defaults to root)'},
          },
        },
      },
      {
        'name': 'read_file',
        'description': 'Read textual content of a file (respects max size limits)',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Absolute path to file'},
            'maxBytes': {'type': 'integer', 'description': 'Optional byte limit'},
          },
          'required': ['path'],
        },
      },
      {
        'name': 'write_file',
        'description': 'Write text content to a file (requires write permission)',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Absolute path to file'},
            'content': {'type': 'string', 'description': 'Text content to write'},
            'append': {'type': 'boolean', 'description': 'Whether to append or overwrite'},
          },
          'required': ['path', 'content'],
        },
      },
      {
        'name': 'delete_file',
        'description': 'Delete a file or empty directory (requires delete permission)',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Absolute path to file or directory'},
          },
          'required': ['path'],
        },
      },
      {
        'name': 'get_file_info',
        'description': 'Get detailed metadata for a file or directory',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Absolute path'},
          },
          'required': ['path'],
        },
      },
      {
        'name': 'search_files',
        'description': 'Search for files matching a query string recursively within root or specified directory',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'query': {'type': 'string', 'description': 'Name or substring to find'},
            'path': {'type': 'string', 'description': 'Base search directory (defaults to root)'},
            'maxResults': {'type': 'integer', 'description': 'Max items to return (default 50)'},
          },
          'required': ['query'],
        },
      },
      {
        'name': 'create_directory',
        'description': 'Create a new directory at the specified path',
        'inputSchema': {
          'type': 'object',
          'properties': {
            'path': {'type': 'string', 'description': 'Absolute path for new directory'},
          },
          'required': ['path'],
        },
      },
    ];
  }

  Future<void> _handleDirectListFiles(HttpRequest request, String? clientIp) async {
    final queryPath = request.uri.queryParameters['path'] ?? config.rootDirectory;
    if (!_isPathWithinRoot(queryPath)) {
      _logRequest(request.method, request.uri.path, HttpStatus.forbidden, clientIp);
      request.response
        ..statusCode = HttpStatus.forbidden
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'Path is outside allowed root directory'}));
      await request.response.close();
      return;
    }

    final dir = Directory(queryPath);
    if (!dir.existsSync()) {
      _logRequest(request.method, request.uri.path, HttpStatus.notFound, clientIp);
      request.response
        ..statusCode = HttpStatus.notFound
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'Directory does not exist'}));
      await request.response.close();
      return;
    }

    final items = <Map<String, dynamic>>[];
    await for (final entity in dir.list(followLinks: false)) {
      try {
        final stat = entity.statSync();
        final isDir = entity is Directory;
        items.add({
          'name': p.basename(entity.path),
          'path': entity.path,
          'isDirectory': isDir,
          'size': isDir ? 0 : stat.size,
          'modified': stat.modified.toIso8601String(),
        });
      } catch (_) {}
    }

    _logRequest(request.method, request.uri.path, HttpStatus.ok, clientIp);
    request.response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.json
      ..write(jsonEncode({'path': queryPath, 'items': items}));
    await request.response.close();
  }

  Future<void> _handleDirectReadFile(HttpRequest request, String? clientIp) async {
    final queryPath = request.uri.queryParameters['path'];
    if (queryPath == null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'Missing path parameter'}));
      await request.response.close();
      return;
    }

    if (!_isPathWithinRoot(queryPath)) {
      _logRequest(request.method, request.uri.path, HttpStatus.forbidden, clientIp);
      request.response
        ..statusCode = HttpStatus.forbidden
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'Path is outside allowed root directory'}));
      await request.response.close();
      return;
    }

    final file = File(queryPath);
    if (!file.existsSync()) {
      _logRequest(request.method, request.uri.path, HttpStatus.notFound, clientIp);
      request.response
        ..statusCode = HttpStatus.notFound
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'File not found'}));
      await request.response.close();
      return;
    }

    final stat = file.statSync();
    if (stat.size > config.maxFileSizeBytes) {
      _logRequest(request.method, request.uri.path, HttpStatus.badRequest, clientIp);
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'error': 'File size exceeds maximum allowed size (${config.maxFileSizeBytes} bytes)'
        }));
      await request.response.close();
      return;
    }

    _logRequest(request.method, request.uri.path, HttpStatus.ok, clientIp);
    request.response.statusCode = HttpStatus.ok;
    final mime = FileService.getMimeType(queryPath) ?? 'application/octet-stream';
    request.response.headers.contentType = ContentType.parse(mime);
    await file.openRead().pipe(request.response);
  }

  Future<void> _handleSseConnect(HttpRequest request, String? clientIp) async {
    final sessionId = 'sess_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}';
    final controller = StreamController<String>.broadcast();
    _sseClients[sessionId] = controller;

    _logRequest(request.method, request.uri.path, HttpStatus.ok, clientIp);

    // Disable response buffering for immediate SSE event delivery
    request.response
      ..statusCode = HttpStatus.ok
      ..bufferOutput = false
      ..headers.set('Content-Type', 'text/event-stream; charset=utf-8')
      ..headers.set('Cache-Control', 'no-cache, no-transform')
      ..headers.set('Connection', 'keep-alive')
      ..headers.set('X-Accel-Buffering', 'no');

    // Build absolute endpoint URL with host from request header and auth token
    final host = request.headers.value('host') ?? '$localIp:$port';
    final tokenParam = config.requireAuth ? '&token=${config.authToken}' : '';
    final endpointUrl = 'http://$host/message?sessionId=$sessionId$tokenParam';

    request.response.write('event: endpoint\ndata: $endpointUrl\n\n');
    await request.response.flush();

    final sub = controller.stream.listen((data) {
      final lines = data.split('\n');
      request.response.write('event: message\n');
      for (final line in lines) {
        request.response.write('data: $line\n');
      }
      request.response.write('\n');
      request.response.flush();
    });

    request.response.done.then((_) {
      sub.cancel();
      controller.close();
      _sseClients.remove(sessionId);
    });
  }

  Future<void> _handleJsonRpcRequest(HttpRequest request, String? clientIp) async {
    final bodyStr = await utf8.decoder.bind(request).join();
    dynamic payload;
    try {
      payload = jsonDecode(bodyStr);
    } catch (_) {
      _logRequest(request.method, request.uri.path, HttpStatus.badRequest, clientIp);
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'jsonrpc': '2.0',
          'error': {'code': -32700, 'message': 'Parse error'},
          'id': null,
        }));
      await request.response.close();
      return;
    }

    if (payload is! Map<String, dynamic>) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'jsonrpc': '2.0',
          'error': {'code': -32600, 'message': 'Invalid Request'},
          'id': null,
        }));
      await request.response.close();
      return;
    }

    final hasId = payload.containsKey('id') && payload['id'] != null;
    final id = payload['id'];
    final method = payload['method'] as String? ?? '';
    final params = payload['params'] as Map<String, dynamic>? ?? {};

    final sessionId = request.uri.queryParameters['sessionId'];
    final isSseClient = sessionId != null && _sseClients.containsKey(sessionId);

    // If it is a notification (no id), execute side-effect and DO NOT reply with a response
    if (!hasId) {
      await _executeRpcMethod(method, params);
      _logRequest(request.method, '$method (notification)', HttpStatus.accepted, clientIp);
      request.response
        ..statusCode = HttpStatus.accepted
        ..headers.contentType = ContentType.text
        ..write('Accepted');
      await request.response.close();
      return;
    }

    final result = await _executeRpcMethod(method, params);

    final responsePayload = {
      'jsonrpc': '2.0',
      'id': id,
      if (result.containsKey('error')) 'error': result['error'] else 'result': result['result'],
    };

    final jsonOut = jsonEncode(responsePayload);

    _logRequest(request.method, method, HttpStatus.ok, clientIp);

    // For SSE clients, deliver the JSON-RPC response through the SSE event stream,
    // and acknowledge the HTTP POST with 202 Accepted.
    if (isSseClient) {
      _sseClients[sessionId]!.add(jsonOut);
      request.response
        ..statusCode = HttpStatus.accepted
        ..headers.contentType = ContentType.text
        ..write('Accepted');
      await request.response.close();
    } else {
      // For direct HTTP RPC clients, return the JSON directly in the response body
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonOut);
      await request.response.close();
    }
  }

  Future<Map<String, dynamic>> _executeRpcMethod(String method, Map<String, dynamic> params) async {
    switch (method) {
      case 'initialize':
        return {
          'result': {
            'protocolVersion': params['protocolVersion'] ?? '2024-11-05',
            'capabilities': {
              'tools': {'listChanged': false},
              'resources': {'subscribe': false, 'listChanged': false},
              'prompts': {'listChanged': false},
            },
            'serverInfo': {
              'name': 'NeoFile MCP Server',
              'version': '1.0.0',
            },
          }
        };

      case 'notifications/initialized':
        return {'result': {}};

      case 'tools/list':
        return {
          'result': {
            'tools': _getMcpTools(),
          }
        };

      case 'tools/call':
        final toolName = params['name'] as String? ?? '';
        final toolArgs = params['arguments'] as Map<String, dynamic>? ?? {};
        return await _executeToolCall(toolName, toolArgs);

      case 'resources/list':
        return {
          'result': {
            'resources': [],
          }
        };

      case 'prompts/list':
        return {
          'result': {
            'prompts': [],
          }
        };

      case 'logging/setLevel':
        return {'result': {}};

      case 'ping':
        return {'result': {}};

      default:
        return {
          'error': {
            'code': -32601,
            'message': 'Method not found: $method',
          }
        };
    }
  }

  String get fullSseUrl => '$serverUrl/sse${config.requireAuth ? "?token=${config.authToken}" : ""}';

  String _normalizeTargetPath(String? raw) {
    if (raw == null || raw.trim().isEmpty || raw.trim() == '.' || raw.trim() == './') {
      return config.rootDirectory;
    }
    final trimmed = raw.trim();
    if (p.isAbsolute(trimmed)) {
      return p.normalize(trimmed);
    }
    return p.normalize(p.join(config.rootDirectory, trimmed));
  }

  Future<Map<String, dynamic>> _executeToolCall(String name, Map<String, dynamic> args) async {
    try {
      switch (name) {
        case 'list_directory':
          final targetPath = _normalizeTargetPath(args['path'] as String?);
          if (!_isPathWithinRoot(targetPath)) {
            return _toolError('Access denied: target path is outside allowed root directory');
          }
          final dir = Directory(targetPath);
          if (!dir.existsSync()) {
            return _toolError('Directory not found: $targetPath');
          }
          final items = <Map<String, dynamic>>[];
          await for (final entity in dir.list(followLinks: false)) {
            try {
              final stat = entity.statSync();
              final isDir = entity is Directory;
              items.add({
                'name': p.basename(entity.path),
                'path': entity.path,
                'isDirectory': isDir,
                'size': isDir ? 0 : stat.size,
                'modified': stat.modified.toIso8601String(),
              });
            } catch (_) {}
          }
          return _toolSuccess(jsonEncode(items));

        case 'read_file':
          final rawPath = args['path'] as String?;
          if (rawPath == null) return _toolError('Missing path argument');
          final filePath = _normalizeTargetPath(rawPath);
          if (!_isPathWithinRoot(filePath)) {
            return _toolError('Access denied: file is outside allowed root directory');
          }
          final file = File(filePath);
          if (!file.existsSync()) {
            return _toolError('File not found: $filePath');
          }
          final stat = file.statSync();
          if (stat.size > config.maxFileSizeBytes) {
            return _toolError('File size (${stat.size} bytes) exceeds limit (${config.maxFileSizeBytes} bytes)');
          }
          final maxBytes = args['maxBytes'] as int?;
          if (maxBytes != null && maxBytes < stat.size) {
            final bytes = await file.openRead(0, maxBytes).toList();
            final flattened = bytes.expand((x) => x).toList();
            final content = utf8.decode(flattened, allowMalformed: true);
            return _toolSuccess(content);
          }
          final text = await file.readAsString();
          return _toolSuccess(text);

        case 'write_file':
          if (!config.allowWrite) {
            return _toolError('Write operations are disabled on this MCP server');
          }
          final rawPath = args['path'] as String?;
          final content = args['content'] as String?;
          if (rawPath == null || content == null) {
            return _toolError('Missing path or content argument');
          }
          final filePath = _normalizeTargetPath(rawPath);
          if (!_isPathWithinRoot(filePath)) {
            return _toolError('Access denied: file path is outside allowed root directory');
          }
          final append = args['append'] as bool? ?? false;
          final file = File(filePath);
          await file.parent.create(recursive: true);
          if (append) {
            await file.writeAsString(content, mode: FileMode.append, flush: true);
          } else {
            await file.writeAsString(content, mode: FileMode.write, flush: true);
          }
          return _toolSuccess('File written successfully: $filePath');

        case 'delete_file':
          if (!config.allowWrite || !config.allowDelete) {
            return _toolError('Delete operations are disabled on this MCP server');
          }
          final rawPath = args['path'] as String?;
          if (rawPath == null) return _toolError('Missing path argument');
          final filePath = _normalizeTargetPath(rawPath);
          if (!_isPathWithinRoot(filePath)) {
            return _toolError('Access denied: target path is outside allowed root directory');
          }
          final entity = FileSystemEntity.typeSync(filePath);
          if (entity == FileSystemEntityType.file) {
            await File(filePath).delete();
            return _toolSuccess('File deleted: $filePath');
          } else if (entity == FileSystemEntityType.directory) {
            await Directory(filePath).delete(recursive: true);
            return _toolSuccess('Directory deleted: $filePath');
          } else {
            return _toolError('Entity not found: $filePath');
          }

        case 'get_file_info':
          final rawPath = args['path'] as String?;
          if (rawPath == null) return _toolError('Missing path argument');
          final targetPath = _normalizeTargetPath(rawPath);
          if (!_isPathWithinRoot(targetPath)) {
            return _toolError('Access denied: target is outside allowed root directory');
          }
          final stat = FileStat.statSync(targetPath);
          if (stat.type == FileSystemEntityType.notFound) {
            return _toolError('Path not found: $targetPath');
          }
          return _toolSuccess(jsonEncode({
            'name': p.basename(targetPath),
            'path': targetPath,
            'type': stat.type.toString(),
            'size': stat.size,
            'modified': stat.modified.toIso8601String(),
            'accessed': stat.accessed.toIso8601String(),
            'mode': stat.modeString(),
          }));

        case 'search_files':
          final query = (args['query'] as String? ?? '').toLowerCase();
          if (query.isEmpty) return _toolError('Empty search query');
          final basePath = _normalizeTargetPath(args['path'] as String?);
          if (!_isPathWithinRoot(basePath)) {
            return _toolError('Access denied: base search path is outside allowed root directory');
          }
          final maxResults = args['maxResults'] as int? ?? 50;
          final baseDir = Directory(basePath);
          if (!baseDir.existsSync()) {
            return _toolError('Base directory not found: $basePath');
          }
          final results = <Map<String, dynamic>>[];
          try {
            await for (final entity in baseDir.list(recursive: true, followLinks: false)) {
              final name = p.basename(entity.path);
              if (name.toLowerCase().contains(query)) {
                final isDir = entity is Directory;
                results.add({
                  'name': name,
                  'path': entity.path,
                  'isDirectory': isDir,
                });
                if (results.length >= maxResults) break;
              }
            }
          } catch (_) {}
          return _toolSuccess(jsonEncode(results));

        case 'create_directory':
          if (!config.allowWrite) {
            return _toolError('Write operations are disabled on this MCP server');
          }
          final rawPath = args['path'] as String?;
          if (rawPath == null) return _toolError('Missing path argument');
          final dirPath = _normalizeTargetPath(rawPath);
          if (!_isPathWithinRoot(dirPath)) {
            return _toolError('Access denied: path is outside allowed root directory');
          }
          await Directory(dirPath).create(recursive: true);
          return _toolSuccess('Directory created: $dirPath');

        default:
          return _toolError('Unknown tool: $name');
      }
    } catch (e) {
      return _toolError('Tool execution exception: $e');
    }
  }

  Map<String, dynamic> _toolSuccess(String text) {
    return {
      'result': {
        'content': [
          {'type': 'text', 'text': text}
        ],
        'isError': false,
      }
    };
  }

  Map<String, dynamic> _toolError(String error) {
    return {
      'result': {
        'content': [
          {'type': 'text', 'text': 'Error: $error'}
        ],
        'isError': true,
      }
    };
  }

  String generateClaudeConfigJson() {
    final tokenParam = config.requireAuth ? '?token=${config.authToken}' : '';
    final sseUrl = '$serverUrl/sse$tokenParam';
    return const JsonEncoder.withIndent('  ').convert({
      'mcpServers': {
        'neofile': {
          'url': sseUrl,
          if (config.requireAuth)
            'headers': {
              'Authorization': 'Bearer ${config.authToken}',
            },
          'description': 'NeoFile Local File Manager MCP Server',
          'permissions': {
            'allowWrite': config.allowWrite,
            'allowDelete': config.allowDelete,
            'rootDirectory': config.rootDirectory,
            'maxFileSizeBytes': config.maxFileSizeBytes,
          },
          'tools': _getMcpTools().map((t) => t['name'] as String).toList(),
        }
      }
    });
  }
}
