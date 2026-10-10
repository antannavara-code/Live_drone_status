import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NetworkDiscovery {
  NetworkDiscovery._();

  static const int defaultPort = 9001;
  static const int _batchSize = 32;
  static const Duration _probeTimeout = Duration(milliseconds: 500);
  static const Duration _readTimeout = Duration(milliseconds: 600);

  static bool _scanning = false;

  static bool get scanning => _scanning;

  /// Scan the local subnet for the FWD FYNEX transmitter broadcasting
  /// JSON telemetry on [port]. Saves the found IP to SharedPreferences
  /// and returns it, or null if nothing was found.
  static Future<String?> discoverTransmitter({int port = defaultPort}) async {
    if (_scanning) return null;
    _scanning = true;
    debugPrint('[Discovery] Scanning for transmitter on port $port...');
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          final prefix = '${parts[0]}.${parts[1]}.${parts[2]}';

          final candidates = <String>[
            for (var i = 1; i <= 254; i++)
              if ('$prefix.$i' != addr.address) '$prefix.$i',
          ];

          debugPrint('[Discovery] Scanning $prefix.1-$prefix.254 (${candidates.length} hosts)...');
          final found = await _scanBatch(candidates, port);
          if (found != null) {
            await _saveHost(found, port);
            return found;
          }
        }
      }
    } catch (e) {
      debugPrint('[Discovery] Error: $e');
    } finally {
      _scanning = false;
    }
    debugPrint('[Discovery] No transmitter found');
    return null;
  }

  static Future<String?> _scanBatch(List<String> ips, int port) async {
    for (var i = 0; i < ips.length; i += _batchSize) {
      final chunk = ips.sublist(
        i,
        i + _batchSize > ips.length ? ips.length : i + _batchSize,
      );
      final results = await Future.wait(chunk.map((ip) => _probe(ip, port)));
      for (final ip in results) {
        if (ip != null) return ip;
      }
    }
    return null;
  }

  static Future<String?> _probe(String ip, int port) async {
    Socket? socket;
    try {
      socket = await Socket.connect(ip, port,
          timeout: _probeTimeout).timeout(_probeTimeout);
      socket.setOption(SocketOption.tcpNoDelay, true);
      final bytes = await socket
          .take(2048)
          .timeout(_readTimeout)
          .fold<Uint8List>(Uint8List(0), (acc, chunk) {
        final merged = Uint8List(acc.length + chunk.length);
        merged.setRange(0, acc.length, acc);
        merged.setRange(acc.length, acc.length + chunk.length, chunk);
        return merged;
      });
      if (bytes.isEmpty) return null;
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      final first = text.substring(0, text.length > 64 ? 64 : text.length);
      if (first.startsWith('{') || first.startsWith('[')) {
        debugPrint('[Discovery] Found transmitter at $ip:$port');
        return ip;
      }
    } catch (_) {
      // Connection refused or timeout — host is not the transmitter.
    } finally {
      try {
        socket?.destroy();
      } catch (_) {}
    }
    return null;
  }

  static Future<void> _saveHost(String host, int port) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tcp_host', host);
    await prefs.setInt('tcp_port', port);
    debugPrint('[Discovery] Saved transmitter host $host:$port');
  }
}
