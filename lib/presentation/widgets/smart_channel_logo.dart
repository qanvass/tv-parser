import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../repository/api/channel_logo_resolver_service.dart';

/// Displays a channel logo with automatic fallback when the primary URL 404s.
class SmartChannelLogo extends StatefulWidget {
  final String? primaryUrl;
  final String channelName;
  final BoxFit fit;
  final int? memCacheWidth;
  final Widget? placeholder;
  final bool showInitialsFallback;
  final double initialsSize;

  const SmartChannelLogo({
    super.key,
    this.primaryUrl,
    required this.channelName,
    this.fit = BoxFit.contain,
    this.memCacheWidth,
    this.placeholder,
    this.showInitialsFallback = true,
    this.initialsSize = 38,
  });

  @override
  State<SmartChannelLogo> createState() => _SmartChannelLogoState();
}

class _SmartChannelLogoState extends State<SmartChannelLogo> {
  String? _activeUrl;
  bool _resolving = false;
  bool _resolveAttempted = false;

  @override
  void initState() {
    super.initState();
    _activeUrl = _cleanUrl(widget.primaryUrl);
  }

  @override
  void didUpdateWidget(SmartChannelLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primaryUrl != widget.primaryUrl ||
        oldWidget.channelName != widget.channelName) {
      _activeUrl = _cleanUrl(widget.primaryUrl);
      _resolveAttempted = false;
      _resolving = false;
    }
  }

  String? _cleanUrl(String? url) {
    final trimmed = url?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _resolveFallback() async {
    if (_resolving || _resolveAttempted) return;
    _resolving = true;
    _resolveAttempted = true;
    final resolved = await ChannelLogoResolverService.resolveLogo(
      channelName: widget.channelName,
      primaryUrl: widget.primaryUrl,
    );
    if (mounted && resolved != null && resolved != _activeUrl) {
      setState(() => _activeUrl = resolved);
    }
    if (mounted) _resolving = false;
  }

  Widget _buildInitials() {
    final words = widget.channelName
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .toList();
    final initials = words
        .map((w) => w.replaceAll(RegExp(r'[^a-zA-Z0-9]'), ''))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase())
        .join();
    final label = initials.isNotEmpty ? initials : '?';
    return Center(
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: widget.initialsSize,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = _activeUrl;
    if (url == null) {
      if (!_resolveAttempted) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _resolveFallback());
      }
      return widget.placeholder ??
          (widget.showInitialsFallback
              ? _buildInitials()
              : Icon(
                  Icons.live_tv_rounded,
                  color: Colors.white.withValues(alpha: 0.08),
                  size: widget.initialsSize,
                ));
    }

    return CachedNetworkImage(
      imageUrl: url,
      fit: widget.fit,
      memCacheWidth: widget.memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 200),
      placeholder: (context, _) =>
          widget.placeholder ??
          Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
              ),
            ),
          ),
      errorWidget: (context, _, __) {
        if (!_resolveAttempted) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _resolveFallback());
        }
        if (widget.placeholder != null && !widget.showInitialsFallback) {
          return widget.placeholder!;
        }
        return widget.showInitialsFallback
            ? _buildInitials()
            : Icon(
                Icons.live_tv_rounded,
                color: Colors.white.withValues(alpha: 0.08),
                size: widget.initialsSize,
              );
      },
    );
  }
}
