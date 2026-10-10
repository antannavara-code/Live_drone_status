import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:typed_data';
import '../../services/theme_provider.dart';

class SystemHealthTab extends StatefulWidget {
  final String droneId;
  const SystemHealthTab({super.key, required this.droneId});

  @override
  State<SystemHealthTab> createState() => _SystemHealthTabState();
}

class _SystemHealthTabState extends State<SystemHealthTab> {
  VlcPlayerController? _vlcController;
  final TextEditingController _urlController = TextEditingController();
  String? _savedUrl;
  bool _isConnecting = false;
  String? _errorMessage;
  bool _useMJPEG = false;

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  @override
  void dispose() {
    _vlcController?.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _loadUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final url = prefs.getString('rtsp_url_${widget.droneId}');
    if (url != null && url.isNotEmpty && mounted) {
      setState(() => _savedUrl = url);
    }
  }

  Future<void> _connect() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _errorMessage = null;
      _isConnecting = true;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rtsp_url_${widget.droneId}', url);

    _vlcController?.dispose();
    _vlcController = null;

    if (_useMJPEG) {
      setState(() {
        _savedUrl = url;
        _isConnecting = false;
      });
      return;
    }

    final controller = VlcPlayerController.network(
      url,
      autoPlay: true,
      autoInitialize: true,
    );

    controller.addOnInitListener(() {
      if (mounted) {
        setState(() {
          _savedUrl = url;
          _isConnecting = false;
          _errorMessage = null;
        });
      }
    });

    controller.addListener(() {
      if (mounted && controller.value.hasError) {
        setState(() {
          _errorMessage = controller.value.errorDescription;
          _isConnecting = false;
        });
      }
    });

