import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:cast/cast.dart';
import 'package:mbark_iptv/helpers/helpers.dart';

class CastDiagnosticsService {
  static final List<String> history = [];

  static void log(String message) {
    debugPrint('[CastDiagnostics] $message');
    history.add('[${DateTime.now().toIso8601String().split('T').last.substring(0, 8)}] $message');
    if (history.length > 50) history.removeAt(0);
  }

  static void logError(dynamic error, [StackTrace? stackTrace]) {
    final msg = 'ERROR: $error';
    debugPrint('[CastDiagnostics] $msg');
    history.add('[${DateTime.now().toIso8601String().split('T').last.substring(0, 8)}] $msg');
    if (history.length > 50) history.removeAt(0);
    if (stackTrace != null) {
      debugPrint(stackTrace.toString());
    }
  }

  static void logSessionEvent(String event, Map<String, dynamic> details) {
    final cleanDetails = Map<String, dynamic>.from(details);
    if (cleanDetails.containsKey('url')) {
      final String fullUrl = cleanDetails['url'].toString();
      try {
        final uri = Uri.parse(fullUrl);
        // Host only: provider paths often embed the account credentials.
        cleanDetails['url'] = '${uri.scheme}://${uri.host}/… (path stripped)';
      } catch (_) {
        cleanDetails['url'] = '(invalid or obfuscated URL)';
      }
    }
    final msg = 'Session Event "$event": $cleanDetails';
    debugPrint('[CastDiagnostics] $msg');
    history.add('[${DateTime.now().toIso8601String().split('T').last.substring(0, 8)}] $msg');
    if (history.length > 50) history.removeAt(0);
  }
}

class CastMediaService {
  static final CastMediaService _instance = CastMediaService._();
  CastMediaService._();

  factory CastMediaService() => _instance;

  static const String _defaultReceiverAppId = 'CC1AD845';

  CastSession? _session;
  CastDevice? _device;
  int? _mediaSessionId;
  bool _isCasting = false;

  /// transportId of the launched Default Media Receiver. Media commands go
  /// here directly: the cast package binds to whichever app reports first
  /// (on Google TV often the home backdrop), which silently drops LOAD.
  String? _appTransport;
  final List<StreamSubscription<dynamic>> _subs = [];
  final StreamController<Map<String, dynamic>> _messages =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Connected device name (null when not casting) — drives cast icons.
  final ValueNotifier<String?> connectedDevice = ValueNotifier<String?>(null);

  CastSession? get currentSession => _session;
  CastDevice? get selectedDevice => _device;
  bool get isCasting => _isCasting && _appTransport != null;

  /// Start discovery of Chromecast devices
  Future<List<CastDevice>> discoverDevices() async {
    // TV gate: never scan for Cast receivers while already running on a TV.
    if (!supportsCasting()) {
      CastDiagnosticsService.log('Skipping Chromecast scan on TV device.');
      return [];
    }
    CastDiagnosticsService.log('Starting Chromecast device scan...');
    try {
      final devices = await CastDiscoveryService()
          .search(timeout: const Duration(seconds: 5));
      CastDiagnosticsService.log('Scan complete. Found ${devices.length} devices.');
      return devices;
    } catch (e, stack) {
      CastDiagnosticsService.logError('Device discovery failed', stack);
      return [];
    }
  }

  /// Connect, launch the Default Media Receiver and wait until it is ready.
  Future<bool> connectToDevice(CastDevice device) async {
    // TV gate: Cast is phone→TV only.
    if (!supportsCasting()) {
      CastDiagnosticsService.log('Blocked Cast connect on TV device.');
      return false;
    }
    CastDiagnosticsService.log(
        'Connecting to device: ${device.name} (${device.host}:${device.port})...');
    try {
      await disconnect();

      final session = await CastSessionManager()
          .startSession(device, const Duration(seconds: 8));
      _session = session;
      _device = device;

      _subs.add(session.stateStream.listen((state) {
        CastDiagnosticsService.log('Session state updated: $state');
        if (state == CastSessionState.closed) _reset();
      }));
      _subs.add(session.messageStream.listen(_onMessage, onError: (_) {}));

      final ready = _waitFor((m) {
        final apps = (m['status'] is Map) ? m['status']['applications'] : null;
        if (apps is! List) return false;
        for (final a in apps) {
          if (a is Map &&
              a['appId'] == _defaultReceiverAppId &&
              a['transportId'] != null) {
            _appTransport = a['transportId'] as String;
            return true;
          }
        }
        return false;
      }, const Duration(seconds: 15));

      // Always address the platform receiver for LAUNCH.
      session.socket.sendMessage(
        CastSession.kNamespaceReceiver,
        session.sessionId,
        'receiver-0',
        {'type': 'LAUNCH', 'appId': _defaultReceiverAppId},
      );

      if (!await ready || _appTransport == null) {
        throw StateError('Media receiver did not start');
      }
      _sendToApp(CastSession.kNamespaceConnection, {'type': 'CONNECT'});

      _isCasting = true;
      connectedDevice.value = device.name;
      CastDiagnosticsService.log('Connected to ${device.name}; media receiver ready.');
      return true;
    } catch (e, stack) {
      CastDiagnosticsService.logError('Failed to connect to ${device.name}: $e', stack);
      await disconnect();
      return false;
    }
  }

