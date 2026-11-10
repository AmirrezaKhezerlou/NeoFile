import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'file_service.dart';

enum FtpServerState { stopped, running }

enum FtpNetworkType { wifi, hotspot, mobileData, none }

class FtpNetworkInfo {
  final FtpNetworkType type;
  final String ip;
  final String interfaceName;

  FtpNetworkInfo({
    required this.type,
    required this.ip,
    required this.interfaceName,
  });

  bool get isLocalNetwork => type == FtpNetworkType.wifi || type == FtpNetworkType.hotspot;
  bool get isWarning => type == FtpNetworkType.mobileData || type == FtpNetworkType.none;

  String get userFriendlyMessage {
    switch (type) {
      case FtpNetworkType.wifi:
        return 'Connected to Wi-Fi ($ip). Ready for local file sharing.';
      case FtpNetworkType.hotspot:
        return 'Personal Hotspot active ($ip). Devices connected to your hotspot can access files.';
      case FtpNetworkType.mobileData:
        return 'Mobile Data active ($ip). FTP server requires a local Wi-Fi or Hotspot network so nearby devices can connect.';
      case FtpNetworkType.none:
        return 'No Wi-Fi or Hotspot connection detected (Airplane mode / Disconnected). Connect to Wi-Fi or turn on Hotspot.';
    }
  }
}

class FtpServerConfig {
  int port;
  bool anonymous;
  String username;
  String password;
  String rootDirectory;
  bool allowWrite;

  FtpServerConfig({
    this.port = 2121,
    this.anonymous = false,
    this.username = 'neofile',
    this.password = '123456',
    String? rootDirectory,
    this.allowWrite = true,
  }) : rootDirectory = rootDirectory ?? FileService.internalStoragePath;
}

class FtpLogItem {
  final DateTime timestamp;
  final String message;
  final bool isError;

  FtpLogItem({required this.timestamp, required this.message, this.isError = false});
}

class FtpServerService with ChangeNotifier {
  static final FtpServerService _instance = FtpServerService._internal();
  factory FtpServerService() => _instance;
  static FtpServerService get instance => _instance;

  FtpServerService._internal() {
    FileService.ensureHandlerInitialized();
    FileService.onFtpStop = () async {
      await stop();
    };
  }

  FtpServerConfig config = FtpServerConfig();
  FtpServerState _state = FtpServerState.stopped;
  ServerSocket? _controlServer;
  String _localIp = '127.0.0.1';
  int _activeConnections = 0;
  final List<FtpLogItem> _logs = [];

  FtpServerState get state => _state;
  bool get isRunning => _state == FtpServerState.running;
  String get localIp => _localIp;
  int get port => _controlServer?.port ?? config.port;
  int get activeConnections => _activeConnections;
  List<FtpLogItem> get logs => List.unmodifiable(_logs);
  String get ftpUrl => config.anonymous
      ? 'ftp://$localIp:$port'
      : 'ftp://${config.username}:${config.password}@$localIp:$port';

  void _log(String msg, {bool isError = false}) {
    _logs.insert(0, FtpLogItem(timestamp: DateTime.now(), message: msg, isError: isError));
    if (_logs.length > 80) _logs.removeLast();
    notifyListeners();
  }

