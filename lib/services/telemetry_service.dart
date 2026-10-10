import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/drone_status.dart';
import 'firestore_service.dart';
import 'network_discovery.dart';
import 'tcp_telemetry_service.dart';
import 'wind_estimator.dart';

extension _ThrottleExt<T> on Stream<T> {
  Stream<T> throttle(Duration duration) {
    final controller = StreamController<T>.broadcast();
    Timer? timer;
    T? latest;
    var hasPending = false;

    listen(
      (data) {
        if (timer == null || !timer!.isActive) {
          controller.add(data);
          timer = Timer(duration, () {
            if (hasPending) {
              controller.add(latest as T);
              hasPending = false;
            }
          });
        } else {
          latest = data;
          hasPending = true;
        }
      },
      onError: (e) => controller.addError(e),
      onDone: () {
        timer?.cancel();
        if (hasPending && latest != null) controller.add(latest as T);
        controller.close();
      },
    );
    return controller.stream;
  }
}

class TelemetryService {
  static final TcpTelemetryService tcp = TcpTelemetryService();
  static StreamSubscription<DroneStatus>? _fleetTcpSub;
  static StreamSubscription<DroneStatus>? _droneTcpSub;
  static StreamController<DroneStatus>? _droneTcpController;

  static bool get tcpConnected => tcp.connected;
  static String? get tcpLastError => tcp.lastError;
  static TcpState get tcpState => tcp.state;

  static double fallbackLat = 0.0;
  static double fallbackLng = 0.0;

  static final Map<String, double> _fleetLastUpdated = {};
  static final Map<String, double> _droneLastUpdated = {};

