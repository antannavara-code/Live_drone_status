import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/drone_status.dart';

class FirestoreService {
  static Future<List<DroneStatus>> fetchFleet() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('drones')
        .get();
    return snapshot.docs
        .map((doc) => DroneStatus.fromJson(doc.data()))
        .toList();
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
          gpsLat: 0.0,
          gpsLng: 0.0,
          altitude: 0.0,
          speed: 0.0,
          heading: 0.0,
          roll: 0.0,
          pitch: 0.0,
          mode: 'N/A',
          armed: false,
          satellites: 0,
          status: 'offline',
        );
      }
      return DroneStatus.fromJson(snapshot.data()!);
    });
  }
}