  static Future<bool> isPortAvailable(int port) async {
    try {
      final s = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      await s.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<int> findAvailablePort(int startingPort) async {
    int port = startingPort;
    for (int i = 0; i < 20; i++) {
      if (await isPortAvailable(port)) return port;
      port++;
    }
    return startingPort;
  }

  FtpNetworkInfo _networkInfo = FtpNetworkInfo(type: FtpNetworkType.none, ip: '127.0.0.1', interfaceName: 'lo');
  FtpNetworkInfo get networkInfo => _networkInfo;

  Future<FtpNetworkInfo> updateNetworkStatus() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      // 1. Check for Wi-Fi or Hotspot interfaces first
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('10.0.2.')) {
            if (name.contains('ap') || name.contains('softap') || name.contains('rndis') || addr.address.startsWith('192.168.43.')) {
              _localIp = addr.address;
              _networkInfo = FtpNetworkInfo(type: FtpNetworkType.hotspot, ip: addr.address, interfaceName: iface.name);
              notifyListeners();
              return _networkInfo;
            }
            if (name.contains('wlan') || name.contains('eth') || name.contains('en')) {
              _localIp = addr.address;
              _networkInfo = FtpNetworkInfo(type: FtpNetworkType.wifi, ip: addr.address, interfaceName: iface.name);
              notifyListeners();
              return _networkInfo;
            }
          }
        }
      }

      // 2. Check for Cellular / Mobile Data
      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('10.0.2.')) {
            if (name.contains('rmnet') || name.contains('ccmni') || name.contains('pdp') || name.contains('data')) {
              _localIp = addr.address;
              _networkInfo = FtpNetworkInfo(type: FtpNetworkType.mobileData, ip: addr.address, interfaceName: iface.name);
              notifyListeners();
              return _networkInfo;
            }
          }
        }
      }

      // 3. Fallback for any other valid interface
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('10.0.2.')) {
            _localIp = addr.address;
            _networkInfo = FtpNetworkInfo(type: FtpNetworkType.wifi, ip: addr.address, interfaceName: iface.name);
            notifyListeners();
            return _networkInfo;
          }
        }
      }
    } catch (_) {}

    _localIp = '127.0.0.1';
    _networkInfo = FtpNetworkInfo(type: FtpNetworkType.none, ip: '127.0.0.1', interfaceName: 'lo');
    notifyListeners();
    return _networkInfo;
  }

  Future<void> _updateLocalIp() async {
    await updateNetworkStatus();
  }

  void _syncNotification() {
    try {
      if (_state == FtpServerState.stopped) {
        FileService.cancelFtpNotification();
        FileService.updateWidgetData({
          'ftp_running': false,
          'ftp_connections': 0,
        });
      } else {
        final clientsMsg = _activeConnections > 0 ? '$_activeConnections connected' : 'Listening';
        FileService.showFtpNotification(
          title: 'NeoFile FTP Server Running',
          message: '$ftpUrl • $clientsMsg',
        );
        FileService.updateWidgetData({
          'ftp_running': true,
          'ftp_url': ftpUrl,
          'ftp_connections': _activeConnections,
        });
      }
    } catch (_) {}
  }

  Future<bool> start() async {
    if (isRunning) return true;

    await _updateLocalIp();

    if (!await isPortAvailable(config.port)) {
      config.port = await findAvailablePort(config.port);
    }

    try {
      _controlServer = await ServerSocket.bind(InternetAddress.anyIPv4, config.port);
      _controlServer!.listen(_handleClientConnection);

      _state = FtpServerState.running;
      _log('FTP Server started on $localIp:$port');
      _syncNotification();
      notifyListeners();
      return true;
    } catch (e) {
      _log('Failed to start FTP: $e', isError: true);
      _state = FtpServerState.stopped;
      _syncNotification();
      notifyListeners();
      return false;
    }
  }

  Future<void> stop() async {
    if (!isRunning) return;

    await _controlServer?.close();
    _controlServer = null;
    _state = FtpServerState.stopped;
    _activeConnections = 0;
    _log('FTP Server stopped.');
    _syncNotification();
    notifyListeners();
  }

  void _handleClientConnection(Socket client) {
    _activeConnections++;
    _syncNotification();
    notifyListeners();
    _log('Client connected from ${client.remoteAddress.address}');

    final session = _FtpClientSession(this, client);
    session.start();
  }

  void _clientDisconnected(Socket client) {
    if (_activeConnections > 0) _activeConnections--;
    _syncNotification();
    _log('Client disconnected: ${client.remoteAddress.address}');
    notifyListeners();
  }
}

class _FtpClientSession {
  final FtpServerService server;
  final Socket controlSocket;
  String _currentDir = '/';
  bool _isAuthenticated = false;
  String? _pendingUser;
  ServerSocket? _passiveDataServer;
  Socket? _activeDataSocket;

  _FtpClientSession(this.server, this.controlSocket);

