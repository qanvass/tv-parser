import 'package:cast/cast.dart';
import 'package:flutter/material.dart';

import '../../../helpers/helpers.dart';
import '../../../repository/api/cast_media_service.dart';

/// Header cast button. Pick a Chromecast once; while connected, anything you
/// play on the phone goes to the TV (see StreamLauncher).
class MobileCastButton extends StatelessWidget {
  const MobileCastButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (!supportsCasting()) return const SizedBox.shrink();
    return ValueListenableBuilder<String?>(
      valueListenable: CastMediaService().connectedDevice,
      builder: (context, device, _) => IconButton(
        tooltip: device == null ? 'Cast to TV' : 'Casting to $device',
        icon: Icon(
          device == null ? Icons.cast_rounded : Icons.cast_connected_rounded,
          color: device == null ? Colors.white : Colors.amber,
          size: 24,
        ),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          backgroundColor: const Color(0xFF161618),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) => const _CastDeviceSheet(),
        ),
      ),
    );
  }
}

class _CastDeviceSheet extends StatefulWidget {
  const _CastDeviceSheet();

  @override
  State<_CastDeviceSheet> createState() => _CastDeviceSheetState();
}

class _CastDeviceSheetState extends State<_CastDeviceSheet> {
  List<CastDevice> _devices = const [];
  bool _scanning = true;
  String? _connecting;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scan();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _error = null;
    });
    final found = await CastMediaService().discoverDevices();
    if (!mounted) return;
    setState(() {
      _devices = found;
      _scanning = false;
    });
  }

  Future<void> _connect(CastDevice device) async {
    setState(() {
      _connecting = device.name;
      _error = null;
    });
    final ok = await CastMediaService().connectToDevice(device);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connected to ${device.name}. '
            'Pick a channel or movie to play it on the TV.',
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      setState(() {
        _connecting = null;
        _error =
            'Couldn\'t connect to ${device.name}. Make sure the TV is '
            'on and on the same Wi-Fi, then try again.';
      });
    }
  }

  Future<void> _stop() async {
    await CastMediaService().disconnect();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final current = CastMediaService().connectedDevice.value;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cast_rounded, color: Colors.amber),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Cast to a TV',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Scan again',
                  onPressed: _scanning || _connecting != null ? null : _scan,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
            if (current != null) ...[
              const SizedBox(height: 6),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.cast_connected_rounded,
                  color: Colors.amber,
                ),
                title: Text(
                  'Casting to $current',
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: TextButton(
                  onPressed: _stop,
                  child: const Text('Stop casting'),
                ),
              ),
              const Divider(color: Colors.white12),
            ],
            const SizedBox(height: 6),
            if (_scanning)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Looking for TVs on your Wi-Fi…',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            else if (_devices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'No TVs found. Turn the TV on, make sure your phone is on '
                  'the same Wi-Fi, then tap refresh.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              )
            else
              for (final d in _devices)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tv_rounded, color: Colors.white),
                  title: Text(
                    d.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: _connecting == d.name
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : (current == d.name
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.amber,
                              )
                            : null),
                  onTap: _connecting != null || current == d.name
                      ? null
                      : () => _connect(d),
                ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }
}
