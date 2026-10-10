import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../models/drone_status.dart';

enum TcpState { disconnected, connecting, connected, error }

class TcpTelemetryService {
  static const int _defaultPort = 9001;
  static const Duration _reconnectBase = Duration(seconds: 1);
  static const Duration _reconnectMax = Duration(seconds: 30);
  static const int _circuitBreakerThreshold = 5;
  static const Duration _circuitBreakerCooldown = Duration(minutes: 5);

  String _host;
  int _port;
  Socket? _socket;
  StreamSubscription? _socketSub;
  Timer? _reconnectTimer;
  bool _disposed = false;
  int _reconnectAttempt = 0;
  bool _connecting = false;
  int _connectSeq = 0;
  Timer? _watchdogTimer;
  double _lastDataTime = 0;
  String? _lastError;
  TcpState _state = TcpState.disconnected;
  int _consecutiveFailures = 0;
  bool _circuitOpen = false;
  Timer? _circuitTimer;

  /// Invoked when the circuit breaker opens after repeated failures,
  /// giving the app a chance to re-discover the transmitter on the network.
  void Function()? onCircuitOpen;

  final StreamController<DroneStatus> _statusController =
      StreamController<DroneStatus>.broadcast();

  Stream<DroneStatus> get statusStream => _statusController.stream;

  TcpTelemetryService({String host = '127.0.0.1', int port = _defaultPort})
      : _host = host,
        _port = port;

  String get host => _host;
  int get port => _port;
  bool get connected => _socket != null;
  String? get lastError => _lastError;
  TcpState get state => _state;
  bool get circuitOpen => _circuitOpen;
  int get consecutiveFailures => _consecutiveFailures;

  void connect({String? host, int? port}) {
    if (host != null) _host = host;
    if (port != null) _port = port;

    _disposed = false;
    _cancelReconnect();
    _cancelCircuitBreaker();
    _stopWatchdog();
    _closeSocket();
    _socket = null;
    _connecting = false;
    _consecutiveFailures = 0;
    _circuitOpen = false;
    _connectSeq++;
    _doConnect(_connectSeq);
  }

  void disconnect() {
    _disposed = true;
    _cancelReconnect();
    _cancelCircuitBreaker();
    _stopWatchdog();
    _closeSocket();
    _socket = null;
    _connecting = false;
    _state = TcpState.disconnected;
  }

  void reconnect() {
    if (_disposed || _connecting) return;
    connect(host: _host, port: _port);
  }

  void _closeSocket() {
    _stopWatchdog();
    _socketSub?.cancel();
    _socketSub = null;
    _socket?.close();
    _socket = null;
  }

