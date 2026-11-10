import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

class FtpRemoteFile {
  final String name;
  final bool isDirectory;
  final int size;
  final DateTime? modified;

  FtpRemoteFile({
    required this.name,
    required this.isDirectory,
    required this.size,
    this.modified,
  });

  String formatSize() {
    if (isDirectory) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class FtpDiscoveredServer {
  final String host;
  final int port;
  final String banner;

  FtpDiscoveredServer({required this.host, required this.port, required this.banner});

  String get url => 'ftp://$host:$port';
}

class FtpClientService with ChangeNotifier {
  static final FtpClientService _instance = FtpClientService._internal();
  factory FtpClientService() => _instance;
  static FtpClientService get instance => _instance;

  FtpClientService._internal();

  Socket? _controlSocket;
  StreamSubscription? _socketSub;
  String _currentHost = '';
  int _currentPort = 21;
  String _currentRemoteDir = '/';
  bool _isConnected = false;
  bool _isScanning = false;
  double _transferProgress = 0.0;
  bool _isTransferring = false;
  String _transferStatus = '';

  final List<FtpRemoteFile> _remoteFiles = [];
  final List<FtpDiscoveredServer> _discoveredServers = [];

  bool get isConnected => _isConnected;
  bool get isScanning => _isScanning;
  bool get isTransferring => _isTransferring;
  double get transferProgress => _transferProgress;
  String get transferStatus => _transferStatus;
  String get currentHost => _currentHost;
  int get currentPort => _currentPort;
  String get currentRemoteDir => _currentRemoteDir;
  List<FtpRemoteFile> get remoteFiles => List.unmodifiable(_remoteFiles);
  List<FtpDiscoveredServer> get discoveredServers => List.unmodifiable(_discoveredServers);

  Completer<String>? _cmdCompleter;
  final StringBuffer _responseBuffer = StringBuffer();

  Future<void> _sendCommand(String cmd) async {
    if (_controlSocket == null) throw Exception('Not connected to FTP server');
    _cmdCompleter = Completer<String>();
    _responseBuffer.clear();
    _controlSocket!.write('$cmd\r\n');
    await _controlSocket!.flush();
  }

  Future<String> _executeCommand(String cmd) async {
    await _sendCommand(cmd);
    return await _cmdCompleter!.future.timeout(const Duration(seconds: 12));
  }

  void _onDataReceived(List<int> data) {
    final text = utf8.decode(data, allowMalformed: true);
    _responseBuffer.write(text);

    final lines = _responseBuffer.toString().split('\n');
    for (final line in lines) {
      final trimmed = line.trim();
      // An FTP final response code line is 3 digits followed by space (e.g. "220 Ready" or "230 Logged in")
      if (trimmed.length >= 3 && int.tryParse(trimmed.substring(0, 3)) != null) {
        if (trimmed.length == 3 || trimmed[3] == ' ') {
          if (_cmdCompleter != null && !_cmdCompleter!.isCompleted) {
            _cmdCompleter!.complete(trimmed);
            return;
          }
        }
      }
    }
  }

  Future<bool> connect({
    required String host,
    int port = 21,
    String username = 'anonymous',
    String password = 'anonymous@neofile.app',
    bool isAnonymous = true,
  }) async {
    await disconnect();

    try {
      _controlSocket = await Socket.connect(host, port, timeout: const Duration(seconds: 8));
      _currentHost = host;
      _currentPort = port;

      _cmdCompleter = Completer<String>();
      _responseBuffer.clear();
      _socketSub = _controlSocket!.listen(
        _onDataReceived,
        onError: (_) => disconnect(),
        onDone: () => disconnect(),
      );

      // Wait for 220 banner
      final banner = await _cmdCompleter!.future.timeout(const Duration(seconds: 8));
      if (!banner.startsWith('220')) {
        await disconnect();
        return false;
      }

      // Send USER
      final user = isAnonymous ? 'anonymous' : username;
      final userResp = await _executeCommand('USER $user');
      if (userResp.startsWith('331')) {
        // Need password
        final pass = isAnonymous ? 'guest@neofile.app' : password;
        final passResp = await _executeCommand('PASS $pass');
        if (!passResp.startsWith('230')) {
          await disconnect();
          return false;
        }
      } else if (!userResp.startsWith('230')) {
        await disconnect();
        return false;
      }

      // Switch to binary mode
      await _executeCommand('TYPE I');

      _isConnected = true;
      _currentRemoteDir = '/';
      notifyListeners();

      await refreshDirectory();
      return true;
    } catch (e) {
      await disconnect();
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_controlSocket != null) {
      try {
        _controlSocket!.write('QUIT\r\n');
        await _controlSocket!.flush();
      } catch (_) {}
      try {
        await _socketSub?.cancel();
        await _controlSocket?.close();
      } catch (_) {}
    }
    _controlSocket = null;
    _socketSub = null;
    _isConnected = false;
    _remoteFiles.clear();
    _currentRemoteDir = '/';
    notifyListeners();
  }

  Future<Socket> _openPassiveDataSocket() async {
    final pasvResp = await _executeCommand('PASV');
    // Format: 227 Entering Passive Mode (h1,h2,h3,h4,p1,p2).
    final start = pasvResp.indexOf('(');
    final end = pasvResp.indexOf(')');
    if (start == -1 || end == -1) throw Exception('Invalid PASV response: $pasvResp');

    final parts = pasvResp.substring(start + 1, end).split(',').map((s) => int.parse(s.trim())).toList();
    if (parts.length != 6) throw Exception('Malformed PASV address: $pasvResp');

    final dataIp = '${parts[0]}.${parts[1]}.${parts[2]}.${parts[3]}';
    final dataPort = parts[4] * 256 + parts[5];

    // Connect to data port (use currentHost if dataIp is internal private 0.0.0.0 or 127.0.0.1)
    final connectHost = (dataIp == '0.0.0.0' || dataIp == '127.0.0.1') ? _currentHost : dataIp;
    return await Socket.connect(connectHost, dataPort, timeout: const Duration(seconds: 8));
  }

  Future<void> refreshDirectory([String? dirPath]) async {
    if (!_isConnected) return;

    final targetDir = dirPath ?? _currentRemoteDir;
    try {
      if (targetDir != _currentRemoteDir) {
        await _executeCommand('CWD $targetDir');
        _currentRemoteDir = targetDir;
      }

      final dataSocket = await _openPassiveDataSocket();
      _sendCommand('LIST');

      final listBuffer = StringBuffer();
      final completer = Completer<void>();

      dataSocket.listen(
        (chunk) {
          listBuffer.write(utf8.decode(chunk, allowMalformed: true));
        },
        onDone: () {
          dataSocket.close();
          completer.complete();
        },
        onError: (e) {
          dataSocket.close();
          completer.completeError(e);
        },
      );

      await completer.future;

      // Wait for "226 Transfer complete" on control socket
      await _cmdCompleter?.future.timeout(const Duration(seconds: 8));

      _remoteFiles.clear();
      final lines = listBuffer.toString().split('\n');
      for (final line in lines) {
        final parsed = _parseListLine(line.trim());
        if (parsed != null) {
          _remoteFiles.add(parsed);
        }
      }

      // Sort: folders first, then alphabetical
      _remoteFiles.sort((a, b) {
        if (a.isDirectory && !b.isDirectory) return -1;
        if (!a.isDirectory && b.isDirectory) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      notifyListeners();
    } catch (e) {
      notifyListeners();
    }
  }

  FtpRemoteFile? _parseListLine(String line) {
    if (line.isEmpty || line.startsWith('total')) return null;

    // Unix style: drwxr-xr-x 1 user group 4096 Nov 10 12:00 FolderName
    // Windows IIS style: 11-10-26 12:00PM <DIR> FolderName
    if (line.startsWith('d') || line.startsWith('-')) {
      final isDir = line.startsWith('d');
      final tokens = line.split(RegExp(r'\s+'));
      if (tokens.length >= 9) {
        final size = int.tryParse(tokens[4]) ?? 0;
        final name = tokens.sublist(8).join(' ');
        if (name == '.' || name == '..') return null;
        return FtpRemoteFile(name: name, isDirectory: isDir, size: size);
      }
    } else if (line.contains('<DIR>')) {
      // Windows style directory
      final parts = line.split('<DIR>');
      if (parts.length == 2) {
        final name = parts[1].trim();
        if (name == '.' || name == '..') return null;
        return FtpRemoteFile(name: name, isDirectory: true, size: 0);
      }
    } else {
      // Windows style file: 11-10-26 12:00PM 123456 filename.txt
      final tokens = line.split(RegExp(r'\s+'));
      if (tokens.length >= 4) {
        final size = int.tryParse(tokens[2]) ?? 0;
        final name = tokens.sublist(3).join(' ');
        return FtpRemoteFile(name: name, isDirectory: false, size: size);
      }
    }
    return null;
  }

  Future<void> navigateUp() async {
    if (!_isConnected || _currentRemoteDir == '/' || _currentRemoteDir.isEmpty) return;
    final parent = p.posix.dirname(_currentRemoteDir);
    await refreshDirectory(parent.isEmpty ? '/' : parent);
  }

  Future<bool> downloadFile(
    FtpRemoteFile remoteFile,
    String localDestFolder, {
    Function(double progress)? onProgress,
  }) async {
    if (!_isConnected || remoteFile.isDirectory) return false;

    _isTransferring = true;
    _transferProgress = 0.0;
    _transferStatus = 'Downloading ${remoteFile.name}...';
    notifyListeners();

    try {
      final dataSocket = await _openPassiveDataSocket();
      await _executeCommand('TYPE I');
      _sendCommand('RETR ${remoteFile.name}');

      final localPath = p.join(localDestFolder, remoteFile.name);
      final file = File(localPath);
      await file.parent.create(recursive: true);
      final sink = file.openWrite();

      int receivedBytes = 0;
      final completer = Completer<void>();

      dataSocket.listen(
        (chunk) {
          sink.add(chunk);
          receivedBytes += chunk.length;
          if (remoteFile.size > 0) {
            _transferProgress = (receivedBytes / remoteFile.size).clamp(0.0, 1.0);
            onProgress?.call(_transferProgress);
            notifyListeners();
          }
        },
        onDone: () async {
          await sink.flush();
          await sink.close();
          await dataSocket.close();
          completer.complete();
        },
        onError: (err) async {
          await sink.close();
          await dataSocket.close();
          completer.completeError(err);
        },
      );

      await completer.future;
      await _cmdCompleter?.future.timeout(const Duration(seconds: 8));

      _isTransferring = false;
      _transferProgress = 1.0;
      _transferStatus = 'Download complete';
      notifyListeners();
      return true;
    } catch (e) {
      _isTransferring = false;
      _transferStatus = 'Download failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> uploadFile(File localFile, {Function(double progress)? onProgress}) async {
    if (!_isConnected || !localFile.existsSync()) return false;

    final fileName = p.basename(localFile.path);
    final fileSize = localFile.lengthSync();

    _isTransferring = true;
    _transferProgress = 0.0;
    _transferStatus = 'Uploading $fileName...';
    notifyListeners();

    try {
      final dataSocket = await _openPassiveDataSocket();
      await _executeCommand('TYPE I');
      _sendCommand('STOR $fileName');

      int sentBytes = 0;
      final stream = localFile.openRead();

      await for (final chunk in stream) {
        dataSocket.add(chunk);
        sentBytes += chunk.length;
        if (fileSize > 0) {
          _transferProgress = (sentBytes / fileSize).clamp(0.0, 1.0);
          onProgress?.call(_transferProgress);
          notifyListeners();
        }
      }

      await dataSocket.flush();
      await dataSocket.close();

      await _cmdCompleter?.future.timeout(const Duration(seconds: 8));

      _isTransferring = false;
      _transferProgress = 1.0;
      _transferStatus = 'Upload complete';
      notifyListeners();

      await refreshDirectory();
      return true;
    } catch (e) {
      _isTransferring = false;
      _transferStatus = 'Upload failed: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRemoteItem(FtpRemoteFile item) async {
    if (!_isConnected) return false;
    try {
      if (item.isDirectory) {
        await _executeCommand('RMD ${item.name}');
      } else {
        await _executeCommand('DELE ${item.name}');
      }
      await refreshDirectory();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createRemoteFolder(String name) async {
    if (!_isConnected || name.trim().isEmpty) return false;
    try {
      await _executeCommand('MKD ${name.trim()}');
      await refreshDirectory();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<FtpDiscoveredServer>> scanLocalNetworkForFtp({int timeoutMs = 450}) async {
    _isScanning = true;
    _discoveredServers.clear();
    notifyListeners();

    try {
      final interfaces = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLinkLocal: false);
      String? localIp;
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback && !addr.address.startsWith('10.0.2.')) {
            localIp = addr.address;
            break;
          }
        }
        if (localIp != null) break;
      }

      if (localIp == null || localIp == '127.0.0.1') {
        _isScanning = false;
        notifyListeners();
        return _discoveredServers;
      }

      final lastDot = localIp.lastIndexOf('.');
      final subnet = localIp.substring(0, lastDot + 1);

      final commonPorts = [21, 2121];
      final futures = <Future>[];

      // Scan local subnet (up to 254 addresses) in concurrent batches
      for (int i = 1; i <= 254; i++) {
        final targetIp = '$subnet$i';
        for (final port in commonPorts) {
          futures.add(_probeFtpHost(targetIp, port, timeoutMs));
        }

        if (futures.length >= 40) {
          await Future.wait(futures);
          futures.clear();
        }
      }

      if (futures.isNotEmpty) {
        await Future.wait(futures);
      }
    } catch (_) {}

    _isScanning = false;
    notifyListeners();
    return _discoveredServers;
  }

  Future<void> _probeFtpHost(String ip, int port, int timeoutMs) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: Duration(milliseconds: timeoutMs));
      final completer = Completer<String>();
      socket.listen(
        (data) {
          final str = utf8.decode(data, allowMalformed: true);
          if (!completer.isCompleted) completer.complete(str);
        },
        onError: (_) {},
        onDone: () {
          if (!completer.isCompleted) completer.complete('');
        },
      );

      final banner = await completer.future.timeout(Duration(milliseconds: timeoutMs + 100), onTimeout: () => '');
      await socket.close();

      if (banner.startsWith('220')) {
        final server = FtpDiscoveredServer(host: ip, port: port, banner: banner.trim());
        if (!_discoveredServers.any((s) => s.host == ip && s.port == port)) {
          _discoveredServers.add(server);
          notifyListeners();
        }
      }
    } catch (_) {}
  }
}