  void start() {
    controlSocket.write('220 NeoFile FTP Server Ready\r\n');
    controlSocket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _handleCommand,
          onError: (_) => _close(),
          onDone: _close,
        );
  }

  void _send(String response) {
    try {
      controlSocket.write('$response\r\n');
    } catch (_) {}
  }

  void _close() {
    _passiveDataServer?.close();
    _activeDataSocket?.close();
    controlSocket.close();
    server._clientDisconnected(controlSocket);
  }

  String _resolveAbsolutePath(String relative) {
    if (relative.startsWith('/')) {
      return p.normalize(p.join(server.config.rootDirectory, relative.substring(1)));
    }
    return p.normalize(p.join(server.config.rootDirectory, _currentDir.replaceAll(RegExp(r'^/'), ''), relative));
  }

  bool _isSafePath(String targetPath) {
    final root = p.canonicalize(server.config.rootDirectory);
    final target = p.canonicalize(targetPath);
    return target == root || p.isWithin(root, target);
  }

  Future<Socket?> _openDataConnection() async {
    if (_passiveDataServer != null) {
      final completer = Completer<Socket?>();
      late StreamSubscription sub;
      sub = _passiveDataServer!.listen((socket) {
        sub.cancel();
        _passiveDataServer?.close();
        _passiveDataServer = null;
        completer.complete(socket);
      }, onError: (_) {
        completer.complete(null);
      });
      return completer.future.timeout(const Duration(seconds: 15), onTimeout: () {
        sub.cancel();
        _passiveDataServer?.close();
        _passiveDataServer = null;
        return null;
      });
    } else if (_activeDataSocket != null) {
      final s = _activeDataSocket;
      _activeDataSocket = null;
      return s;
    }
    return null;
  }

  Future<void> _handleCommand(String line) async {
    final parts = line.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return;

    final cmd = parts[0].toUpperCase();
    final arg = parts.length > 1 ? parts.sublist(1).join(' ') : '';

    switch (cmd) {
      case 'USER':
        _pendingUser = arg;
        if (server.config.anonymous) {
          _isAuthenticated = true;
          _send('230 User logged in (anonymous mode).');
        } else {
          _send('331 Password required for $arg');
        }
        break;

      case 'PASS':
        if (server.config.anonymous) {
          _isAuthenticated = true;
          _send('230 Anonymous user logged in.');
        } else if (_pendingUser == server.config.username && arg == server.config.password) {
          _isAuthenticated = true;
          _send('230 User logged in.');
        } else {
          _isAuthenticated = false;
          _send('530 Login incorrect.');
        }
        break;

      case 'QUIT':
        _send('221 Goodbye.');
        _close();
        break;

      case 'NOOP':
        _send('200 OK');
        break;

      case 'SYST':
        _send('215 UNIX Type: L8');
        break;

      case 'FEAT':
        _send('211-Features:\r\n UTF8\r\n MLST\r\n PASV\r\n SIZE\r\n211 End');
        break;

      case 'OPTS':
        if (arg.toUpperCase() == 'UTF8 ON') {
          _send('200 UTF8 mode enabled');
        } else {
          _send('502 Option not implemented');
        }
        break;

      case 'PWD':
        if (!_isAuthenticated) {
          _send('530 Please login with USER and PASS.');
          return;
        }
        _send('257 "$_currentDir" is current directory');
        break;

      case 'TYPE':
        _send('200 Type set to $arg');
        break;

      case 'PASV':
        if (!_isAuthenticated) {
          _send('530 Login first.');
          return;
        }
        try {
          await _passiveDataServer?.close();
          _passiveDataServer = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
          final pPort = _passiveDataServer!.port;
          final ipParts = server.localIp.split('.');
          final p1 = pPort >> 8;
          final p2 = pPort & 0xFF;
          _send('227 Entering Passive Mode (${ipParts.join(',')},$p1,$p2).');
        } catch (e) {
          _send('425 Can\'t open data connection');
        }
        break;

      case 'EPSV':
        if (!_isAuthenticated) {
          _send('530 Login first.');
          return;
        }
        try {
          await _passiveDataServer?.close();
          _passiveDataServer = await ServerSocket.bind(InternetAddress.anyIPv4, 0);
          _send('229 Entering Extended Passive Mode (|||${_passiveDataServer!.port}|)');
        } catch (e) {
          _send('425 Can\'t open data connection');
        }
        break;

      case 'CWD':
        if (!_isAuthenticated) {
          _send('530 Login first.');
          return;
        }
        final targetPath = _resolveAbsolutePath(arg);
        if (_isSafePath(targetPath) && Directory(targetPath).existsSync()) {
          if (arg.startsWith('/')) {
            _currentDir = arg;
          } else {
            _currentDir = p.posix.normalize(p.posix.join(_currentDir, arg));
          }
          _send('250 Directory successfully changed to "$_currentDir"');
        } else {
          _send('550 Failed to change directory');
        }
        break;

      case 'CDUP':
        if (!_isAuthenticated) {
          _send('530 Login first.');
          return;
        }
        if (_currentDir != '/' && _currentDir.isNotEmpty) {
          _currentDir = p.posix.dirname(_currentDir);
          if (_currentDir == '.') _currentDir = '/';
        }
        _send('200 Directory changed to "$_currentDir"');
        break;

      case 'LIST':
      case 'NLST':
        if (!_isAuthenticated) {
          _send('530 Login first.');
          return;
        }
        final targetPath = _resolveAbsolutePath(arg.isNotEmpty ? arg : '.');
        if (!_isSafePath(targetPath)) {
          _send('550 Access denied: Path outside root directory.');
          return;
        }
        final dataSocket = await _openDataConnection();
        if (dataSocket == null) {
          _send('425 Cannot open data connection');
          return;
        }
        _send('150 Here comes the directory listing.');

        final targetDir = Directory(targetPath);
        final buffer = StringBuffer();
        if (targetDir.existsSync()) {
          try {
            final entities = targetDir.listSync(followLinks: false);
            for (final entity in entities) {
              final stat = entity.statSync();
              final isDir = entity is Directory;
              final name = p.basename(entity.path);
              if (cmd == 'NLST') {
                buffer.write('$name\r\n');
              } else {
                final typeChar = isDir ? 'd' : '-';
                final perm = isDir ? 'rwxr-xr-x' : 'rw-r--r--';
                final size = isDir ? 4096 : stat.size;
                final dateStr = 'Jan 01  2026';
                buffer.write('$typeChar$perm 1 owner group $size $dateStr $name\r\n');
              }
            }
          } catch (_) {}
        }
        try {
          dataSocket.write(buffer.toString());
          await dataSocket.flush();
        } catch (_) {} finally {
          try { await dataSocket.close(); } catch (_) {}
        }
        _send('226 Directory send OK.');
        break;

      case 'SIZE':
        if (!_isAuthenticated) {
          _send('530 Login first.');
          return;
        }
        final filePath = _resolveAbsolutePath(arg);
        if (_isSafePath(filePath) && File(filePath).existsSync()) {
          _send('213 ${File(filePath).lengthSync()}');
        } else {
          _send('550 Could not get file size');
        }
        break;

      case 'RETR':
        if (!_isAuthenticated) {
          _send('530 Login first.');
          return;
        }
        final filePath = _resolveAbsolutePath(arg);
        if (!_isSafePath(filePath) || !File(filePath).existsSync()) {
          _send('550 File not found');
          return;
        }
        final dataSocket = await _openDataConnection();
        if (dataSocket == null) {
          _send('425 Data connection failed');
          return;
        }
        _send('150 Opening binary mode data connection for ${p.basename(filePath)}');
        try {
          final file = File(filePath);
          await file.openRead().pipe(dataSocket);
          _send('226 Transfer complete.');
        } catch (_) {
          _send('426 Connection closed; transfer aborted.');
        } finally {
          try { await dataSocket.close(); } catch (_) {}
        }
        break;

      case 'STOR':
        if (!_isAuthenticated) {
          _send('530 Login first.');
          return;
        }
        if (!server.config.allowWrite) {
          _send('550 Write permission denied');
          return;
        }
        final filePath = _resolveAbsolutePath(arg);
        if (!_isSafePath(filePath)) {
          _send('550 Path outside root directory');
          return;
        }
        final dataSocket = await _openDataConnection();
        if (dataSocket == null) {
          _send('425 Data connection failed');
          return;
        }
        _send('150 Ready to receive data');
        IOSink? sink;
        try {
          final file = File(filePath);
          await file.parent.create(recursive: true);
          sink = file.openWrite();
          await dataSocket.forEach(sink.add);
          await sink.flush();
          await sink.close();
          sink = null;
          _send('226 File successfully transferred.');
        } catch (e) {
          try { await sink?.close(); } catch (_) {}
          _send('426 Connection closed; transfer aborted.');
        } finally {
          try { await dataSocket.close(); } catch (_) {}
        }
        break;

      case 'DELE':
        if (!_isAuthenticated || !server.config.allowWrite) {
          _send('550 Permission denied');
          return;
        }
        final filePath = _resolveAbsolutePath(arg);
        if (_isSafePath(filePath) && File(filePath).existsSync()) {
          try {
            File(filePath).deleteSync();
            _send('250 File deleted successfully');
          } catch (_) {
            _send('550 Delete failed');
          }
        } else {
          _send('550 File not found');
        }
        break;

      case 'MKD':
        if (!_isAuthenticated || !server.config.allowWrite) {
          _send('550 Permission denied');
          return;
        }
        final dirPath = _resolveAbsolutePath(arg);
        if (_isSafePath(dirPath)) {
          try {
            Directory(dirPath).createSync(recursive: true);
            _send('257 "$arg" created');
          } catch (_) {
            _send('550 Failed to create directory');
          }
        } else {
          _send('550 Path denied');
        }
        break;

      case 'RMD':
        if (!_isAuthenticated || !server.config.allowWrite) {
          _send('550 Permission denied');
          return;
        }
        final dirPath = _resolveAbsolutePath(arg);
        final canonicalRoot = p.canonicalize(server.config.rootDirectory);
        final canonicalTarget = p.canonicalize(dirPath);

        // Security: Prevent wiping the root directory
        if (canonicalTarget == canonicalRoot) {
          _send('550 Cannot remove root directory');
          return;
        }

        if (_isSafePath(dirPath) && Directory(dirPath).existsSync()) {
          try {
            final dir = Directory(dirPath);
            // RFC 959 compliance: Only remove empty directories
            if (dir.listSync(followLinks: false).isNotEmpty) {
              _send('550 Directory not empty');
              return;
            }
            dir.deleteSync(recursive: false);
            _send('250 Directory removed');
          } catch (_) {
            _send('550 Remove failed');
          }
        } else {
          _send('550 Directory not found');
        }
        break;

      default:
        _send('502 Command not implemented');
        break;
    }
  }
}
