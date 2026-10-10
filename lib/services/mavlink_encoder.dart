import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/drone_status.dart';

class _ByteWriter {
  final List<int> _bytes = [];

  void u8(int v) => _bytes.add(v & 0xFF);
  void i8(int v) => _bytes.add(v & 0xFF);
  void u16(int v) { _bytes.add(v & 0xFF); _bytes.add((v >> 8) & 0xFF); }
  void i16(int v) => u16(v);
  void u32(int v) { _bytes.add(v & 0xFF); _bytes.add((v >> 8) & 0xFF); _bytes.add((v >> 16) & 0xFF); _bytes.add((v >> 24) & 0xFF); }
  void i32(int v) => u32(v);
  void f32(double v) {
    final b = ByteData(4)..setFloat32(0, v, Endian.little);
    _bytes.addAll(b.buffer.asUint8List());
  }
  List<int> get bytes => _bytes;
}

class _ByteReader {
  final List<int> _bytes;
  int _offset = 0;
  _ByteReader(this._bytes);
  int u8() => _bytes[_offset++];
  int i16() { final v = (_bytes[_offset] | (_bytes[_offset + 1] << 8)).toSigned(16); _offset += 2; return v; }
  int u16() { final v = _bytes[_offset] | (_bytes[_offset + 1] << 8); _offset += 2; return v; }
  int u32() { final v = _bytes[_offset] | (_bytes[_offset + 1] << 8) | (_bytes[_offset + 2] << 16) | (_bytes[_offset + 3] << 24); _offset += 4; return v; }
  List<int> bytes(int n) { final v = _bytes.sublist(_offset, _offset + n); _offset += n; return v; }
  bool get done => _offset >= _bytes.length;
}

final _crcExtra = <int, int>{
  0: 50,    // HEARTBEAT
  1: 124,   // SYS_STATUS
  2: 137,   // SYSTEM_TIME
  4: 237,   // PING
  11: 217,  // SET_MODE
  20: 214,  // PARAM_REQUEST_READ
  21: 159,  // PARAM_REQUEST_LIST
  22: 220,  // PARAM_VALUE
  24: 168,  // PARAM_SET
  27: 144,  // RAW_IMU
  29: 115,  // SCALED_PRESSURE
  30: 39,   // ATTITUDE
  33: 104,  // GLOBAL_POSITION_INT
  65: 118,  // RC_CHANNELS
  69: 243,  // MANUAL_CONTROL
  74: 20,   // VFR_HUD
  76: 158,  // COMMAND_INT
  147: 154, // BATTERY_STATUS
  253: 83,  // STATUSTEXT
   117: 128, // LOG_REQUEST_LIST
   118: 56,  // LOG_ENTRY
   119: 116, // LOG_REQUEST_DATA
   120: 134, // LOG_DATA
   122: 203, // LOG_REQUEST_END
};

int _crc16(int crc, int data) {
  crc ^= data;
  for (int i = 0; i < 8; i++) {
    if ((crc & 1) != 0) {
      crc = (crc >> 1) ^ 0x8408;
    } else {
      crc >>= 1;
    }
  }
  return crc;
}

int _computeCrc(int msgid, int payloadLen, List<int> payload) {
  int crc = 0xFFFF;
  crc = _crc16(crc, payloadLen);
  for (final b in [...payload]) crc = _crc16(crc, b);
  crc = _crc16(crc, _crcExtra[msgid] ?? 0);
  crc ^= 0xFFFF;
  return crc;
}

List<int> _packet(int seq, int msgid, List<int> payload, {int senderSysid = 250, int senderCompid = 250}) {
  final crc = _computeCrc(msgid, payload.length, payload);

  return [
    0xFE, // STX v1
    payload.length,
    seq,
    senderSysid,
    senderCompid,
    msgid,
    ...payload,
    crc & 0xFF,
    (crc >> 8) & 0xFF,
  ];
}

List<int> _packetV2(int seq, int msgid, List<int> payload, {int senderSysid = 255, int senderCompid = 1}) {
  final len = payload.length;
  const incompat = 0;
  const compat = 0;
  final crc = _computeV2Crc(len, incompat, compat, seq, senderSysid, senderCompid, msgid, payload);

  return [
    0xFD, // STX v2
    len,
    incompat,
    compat,
    seq,
    senderSysid,
    senderCompid,
    msgid & 0xFF,
    (msgid >> 8) & 0xFF,
    (msgid >> 16) & 0xFF,
    ...payload,
    crc & 0xFF,
    (crc >> 8) & 0xFF,
  ];
}

