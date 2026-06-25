class FlightRecord {
  final String missionName;
  final String flownAt;
  final String distance;
  final String status;

  FlightRecord({
    required this.missionName,
    required this.flownAt,
    required this.distance,
    required this.status,
  });

  factory FlightRecord.fromJson(Map<String, dynamic> json) {
    return FlightRecord(
      missionName: json['mission_name'] as String? ?? 'Unknown mission',
      flownAt: json['flown_at'] as String? ?? 'Unknown time',
      distance: json['distance'] as String? ?? '0 km',
      status: json['status'] as String? ?? 'Unknown',
    );
  }
}