  void _onMessage(Map<String, dynamic> message) {
    final type = message['type'];
    if (type == 'MEDIA_STATUS') {
      final status = message['status'];
      if (status is List && status.isNotEmpty && status[0] is Map) {
        final id = status[0]['mediaSessionId'];
        if (id is int) _mediaSessionId = id;
        final playerState = status[0]['playerState'];
        if (playerState != null) {
          CastDiagnosticsService.log('Receiver Player State: $playerState');
        }
      }
    } else if (type == 'RECEIVER_STATUS' && _isCasting && _appTransport != null) {
      // Our receiver app was closed on the TV (e.g. user pressed Home).
      final apps = (message['status'] is Map) ? message['status']['applications'] : null;
      final stillRunning = apps is List &&
          apps.any((a) => a is Map && a['transportId'] == _appTransport);
      if (!stillRunning) {
        CastDiagnosticsService.log('Media receiver closed on device.');
        unawaited(disconnect());
      }
    }
    if (!_messages.isClosed) _messages.add(message);
  }

  Future<bool> _waitFor(
    bool Function(Map<String, dynamic>) match,
    Duration timeout,
  ) {
    final completer = Completer<bool>();
    final sub = _messages.stream.listen((m) {
      if (!completer.isCompleted && match(m)) completer.complete(true);
    });
    return completer.future
        .timeout(timeout, onTimeout: () => false)
        .whenComplete(sub.cancel);
  }

  void _sendToApp(String namespace, Map<String, dynamic> payload) {
    final session = _session;
    final transport = _appTransport;
    if (session == null || transport == null) return;
    session.socket.sendMessage(namespace, session.sessionId, transport, payload);
  }