int _computeV2Crc(int len, int incompatFlags, int compatFlags, int seq, int sysid, int compid, int msgid, List<int> payload) {
  int crc = 0xFFFF;
  crc = _crc16(crc, len);
  crc = _crc16(crc, incompatFlags);
  crc = _crc16(crc, compatFlags);
  crc = _crc16(crc, seq);
  crc = _crc16(crc, sysid);
  crc = _crc16(crc, compid);
  crc = _crc16(crc, msgid & 0xFF);
  crc = _crc16(crc, (msgid >> 8) & 0xFF);
  crc = _crc16(crc, (msgid >> 16) & 0xFF);
  for (final b in payload) crc = _crc16(crc, b);
  crc = _crc16(crc, _crcExtra[msgid] ?? 0);
  crc ^= 0xFFFF;
  return crc;
}

// Parse a MAVLink v1 or v2 packet from raw bytes, returns null if incomplete / bad CRC
// Returns {msgid, payload (List<int>)}
Map<String, dynamic>? parseMavlinkPacket(List<int> raw) {
  if (raw.isEmpty) return null;

  if (raw[0] == 0xFE) {
    // MAVLink v1
    if (raw.length < 6) return null;
    final len = raw[1];
    if (raw.length < len + 8) return null;
    final msgid = raw[5];
    final payload = raw.sublist(6, 6 + len);
    final crcReceived = raw[6 + len] | (raw[6 + len + 1] << 8);
    final crcCalc = _computeCrc(msgid, len, payload);
    if (crcReceived != crcCalc) {
      debugPrint('[MAVLink] V1 CRC mismatch: msgid=$msgid crcCalc=0x${crcCalc.toRadixString(16).padLeft(4, '0')} crcRecv=0x${crcReceived.toRadixString(16).padLeft(4, '0')} len=$len extra=${_crcExtra[msgid] ?? 0}');
    }
    return {'msgid': msgid, 'payload': payload, 'len': len};
  }

  if (raw[0] == 0xFD) {
    // MAVLink v2
    if (raw.length < 12) return null;
    final len = raw[1];
    final incompat = raw[2];
    final compat = raw[3];
    final sigLen = (incompat & 0x01) != 0 ? 13 : 0;
    final packetLen = len + 12 + sigLen;
    if (raw.length < packetLen) return null;

    final msgid = raw[7] | (raw[8] << 8) | (raw[9] << 16);
    final payload = raw.sublist(10, 10 + len);
    final crcReceived = raw[10 + len] | (raw[10 + len + 1] << 8);
    final crcCalc = _computeV2Crc(len, incompat, compat, raw[4], raw[5], raw[6], msgid, payload);
    if (crcReceived != crcCalc) {
      debugPrint('[MAVLink] V2 CRC mismatch: msgid=$msgid crcCalc=0x${crcCalc.toRadixString(16).padLeft(4, '0')} crcRecv=0x${crcReceived.toRadixString(16).padLeft(4, '0')} len=$len extra=${_crcExtra[msgid] ?? 0}');
    }
    return {'msgid': msgid, 'payload': payload, 'len': len};
  }

  return null;
}

// ===== Log download messages =====

// LOG_REQUEST_LIST (117)
List<int> encodeLogRequestList(int sysid, int compid, {int seq = 0}) {
  final w = _ByteWriter();
  w.u8(sysid);
  w.u8(compid);
  w.u16(1);  // start: first log id
  w.u16(0);  // end: 0 = all
  return _packetV2(seq, 117, w.bytes);
}

// LOG_REQUEST_DATA (119)
List<int> encodeLogRequestData(int sysid, int compid, int logId, int offset, int count, {int seq = 0}) {
  final w = _ByteWriter();
  w.u8(sysid);
  w.u8(compid);
  w.u16(logId);
  w.u32(offset);
  w.u32(count);
  return _packetV2(seq, 119, w.bytes);
}

// LOG_REQUEST_END (122)
List<int> encodeLogRequestEnd(int sysid, int compid, {int seq = 0}) {
  final w = _ByteWriter();
  w.u8(sysid);
  w.u8(compid);
  return _packetV2(seq, 122, w.bytes);
}

// ==== Log response message types ====
// LOG_ENTRY (118) — returned from drone with log list info
class MavlinkLogEntry {
  final int id;
  final int numLogs;
  final int lastLogNum;
  final int timeUtc;
  final int size;
  MavlinkLogEntry(this.id, this.numLogs, this.lastLogNum, this.timeUtc, this.size);
}

MavlinkLogEntry? parseLogEntry(List<int> payload) {
  if (payload.length < 14) return null;
  final r = _ByteReader(payload);
  return MavlinkLogEntry(r.u16(), r.u16(), r.u16(), r.u32(), r.u32());
}

// LOG_DATA (120) — returned from drone with log data chunk
class MavlinkLogData {
  final int id;
  final int offset;
  final int count;
  final List<int> data;
  MavlinkLogData(this.id, this.offset, this.count, this.data);
}

