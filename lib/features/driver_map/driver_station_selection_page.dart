import 'package:flutter/material.dart';

import '../stations/models/station.dart';
import 'driver_station_detail_page.dart';
import 'driver_station_models.dart';
import 'driver_station_repository.dart';

class DriverStationSelectionPage extends StatefulWidget {
  const DriverStationSelectionPage({super.key});

  @override
  State<DriverStationSelectionPage> createState() =>
      _DriverStationSelectionPageState();
}

class _DriverStationSelectionPageState
    extends State<DriverStationSelectionPage> {
  final _repo = const DriverStationRepository();

  bool _loading = true;
  String? _error;
  List<DriverStationView> _stations = const [];

  @override
  void initState() {
    super.initState();
    _loadStations();
  }

  Future<void> _loadStations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final stations = await _repo.fetchApprovedStations();
      if (!mounted) return;
      setState(() {
        _stations = stations;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openStation(DriverStationView view) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DriverStationDetailPage(initialStation: view, repository: _repo),
      ),
    );
    await _loadStations();
  }

  void _openMap() {
    Navigator.of(context).pop('open_map');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.of(context).pop()),
            Expanded(child: _buildBody()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _openMap,
                  child: const Text('Trouver d\'autres bornes'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _EmptyState(
        message: 'Impossible de charger vos bornes. Reessayez plus tard.',
        buttonLabel: 'Reessayer',
        onTap: _loadStations,
      );
    }

    if (_stations.isEmpty) {
      return _EmptyState(
        message: 'Vous n\'avez pas encore de borne disponible.',
        buttonLabel: 'Trouver d\'autres bornes',
        onTap: _openMap,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      itemCount: _stations.length,
      itemBuilder: (context, index) {
        final view = _stations[index];
        final station = view.station;
        final address =
            station.locationFormatted ?? _addressFromStation(station);
        final chargerLabel = station.chargerLabel;
        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () => _openStation(view),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE7ECFF),
              backgroundImage: station.photoUrl != null
                  ? NetworkImage(station.photoUrl!)
                  : null,
              child: station.photoUrl == null
                  ? const Icon(Icons.image_outlined, color: Color(0xFF2C75FF))
                  : null,
            ),
            title: Text(
              station.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (chargerLabel != null)
                  Text(
                    chargerLabel,
                    style: const TextStyle(color: Colors.black87),
                  ),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _addressFromStation(Station station) {
    final parts = [
      station.streetNumber,
      station.streetName,
      station.postalCode,
      station.city,
    ];
    return parts.where((part) => part.trim().isNotEmpty).join(' ');
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C75FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: onBack,
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Selectionner une borne',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.message,
    required this.buttonLabel,
    required this.onTap,
  });

  final String message;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2C75FF),
                side: const BorderSide(color: Color(0xFF2C75FF)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