  /// MIME type for the receiver. Unknown URLs (e.g. /api/stream/123) are
  /// probed with a HEAD request (following redirects).
  static Future<String> resolveContentType(String url) async {
    final known = _typeFromPath(url);
    if (known != null) return known;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 4);
      final req = await client.headUrl(Uri.parse(url)).timeout(const Duration(seconds: 5));
      req.followRedirects = true;
      final res = await req.close().timeout(const Duration(seconds: 5));
      final finalUrl =
          res.redirects.isNotEmpty ? res.redirects.last.location.toString() : url;
      final header = res.headers.contentType?.mimeType.toLowerCase();
      await res.drain<void>().catchError((_) {});
      final fromPath = _typeFromPath(finalUrl);
      if (fromPath != null) return fromPath;
      if (header != null && header.isNotEmpty && header != 'application/octet-stream') {
        if (header.contains('mpegurl')) return 'application/x-mpegURL';
        return header;
      }
    } catch (_) {
    } finally {
      client?.close(force: true);
    }
    // Extension-less IPTV live links are almost always HLS.
    return 'application/x-mpegURL';
  }

  static String? _typeFromPath(String url) {
    final path = url.toLowerCase().split('?').first;
    if (path.endsWith('.m3u8') || path.contains('.m3u8/')) return 'application/x-mpegURL';
    if (path.endsWith('.mp4') || path.endsWith('.m4v')) return 'video/mp4';
    if (path.endsWith('.mpd')) return 'application/dash+xml';
    if (path.endsWith('.webm')) return 'video/webm';
    if (path.endsWith('.ts')) return 'video/mp2t';
    if (path.endsWith('.mkv')) return 'video/x-matroska';
    return null;
  }

  static bool _failed(Map<String, dynamic> m) {
    final type = m['type'];
    if (type == 'LOAD_FAILED' || type == 'LOAD_CANCELLED' || type == 'INVALID_REQUEST') {
      return true;
    }
    final status = m['status'];
    return type == 'MEDIA_STATUS' &&
        status is List &&
        status.isNotEmpty &&
        status[0] is Map &&
        status[0]['playerState'] == 'IDLE' &&
        status[0]['idleReason'] == 'ERROR';
  }

  static bool _started(Map<String, dynamic> m) {
    if (m['type'] != 'MEDIA_STATUS') return false;
    final status = m['status'];
    if (status is! List || status.isEmpty || status[0] is! Map) return false;
    final state = status[0]['playerState'];
    return state == 'PLAYING' || state == 'BUFFERING';
  }

  /// Load a stream onto the connected device. True only once the receiver
  /// reports buffering/playing; false on LOAD_FAILED, error or timeout.
  Future<bool> castStream(
    String url, {
    required String title,
    String? subtitle,
    String? posterUrl,
    required String streamType, // 'LIVE' or 'BUFFERED'
  }) async {
    if (!isCasting) {
      CastDiagnosticsService.log('Cannot cast stream: No active session.');
      return false;
    }
    final contentType = await resolveContentType(url);

    CastDiagnosticsService.logSessionEvent('LOAD_STREAM', {
      'url': url,
      'title': title,
      'contentType': contentType,
      'streamType': streamType,
    });

    var failed = false;
    String? failReason;
    final outcome = _waitFor((m) {
      if (_failed(m)) {
        failed = true;
        final st = m['status'];
        failReason = '${m['type']} reason=${m['reason'] ?? (st is List && st.isNotEmpty && st[0] is Map ? st[0]['idleReason'] : '')} '
            'detail=${m['detailedErrorCode'] ?? m['customData'] ?? ''}';
        return true;
      }
      return _started(m);
    }, const Duration(seconds: 20));

    _sendToApp(CastSession.kNamespaceMedia, {
      'type': 'LOAD',
      'autoPlay': true,
      'currentTime': 0,
      'media': {
        'contentId': url,
        'contentType': contentType,
        'streamType': streamType,
        'metadata': {
          'metadataType': 0,
          'title': title,
          if (subtitle != null && subtitle.isNotEmpty) 'subtitle': subtitle,
          if (posterUrl != null && posterUrl.isNotEmpty)
            'images': [
              {'url': posterUrl}
            ],
        },
      },
    });

    final answered = await outcome;
    final ok = answered && !failed;
    CastDiagnosticsService.log(
        'LOAD result: ${ok ? 'playing' : (answered ? 'failed: $failReason' : 'timeout')} ($contentType)');
    return ok;
  }

  /// Pause playback on the Cast device
  Future<void> pause() async {
    if (_mediaSessionId == null) return;
    _sendToApp(CastSession.kNamespaceMedia,
        {'type': 'PAUSE', 'mediaSessionId': _mediaSessionId});
    CastDiagnosticsService.log('Sent PAUSE command');
  }

  /// Play/Resume playback on the Cast device
  Future<void> play() async {
    if (_mediaSessionId == null) return;
    _sendToApp(CastSession.kNamespaceMedia,
        {'type': 'PLAY', 'mediaSessionId': _mediaSessionId});
    CastDiagnosticsService.log('Sent PLAY command');
  }

  /// Seek to a specific timestamp in seconds
  Future<void> seek(double positionInSeconds) async {
    if (_mediaSessionId == null) return;
    _sendToApp(CastSession.kNamespaceMedia, {
      'type': 'SEEK',
      'mediaSessionId': _mediaSessionId,
      'currentTime': positionInSeconds,
    });
    CastDiagnosticsService.log('Sent SEEK command to: $positionInSeconds seconds');
  }

  void _reset() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _session = null;
    _device = null;
    _mediaSessionId = null;
    _appTransport = null;
    _isCasting = false;
    connectedDevice.value = null;
  }

  /// Stop casting and end session
  Future<void> disconnect() async {
    final session = _session;
    if (session != null) {
      CastDiagnosticsService.log('Ending Cast session: ${session.sessionId}');
      try {
        if (_appTransport != null) {
          _sendToApp(CastSession.kNamespaceConnection, {'type': 'CLOSE'});
        }
        await CastSessionManager().endSession(session.sessionId);
      } catch (e) {
        CastDiagnosticsService.logError('Error ending session', null);
      }
    }
    _reset();
  }
}