MavlinkLogData? parseLogData(List<int> payload) {
  if (payload.length < 7) return null;
  // id=u16, ofs=u32, count=u8, data=u8[]
  final r = _ByteReader(payload);
  final id = r.u16();
  final ofs = r.u32();
  final count = r.u8();
  final maxData = payload.length - 7;
  final dataCount = count > maxData ? maxData : count;
  final data = r.bytes(dataCount);
  return MavlinkLogData(id, ofs, count, data);
}

// ===== TLOG recorder messages =====
List<int> _sysStatus(int batRemaining) {
  final w = _ByteWriter();
  w.u32(0xFFFFFFFF); // sensors present
  w.u32(0xFFFFFFFF); // sensors enabled
  w.u32(0xFFFFFFFF); // sensors health
  w.u16(5000);       // load 50%
  w.u16(0);          // voltage (mV)
  w.i16(-1);         // current (cA)
  w.i8(batRemaining); // battery remaining %
  w.u16(0);          // drop rate
  w.u16(0);          // errors comm
  w.u16(0); w.u16(0); w.u16(0); w.u16(0); // errors count
  return w.bytes;
}

List<int> _attitude(int timeMs, double roll, double pitch, double yaw) {
  final w = _ByteWriter();
  w.u32(timeMs);
  w.f32(roll);
  w.f32(pitch);
  w.f32(yaw);
  w.f32(0); // rollspeed
  w.f32(0); // pitchspeed
  w.f32(0); // yawspeed
  return w.bytes;
}

List<int> _globalPosInt(int latDegE7, int lonDegE7, int altMm, int relAltMm, int vx, int vy, int vz, int hdg) {
  final w = _ByteWriter();
  w.i32(latDegE7);
  w.i32(lonDegE7);
  w.i32(altMm);
  w.i32(relAltMm);
  w.i16(vx);
  w.i16(vy);
  w.i16(vz);
  w.u16(hdg);
  return w.bytes;
}

List<int> _vfrHud(double airspeed, double groundspeed, int heading, int throttle, double alt, double climb) {
  final w = _ByteWriter();
  w.f32(airspeed);
  w.f32(groundspeed);
  w.i16(heading);
  w.u16(throttle);
  w.f32(alt);
  w.f32(climb);
  return w.bytes;
}

List<int> _batteryStatus(int voltageMv, int currentCa, int remaining) {
  final w = _ByteWriter();
  w.u8(0);   // id
  w.u8(1);   // function = MAV_BATTERY_FUNCTION_ALL
  w.u8(2);   // type = MAV_BATTERY_TYPE_LIPO
  w.i16(-1); // temperature (unknown)
  for (int i = 0; i < 10; i++) {
    w.u16(i == 0 ? voltageMv : 0);
  }
  w.i16(currentCa);
  w.i32(-1); // current consumed (unknown)
  w.i32(-1); // energy consumed (unknown)
  w.i8(remaining);
  w.i32(-1); // time remaining
  w.u8(0);   // charge state
  return w.bytes;
}

List<int> encodeTlogEntry(int seq, DroneStatus drone, double timeSec, int timeMs) {
  final latDegE7 = (drone.gpsLat * 1e7).round();
  final lonDegE7 = (drone.gpsLng * 1e7).round();
  final altMm = (drone.altitude * 1000).round();
  final relAltMm = altMm;
  final gsCmS = (drone.speed * 100).round();
  final hdgCdeg = (drone.heading * 100).round();
  final batMv = (drone.batteryVoltage * 1000).round();
  final batCa = (drone.batteryCurrent * 100).round();
  final batRem = drone.batteryPercent.clamp(0, 100);

  final ts = drone.lastUpdated > 0
      ? DateTime.fromMillisecondsSinceEpoch((drone.lastUpdated * 1000).round())
      : DateTime.now();
  final micros = ts.microsecondsSinceEpoch;
  final tsBytes = [for (int i = 0; i < 8; i++) (micros >> (i * 8)) & 0xFF];

  final p1 = _packet(seq, 1, _sysStatus(batRem));
  final p2 = _packet(seq + 1, 33, _globalPosInt(latDegE7, lonDegE7, altMm, relAltMm, gsCmS, gsCmS, 0, hdgCdeg));
  final p3 = _packet(seq + 2, 74, _vfrHud(drone.speed, drone.speed, drone.heading.round(), drone.throttle, drone.altitude, drone.verticalSpeed));
  final p4 = _packet(seq + 3, 30, _attitude(timeMs, drone.roll * 3.14159 / 180.0, drone.pitch * 3.14159 / 180.0, drone.heading * 3.14159 / 180.0));
  final p5 = _packet(seq + 4, 147, _batteryStatus(batMv, batCa, batRem));

  return [...tsBytes, ...p1, ...tsBytes, ...p2, ...tsBytes, ...p3, ...tsBytes, ...p4, ...tsBytes, ...p5];
}
