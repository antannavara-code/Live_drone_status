import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:http/http.dart' as http;
import '../models/drone_status.dart';
import '../models/flight_record.dart';

class ApiService {
  static final Duration _requestTimeout = const Duration(seconds: 10);
  static final Duration _retryDelay = const Duration(milliseconds: 350);
  static final String baseUrl =
      const String.fromEnvironment('API_BASE_URL').isNotEmpty
      ? const String.fromEnvironment('API_BASE_URL')
      : _defaultBaseUrl;

  /// Tracks whether we are currently serving offline demo data.
  static bool isOfflineMode = false;

  static String get _defaultBaseUrl {
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      return 'http://$host:8000';
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
        return 'http://localhost:8000';
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
        return 'http://localhost:8000';
    }
  }

  // ---------------------------------------------------------------------------
  // Offline demo data — returned when the backend is unreachable so the app
  // never shows a blocking error screen.
  // ---------------------------------------------------------------------------

  static List<DroneStatus> _demoDrones() {
    return [
      DroneStatus(
        droneId: 'DRONE-001',
        batteryPercent: 85,
        batteryVoltage: 24.8,
        gpsLat: 12.9716,
        gpsLng: 77.5946,
        altitude: 120.5,
        speed: 0.0,
        heading: 180.0,
        roll: 0.5,
        pitch: -1.2,
        mode: 'STABILIZE',
        armed: false,
        satellites: 12,
        status: 'READY',
      ),
      DroneStatus(
        droneId: 'DRONE-002',
        batteryPercent: 72,
        batteryVoltage: 23.6,
        gpsLat: 12.9340,
        gpsLng: 77.6100,
        altitude: 0.0,
        speed: 0.0,
        heading: 0.0,
        roll: 0.0,
        pitch: 0.0,
        mode: 'STANDBY',
        armed: false,
        satellites: 8,
        status: 'STANDBY',
      ),
      DroneStatus(
        droneId: 'DRONE-003',
        batteryPercent: 45,
        batteryVoltage: 22.9,
        gpsLat: 12.9850,
        gpsLng: 77.5800,
        altitude: 50.2,
        speed: 8.5,
        heading: 270.0,
        roll: 2.1,
        pitch: -3.4,
        mode: 'AUTO',
        armed: true,
        satellites: 14,
        status: 'FLYING',
      ),
    ];
  }

  static List<FlightRecord> _demoFlights(String droneId) {
    final allFlights = <String, List<FlightRecord>>{
      'DRONE-001': [
        FlightRecord(
          missionName: 'Pipeline Patrol',
          flownAt: '2026-05-25 14:20',
          distance: '12.4 km',
          status: 'Completed',
        ),
        FlightRecord(
          missionName: 'Inspection Run',
          flownAt: '2026-05-24 09:55',
          distance: '5.2 km',
          status: 'Completed',
        ),
      ],
      'DRONE-002': [
        FlightRecord(
          missionName: 'Standby Check',
          flownAt: '2026-05-25 11:10',
          distance: '0.0 km',
          status: 'Standby',
        ),
      ],
      'DRONE-003': [
        FlightRecord(
          missionName: 'Survey Mission',
          flownAt: '2026-05-23 17:30',
          distance: '8.9 km',
          status: 'Completed',
        ),
        FlightRecord(
          missionName: 'Waypoint Sweep',
          flownAt: '2026-05-22 13:45',
          distance: '7.6 km',
          status: 'Completed',
        ),
      ],
    };
    return allFlights[droneId] ?? [];
  }

  // ---------------------------------------------------------------------------
  // Public API methods — all gracefully fall back to demo data.
  // ---------------------------------------------------------------------------

  static Future<List<DroneStatus>> fetchDroneList() async {
    try {
      final response = await _getWithRetry(Uri.parse('$baseUrl/drones'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        isOfflineMode = false;
        return data
            .map((item) => DroneStatus.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      // Non-200 status — fall back to demo data
      debugPrint('[ApiService] /drones returned ${response.statusCode}, using demo data');
    } catch (error) {
      debugPrint('[ApiService] Backend unreachable ($error), using demo data');
    }

    isOfflineMode = true;
    return _demoDrones();
  }

  static Future<DroneStatus> fetchDroneStatus(String droneId) async {
    try {
      final response =
          await _getWithRetry(Uri.parse('$baseUrl/drone/$droneId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return DroneStatus.fromJson(data);
      }
    } catch (_) {}

    // Fall back to demo data
    final drones = _demoDrones();
    return drones.firstWhere(
      (d) => d.droneId == droneId,
      orElse: () => drones.first,
    );
  }

  static Future<List<FlightRecord>> fetchRecentFlights(String droneId) async {
    try {
      final response = await _getWithRetry(
        Uri.parse('$baseUrl/drone/$droneId/flights'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map(
                (item) => FlightRecord.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // Fall back to demo data
    return _demoFlights(droneId);
  }

  static Future<http.Response> _getWithRetry(
    Uri uri, {
    int attempts = 3,
  }) async {
    Object? lastError;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        return await http.get(uri).timeout(_requestTimeout);
      } catch (error) {
        lastError = error;
        if (attempt < attempts) {
          await Future<void>.delayed(
            Duration(
              milliseconds: _retryDelay.inMilliseconds * attempt,
            ),
          );
        }
      }
    }

    throw Exception('Unable to reach fleet service at $baseUrl: $lastError');
  }
}
