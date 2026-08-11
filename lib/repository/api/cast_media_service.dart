import 'dart:async';
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
        cleanDetails['url'] = '${uri.scheme}://${uri.host}${uri.path} (sensitive params stripped)';
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

  CastSession? _session;
  CastDevice? _device;
  int? _mediaSessionId;
  bool _isCasting = false;

  CastSession? get currentSession => _session;
  CastDevice? get selectedDevice => _device;
  bool get isCasting => _isCasting;

  /// Start discovery of Chromecast devices
  Future<List<CastDevice>> discoverDevices() async {
    // TV gate: never scan for Cast receivers while already running on a TV.
    if (!supportsCasting()) {
      CastDiagnosticsService.log('Skipping Chromecast scan on TV device.');
      return [];
    }
    CastDiagnosticsService.log('Starting Chromecast device scan...');
    try {
      final devices = await CastDiscoveryService().search(timeout: const Duration(seconds: 4));
      CastDiagnosticsService.log('Scan complete. Found ${devices.length} devices.');
      return devices;
    } catch (e, stack) {
      CastDiagnosticsService.logError('Device discovery failed', stack);
      return [];
    }
  }

  /// Connect to a specific Chromecast device and launch default media receiver app
  Future<bool> connectToDevice(CastDevice device) async {
    // TV gate: Cast is phone→TV only.
    if (!supportsCasting()) {
      CastDiagnosticsService.log('Blocked Cast connect on TV device.');
      return false;
    }
    CastDiagnosticsService.log('Connecting to device: ${device.name} (${device.host}:${device.port})...');
    try {
      await disconnect();

      _session = await CastSessionManager().startSession(device, const Duration(seconds: 8));
      _device = device;
      
      _session!.sendMessage(CastSession.kNamespaceReceiver, {
        'type': 'LAUNCH',
        'appId': 'CC1AD845', // Default Media Receiver App ID
      });

      _session!.stateStream.listen((state) {
        CastDiagnosticsService.log('Session state updated: $state');
        if (state == CastSessionState.closed) {
          _isCasting = false;
          _session = null;
          _device = null;
          _mediaSessionId = null;
        }
      });

      _session!.messageStream.listen((message) {
        if (message['type'] == 'MEDIA_STATUS' || message['type'] == 'STATUS') {
          final status = message['status'];
          if (status is List && status.isNotEmpty) {
            final mediaSessionId = status[0]['mediaSessionId'];
            if (mediaSessionId != null) {
              _mediaSessionId = mediaSessionId;
              CastDiagnosticsService.log('Captured mediaSessionId: $_mediaSessionId');
            }
            final playerState = status[0]['playerState'];
            if (playerState != null) {
              CastDiagnosticsService.log('Receiver Player State: $playerState');
            }
          }
        }
      });

      _isCasting = true;
      CastDiagnosticsService.log('Successfully connected to ${device.name}. Session connected: true');
      return true;
    } catch (e, stack) {
      CastDiagnosticsService.logError('Failed to connect to ${device.name}. Session connected: false', stack);
      _session = null;
      _device = null;
      _isCasting = false;
      return false;
    }
  }

  /// Load a stream/media URL onto the connected Cast device
  Future<void> castStream(
    String url, {
    required String title,
    String? subtitle,
    String? posterUrl,
    required String streamType, // 'LIVE' or 'BUFFERED'
  }) async {
    if (_session == null) {
      CastDiagnosticsService.log('Cannot cast stream: No active session.');
      return;
    }

    // Determine contentType (MIME) from URL
    String contentType = 'application/octet-stream';
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('.m3u8')) {
      contentType = 'application/x-mpegURL';
    } else if (lowerUrl.contains('.ts')) {
      contentType = 'video/mp2t';
    } else if (lowerUrl.contains('.mp4')) {
      contentType = 'video/mp4';
    } else if (lowerUrl.contains('.mkv')) {
      contentType = 'video/x-matroska';
    }

    CastDiagnosticsService.logSessionEvent('LOAD_STREAM', {
      'url': url,
      'title': title,
      'subtitle': subtitle ?? '',
      'contentType': contentType,
      'streamType': streamType,
      'posterUrl': posterUrl ?? '',
    });

    try {
      _session!.sendMessage(CastSession.kNamespaceMedia, {
        'type': 'LOAD',
        'autoPlay': true,
        'currentTime': 0,
        'media': {
          'contentId': url,
          'contentType': contentType,
          'streamType': streamType, // LIVE or BUFFERED
          'metadata': {
            'metadataType': 0, // Generic
            'title': title,
            if (subtitle != null && subtitle.isNotEmpty) 'subtitle': subtitle,
            if (posterUrl != null && posterUrl.isNotEmpty) 'images': [
              {'url': posterUrl}
            ],
          }
        },
      });
      CastDiagnosticsService.log('Sent LOAD request: true. Stream: $title ($contentType)');
    } catch (e, stack) {
      CastDiagnosticsService.logError('Failed to send LOAD request: false', stack);
    }
  }

  /// Pause playback on the Cast device
  Future<void> pause() async {
    if (_session == null || _mediaSessionId == null) return;
    try {
      _session!.sendMessage(CastSession.kNamespaceMedia, {
        'type': 'PAUSE',
        'mediaSessionId': _mediaSessionId,
      });
      CastDiagnosticsService.log('Sent PAUSE command');
    } catch (e) {
      CastDiagnosticsService.logError('Pause command failed: $e');
    }
  }

  /// Play/Resume playback on the Cast device
  Future<void> play() async {
    if (_session == null || _mediaSessionId == null) return;
    try {
      _session!.sendMessage(CastSession.kNamespaceMedia, {
        'type': 'PLAY',
        'mediaSessionId': _mediaSessionId,
      });
      CastDiagnosticsService.log('Sent PLAY command');
    } catch (e) {
      CastDiagnosticsService.logError('Play command failed: $e');
    }
  }

  /// Seek to a specific timestamp in seconds
  Future<void> seek(double positionInSeconds) async {
    if (_session == null || _mediaSessionId == null) return;
    try {
      _session!.sendMessage(CastSession.kNamespaceMedia, {
        'type': 'SEEK',
        'mediaSessionId': _mediaSessionId,
        'currentTime': positionInSeconds,
      });
      CastDiagnosticsService.log('Sent SEEK command to: $positionInSeconds seconds');
    } catch (e) {
      CastDiagnosticsService.logError('Seek command failed: $e');
    }
  }

  /// Stop casting and end session
  Future<void> disconnect() async {
    if (_session != null) {
      CastDiagnosticsService.log('Ending Cast session: ${_session!.sessionId}');
      try {
        await CastSessionManager().endSession(_session!.sessionId);
      } catch (e) {
        CastDiagnosticsService.logError('Error ending session', null);
      }
      _session = null;
      _device = null;
      _mediaSessionId = null;
      _isCasting = false;
    }
  }
}
