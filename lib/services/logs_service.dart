import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'flight_recorder.dart';

class FlightLog {
  final String fileName;
  final int flightNumber;
  final int sizeBytes;
  final DateTime? startTime;
  final DateTime? endTime;
  final DateTime uploadedAt;
  final int durationSec;
  final String filePath;
  final String? storagePath;
  final String? data;
  final bool isLocal;
  final List<String> cloudFields;

  FlightLog({
    required this.fileName,
    required this.flightNumber,
    required this.sizeBytes,
    this.startTime,
    this.endTime,
    required this.uploadedAt,
    this.durationSec = 0,
    this.filePath = '',
    this.storagePath,
    this.data,
    required this.isLocal,
    this.cloudFields = const [],
  });

  String get displayLabel => 'Flight $flightNumber';

  String get dateDisplay {
    final dt = startTime ?? uploadedAt;
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
  }

  String get timeDisplay {
    final dt = startTime ?? uploadedAt;
    final hour = dt.hour;
    final min = dt.minute.toString().padLeft(2, '0');
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final h12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$h12:$min $ampm';
  }

  String get durationDisplay {
    if (durationSec == 0) return '—';
    final h = durationSec ~/ 3600;
    final m = (durationSec % 3600) ~/ 60;
    final s = durationSec % 60;
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  String get sizeDisplay {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  bool get hasData => data != null && data!.isNotEmpty;
  bool get hasStorage => storagePath != null && storagePath!.isNotEmpty;

  static void dumpDocFields(String docId, Map<String, dynamic> data) {
    debugPrint('===== Firestore doc $docId =====');
    for (final entry in data.entries) {
      final val = entry.value;
      final typeStr = val is String ? 'String(${val.length} chars)'
          : val is num ? '${val.runtimeType}($val)'
          : val is Timestamp ? 'Timestamp(${val.toDate()})'
          : val is List ? 'List(${val.length} items)'
          : val is Map ? 'Map(${val.length} keys)'
          : '${val.runtimeType}';
      debugPrint('  ${entry.key}: $typeStr');
      if (val is String && val.length > 20) {
        final previewLen = val.length > 80 ? 80 : val.length;
        debugPrint('    preview: ${val.substring(0, previewLen)}...');
      }
    }
    debugPrint('==============================');
  }

  static FlightLog fromFirestore(String docId, Map<String, dynamic> data) {
    dumpDocFields(docId, data);

    final uploadedAt = (() {
      final v = data['uploaded_at'];
      if (v is Timestamp) return v.toDate();
      if (v is String) return DateTime.tryParse(v) ?? DateTime.now();
      return DateTime.now();
    })();

    // Try every possible field name for data
    String? findData(Map<String, dynamic> map) {
      for (final key in map.keys) {
        final val = map[key];
        if (val is String && val.isNotEmpty && val.length > 50) {
          return val;
        }
      }
      return null;
    }

    String? findStorage(Map<String, dynamic> map) {
      for (final key in ['storage_path', 'storagePath', 'storage', 'file_path', 'path', 'url']) {
        final val = map[key];
        if (val is String && val.isNotEmpty) return val;
      }
      return null;
    }

    final storagePath = findStorage(data);
    final logData = data['data'] as String? ?? findData(data);

    return FlightLog(
      fileName: data['file_name'] as String? ?? '',
      flightNumber: (data['flight_number'] as num?)?.toInt() ?? 0,
      sizeBytes: (data['size_bytes'] as num?)?.toInt() ?? 0,
      uploadedAt: uploadedAt,
      storagePath: storagePath,
      data: logData,
      isLocal: false,
      cloudFields: data.keys.toList()..sort(),
    );
  }
}

class DownloadedFile {
  final String fileName;
  final String filePath;
  final int sizeBytes;
  final DateTime downloadedAt;
  final int flightNumber;

  DownloadedFile({
    required this.fileName,
    required this.filePath,
    required this.sizeBytes,
    required this.downloadedAt,
    required this.flightNumber,
  });

  String get sizeDisplay {
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) return '${(sizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class LogsService {
  static final StreamController<List<FlightLog>> _controller =
      StreamController<List<FlightLog>>.broadcast();
  static StreamSubscription<void>? _changeSub;
  static StreamSubscription<QuerySnapshot>? _firestoreSub;
  static List<FlightLog> _cloudLogs = [];

  static Stream<List<FlightLog>> logsStream(String droneId) {
    _changeSub ??= FlightRecorder.onChange.listen((_) => _emitLogs());
    _firestoreSub ??= FirebaseFirestore.instance
        .collection('flight_logs')
        .where('drone_id', isEqualTo: droneId)
        .snapshots()
        .listen((snapshot) {
      _cloudLogs = snapshot.docs.map((doc) {
        return FlightLog.fromFirestore(doc.id, doc.data());
      }).toList();
      _emitLogs();
    });
    _emitLogs();
    return _controller.stream;
  }

  static void _emitLogs() {
    final localLogs = FlightRecorder.flights.where((entry) {
      return entry['bin_name'] != null;
    }).map((entry) {
      final startTime = _parseDt(entry['start_time']);
      final endTime = _parseDt(entry['end_time']);
      final fileName = entry['bin_name'] as String;
      final sizeBytes = (entry['bin_size_bytes'] as num?)?.toInt() ?? 0;

      return FlightLog(
        fileName: fileName,
        flightNumber: entry['flight_number'] as int,
        sizeBytes: sizeBytes,
        startTime: startTime,
        endTime: endTime,
        uploadedAt: endTime ?? DateTime.now(),
        durationSec: (entry['duration_sec'] as num?)?.toInt() ?? 0,
        filePath: '${FlightRecorder.logsDirectory}/$fileName',
        isLocal: true,
      );
    }).toList();

    final localNumbers = localLogs.map((l) => l.flightNumber).toSet();
    final merged = [...localLogs];
    for (final cloud in _cloudLogs) {
      if (localNumbers.contains(cloud.flightNumber)) continue;
      if (!cloud.fileName.endsWith('.bin')) continue;
      merged.add(cloud);
    }
    merged.sort((a, b) => b.flightNumber.compareTo(a.flightNumber));
    _controller.add(merged);
  }

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  static String _lastSavePath = '';

  static String get saveLocationLabel {
    if (_lastSavePath.isEmpty) return 'Downloading...';
    return _lastSavePath;
  }

  static Future<String> downloadLog(FlightLog log) async {
    String dirPath;

    // Try public Downloads path first
    if (Platform.isAndroid) {
      dirPath = '/storage/emulated/0/Download/DroneLogs';
      try {
        final dir = Directory(dirPath);
        if (!await dir.exists()) await dir.create(recursive: true);
        // Verify writable
        final testFile = File('$dirPath/.test');
        await testFile.writeAsString('test');
        await testFile.delete();
      } catch (_) {
        dirPath = '${(await getApplicationDocumentsDirectory()).path}/flight_logs';
      }
    } else {
      final downloads = await getDownloadsDirectory();
      dirPath = downloads != null
          ? '${downloads.path}/DroneLogs'
          : '${(await getApplicationDocumentsDirectory()).path}/flight_logs';
    }

    final dir = Directory(dirPath);
    if (!await dir.exists()) await dir.create(recursive: true);
    final destPath = '${dir.path}/${log.fileName}';

    _lastSavePath = destPath;

    if (log.isLocal) {
      final src = File(log.filePath);
      if (!await src.exists()) throw Exception('Log file not found');
      await src.copy(destPath);
      return destPath;
    }

    // Try storage path
    if (log.hasStorage) {
      try {
        await FirebaseStorage.instance.ref(log.storagePath!).writeToFile(File(destPath));
        return destPath;
      } catch (e) {
        debugPrint('[LogsService] Storage download failed: $e');
        // Fall through to try data field
      }
    }

    // Try data field (base64 or raw text)
    if (log.hasData) {
      try {
        await File(destPath).writeAsBytes(base64Decode(log.data!));
        return destPath;
      } catch (_) {
        // Not base64 — write as raw text
        await File(destPath).writeAsString(log.data!);
        return destPath;
      }
    }

    // No source found
    final sizeHint = log.sizeBytes > 0 ? ' (${log.sizeDisplay})' : '';
    final fields = log.cloudFields.isEmpty ? '' : ' — fields: ${log.cloudFields.join(", ")}';
    throw Exception(
      'Log file${sizeHint} — no data field with log content found$fields',
    );
  }

  static Future<String> readFileContent(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw Exception('File not found');
    final len = await file.length();
    if (len > 100 * 1024) {
      return '[File too large to display (${(len / 1024).toStringAsFixed(1)} KB)]\n\nPath: $filePath';
    }
    return await file.readAsString();
  }
}
