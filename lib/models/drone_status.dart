import 'package:cloud_firestore/cloud_firestore.dart';

class StatusText {
  final int severity;
  final String text;
  final int time;

  StatusText({required this.severity, required this.text, required this.time});

  factory StatusText.fromJson(Map<String, dynamic> json) {
    return StatusText(
      severity: (json['severity'] as num?)?.toInt() ?? 6,
      text: json['text'] as String? ?? '',
      time: (json['time'] as num?)?.toInt() ?? 0,
    );
  }

  String get severityIcon {
    const icons = ['🆘', '🚨', '🔥', '⚠️', '⚠️', 'ℹ️', '✅', '🔍'];
    return icons[severity.clamp(0, icons.length - 1)];
  }

  String get timeDisplay {
    final dt = DateTime.fromMillisecondsSinceEpoch(time * 1000);
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class DroneStatus {
  final String droneId;
  final int batteryPercent;
  final double batteryVoltage;
  final double batteryCurrent;
  final double batteryTemperature;
  final int cellCount;
  final double gpsLat;
  final double gpsLng;
  final double altitude;
  final double speed;
  final double verticalSpeed;
  final double heading;
  final double roll;
  final double pitch;
  final int throttle;
  final String mode;
  final bool armed;
  final int satellites;
  final String status;
  final int sensorHealthMask;
  final int sensorPresentMask;
  final double cpuLoad;
  final double dropRate;
  final int errorsComm;
  final int timeBootMs;
  final int ekfFlags;
  final int systemStatus;
  final List<StatusText> statusTexts;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final double accelX;
  final double accelY;
  final double accelZ;
  final int rcRssi;
  final double lastUpdated;
  final double diskUsage;
  final double diskTotalGb;
  final double distanceToHome;
  final double windSpeed;
  final double windDirection;

  DroneStatus({
    required this.droneId,
    required this.batteryPercent,
    required this.batteryVoltage,
    required this.batteryCurrent,
    required this.batteryTemperature,
    required this.cellCount,
    required this.gpsLat,
    required this.gpsLng,
    required this.altitude,
    required this.speed,
    required this.verticalSpeed,
    required this.heading,
    required this.roll,
    required this.pitch,
    required this.throttle,
    required this.mode,
    required this.armed,
    required this.satellites,
    required this.status,
    required this.sensorHealthMask,
    required this.sensorPresentMask,
    required this.cpuLoad,
    required this.dropRate,
    required this.errorsComm,
    required this.timeBootMs,
    required this.ekfFlags,
    required this.systemStatus,
    required this.statusTexts,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.rcRssi,
    required this.lastUpdated,
    required this.diskUsage,
    required this.diskTotalGb,
    required this.distanceToHome,
    this.windSpeed = 0.0,
    this.windDirection = 0.0,
  });

  DroneStatus copyWith({double? lastUpdated, double? windSpeed, double? windDirection}) {
    return DroneStatus(
      droneId: droneId,
      batteryPercent: batteryPercent,
      batteryVoltage: batteryVoltage,
      batteryCurrent: batteryCurrent,
      batteryTemperature: batteryTemperature,
      cellCount: cellCount,
      gpsLat: gpsLat,
      gpsLng: gpsLng,
      altitude: altitude,
      speed: speed,
      verticalSpeed: verticalSpeed,
      heading: heading,
      roll: roll,
      pitch: pitch,
      throttle: throttle,
      mode: mode,
      armed: armed,
      satellites: satellites,
      status: status,
      sensorHealthMask: sensorHealthMask,
      sensorPresentMask: sensorPresentMask,
      cpuLoad: cpuLoad,
      dropRate: dropRate,
      errorsComm: errorsComm,
      timeBootMs: timeBootMs,
      ekfFlags: ekfFlags,
      systemStatus: systemStatus,
      statusTexts: statusTexts,
      gyroX: gyroX,
      gyroY: gyroY,
      gyroZ: gyroZ,
      accelX: accelX,
      accelY: accelY,
      accelZ: accelZ,
      rcRssi: rcRssi,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      diskUsage: diskUsage,
      diskTotalGb: diskTotalGb,
      distanceToHome: distanceToHome,
      windSpeed: windSpeed ?? this.windSpeed,
      windDirection: windDirection ?? this.windDirection,
    );
  }

  factory DroneStatus.fromJson(Map<String, dynamic> json) {
    final texts = (json['status_texts'] as List<dynamic>?)
            ?.map((e) => StatusText.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return DroneStatus(
      droneId: json['drone_id'] as String? ?? 'UNKNOWN',
      batteryPercent: (json['battery_percent'] as num?)?.toInt() ?? 0,
      batteryVoltage: (json['battery_voltage'] as num?)?.toDouble() ?? 0.0,
      batteryCurrent: (json['battery_current'] as num?)?.toDouble() ?? 0.0,
      batteryTemperature:
          (json['battery_temperature'] as num?)?.toDouble() ?? 0.0,
      cellCount: (json['cell_count'] as num?)?.toInt() ?? 0,
      gpsLat: ((json['gps_lat'] ?? json['lat'] ?? json['latitude']) as num?)?.toDouble() ?? 0.0,
      gpsLng: ((json['gps_lng'] ?? json['lng'] ?? json['longitude']) as num?)?.toDouble() ?? 0.0,
      altitude: (json['altitude'] as num?)?.toDouble() ?? 0.0,
      speed: ((json['speed'] ?? json['ground_speed']) as num?)?.toDouble() ?? 0.0,
      verticalSpeed: ((json['vertical_speed'] ?? json['climb_rate']) as num?)?.toDouble() ?? 0.0,
      heading: (json['heading'] as num?)?.toDouble() ?? 0.0,
      roll: (json['roll'] as num?)?.toDouble() ?? 0.0,
      pitch: (json['pitch'] as num?)?.toDouble() ?? 0.0,
      throttle: (json['throttle'] as num?)?.toInt() ?? 0,
      mode: (json['mode'] ?? json['flight_mode']) as String? ?? 'UNKNOWN',
      armed: json['armed'] as bool? ?? false,
      satellites: ((json['satellites'] ?? json['gps_sats']) as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'idle',
      sensorHealthMask:
          ((json['sensor_health_mask'] as num?)?.toInt() ?? 0),
      sensorPresentMask:
          ((json['sensor_present_mask'] as num?)?.toInt() ?? 0),
      cpuLoad: (json['cpu_load'] as num?)?.toDouble() ?? 0.0,
      dropRate: (json['drop_rate'] as num?)?.toDouble() ?? 0.0,
      errorsComm: (json['errors_comm'] as num?)?.toInt() ?? 0,
      timeBootMs: ((json['time_boot_ms'] as num?)?.toInt() ?? 0),
      ekfFlags: ((json['ekf_flags'] as num?)?.toInt() ?? 0),
      systemStatus: ((json['system_status'] as num?)?.toInt() ?? 0),
      statusTexts: texts,
      gyroX: (json['gyro_x'] as num?)?.toDouble() ?? 0.0,
      gyroY: (json['gyro_y'] as num?)?.toDouble() ?? 0.0,
      gyroZ: (json['gyro_z'] as num?)?.toDouble() ?? 0.0,
      accelX: ((json['accel_x'] ?? json['acce_x']) as num?)?.toDouble() ?? 0.0,
      accelY: ((json['accel_y'] ?? json['acce_y']) as num?)?.toDouble() ?? 0.0,
      accelZ: ((json['accel_z'] ?? json['acce_z']) as num?)?.toDouble() ?? 0.0,
      rcRssi: (json['rc_rssi'] as num?)?.toInt() ?? -1,
      distanceToHome: (json['dist_to_home'] as num?)?.toDouble() ?? 0.0,
      lastUpdated: (() {
        final v = json['last_updated'] ?? json['lastUpdated'] ?? json['timestamp'] ?? json['local_received_time'];
        if (v is Timestamp) return v.toDate().millisecondsSinceEpoch / 1000.0;
        if (v is String) {
          final dt = DateTime.tryParse(v);
          if (dt != null) return dt.millisecondsSinceEpoch / 1000.0;
          return double.tryParse(v) ?? 0.0;
        }
        return (v as num?)?.toDouble() ?? 0.0;
      })(),
      diskUsage: (json['disk_usage'] as num?)?.toDouble() ?? 0.0,
      diskTotalGb: (json['disk_total_gb'] as num?)?.toDouble() ?? 0.0,
    );
  }

  // ── Sensor health bitmask constants ──
  static const int _gyro = 1;
  static const int _accel = 2;
  static const int _mag = 4;
  static const int _baro = 8;
  static const int _gps = 32;
  static const int _motor = 65536;
  static const int _rc = 131072;
  static const int _ahrs = 4194304;
  static const int _battery = 67108864;

  bool get gyroHealthy => sensorHealthMask & _gyro != 0;
  bool get accelHealthy => sensorHealthMask & _accel != 0;
  bool get magHealthy => sensorHealthMask & _mag != 0;
  bool get baroHealthy => sensorHealthMask & _baro != 0;
  bool get gpsHealthy => sensorHealthMask & _gps != 0;
  bool get motorHealthy => sensorHealthMask & _motor != 0;
  bool get rcHealthy => sensorHealthMask & _rc != 0;
  bool get ahrsHealthy => sensorHealthMask & _ahrs != 0;
  bool get batteryHealthy => sensorHealthMask & _battery != 0;

  bool get gyroPresent => sensorPresentMask & _gyro != 0;
  bool get accelPresent => sensorPresentMask & _accel != 0;
  bool get magPresent => sensorPresentMask & _mag != 0;
  bool get baroPresent => sensorPresentMask & _baro != 0;
  bool get gpsPresent => sensorPresentMask & _gps != 0;
  bool get motorPresent => sensorPresentMask & _motor != 0;
  bool get rcPresent => sensorPresentMask & _rc != 0;
  bool get ahrsPresent => sensorPresentMask & _ahrs != 0;
  bool get batteryPresent => sensorPresentMask & _battery != 0;

  double get systemHealthScore {
    final sensors = [
      gyroPresent, accelPresent, magPresent, baroPresent,
      gpsPresent, motorPresent, rcPresent, ahrsPresent, batteryPresent,
    ];
    final health = [
      gyroHealthy, accelHealthy, magHealthy, baroHealthy,
      gpsHealthy, motorHealthy, rcHealthy, ahrsHealthy, batteryHealthy,
    ];
    int presentCount = 0;
    int healthyCount = 0;
    for (int i = 0; i < sensors.length; i++) {
      if (sensors[i]) {
        presentCount++;
        if (health[i]) healthyCount++;
      }
    }
    return presentCount > 0 ? healthyCount / presentCount : 0.0;
  }

  String get systemStatusString {
    if (!isConnected) return 'DISCONNECTED';
    const labels = [
      'UNINIT', 'BOOT', 'CALIBRATING', 'STANDBY', 'ACTIVE',
      'CRITICAL', 'EMERGENCY', 'POWEROFF', 'FLIGHT_TERM',
    ];
    return labels[systemStatus.clamp(0, labels.length - 1)];
  }

  String get batteryDisplay => isConnected ? '${batteryVoltage.toStringAsFixed(1)}V' : '--.-V';
  String get batteryPercentDisplay => isConnected ? '$batteryPercent%' : '--%';
  String get batteryCurrentDisplay => isConnected ? '${batteryCurrent.toStringAsFixed(2)} A' : '--.-- A';
  String get batteryTemperatureDisplay =>
      isConnected ? '${batteryTemperature.toStringAsFixed(1)}°C' : '--.-°C';
  String get cellDisplay => isConnected ? (cellCount > 0 ? '${cellCount}S1P' : '') : '--';
  String get gpsDisplay =>
      isConnected ? '${gpsLat.toStringAsFixed(4)}, ${gpsLng.toStringAsFixed(4)}' : '--.----, --.----';
  String get altitudeDisplay => isConnected ? '${altitude.toStringAsFixed(1)} m' : '---.- m';
  String get speedDisplay => isConnected ? '${speed.toStringAsFixed(1)} m/s' : '--.- m/s';
  String get verticalSpeedDisplay => isConnected ? '${verticalSpeed.toStringAsFixed(1)} m/s' : '--.- m/s';
  String get headingDisplay => isConnected ? '${heading.toStringAsFixed(0)}°' : '---°';
  String get rollDisplay => isConnected ? '${roll.toStringAsFixed(1)}°' : '--.-°';
  String get pitchDisplay => isConnected ? '${pitch.toStringAsFixed(1)}°' : '--.-°';
  String get modeDisplay => isConnected ? mode : '---';
  String get throttleDisplay => isConnected ? '$throttle%' : '--%';
  String get gyroDisplay => isConnected
      ? '(${gyroX.toStringAsFixed(2)}, ${gyroY.toStringAsFixed(2)}, ${gyroZ.toStringAsFixed(2)})'
      : '(--.---, --.---, --.---)';
  String get accelDisplay => isConnected
      ? '(${accelX.toStringAsFixed(2)}, ${accelY.toStringAsFixed(2)}, ${accelZ.toStringAsFixed(2)}) G'
      : '(--.---, --.---, --.---) G';
  String get rcRssiDisplay => isConnected ? (rcRssi >= 0 ? '$rcRssi/255' : 'N/A') : '--';
  bool get isConnected {
    if (lastUpdated <= 0) return false;
    final diff = (DateTime.now().millisecondsSinceEpoch / 1000) - lastUpdated;
    return diff.abs() < 120;
  }
  double get dataAgeSeconds => (DateTime.now().millisecondsSinceEpoch / 1000) - lastUpdated;
  bool get isStale => isConnected && dataAgeSeconds > 20;
  bool get jetsonConnected => isConnected;
  String get satellitesDisplay => isConnected ? '$satellites satellites' : '-- satellites';
  String get armDisplay => isConnected ? (armed ? 'ARMED' : 'DISARMED') : '---';
  String get cpuLoadDisplay => isConnected ? '${cpuLoad.toStringAsFixed(1)}%' : '--.-%';
  String get dropRateDisplay => isConnected ? '${dropRate.toStringAsFixed(1)}%' : '--.-%';
  String get errorsCommDisplay => isConnected ? '$errorsComm errors' : '-- errors';
  String get distanceToHomeDisplay {
    if (!isConnected) return '---.- m';
    if (distanceToHome <= 0) return '0 m';
    if (distanceToHome < 1000) return '${distanceToHome.toStringAsFixed(1)} m';
    return '${(distanceToHome / 1000).toStringAsFixed(2)} km';
  }
  String get windSpeedDisplay => isConnected && windSpeed > 0 ? '${windSpeed.toStringAsFixed(1)} m/s' : '--.- m/s';
  String get windDirectionDisplay {
    if (!isConnected || windSpeed <= 0) return '---°';
    const dirs = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE',
                  'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
    final idx = ((windDirection + 11.25) / 22.5).floor() % 16;
    return '${windDirection.toStringAsFixed(0)}° ${dirs[idx]}';
  }
  String get flightTimeDisplay {
    if (!isConnected) return '--:--:--';
    if (timeBootMs <= 0) return '--:--:--';
    final secs = timeBootMs ~/ 1000;
    final h = (secs ~/ 3600).toString().padLeft(2, '0');
    final m = ((secs % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  // ── 3x3 sensor grid data ──
  static final _gridSensors = [
    SensorDef('Gyro', '🌀', _gyro),
    SensorDef('Accel', '📐', _accel),
    SensorDef('Compass', '🧭', _mag),
    SensorDef('Baro', '📊', _baro),
    SensorDef('GPS', '🛰', _gps),
    SensorDef('Motor', '⚙️', _motor),
  ];
  List<SensorDef> get gridSensors => _gridSensors;
}

class SensorDef {
  final String label;
  final String emoji;
  final int mask;
  const SensorDef(this.label, this.emoji, this.mask);
  bool isHealthy(int healthMask) => healthMask & mask != 0;
  bool isPresent(int presentMask) => presentMask & mask != 0;
}
