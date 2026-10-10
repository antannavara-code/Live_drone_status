import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/drone_status.dart';

class FirestoreService {
  static Future<List<DroneStatus>> fetchFleet() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('drones')
        .get();
    return snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data.putIfAbsent('drone_id', () => doc.id);
          return DroneStatus.fromJson(data);
        })
        .toList();
  }

  static Stream<List<DroneStatus>> fleetStream() {
    return FirebaseFirestore.instance
        .collection('drones')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data.putIfAbsent('drone_id', () => doc.id);
        return DroneStatus.fromJson(data);
      }).toList();
    });
  }

  static Stream<DroneStatus> droneStream(String droneId) {
    return FirebaseFirestore.instance
        .collection('drones')
        .doc(droneId)
        .snapshots(includeMetadataChanges: false)
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return DroneStatus(
          droneId: droneId,
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
          status: 'offline',
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
      }
      final data = Map<String, dynamic>.from(snapshot.data()!);
      data.putIfAbsent('drone_id', () => snapshot.id);
      return DroneStatus.fromJson(data);
    });
  }
}
