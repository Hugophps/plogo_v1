import 'package:flutter/material.dart';

import '../models/station.dart';
import 'station_maps_launcher.dart';

class StationAddressDisplay extends StatelessWidget {
  const StationAddressDisplay({
    super.key,
    required this.station,
    required this.mapsLauncher,
    this.backgroundColor = const Color(0xFFF1F4FF),
    this.padding = const EdgeInsets.all(12),
  });

  final Station station;
  final StationMapsLauncher mapsLauncher;
  final Color backgroundColor;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final lines = _resolveAddressLines(station);
    final hasLine2 = lines.$2 != null && lines.$2!.isNotEmpty;
    final canLaunchMaps = _hasLaunchableAddress(station);

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ScrollingAddressLine(
                  text: lines.$1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                  backgroundColor: backgroundColor,
                ),
                if (hasLine2) ...[
                  const SizedBox(height: 4),
                  _ScrollingAddressLine(
                    text: lines.$2!,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                    backgroundColor: backgroundColor,
                  ),
                ],
              ],
            ),
          ),
          if (canLaunchMaps) ...[
            const SizedBox(width: 8),
            _OpenInMapsButton(
              onPressed: () =>
                  mapsLauncher.open(context: context, station: station),
            ),
          ],
        ],
      ),
    );
  }

  (String, String?) _resolveAddressLines(Station station) {
    final street = _streetLine(station);
    final cityLine = _cityLine(station);
    String? line1 = street?.trim();
    String? line2 = cityLine?.trim();
    final formatted = station.locationFormatted?.trim();

    if ((line1 == null || line1.isEmpty) &&
        (line2 == null || line2.isEmpty)) {
      if (formatted != null && formatted.isNotEmpty) {
        final parts = formatted.split(',');
        line1 = parts.first.trim();
        if (parts.length > 1) {
          line2 = parts.sublist(1).join(', ').trim();
        }
      } else {
        final fallback = [
          station.streetNumber,
          station.streetName,
          station.postalCode,
          station.city,
          station.country,
        ].where((part) => part.trim().isNotEmpty).join(' ');
        line1 = fallback.isEmpty ? 'Adresse indisponible' : fallback;
      }
    } else if (line1 == null || line1.isEmpty) {
      line1 = line2;
      line2 = null;
    }

    if (line1 == null || line1.isEmpty) {
      line1 = 'Adresse indisponible';
    }

    return (line1, line2);
  }

  bool _hasLaunchableAddress(Station station) {
    if (station.locationLat != null && station.locationLng != null) {
      return true;
    }
    if (station.locationFormatted != null &&
        station.locationFormatted!.trim().isNotEmpty) {
      return true;
    }
    return [
      station.streetNumber,
      station.streetName,
      station.postalCode,
      station.city,
    ].any((part) => part.trim().isNotEmpty);
  }

  String? _streetLine(Station station) {
    final parts = <String>[
      station.streetNumber,
      station.streetName,
    ].where((part) => part.trim().isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }

  String? _cityLine(Station station) {
    final parts = <String>[
      station.postalCode,
      station.city,
      station.country,
    ].where((part) => part.trim().isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.join(' ');
  }
}

class _OpenInMapsButton extends StatelessWidget {
  const _OpenInMapsButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Ouvrir l’adresse dans une carte',
      button: true,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFE7ECFF),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          onPressed: onPressed,
          color: const Color(0xFF2C75FF),
          icon: const Icon(Icons.location_pin),
        ),
      ),
    );
  }
}

class _ScrollingAddressLine extends StatefulWidget {
  const _ScrollingAddressLine({
    required this.text,
    required this.style,
    required this.backgroundColor,
    this.pause = const Duration(seconds: 2),
  });

  final String text;
  final TextStyle style;
  final Color backgroundColor;
  final Duration pause;

  @override
  State<_ScrollingAddressLine> createState() => _ScrollingAddressLineState();
}

class _ScrollingAddressLineState extends State<_ScrollingAddressLine> {
  final ScrollController _controller = ScrollController();
  bool _shouldScroll = false;
  bool _loopActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateScrollNeed());
  }

  @override
  void didUpdateWidget(covariant _ScrollingAddressLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _stopLoop();
      if (_controller.hasClients) {
        _controller.jumpTo(0);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateScrollNeed());
  }

  void _evaluateScrollNeed() {
    if (!mounted || !_controller.hasClients) return;
    final needScroll = _controller.position.maxScrollExtent > 4;
    if (needScroll != _shouldScroll) {
      setState(() => _shouldScroll = needScroll);
    }
    if (needScroll) {
      _startLoop();
    } else {
      _stopLoop();
    }
  }

  void _startLoop() {
    if (_loopActive) return;
    _loopActive = true;
    _runLoop();
  }

  Future<void> _runLoop() async {
    while (_loopActive && mounted) {
      await Future.delayed(widget.pause);
      if (!_loopActive || !mounted || !_controller.hasClients) break;
      final duration = _scrollDuration();
      try {
        await _controller.animateTo(
          _controller.position.maxScrollExtent,
          duration: duration,
          curve: Curves.easeInOut,
        );
      } catch (_) {
        break;
      }
      if (!_loopActive || !mounted || !_controller.hasClients) break;
      await Future.delayed(widget.pause);
      if (!_loopActive || !mounted || !_controller.hasClients) break;
      try {
        await _controller.animateTo(
          0,
          duration: duration,
          curve: Curves.easeInOut,
        );
      } catch (_) {
        break;
      }
    }
    _loopActive = false;
  }

  Duration _scrollDuration() {
    if (!_controller.hasClients) return const Duration(milliseconds: 1500);
    final extent = _controller.position.maxScrollExtent;
    final milliseconds = (extent * 40).clamp(1500, 8000).round();
    return Duration(milliseconds: milliseconds);
  }

  void _stopLoop() {
    _loopActive = false;
  }

  @override
  void dispose() {
    _loopActive = false;
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluateScrollNeed());
    final lineHeight =
        widget.style.fontSize != null ? widget.style.fontSize! * 1.4 : null;
    return SizedBox(
      height: lineHeight,
      child: Stack(
        children: [
          ClipRect(
            child: SingleChildScrollView(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Text(
                widget.text,
                style: widget.style,
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
          if (_shouldScroll) ...[
            _GradientFade(
              alignment: Alignment.centerLeft,
              color: widget.backgroundColor,
            ),
            _GradientFade(
              alignment: Alignment.centerRight,
              color: widget.backgroundColor,
            ),
          ],
        ],
      ),
    );
  }
}

class _GradientFade extends StatelessWidget {
  const _GradientFade({required this.alignment, required this.color});

  final Alignment alignment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final begin = alignment == Alignment.centerLeft
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final end = alignment == Alignment.centerLeft
        ? Alignment.centerRight
        : Alignment.centerLeft;
    return Align(
      alignment: alignment,
      child: IgnorePointer(
        child: Container(
          width: 18,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: begin,
              end: end,
              colors: [
                color,
                color.withOpacity(0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