  static final Map<String, WindEstimator> _windEstimators = {};

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('tcp_host') ?? '192.168.50.120';
    final port = prefs.getInt('tcp_port') ?? 9001;
    fallbackLat = prefs.getDouble('last_gps_lat') ?? 0.0;
    fallbackLng = prefs.getDouble('last_gps_lng') ?? 0.0;
    tcp.onCircuitOpen = () {
      ensureConnection();
    };
    tcp.connect(host: host, port: port);
  }

  /// Ensures the TCP telemetry link is alive. If the circuit breaker is
  /// open (network likely changed), scans the subnet for the transmitter;
  /// otherwise retries the saved host. No-op when already connected.
  static Future<void> ensureConnection() async {
    if (tcp.connected) return;
    if (tcp.circuitOpen) {
      await _discoverAndConnect();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final host = prefs.getString('tcp_host') ?? '192.168.50.120';
    final port = prefs.getInt('tcp_port') ?? 9001;
    tcp.connect(host: host, port: port);
  }

  static Future<void> _discoverAndConnect() async {
    final found = await NetworkDiscovery.discoverTransmitter();
    if (found != null) {
      final prefs = await SharedPreferences.getInstance();
      final port = prefs.getInt('tcp_port') ?? 9001;
      tcp.connect(host: found, port: port);
    }
  }

  static void _saveGps(DroneStatus s) {
    debugPrint('GPS: lat=${s.gpsLat}, lng=${s.gpsLng}');
    if (s.gpsLat != 0.0 || s.gpsLng != 0.0) {
      fallbackLat = s.gpsLat;
      fallbackLng = s.gpsLng;
      SharedPreferences.getInstance().then((prefs) {
        prefs.setDouble('last_gps_lat', s.gpsLat);
        prefs.setDouble('last_gps_lng', s.gpsLng);
      });
    }
  }

  static Stream<T> _withHeartbeat<T>(
    Stream<T> source, {
    T Function(T original)? refresh,
  }) {
    final controller = StreamController<T>.broadcast();
    T? latest;
    Timer? timer;

    void emit(T value) {
      latest = value;
      controller.add(value);
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (latest != null) {
          controller.add(refresh != null ? refresh(latest!) : latest!);
        }
      });
    }

    source.listen(
      (data) => emit(data),
      onError: (e) => controller.addError(e),
      onDone: () {
        timer?.cancel();
        controller.close();
      },
    );

    return controller.stream;
  }

  static Stream<List<DroneStatus>>? _cachedFleet;
  static Stream<List<DroneStatus>> fleetStream() {
    if (_cachedFleet != null) return _cachedFleet!;
    final firestore = FirestoreService.fleetStream();

    final tcpController = StreamController<List<DroneStatus>>.broadcast();
    final Map<String, DroneStatus> _latest = {};

    _fleetTcpSub?.cancel();
    _fleetTcpSub = tcp.statusStream
        .throttle(const Duration(milliseconds: 200))
        .listen((status) {
      if (status.droneId == '_connection_') return;
      _latest[status.droneId] = status;
      if (_latest.isNotEmpty) {
        tcpController.add(_latest.values.toList());
      }
    });

    final merged = StreamGroup.merge([
      Stream.value(<DroneStatus>[]),
      firestore,
      tcpController.stream,
    ]);

    final deduped = StreamController<List<DroneStatus>>.broadcast();
    merged.listen(
      (list) {
        final filtered = <DroneStatus>[];
        for (final data in list) {
          _saveGps(data);
          final last = _fleetLastUpdated[data.droneId] ?? -1.0;
          if (data.lastUpdated >= last) {
            _fleetLastUpdated[data.droneId] = data.lastUpdated;
            filtered.add(data);
          }
        }
        if (filtered.isNotEmpty) deduped.add(filtered);
      },
      onError: (e) => deduped.addError(e),
      onDone: () => deduped.close(),
    );

    _cachedFleet = _withHeartbeat(deduped.stream);
    return _cachedFleet!;
  }

  static final Map<String, Stream<DroneStatus>> _cachedDrone = {};

  static DroneStatus _emptyStatus(String droneId) => DroneStatus(
        droneId: droneId,
        status: 'connecting',
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
        mode: 'N/A',
        armed: false,
        satellites: 0,
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
        diskUsage: 0.0,
        diskTotalGb: 0.0,
        rcRssi: 0,
        lastUpdated: 0.0,
        distanceToHome: 0.0,
      );

  static Stream<DroneStatus> droneStream(String droneId) {
    final existing = _cachedDrone[droneId];
    if (existing != null) return existing;

    final firestore = FirestoreService.droneStream(droneId);

    _droneTcpController?.close();
    _droneTcpSub?.cancel();
    _droneTcpController = StreamController<DroneStatus>.broadcast();
    _droneTcpSub = tcp.statusStream
        .where((s) => s.droneId != '_connection_')
        .throttle(const Duration(milliseconds: 200))
        .listen((s) {
      _droneTcpController!.add(s);
    }, onError: (_) {});

    final merged = StreamGroup.merge([
      Stream<DroneStatus>.value(_emptyStatus(droneId)),
      firestore,
      _droneTcpController!.stream,
    ]);

    final deduped = StreamController<DroneStatus>.broadcast();
    merged.listen(
      (data) {
        _saveGps(data);
        final last = _droneLastUpdated[droneId] ?? -1.0;
        if (data.lastUpdated >= last) {
          _droneLastUpdated[droneId] = data.lastUpdated;

          final estimator = _windEstimators.putIfAbsent(droneId, () => WindEstimator());
          estimator.update(data.speed, data.heading, data.mode, data.altitude);

          deduped.add(data.copyWith(
            windSpeed: estimator.windSpeed,
            windDirection: estimator.windDirection,
          ));
        }
      },
      onError: (e) => deduped.addError(e),
      onDone: () => deduped.close(),
    );

    final stream = _withHeartbeat(deduped.stream, refresh: (s) => s.copyWith(
      lastUpdated: DateTime.now().millisecondsSinceEpoch / 1000.0,
    ));
    _cachedDrone[droneId] = stream;
    return stream;
  }

  static Future<void> connect({String? host, int? port}) async {
    if (host != null || port != null) {
      final prefs = await SharedPreferences.getInstance();
      if (host != null) await prefs.setString('tcp_host', host);
      if (port != null) await prefs.setInt('tcp_port', port);
    }
    tcp.connect(host: host, port: port);
  }

  static void disconnect() {
    _fleetTcpSub?.cancel();
    _droneTcpSub?.cancel();
    tcp.disconnect();
  }
}

class StreamGroup<T> {
  static Stream<T> merge<T>(Iterable<Stream<T>> streams) {
    final controller = StreamController<T>.broadcast();
    int active = 0;
    for (final stream in streams) {
      active++;
      stream.listen(
        (data) => controller.add(data),
        onError: (e) {},
        onDone: () {
          active--;
          if (active == 0) controller.close();
        },
      );
    }
    return controller.stream;
  }
}