    Future.delayed(const Duration(seconds: 12), () {
      if (mounted && _isConnecting) {
        setState(() {
          _errorMessage = 'Connection timed out.\nMake sure phone and Jetson are on the same network.';
          _isConnecting = false;
        });
      }
    });
  }

  void _editUrl() {
    _vlcController?.pause();
    _urlController.text = _savedUrl ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.panelAlt,
        title: Text('Stream URL', style: TextStyle(color: AppColors.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _urlController,
                style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'rtsp://192.168.50.162:8554/video1',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: AppColors.borderSubtle,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('MJPEG mode', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const Spacer(),
                Switch(
                  value: _useMJPEG,
                  onChanged: (v) => setState(() => _useMJPEG = v),
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _connect();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Save & Connect'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_savedUrl == null) return _buildUrlEntry();
    if (_errorMessage != null) return _buildError();
    return Column(
      children: [
        Expanded(child: _buildPlayer()),
        _buildStatusBar(),
      ],
    );
  }

  Widget _buildUrlEntry() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.videocam, color: AppColors.primary, size: 64),
            const SizedBox(height: 24),
            Text('Enter Stream URL', style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
                style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'rtsp://192.168.50.162:8554/video1',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: AppColors.panelAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('MJPEG mode', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const Spacer(),
                Switch(
                  value: _useMJPEG,
                  onChanged: (v) => setState(() => _useMJPEG = v),
                  activeThumbColor: AppColors.primary,
                  activeTrackColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isConnecting ? null : _connect,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                child: _isConnecting
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Connect', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text('Connection failed', style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(_savedUrl ?? '', style: const TextStyle(color: Colors.white30, fontSize: 12), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _editUrl,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Change URL'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayer() {
    if (_isConnecting) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    if (_useMJPEG && _savedUrl != null) {
      return MjpegPlayer(url: _savedUrl!);
    }

    if (_vlcController != null) {
      return VlcPlayer(
        controller: _vlcController!,
        aspectRatio: 16 / 9,
        placeholder: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Center(
      child: ElevatedButton(onPressed: _connect, child: const Text('Reconnect')),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: AppColors.scaffoldAlt,
      child: Row(
        children: [
          GestureDetector(
            onTap: _editUrl,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, color: AppColors.textMuted, size: 14),
                  SizedBox(width: 6),
                  Text('Change URL', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            width: 8, height: 8,
            decoration: BoxDecoration(
              color: _errorMessage != null ? Colors.redAccent : AppColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _errorMessage != null ? 'ERROR' : 'LIVE',
            style: TextStyle(
              color: _errorMessage != null ? Colors.redAccent : AppColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class MjpegPlayer extends StatefulWidget {
  final String url;
  const MjpegPlayer({super.key, required this.url});

  @override
  State<MjpegPlayer> createState() => _MjpegPlayerState();
}

class _MjpegPlayerState extends State<MjpegPlayer> {
  Uint8List? _currentFrame;
  String? _error;
  http.Client? _client;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _startStream();
  }

  @override
  void didUpdateWidget(MjpegPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _stopStream();
      _startStream();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _stopStream();
    super.dispose();
  }

  void _stopStream() {
    _client?.close();
    _client = null;
  }

  Future<void> _startStream() async {
    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(widget.url));
      final response = await _client!.send(request);

      if (_disposed) return;

      final boundary = _extractBoundary(response.headers);
      final bytes = <int>[];
      final boundaryBytes = boundary?.codeUnits ?? _defaultBoundary();
      bool inHeaders = true;
      int contentLength = 0;
      final frameBytes = <int>[];

      await for (final chunk in response.stream) {
        if (_disposed) return;
        bytes.addAll(chunk);

        while (true) {
          if (inHeaders) {
            final headerEnd = _indexOf(bytes, [13, 10, 13, 10]);
            if (headerEnd == -1) break;

            final headerStr = String.fromCharCodes(bytes.sublist(0, headerEnd));
            final lines = headerStr.split('\r\n');
            contentLength = 0;
            for (final line in lines) {
              if (line.toLowerCase().startsWith('content-length:')) {
                contentLength = int.tryParse(line.split(':')[1].trim()) ?? 0;
              }
            }
            bytes.removeRange(0, headerEnd + 4);
            inHeaders = false;
          }

          if (contentLength > 0 && bytes.length < contentLength) break;

          if (bytes.length >= contentLength) {
            frameBytes.addAll(bytes.sublist(0, contentLength));
            bytes.removeRange(0, contentLength);

            final frameEnd = _indexOf(bytes, boundaryBytes);
            if (frameEnd != -1) {
              bytes.removeRange(0, frameEnd + boundaryBytes.length);
            }

            if (!_disposed && mounted) {
              setState(() {
                _currentFrame = Uint8List.fromList(frameBytes);
                _error = null;
              });
              frameBytes.clear();
              inHeaders = true;
            }
          } else {
            break;
          }
        }
      }
    } catch (e) {
      if (!_disposed && mounted) {
        setState(() => _error = e.toString());
      }
    }
  }

  List<int> _defaultBoundary() => '\r\n--BOUNDARY\r\n'.codeUnits;

  String? _extractBoundary(Map<String, String> headers) {
    final ct = headers['content-type'] ?? '';
    final idx = ct.indexOf('boundary=');
    if (idx == -1) return null;
    var b = ct.substring(idx + 9);
    if (b.startsWith('"') && b.endsWith('"')) b = b.substring(1, b.length - 1);
    return '\r\n--$b\r\n';
  }

  int _indexOf(List<int> haystack, List<int> needle) {
    if (needle.isEmpty) return 0;
    for (int i = 0; i <= haystack.length - needle.length; i++) {
      bool match = true;
      for (int j = 0; j < needle.length; j++) {
        if (haystack[i + j] != needle[j]) { match = false; break; }
      }
      if (match) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image, color: Colors.redAccent, size: 48),
            const SizedBox(height: 8),
            Text('MJPEG error', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 4),
            Text(_error!, style: const TextStyle(color: Colors.white30, fontSize: 11), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis),
          ],
        ),
      );
    }

    if (_currentFrame == null) {
      return Center(child: CircularProgressIndicator(color: AppColors.primary));
    }

    return Image.memory(_currentFrame!, fit: BoxFit.contain);
  }
}
