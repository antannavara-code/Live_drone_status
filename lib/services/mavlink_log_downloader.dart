import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/drone_status.dart';
import 'telemetry_service.dart';
import 'flight_recorder.dart';
import 'mavlink_encoder.dart';

enum MavlinkDownloaderState { disconnected, connecting, connected, downloading, error }

class MavlinkLogDownloader {
  static const int _defaultPort = 14551;
  static const int _chunkSize = 90;
  static const Duration _responseTimeout = Duration(seconds: 5);
  static const int _maxRetries = 3;

  static String _host = '192.168.43.198';
  static int _port = _defaultPort;
  static Socket? _socket;
  static StreamSubscription? _socketSub;
  static StreamSubscription<DroneStatus>? _droneSub;
  static bool _disposed = false;
  static bool _connecting = false;
  static int _connectSeq = 0;
  static String? _lastError;
  static MavlinkDownloaderState _state = MavlinkDownloaderState.disconnected;
  static String _logsDir = '';

  // Buffer for binary accumulation
  static final List<int> _buffer = [];

  // Packet sequence number
  static int _seq = 0;

  // Download state
  static bool _downloadInProgress = false;
  static bool _wasArmed = false;
  static int _armDisarmSeq = 0;

  // Pending request tracking
  static Completer<bool>? _pendingCompleter;
  static Timer? _pendingTimer;
  static int _pendingLogId = 0;
  static int _pendingOffset = 0;
  static int _currentOffset = 0;
  static List<_LogEntryInfo> _pendingLogs = [];
  static List<int> _currentData = [];
  static double _progress = 0.0;

  // Events
  static final StreamController<MavlinkDownloaderState> _stateController =
      StreamController<MavlinkDownloaderState>.broadcast();

  static Stream<MavlinkDownloaderState> get stateStream => _stateController.stream;
  static MavlinkDownloaderState get state => _state;
  static String? get lastError => _lastError;
  static double get progress => _progress;
  static bool get isDownloading => _downloadInProgress;
  static String get host => _host;
  static int get port => _port;

  // Auto-import state
  static Timer? _autoImportTimer;
  static String? _autoImportHost;
  static int _autoImportPort = 8080;
  static bool _autoImportEnabled = false;
  static DateTime? _lastAutoImportCheck;
  static final StreamController<bool> _autoImportStateController =
      StreamController<bool>.broadcast();
  static Stream<bool> get autoImportStateStream => _autoImportStateController.stream;
  static bool get isAutoImportEnabled => _autoImportEnabled;
  static DateTime? get lastAutoImportCheck => _lastAutoImportCheck;