  void _startWatchdog() {
    _stopWatchdog();
    _lastDataTime = DateTime.now().millisecondsSinceEpoch / 1000;
    _watchdogTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (_disposed) return;
      final now = DateTime.now().millisecondsSinceEpoch / 1000;
      if (_socket != null && now - _lastDataTime > 120) {
        debugPrint('[TCP] Watchdog: no data for 120s, reconnecting');
        _socketSub?.cancel();
        _socketSub = null;
        _socket?.close();
        _socket = null;
        _connecting = false;
        _scheduleReconnect();
      }
    });
  }

  void _stopWatchdog() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;
  }

  void _doConnect(int seq) {
    if (_disposed || _connecting) return;
    if (_circuitOpen) {
      debugPrint('[TCP] Circuit breaker open — skipping connect until cooldown expires');
      _state = TcpState.disconnected;
      return;
    }
    _connecting = true;

    debugPrint('[TCP] Connecting to $_host:$_port (seq=$seq)...');
    _lastError = null;
    _state = TcpState.connecting;
    Socket.connect(_host, _port,
            timeout: const Duration(seconds: 30))
        .then((socket) {
      if (seq != _connectSeq) {
        debugPrint('[TCP] Ignoring stale connection seq=$seq (current=$_connectSeq)');
        socket.close();
        return;
      }
      debugPrint('[TCP] Connected to $_host:$_port');
      _lastError = null;
      _state = TcpState.connected;
      _socket = socket;
      _connecting = false;
      _reconnectAttempt = 0;
      _consecutiveFailures = 0;
      _statusController.add(DroneStatus(
        droneId: '_connection_',
        batteryPercent: 0,
        batteryVoltage: 0.0,
        batteryCurrent: 0.0,
        batteryTemperature: 0.0,
        cellCount: 0,
        gpsLat: 0.0,
        gpsLng: 0.0,
        altitude: 0.0,
        speed: 0.0,
        verticalSpeed: 0.0,
        heading: 0.0,
        roll: 0.0,
        pitch: 0.0,
        throttle: 0,
        mode: 'CONNECTED',
        armed: false,
        satellites: 0,
        status: 'connected',
        sensorHealthMask: 0,
        sensorPresentMask: 0,
        cpuLoad: 0.0,
        dropRate: 0.0,
        errorsComm: 0,
        timeBootMs: 0,
        ekfFlags: 0,
        systemStatus: 0,
        statusTexts: [],
        gyroX: 0.0,
        gyroY: 0.0,
        gyroZ: 0.0,
        accelX: 0.0,
        accelY: 0.0,
        accelZ: 0.0,
        rcRssi: 0,
        diskUsage: 0.0,
        diskTotalGb: 0.0,
        lastUpdated: DateTime.now().millisecondsSinceEpoch / 1000.0,
        distanceToHome: 0.0,
      ));

      _socketSub = socket
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          _lastDataTime = DateTime.now().millisecondsSinceEpoch / 1000;
          if (line.trim().isEmpty) return;
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            json.remove('last_updated');
            json.remove('lastUpdated');
            json.remove('timestamp');
            json['local_received_time'] =
                DateTime.now().millisecondsSinceEpoch / 1000.0;
            final status = DroneStatus.fromJson(json);
            debugPrint('[TCP] drone=${status.droneId} lat=${status.gpsLat} lng=${status.gpsLng}');
            _statusController.add(status);
          } catch (e) {
            // Skip malformed lines
          }
        },
        onError: (_) => _onSocketClosed(),
        onDone: () => _onSocketClosed(),
        cancelOnError: false,
      );

      _startWatchdog();
    }).catchError((e) {
      if (seq != _connectSeq) return;
      debugPrint('[TCP] Connection failed: $e');
      _lastError = e.toString();
      _state = TcpState.error;
      _connecting = false;
      _socket = null;
      if (_isConnectionRefused(e)) {
        _consecutiveFailures++;
        if (_consecutiveFailures >= _circuitBreakerThreshold) {
          _openCircuitBreaker();
          return;
        }
      }
      _scheduleReconnect();
    });
  }

  bool _isConnectionRefused(Object error) {
    final s = error.toString();
    return s.contains('Connection refused') ||
        s.contains('ECONNREFUSED') ||
        s.contains('errno = 111') ||
        s.contains('Connection timed out') ||
        s.contains('errno = 110');
  }

  void _openCircuitBreaker() {
    _circuitOpen = true;
    debugPrint('[TCP] Circuit breaker opened — $_circuitBreakerThreshold consecutive failures, cooling down for ${_circuitBreakerCooldown.inMinutes} min');
    onCircuitOpen?.call();
    _circuitTimer = Timer(_circuitBreakerCooldown, () {
      debugPrint('[TCP] Circuit breaker cooldown expired — resetting');
      _consecutiveFailures = 0;
      _circuitOpen = false;
      _scheduleReconnect();
    });
  }

  void _cancelCircuitBreaker() {
    _circuitTimer?.cancel();
    _circuitTimer = null;
  }

  void _onSocketClosed() {
    _stopWatchdog();
    _socketSub?.cancel();
    _socketSub = null;
    _socket = null;
    _connecting = false;
    _state = TcpState.disconnected;
    if (!_circuitOpen) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _reconnectAttempt++;
    _connectSeq++;
    final delay = _reconnectBase * (_reconnectAttempt)
        .clamp(1, _reconnectMax.inSeconds ~/ _reconnectBase.inSeconds);
    _reconnectTimer = Timer(delay, () => _doConnect(_connectSeq));
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void dispose() {
    disconnect();
    _cancelCircuitBreaker();
    _statusController.close();
  }
}
