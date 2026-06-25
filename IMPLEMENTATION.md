# Drone Tracking System — Implementation Log

## Architecture

```
Cube Orange (ArduPilot)
    ↕ MAVLink (serial: /dev/ttyUSB0, 115200 baud)
Jetson (drone_firebase.py)
    ↕ Firestore (every 2 seconds)
Firebase Firestore (cloud)
    ↕ StreamBuilder (real-time listener)
Flutter App (QR scan → live data)
```

## New Files Created

### `~/drone_tracking/` (Jetson-side — copy to Jetson)

| File | Description |
|------|-------------|
| `drone_firebase.py` | Python script: reads ArduPilot telemetry via pymavlink → pushes to Firestore every 2s. Fields: battery_percent, battery_voltage, gps_lat/lng, altitude, speed, heading, roll, pitch, mode, armed, satellites, status |
| `drone.service` | systemd unit for auto-start on Jetson boot. Path: `/etc/systemd/system/drone.service` |

### `~/Desktop/flutter_app/` (Flutter app)

| File | Description |
|------|-------------|
| `lib/services/firestore_service.dart` | Wrapper that returns `Stream<DroneStatus>` from Firestore document `drones/{droneId}` |

## Files Modified

| File | Changes |
|------|---------|
| `pubspec.yaml` | Added dependencies: `firebase_core ^3.12.1`, `cloud_firestore ^5.6.6`, `mobile_scanner ^6.0.7` |
| `lib/main.dart` | Added `Firebase.initializeApp()` with `DefaultFirebaseOptions.currentPlatform` |
| `lib/models/drone_status.dart` | Replaced old display fields (batteryVoltage String, gpsStatus String, etc.) with MAVLink data fields: batteryPercent int, batteryVoltage double, gpsLat double, gpsLng double, altitude double, speed double, heading double, roll double, pitch double, mode String, armed bool, satellites int, status String. Added display getters (batteryDisplay, gpsDisplay, etc.) |
| `lib/screens/qr_scan_screen.dart` | Added camera-based QR scanning via `mobile_scanner`. Scanner with torch + camera switch. Navigates to `DroneDetailScreen` instead of `DashboardScreen` after scan. Manual text entry retained as fallback. |
| `lib/screens/drone_detail_screen.dart` | Replaced `FutureBuilder` (HTTP API) with `StreamBuilder` (Firestore real-time). Shows live MAVLink data: battery %, voltage, GPS coords, altitude, speed, heading, roll, pitch, satellites, mode, armed status. Cards + telemetry grid + system status section. |
| `lib/services/api_service.dart` | Updated `_demoDrones()` to match new `DroneStatus` constructor with MAVLink-compatible demo data |
| `lib/screens/dashboard_screen.dart` | Updated all field references to use new getters (batteryDisplay, gpsDisplay, etc.) |

## Manual Setup Required (by you)

### 1. Create Firebase project
- Go to https://console.firebase.google.com
- Create new project (or use existing)
- Enable **Cloud Firestore** → choose test mode for now

### 2. Download service account
- Project Settings → Service Accounts → "Generate new private key"
- Save as `serviceAccount.json`
- Upload to Jetson at: `/home/jetson/drone/serviceAccount.json`

### 3. Configure Flutter Firebase
```bash
cd ~/Desktop/flutter_app
dart pub global activate flutterfire_cli
flutterfire configure --project=YOUR_FIREBASE_PROJECT_ID
```
This generates `firebase_options.dart` (needed by main.dart)

### 4. Install on Jetson
```bash
# Copy script to Jetson
scp ~/drone_tracking/drone_firebase.py jetson@JETSON_IP:/home/jetson/drone/
scp ~/drone_tracking/drone.service jetson@JETSON_IP:/tmp/

# On Jetson:
sudo apt-get update
pip3 install pymavlink firebase-admin

# Copy service account
mkdir -p /home/jetson/drone
# (place serviceAccount.json in /home/jetson/drone/)

# Install systemd service
sudo cp /tmp/drone.service /etc/systemd/system/
sudo systemctl enable drone.service
sudo systemctl start drone.service
```

### 5. Wire the hardware
- Connect Cube Orange TELEM2 → Jetson UART (ttyTHS1, 57600 baud) **OR**
- Connect Cube Orange USB → Jetson USB (ttyUSB0, 115200 baud)

### 6. Run Flutter app
```bash
cd ~/Desktop/flutter_app
flutter pub get
flutter run
```

## Data Flow

```
QR Code contains: "DRONE-001"
                    ↓ scan
Phone app opens DroneDetailScreen(droneId: "DRONE-001")
                    ↓
Firestore stream: collection("drones").doc("DRONE-001").snapshots()
                    ↑
Jetson script pushes every 2s:
  db.collection("drones").document("DRONE-001").set({
    battery_percent: 85,
    battery_voltage: 24.8,
    gps_lat: 12.9716,
    gps_lng: 77.5946,
    altitude: 10.5,
    speed: 2.3,
    ...
    last_updated: SERVER_TIMESTAMP
  })
```

## Configuration Options (drone_firebase.py)

| Variable | Default | Description |
|----------|---------|-------------|
| `DRONE_ID` | `DRONE-001` | Must match QR code content |
| `SERIAL_PORT` | `/dev/ttyUSB0` | USB = ttyUSB0, TELEM2 = ttyTHS1 |
| `BAUD_RATE` | `115200` | USB = 115200, TELEM2 = 57600 |
| `SERVICE_ACCOUNT_PATH` | `/home/jetson/drone/serviceAccount.json` | Path to Firebase credentials |
