import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/drone_status.dart';
import 'telemetry_service.dart';
import 'mavlink_encoder.dart';

class _TelemetrySample {
  final double timeSec;
  final DroneStatus drone;

  _TelemetrySample({
    required this.timeSec,
    required this.drone,
  });
}

class FlightRecorder {
  static StreamSubscription<DroneStatus>? _sub;
  static List<_TelemetrySample>? _samples;
  static bool _wasArmed = false;
  static double _startTime = 0;

  static final List<Map<String, dynamic>> _flights = [];
  static bool _loaded = false;

  static final StreamController<void> _onChange = StreamController<void>.broadcast();
  static Stream<void> get onChange => _onChange.stream;

  static String _indexPath = '';
  static String _logsDir = '';

  static Future<void> init(String droneId) async {
    final appDir = await getApplicationDocumentsDirectory();
    _logsDir = '${appDir.path}/flight_logs';
    _indexPath = '$_logsDir/index.json';

    final dir = Directory(_logsDir);
    if (!await dir.exists()) await dir.create(recursive: true);

    if (await File(_indexPath).exists()) {
      final raw = await File(_indexPath).readAsString();
      try {
        final List<dynamic> rawList = jsonDecode(raw);
        final seen = <int>{};
        for (final entry in rawList) {
          final logId = (entry as Map<String, dynamic>)['fc_log_id'] as int?;
          if (logId != null && !seen.add(logId)) continue;
          _flights.add(entry);
        }
      } catch (_) {}
    }
    _loaded = true;

    _sub?.cancel();
    _sub = TelemetryService.droneStream(droneId).listen(_onDroneUpdate);
  }

  static void dispose() {
    _sub?.cancel();
    _sub = null;
    _samples = null;
    _wasArmed = false;
  }

  static void _onDroneUpdate(DroneStatus drone) {
    if (!drone.armed) {
      if (_wasArmed && _samples != null && _samples!.isNotEmpty) {
        _finalizeFlight();
      }
      _wasArmed = false;
      _samples = null;
      return;
    }

    if (!_wasArmed) {
      _wasArmed = true;
      _startTime = DateTime.now().millisecondsSinceEpoch / 1000;
      _samples = [];
    }

    if (_samples == null) return;

    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    _samples!.add(_TelemetrySample(
      timeSec: now - _startTime,
      drone: drone,
    ));
  }

  static Future<void> _finalizeFlight() async {
    if (_samples == null || _samples!.isEmpty) return;

    final flightNumber = _flights.length + 1;
    final startTime = DateTime.now().subtract(
      Duration(milliseconds: (_samples!.last.timeSec * 1000).toInt()),
    );
    final endTime = DateTime.now();
    final durationSec = _samples!.last.timeSec.toInt();
    final csvName = 'flight_$flightNumber.csv';
    final tlogName = 'flight_$flightNumber.tlog';

    // Write CSV
    final csvBuffer = StringBuffer();
    csvBuffer.writeln('time_sec,altitude_m,speed_m_s,heading_deg,'
        'battery_v,gps_lat,gps_lng,armed');
    for (final s in _samples!) {
      final d = s.drone;
      csvBuffer.writeln(
        '${s.timeSec.toStringAsFixed(1)},'
        '${d.altitude.toStringAsFixed(1)},'
        '${d.speed.toStringAsFixed(1)},'
        '${d.heading.toStringAsFixed(1)},'
        '${d.batteryVoltage.toStringAsFixed(2)},'
        '${d.gpsLat.toStringAsFixed(6)},'
        '${d.gpsLng.toStringAsFixed(6)},'
        '${d.armed}',
      );
    }
    await File('$_logsDir/$csvName').writeAsString(csvBuffer.toString());
    final csvStat = await File('$_logsDir/$csvName').stat();

    // Write TLOG
    final tlogBytes = <int>[];
    int seq = 0;
    for (final s in _samples!) {
      final timeMs = (s.timeSec * 1000).round();
      tlogBytes.addAll(encodeTlogEntry(seq, s.drone, s.timeSec, timeMs));
      seq += 5;
    }
    await File('$_logsDir/$tlogName').writeAsBytes(tlogBytes);
    final tlogStat = await File('$_logsDir/$tlogName').stat();

    final entry = {
      'flight_number': flightNumber,
      'start_time': startTime.toIso8601String(),
      'end_time': endTime.toIso8601String(),
      'file_name': csvName,
      'tlog_name': tlogName,
      'size_bytes': csvStat.size,
      'tlog_size_bytes': tlogStat.size,
      'duration_sec': durationSec,
    };

    _flights.add(entry);
    await File(_indexPath).writeAsString(jsonEncode(_flights));
    _onChange.add(null);

    _samples = null;
  }

  static void registerFlight(Map<String, dynamic> entry) {
    _flights.add(entry);
    _saveIndex();
    _onChange.add(null);
  }

  static Future<void> _saveIndex() async {
    try {
      await File(_indexPath).writeAsString(jsonEncode(_flights));
    } catch (e) {
      debugPrint('[FlightRecorder] Failed to save index: $e');
    }
  }

  static List<Map<String, dynamic>> get flights => List.unmodifiable(_flights);
  static String get logsDirectory => _logsDir;
  static bool get isLoaded => _loaded;
}