  static Future<void> init(String droneId) async {
    _disposed = false;

    final appDir = await getApplicationDocumentsDirectory();
    _logsDir = '${appDir.path}/flight_logs';
    final dir = Directory(_logsDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    final prefs = await SharedPreferences.getInstance();
    _host = prefs.getString('tcp_host') ?? '192.168.43.198';
    _port = prefs.getInt('mavlink_port') ?? _defaultPort;

    _droneSub?.cancel();
    _droneSub = TelemetryService.droneStream(droneId).listen(_onDroneUpdate);

    _connect();

    final autoImport = prefs.getBool('auto_import') ?? false;
    if (autoImport) {
      final savedHost = prefs.getString('jetson_http_host') ?? '192.168.43.190';
      startAutoImport(savedHost);
    }

    Future.delayed(const Duration(seconds: 3), () async {
      try {
        final found = await discoverJetson();
        if (found != null) {
          debugPrint('[MAVLink] Startup: found Jetson at $found');
          final count = await importFromHttpJson(found);
          if (count > 0) {
            debugPrint('[MAVLink] Startup: imported $count log(s) from $found');
          }
          if (!_autoImportEnabled) {
            startAutoImport(found);
          }
        }
      } catch (e) {
        debugPrint('[MAVLink] Startup discovery failed: $e');
      }
    });
  }

  static void dispose() {
    _disposed = true;
    _droneSub?.cancel();
    _droneSub = null;
    _disconnect();
  }

  static void reconnect({String? host, int? port}) {
    if (host != null) _host = host;
    if (port != null) _port = port;
    if (_disposed) return;
    _disconnect();
    _connect();
  }

  static void _connect() {
    if (_disposed || _connecting) return;
    _connecting = true;
    _connectSeq++;
    final seq = _connectSeq;

    debugPrint('[MAVLink] Connecting TCP to $_host:$_port (seq=$seq)');
    _lastError = null;
    _setState(MavlinkDownloaderState.connecting);

    Socket.connect(_host, _port, timeout: const Duration(seconds: 5))
        .then((socket) {
      if (seq != _connectSeq || _disposed) {
        socket.close();
        return;
      }
      debugPrint('[MAVLink] TCP connected to $_host:$_port');
      _socket = socket;
      _connecting = false;
      _lastError = null;
      _setState(MavlinkDownloaderState.connected);

      _socketSub = socket.listen(
        (data) {
          debugPrint('[MAVLink] Received ${data.length} bytes from $_host:$_port  hex=${data.take(20).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
          _onData(data.toList());
        },
        onError: (e) {
          debugPrint('[MAVLink] TCP error: $e');
          _lastError = e.toString();
          _setState(MavlinkDownloaderState.error);
          _onDisconnected();
        },
        onDone: () {
          debugPrint('[MAVLink] TCP connection closed');
          _onDisconnected();
        },
      );
    }).catchError((e) {
      if (seq != _connectSeq || _disposed) return;
      debugPrint('[MAVLink] TCP connect failed: $e');
      _lastError = e.toString();
      _setState(MavlinkDownloaderState.error);
      _connecting = false;
      _socket = null;
      _scheduleReconnect();
    });
  }

  static void _disconnect() {
    _cancelPending();
    _downloadInProgress = false;
    _socketSub?.cancel();
    _socketSub = null;
    _socket?.close();
    _socket = null;
    _connecting = false;
    _buffer.clear();
    _seq = 0;
    _setState(MavlinkDownloaderState.disconnected);
  }

  static void _onDisconnected() {
    _cancelPending();
    _downloadInProgress = false;
    _socketSub?.cancel();
    _socketSub = null;
    _socket = null;
    _connecting = false;
    _buffer.clear();
    _seq = 0;
    if (!_disposed) {
      _setState(MavlinkDownloaderState.disconnected);
      _scheduleReconnect();
    }
  }

  static Timer? _reconnectTimer;
  static int _reconnectAttempt = 0;

  static void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectAttempt++;
    final delay = Duration(seconds: (_reconnectAttempt).clamp(1, 30));
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () => _connect());
  }

  static void _setState(MavlinkDownloaderState newState) {
    _state = newState;
    if (!_disposed) _stateController.add(newState);
  }

  static void _sendBytes(List<int> bytes) {
    debugPrint('[MAVLink] Sending ${bytes.length} bytes to $_host:$_port hex=${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');
    _socket?.add(bytes);
  }

  /// Manually trigger log download (doesn't need arm/disarm)
  static void requestLogs() {
    if (_disposed || _downloadInProgress || _socket == null) return;
    debugPrint('[MAVLink] Manual log download requested');
    _startDownload();
  }

  // ===== Drone arm/disarm detection =====
  static void _onDroneUpdate(DroneStatus drone) {
    if (!drone.armed) {
      if (_wasArmed) {
        _wasArmed = false;
        _armDisarmSeq++;
        _onDisarmed(_armDisarmSeq);
      }
    } else {
      _wasArmed = true;
    }
  }

  static Future<void> _onDisarmed(int seq) async {
    if (_disposed || _downloadInProgress || _socket == null) return;
    debugPrint('[MAVLink] Drone disarmed — starting log download (seq=$seq)');

    // Small delay to let the dust settle
    await Future.delayed(const Duration(seconds: 2));
    if (seq != _armDisarmSeq || _disposed || _socket == null) return;

    _startDownload();
  }

  // ===== MAVLink binary parser =====
  static void _onData(List<int> chunk) {
    _buffer.addAll(chunk);
    _tryParse();
  }

