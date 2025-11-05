import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../location/google_place_models.dart';
import '../location/google_place_service.dart';
import '../profile/models/profile.dart';
import 'driver_station_detail_page.dart';
import 'driver_station_models.dart';
import 'driver_station_repository.dart';

class DriverMapPage extends StatefulWidget {
  const DriverMapPage({super.key, required this.profile});

  final Profile profile;

  @override
  State<DriverMapPage> createState() => _DriverMapPageState();
}

class _DriverMapPageState extends State<DriverMapPage> {
  static const LatLng _fallbackCenter = LatLng(50.8503, 4.3517); // Bruxelles

  final _repository = const DriverStationRepository();
  final _placeService = const GooglePlaceService();
  final TextEditingController _searchController = TextEditingController();

  GoogleMapController? _mapController;
  String _sessionToken = generateSessionToken();
  bool _loadingStations = true;
  String? _loadError;
  bool _serviceUnavailable = false;
  bool _locatingUser = false;

  List<DriverStationView> _stations = const [];

  CameraPosition get _initialCamera {
    final lat = widget.profile.addressLat;
    final lng = widget.profile.addressLng;
    if (lat != null && lng != null) {
      return CameraPosition(target: LatLng(lat, lng), zoom: 13);
    }
    return const CameraPosition(target: _fallbackCenter, zoom: 12);
  }

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() {
      _loadingStations = true;
      _loadError = null;
    });
    try {
      final stations = await _repository.fetchStationsWithMemberships();
      if (!mounted) return;
      setState(() {
        _stations = stations
            .where(
              (view) =>
                  view.station.locationLat != null &&
                  view.station.locationLng != null,
            )
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loadingStations = false);
      }
    }
  }

  Set<Marker> get _markers {
    final markers = <Marker>{};
    for (final view in _stations) {
      final lat = view.station.locationLat;
      final lng = view.station.locationLng;
      if (lat == null || lng == null) continue;
      final markerId = MarkerId(view.station.id);
      markers.add(
        Marker(
          markerId: markerId,
          position: LatLng(lat, lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          onTap: () => _openStationDetail(view),
        ),
      );
    }
    return markers;
  }

  Future<List<GooglePlacePrediction>> _fetchSuggestions(String pattern) async {
    if (pattern.trim().length < 3) {
      return const [];
    }
    try {
      final results = await _placeService.searchAddresses(
        pattern,
        sessionToken: _sessionToken,
      );
      if (_serviceUnavailable) {
        setState(() => _serviceUnavailable = false);
      }
      return results;
    } catch (_) {
      if (mounted) {
        setState(() => _serviceUnavailable = true);
      }
      return const [];
    }
  }

  Future<void> _centerOnPrediction(GooglePlacePrediction prediction) async {
    try {
      final details = await _placeService.fetchDetails(
        prediction.placeId,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      _sessionToken = generateSessionToken();
      _searchController.text = details.formattedAddress;
      await _animateTo(LatLng(details.lat, details.lng), zoom: 14);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adresse introuvable. RÃƒÆ’Ã‚Â©essayez plus tard.'),
        ),
      );
    }
  }

  Future<void> _centerOnUser() async {
    setState(() => _locatingUser = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La gÃƒÆ’Ã‚Â©olocalisation est nÃƒÆ’Ã‚Â©cessaire pour centrer la carte.',
            ),
          ),
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      await _animateTo(LatLng(position.latitude, position.longitude), zoom: 14);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de rÃƒÆ’Ã‚Â©cupÃƒÆ’Ã‚Â©rer votre position: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _locatingUser = false);
      }
    }
  }

  Future<void> _animateTo(LatLng target, {double? zoom}) async {
    final controller = _mapController;
    if (controller == null) return;
    final resolvedZoom =
        zoom ??
        (kIsWeb ? _initialCamera.zoom : await controller.getZoomLevel());
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: resolvedZoom),
      ),
    );
  }

  Future<void> _openStationDetail(DriverStationView view) async {
    final membership = await Navigator.of(context)
        .push<DriverStationMembership?>(
          MaterialPageRoute(
            builder: (context) => DriverStationDetailPage(
              initialStation: view,
              repository: _repository,
            ),
          ),
        );
    if (membership != null || view.membership != null) {
      setState(() {
        final updated = view.copyWith(membership: membership);
        final index = _stations.indexWhere(
          (s) => s.station.id == view.station.id,
        );
        if (index >= 0) {
          final list = List<DriverStationView>.from(_stations);
          list[index] = updated;
          _stations = list;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: _initialCamera,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              markers: _markers,
              onMapCreated: (controller) => _mapController = controller,
            ),
          ),
          Positioned(
            top: 20,
            left: 16,
            right: 16,
            child: SafeArea(child: _buildSearchField()),
          ),
          Positioned(
            bottom: 24,
            right: 16,
            child: SafeArea(
              child: FloatingActionButton(
                onPressed: _locatingUser ? null : _centerOnUser,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2C75FF),
                child: _locatingUser
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location),
              ),
            ),
          ),
          if (_loadingStations)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_loadError != null)
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: SafeArea(
                child: _ErrorBanner(
                  message: _loadError!,
                  onRetry: _loadStations,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TypeAheadField<GooglePlacePrediction>(
      controller: _searchController,
      builder: (context, controller, focusNode) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'Rechercher une adresse',
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE0E3EB)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE0E3EB)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF2C75FF),
                width: 1.5,
              ),
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      controller.clear();
                      _sessionToken = generateSessionToken();
                    },
                    icon: const Icon(Icons.clear),
                  )
                : null,
          ),
        );
      },
      suggestionsCallback: _fetchSuggestions,
      itemBuilder: (context, prediction) => ListTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text(prediction.description),
      ),
      onSelected: (prediction) => _centerOnPrediction(prediction),
      loadingBuilder: (context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      ),
      emptyBuilder: (context) => _serviceUnavailable
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE2E2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFB3B3)),
              ),
              child: const Text(
                'Service d\'adresses indisponible pour le moment.',
                style: TextStyle(
                  color: Color(0xFFB42321),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE2E2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFB3B3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB42321)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFFB42321),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('RÃƒÆ’Ã‚Â©essayer')),
        ],
      ),
    );
  }
}
