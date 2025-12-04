import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/station.dart';

class StationMapsLauncher {
  const StationMapsLauncher();

  Future<void> open({
    required BuildContext context,
    required Station station,
  }) async {
    final address = _resolveAddress(station);
    if (address == null) {
      _showError(context, 'Adresse indisponible pour cette borne.');
      return;
    }

    if (kIsWeb) {
      final success = await _launchUri(
        _googleMapsWebUri(address),
        mode: LaunchMode.platformDefault,
      );
      if (!success) {
        _showError(
          context,
          'Impossible d’ouvrir une carte dans votre navigateur.',
        );
      }
      return;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final opened = await _launchAndroidIntent(station, address);
        if (!opened) {
          _showError(
            context,
            'Impossible d’ouvrir une application de carte.',
          );
        }
        break;
      case TargetPlatform.iOS:
        await _presentIOSSheet(context, station, address);
        break;
      default:
        final fallbackOpened = await _launchUri(
          _googleMapsWebUri(address),
        );
        if (!fallbackOpened) {
          _showError(
            context,
            'Impossible d’ouvrir une application de carte.',
          );
        }
    }
  }

  Future<bool> _launchAndroidIntent(Station station, String address) async {
    final coords = _coordinatesString(station);
    final uri = Uri(
      scheme: 'geo',
      path: coords ?? '0,0',
      queryParameters: {'q': coords ?? address},
    );
    if (await _launchUri(uri)) return true;
    return _launchUri(_googleMapsWebUri(address));
  }

  Future<void> _presentIOSSheet(
    BuildContext context,
    Station station,
    String address,
  ) async {
    final coords = _coordinatesString(station);
    final appleUri = _appleMapsUri(address, coords);
    final googleUri = _googleMapsAppUri(address, coords);
    final supportsGoogle = await canLaunchUrl(googleUri);

    if (!supportsGoogle) {
      final opened = await _launchUri(appleUri);
      if (!opened) {
        final fallback = await _launchUri(_googleMapsWebUri(address));
        if (!fallback) {
          _showError(context, 'Impossible d’ouvrir Plans.');
        }
      }
      return;
    }

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) {
        return CupertinoActionSheet(
          title: const Text('Ouvrir dans une carte'),
          message: Text(address),
          actions: [
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                final opened = await _launchUri(appleUri);
                if (!opened) {
                  final fallback = await _launchUri(_googleMapsWebUri(address));
                  if (!fallback) {
                    _showError(context, 'Impossible d’ouvrir Plans.');
                  }
                }
              },
              child: const Text('Plans'),
            ),
            CupertinoActionSheetAction(
              onPressed: () async {
                Navigator.of(sheetContext).pop();
                final opened = await _launchUri(googleUri);
                if (!opened) {
                  final fallback = await _launchUri(_googleMapsWebUri(address));
                  if (!fallback) {
                    _showError(
                      context,
                      'Impossible d’ouvrir Google Maps.',
                    );
                  }
                }
              },
              child: const Text('Google Maps'),
            ),
          ],
          cancelButton: CupertinoActionSheetAction(
            onPressed: () => Navigator.of(sheetContext).pop(),
            isDefaultAction: true,
            child: const Text('Annuler'),
          ),
        );
      },
    );
  }

  Future<bool> _launchUri(
    Uri uri, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    try {
      return await launchUrl(uri, mode: mode);
    } catch (_) {
      return false;
    }
  }

  Uri _googleMapsWebUri(String address) {
    return Uri(
      scheme: 'https',
      host: 'www.google.com',
      path: '/maps/search/',
      queryParameters: {'api': '1', 'query': address},
    );
  }

  Uri _googleMapsAppUri(String address, String? coords) {
    final params = <String, String>{'q': address};
    if (coords != null) {
      params['center'] = coords;
    }
    return Uri(
      scheme: 'comgooglemaps',
      host: '',
      queryParameters: params,
    );
  }

  Uri _appleMapsUri(String address, String? coords) {
    final params = <String, String>{'q': address};
    if (coords != null) {
      params['ll'] = coords;
    }
    return Uri.https('maps.apple.com', '/', params);
  }

  String? _coordinatesString(Station station) {
    final lat = station.locationLat;
    final lng = station.locationLng;
    if (lat == null || lng == null) return null;
    return '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}';
  }

  String? _resolveAddress(Station station) {
    final formatted = station.locationFormatted;
    if (formatted != null && formatted.trim().isNotEmpty) {
      return formatted.trim();
    }
    final parts = <String>[
      station.streetNumber,
      station.streetName,
      station.postalCode,
      station.city,
      station.country,
    ];
    final cleaned = parts.where((part) => part.trim().isNotEmpty).toList();
    if (cleaned.isEmpty) return null;
    return cleaned.join(' ');
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