  static void _tryParse() {
    while (_buffer.length >= 6) {
      // Find next STX (0xFE for v1, 0xFD for v2)
      final stxIdxV1 = _buffer.indexOf(0xFE);
      final stxIdxV2 = _buffer.indexOf(0xFD);

      if (stxIdxV1 < 0 && stxIdxV2 < 0) {
        debugPrint('[MAVLink] Discarding ${_buffer.length} bytes — no STX (0xFE/0xFD) found');
        _buffer.clear();
        return;
      }

      final stxIdx = (stxIdxV1 >= 0 && (stxIdxV2 < 0 || stxIdxV1 < stxIdxV2))
          ? stxIdxV1
          : stxIdxV2;

      if (stxIdx > 0) {
        debugPrint('[MAVLink] Skipping $stxIdx garbage bytes before STX');
        _buffer.removeRange(0, stxIdx);
        continue;
      }

      // Determine packet length based on STX type
      final bool isV1 = _buffer[0] == 0xFE;
      int packetLen;
      if (isV1) {
        if (_buffer.length < 6) return;
        final payloadLen = _buffer[1];
        packetLen = payloadLen + 8;
      } else {
        if (_buffer.length < 12) return;
        final payloadLen = _buffer[1];
        final incompat = _buffer[2];
        final sigLen = (incompat & 0x01) != 0 ? 13 : 0;
        packetLen = payloadLen + 12 + sigLen;
      }

      if (_buffer.length < packetLen) return;

      final packet = _buffer.sublist(0, packetLen);
      _buffer.removeRange(0, packetLen);

      debugPrint('[MAVLink] Parsing ${isV1 ? "v1" : "v2"} packet hex=${packet.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}');

      final parsed = parseMavlinkPacket(packet);
      if (parsed != null) {
        _handlePacket(parsed['msgid'] as int, parsed['payload'] as List<int>);
      }
    }
  }

  static void _handlePacket(int msgid, List<int> payload) {
    switch (msgid) {
      case 0: // HEARTBEAT (suppressed unless verbose)
        break;
      case 118: // LOG_ENTRY
        _handleLogEntry(payload);
        break;
      case 120: // LOG_DATA
        _handleLogData(payload);
        break;
      default:
        debugPrint('[MAVLink] Unhandled msgid=$msgid len=${payload.length}');
    }
  }

  // ===== Log entry processing =====
  static void _handleLogEntry(List<int> payload) {
    final entry = parseLogEntry(payload);
    if (entry == null) return;
    debugPrint('[MAVLink] LOG_ENTRY: id=${entry.id} size=${entry.size} num_logs=${entry.numLogs} last=${entry.lastLogNum}');

    // Skip logs already downloaded
    final existing = FlightRecorder.flights
        .map((f) => f['fc_log_id'] as int?)
        .where((id) => id != null)
        .toSet();
    if (existing.contains(entry.id)) {
      debugPrint('[MAVLink] Skipping log ${entry.id} — already downloaded');
      return;
    }

    _pendingLogs.add(_LogEntryInfo(
      id: entry.id,
      size: entry.size,
    ));
  }

  static void _handleLogData(List<int> payload) {
    final data = parseLogData(payload);
    if (data == null) return;
    debugPrint('[MAVLink] LOG_DATA: id=${data.id} offset=${data.offset} count=${data.count}');

    // Check if this matches the pending request
    if (_pendingCompleter == null) return;
    if (_pendingLogId != data.id || _pendingOffset != data.offset) return;

    _cancelTimer();
    _currentData.addAll(data.data.take(data.count));
    _pendingCompleter?.complete(true);
    _pendingCompleter = null;
  }

  // ===== Download orchestration =====
  static void _startDownload() {
    if (_socket == null) {
      debugPrint('[MAVLink] _startDownload: socket is null, aborting');
      return;
    }
    debugPrint('[MAVLink] _startDownload: beginning log download');
    _downloadInProgress = true;
    _setState(MavlinkDownloaderState.downloading);
    _pendingLogs = [];
    _progress = 0.0;

    // Send LOG_REQUEST_END first to clear any stale state on the FC
    _sendBytes(encodeLogRequestEnd(6, 1, seq: _seq++));

    Future.delayed(const Duration(milliseconds: 200), () {
      if (_disposed || _socket == null) return;
      final packet = encodeLogRequestList(6, 1, seq: _seq++);
      debugPrint('[MAVLink] Sending LOG_REQUEST_LIST target=6,1 seq=${_seq - 1}');
      _sendBytes(packet);

      // Wait for LOG_ENTRY responses
      Future.delayed(const Duration(seconds: 8), () {
        if (_disposed) return;
        debugPrint('[MAVLink] LOG_ENTRY wait expired, pendingLogs=${_pendingLogs.length}');
        _processDownloadQueue();
      });
    });
  }

  static Future<void> _processDownloadQueue() async {
    if (_disposed || _pendingLogs.isEmpty) {
      debugPrint('[MAVLink] _processDownloadQueue: no pending logs, finishing');
      _finishDownload();
      return;
    }
    debugPrint('[MAVLink] _processDownloadQueue: ${_pendingLogs.length} logs to download');

    for (final log in _pendingLogs) {
      if (_disposed) break;
      await _downloadSingleLog(log);
    }

    _finishDownload();
  }

  static Future<void> _downloadSingleLog(_LogEntryInfo log) async {
    if (_socket == null || _disposed) return;
    _currentData = [];
    _currentOffset = 0;

    while (_currentOffset < log.size) {
      if (_disposed || _socket == null) return;

      final remaining = log.size - _currentOffset;
      final count = remaining < _chunkSize ? remaining : _chunkSize;

      final sent = await _sendWithRetry(log.id, _currentOffset, count);
      if (!sent) {
        debugPrint('[MAVLink] Failed to download chunk offset=$_currentOffset for log ${log.id}, skipping');
        return;
      }

      _currentOffset += count;
      _progress = _currentOffset.toDouble() / log.size;
    }

    // Save .bin file
    await _saveBinFile(log);
  }

  static Future<bool> _sendWithRetry(int logId, int offset, int count) async {
    for (int attempt = 0; attempt < _maxRetries; attempt++) {
      if (_disposed || _socket == null) return false;

      final packet = encodeLogRequestData(6, 1, logId, offset, count, seq: _seq++);
      _sendBytes(packet);

      final completer = Completer<bool>();
      _pendingCompleter = completer;
      _pendingLogId = logId;
      _pendingOffset = offset;

      _pendingTimer = Timer(_responseTimeout, () {
        if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
          _pendingCompleter!.complete(false);
          _pendingCompleter = null;
        }
      });

      try {
        final result = await completer.future;
        if (result) return true;
      } catch (_) {}

      debugPrint('[MAVLink] Retry ${attempt + 1}/$_maxRetries for log=$logId offset=$offset');
    }
    return false;
  }

  static void _cancelPending() {
    _cancelTimer();
    _pendingCompleter = null;
    _pendingLogs.clear();
    _currentData.clear();
    _downloadInProgress = false;
  }

  static void _cancelTimer() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
  }

  static Future<void> _saveBinFile(_LogEntryInfo log) async {
    try {
      // Find a flight number
      final flights = FlightRecorder.flights;
      final existingNums = flights.map((f) => f['flight_number'] as int).toSet();
      int flightNum = 1;
      while (existingNums.contains(flightNum)) flightNum++;

      final fcName = 'fc_${log.id}.bin';
      await File('$_logsDir/$fcName').writeAsBytes(_currentData);

      FlightRecorder.registerFlight({
        'flight_number': flightNum,
        'fc_log_id': log.id,
        'start_time': DateTime.now().toIso8601String(),
        'end_time': DateTime.now().toIso8601String(),
        'bin_name': fcName,
        'bin_size_bytes': _currentData.length,
        'duration_sec': 0,
        'source': 'flight_controller',
      });

      debugPrint('[MAVLink] Saved bin for fc_log ${log.id} → $_logsDir/$fcName (${_currentData.length} bytes)');
    } catch (e) {
      debugPrint('[MAVLink] Failed to save .bin: $e');
    }
  }

  static void _finishDownload() {
    if (_socket != null) {
      try {
        final end = encodeLogRequestEnd(6, 1, seq: _seq++);
        _sendBytes(end);
      } catch (_) {}
    }

    _downloadInProgress = false;
    _pendingLogs.clear();
    _currentData.clear();
    _progress = 1.0;
    _setState(MavlinkDownloaderState.connected);
  }

  /// Import .bin files from Jetson HTTP server (download_logs.py)
  static Future<int> importFromHttp(String host, {int port = 8080}) async {
    if (_logsDir.isEmpty) {
      final appDir = await getApplicationDocumentsDirectory();
      _logsDir = '${appDir.path}/flight_logs';
      final dir = Directory(_logsDir);
      if (!await dir.exists()) await dir.create(recursive: true);
    }

    final client = HttpClient();
    int imported = 0;

    try {
      // Fetch directory listing
      final request = await client.getUrl(Uri.parse('http://$host:$port/'));
      final response = await request.close();
      if (response.statusCode != 200) {
        debugPrint('[MAVLink] HTTP import: status ${response.statusCode}');
        return 0;
      }
      final body = await response.transform(utf8.decoder).join();

      // Parse .bin links from HTML directory listing
      final binRegex = RegExp(r'''<a href="(fc_(\d+)\.bin)">''');
      final matches = binRegex.allMatches(body);
      if (matches.isEmpty) {
        debugPrint('[MAVLink] HTTP import: no .bin files found');
        return 0;
      }

      final existingIds = FlightRecorder.flights
          .map((f) => f['fc_log_id'] as int?)
          .where((id) => id != null)
          .toSet();

      for (final m in matches) {
        final filename = m.group(1)!;
        final logId = int.parse(m.group(2)!);

        if (existingIds.contains(logId)) {
          debugPrint('[MAVLink] HTTP import: skipping $filename');
          continue;
        }

        // Download .bin
        final fileRequest =
            await client.getUrl(Uri.parse('http://$host:$port/$filename'));
        final fileResponse = await fileRequest.close();
        if (fileResponse.statusCode != 200) {
          debugPrint(
              '[MAVLink] HTTP import: failed $filename (${fileResponse.statusCode})');
          continue;
        }

        final bytes = await fileResponse.fold<List<int>>(
            <int>[], (prev, chunk) => prev..addAll(chunk));

        // Save file
        await File('$_logsDir/$filename').writeAsBytes(bytes);

        // Register with FlightRecorder
        final flights = FlightRecorder.flights;
        final existingNums =
            flights.map((f) => f['flight_number'] as int).toSet();
        int flightNum = 1;
        while (existingNums.contains(flightNum)) flightNum++;

        FlightRecorder.registerFlight({
          'flight_number': flightNum,
          'fc_log_id': logId,
          'start_time': DateTime.now().toIso8601String(),
          'end_time': DateTime.now().toIso8601String(),
          'bin_name': filename,
          'bin_size_bytes': bytes.length,
          'duration_sec': 0,
          'source': 'flight_controller_http',
        });

        imported++;
        debugPrint('[MAVLink] HTTP import: saved $filename ($imported total)');
      }
    } catch (e) {
      debugPrint('[MAVLink] HTTP import error: $e');
      rethrow;
    } finally {
      client.close();
    }

    return imported;
  }

  /// Start background polling of Jetson HTTP server
  static void startAutoImport(String host,
      {int port = 8080, Duration interval = const Duration(seconds: 5)}) {
    _autoImportHost = host;
    _autoImportPort = port;
    _autoImportEnabled = true;
    _autoImportStateController.add(true);
    debugPrint(
        '[MAVLink] Auto-import started: $host:$port every ${interval.inSeconds}s');

    _autoImportTimer?.cancel();
    _autoImportTimer = Timer.periodic(interval, (_) => _autoImportPoll());
    _autoImportPoll();
  }

  static void stopAutoImport() {
    _autoImportEnabled = false;
    _autoImportTimer?.cancel();
    _autoImportTimer = null;
    _autoImportStateController.add(false);
    debugPrint('[MAVLink] Auto-import stopped');
  }

  static Future<void> _autoImportPoll() async {
    if (!_autoImportEnabled) return;
    String? host = _autoImportHost;
    if (host == null || host.isEmpty) return;
    try {
      final count = await importFromHttpJson(host, port: _autoImportPort);
      _lastAutoImportCheck = DateTime.now();
      if (count == 0 && _autoImportHost != null) {
        final found = await discoverJetson(port: _autoImportPort);
        if (found != null && found != _autoImportHost) {
          _autoImportHost = found;
          debugPrint('[MAVLink] Auto-import: discovered Jetson at $found');
          await importFromHttpJson(found, port: _autoImportPort);
        }
      }
    } catch (e) {
      debugPrint('[MAVLink] Auto-import poll error: $e');
      try {
        final found = await discoverJetson(port: _autoImportPort);
        if (found != null) {
          _autoImportHost = found;
          debugPrint('[MAVLink] Auto-import: rediscovered Jetson at $found');
          await importFromHttpJson(found, port: _autoImportPort);
          _lastAutoImportCheck = DateTime.now();
        }
      } catch (_) {}
    }
  }

  /// Scan local subnet for Jetson daemon on port 8080
  static Future<String?> discoverJetson({int port = 8080}) async {
    debugPrint('[MAVLink] Scanning local network for Jetson daemon...');
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 2);

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';

          final futures = <Future<String?>>[];
          for (int i = 1; i <= 254; i++) {
            final ip = '$prefix.$i';
            if (ip == addr.address) continue;
            futures.add(_probeJetson(client, ip, port));
          }

          final results = await Future.wait(futures, eagerError: false);
          for (final result in results) {
            if (result != null) return result;
          }
        }
      }
    } catch (e) {
      debugPrint('[MAVLink] Discovery error: $e');
    } finally {
      client.close();
    }
    return null;
  }

  static Future<String?> _probeJetson(
      HttpClient client, String ip, int port) async {
    try {
      final request =
          await client.getUrl(Uri.parse('http://$ip:$port/api/status'));
      final response = await request.close().timeout(
          const Duration(seconds: 2));
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final data = jsonDecode(body) as Map<String, dynamic>;
        if (data.containsKey('logs')) {
          debugPrint('[MAVLink] Found Jetson at $ip:$port');
          return ip;
        }
      }
    } catch (_) {}
    return null;
  }

  /// Import .bin files using /api/status JSON endpoint
  static Future<int> importFromHttpJson(String host,
      {int port = 8080}) async {
    if (_logsDir.isEmpty) {
      final appDir = await getApplicationDocumentsDirectory();
      _logsDir = '${appDir.path}/flight_logs';
      final dir = Directory(_logsDir);
      if (!await dir.exists()) await dir.create(recursive: true);
    }

    final client = HttpClient();
    int imported = 0;

    try {
      final request =
          await client.getUrl(Uri.parse('http://$host:$port/api/status'));
      final response = await request.close();
      if (response.statusCode != 200) return 0;

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;
      final logs = (data['logs'] as List?) ?? [];

      final existingIds = FlightRecorder.flights
          .map((f) => f['fc_log_id'] as int?)
          .where((id) => id != null)
          .toSet();

      debugPrint('[MAVLink] importFromHttpJson: host=$host, api_logs=${logs.length}, existingIds=$existingIds, flights_count=${FlightRecorder.flights.length}');

      for (final entry in logs) {
        final logId = entry['id'] as int;
        final filename = entry['name'] as String;

        if (existingIds.contains(logId)) {
          debugPrint('[MAVLink] importFromHttpJson: skip log $logId ($filename) - already imported');
          continue;
        }

        final fileRequest =
            await client.getUrl(Uri.parse('http://$host:$port/$filename'));
        final fileResponse = await fileRequest.close();
        if (fileResponse.statusCode != 200) continue;

        final bytes = await fileResponse.fold<List<int>>(
            <int>[], (prev, chunk) => prev..addAll(chunk));

        await File('$_logsDir/$filename').writeAsBytes(bytes);

        final currentIds = FlightRecorder.flights
            .map((f) => f['fc_log_id'] as int?)
            .where((id) => id != null)
            .toSet();
        if (currentIds.contains(logId)) {
          debugPrint('[MAVLink] importFromHttpJson: skip $filename - registered by concurrent call');
          continue;
        }

        final flights = FlightRecorder.flights;
        final existingNums =
            flights.map((f) => f['flight_number'] as int).toSet();
        int flightNum = 1;
        while (existingNums.contains(flightNum)) flightNum++;

        FlightRecorder.registerFlight({
          'flight_number': flightNum,
          'fc_log_id': logId,
          'start_time': DateTime.now().toIso8601String(),
          'end_time': DateTime.now().toIso8601String(),
          'bin_name': filename,
          'bin_size_bytes': bytes.length,
          'duration_sec': 0,
          'source': 'flight_controller_http',
        });

        imported++;
        debugPrint('[MAVLink] Auto-import: saved $filename');
      }
    } catch (e) {
      debugPrint('[MAVLink] importFromHttpJson error: $e');
      rethrow;
    } finally {
      client.close();
    }

    return imported;
  }
}

class _LogEntryInfo {
  final int id;
  final int size;
  _LogEntryInfo({required this.id, required this.size});
}
