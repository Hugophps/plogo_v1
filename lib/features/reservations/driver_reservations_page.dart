import 'package:flutter/material.dart';

import '../../core/app_timezone.dart';
import '../driver_map/driver_station_selection_page.dart';
import '../profile/models/profile.dart';
import '../stations/models/station.dart';
import 'driver_reservation_details_page.dart';
import 'driver_reservations_repository.dart';

class DriverReservationsPage extends StatefulWidget {
  const DriverReservationsPage({super.key, required this.profile});

  final Profile profile;

  @override
  State<DriverReservationsPage> createState() => _DriverReservationsPageState();
}

class _DriverReservationsPageState extends State<DriverReservationsPage> {
  final _repository = const DriverReservationsRepository();

  bool _loading = true;
  String? _error;
  DriverReservationFilter _filter = DriverReservationFilter.upcoming;
  List<DriverReservation> _upcomingReservations = const [];
  List<DriverReservation> _pastReservations = const [];

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reservations = await _repository.fetchReservations();
      if (!mounted) return;
      setState(() => _applyFilters(reservations));
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _openReservation(DriverReservation reservation) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DriverReservationDetailsPage(
          reservation: reservation,
          profile: widget.profile,
        ),
      ),
    );
    if (updated == true) {
      await _loadReservations();
    }
  }

  Future<void> _openStationSelection() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DriverStationSelectionPage()),
    );
    await _loadReservations();
  }

  void _applyFilters(List<DriverReservation> reservations) {
    final nowUtc = DateTime.now().toUtc();
    final upcoming = <DriverReservation>[];
    final past = <DriverReservation>[];

    for (final reservation in reservations) {
      if (reservation.slot.endAt.isAfter(nowUtc)) {
        upcoming.add(reservation);
      } else {
        past.add(reservation);
      }
    }

    upcoming.sort((a, b) => a.slot.startAt.compareTo(b.slot.startAt));
    past.sort((a, b) => b.slot.startAt.compareTo(a.slot.startAt));

    _upcomingReservations = upcoming;
    _pastReservations = past;
  }

  List<DriverReservation> get _visibleReservations {
    return _filter == DriverReservationFilter.upcoming
        ? _upcomingReservations
        : _pastReservations;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            const _PageHeader(),
            Expanded(child: _buildBody()),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _openStationSelection,
                  child: const Text("Réserver un autre créneau"),
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
      return _StateMessage(
        message:
            "Impossible de charger vos réservations. Vérifiez votre connexion puis réessayez.",
        buttonLabel: "Réessayer",
        onTap: _loadReservations,
      );
    }

    final hasAnyReservation =
        _upcomingReservations.isNotEmpty || _pastReservations.isNotEmpty;
    if (!hasAnyReservation) {
      return _StateMessage(
        message:
            "Vous n'avez pas encore de créneau de recharge planifié. Ajoutez-en un pour remplir votre agenda.",
        buttonLabel: "Réserver un créneau",
        onTap: _openStationSelection,
      );
    }

    final reservations = _visibleReservations;
    final descending = _filter == DriverReservationFilter.past;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SegmentedButton<DriverReservationFilter>(
            segments: const [
              ButtonSegment(
                value: DriverReservationFilter.upcoming,
                label: Text("À venir"),
                icon: Icon(Icons.event_available_outlined),
              ),
              ButtonSegment(
                value: DriverReservationFilter.past,
                label: Text('Historique'),
                icon: Icon(Icons.history),
              ),
            ],
            showSelectedIcon: false,
            selected: {_filter},
            onSelectionChanged: (selection) {
              setState(() => _filter = selection.first);
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadReservations,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              children: reservations.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.only(top: 60),
                        child: _StateMessage(
                          message: _filter == DriverReservationFilter.upcoming
                              ? "Aucun créneau à venir. Pensez à réserver votre prochaine recharge."
                              : "Pas encore d'historique. Vos anciens créneaux apparaitront ici.",
                          buttonLabel: 'Actualiser',
                          onTap: _loadReservations,
                        ),
                      ),
                    ]
                  : _groupReservations(
                      reservations,
                      descending: descending,
                    ).map(_buildGroup).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Iterable<_ReservationGroup> _groupReservations(
    List<DriverReservation> reservations, {
    bool descending = false,
  }) sync* {
    final groups = <DateTime, List<DriverReservation>>{};
    for (final reservation in reservations) {
      final start = brusselsFromUtc(reservation.slot.startAt.toUtc());
      final key = DateTime(start.year, start.month, start.day);
      groups.putIfAbsent(key, () => []).add(reservation);
    }
    final sortedKeys = groups.keys.toList()
      ..sort((a, b) => descending ? b.compareTo(a) : a.compareTo(b));
    for (final key in sortedKeys) {
      final values = groups[key]!
        ..sort(
          (a, b) => descending
              ? b.slot.startAt.compareTo(a.slot.startAt)
              : a.slot.startAt.compareTo(b.slot.startAt),
        );
      yield _ReservationGroup(date: key, reservations: values);
    }
  }

  Widget _buildGroup(_ReservationGroup group) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(group.date),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ...group.reservations.map(
            (reservation) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReservationTile(
                reservation: reservation,
                onTap: () => _openReservation(reservation),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    const weekdays = [
      'Lundi',
      'Mardi',
      'Mercredi',
      'Jeudi',
      'Vendredi',
      'Samedi',
      'Dimanche',
    ];
    const months = [
      'janvier',
      'fevrier',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'aout',
      'septembre',
      'octobre',
      'novembre',
      'decembre',
    ];
    final weekday = weekdays[date.weekday - 1];
    final month = months[date.month - 1];
    return '$weekday ${date.day} $month ${date.year}';
  }
}

class _ReservationGroup {
  const _ReservationGroup({required this.date, required this.reservations});

  final DateTime date;
  final List<DriverReservation> reservations;
}

class _ReservationTile extends StatelessWidget {
  const _ReservationTile({required this.reservation, required this.onTap});

  final DriverReservation reservation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final start = brusselsFromUtc(reservation.slot.startAt.toUtc());
    final end = brusselsFromUtc(reservation.slot.endAt.toUtc());
    final station = reservation.station;
    final address = station.locationFormatted ?? _formatAddress(station);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.06),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFE7ECFF),
              ),
              child: const Icon(Icons.ev_station, color: Color(0xFF2C75FF)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatHour(start)} - ${_formatHour(end)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    station.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatHour(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _formatAddress(Station station) {
    final parts = [
      station.streetNumber,
      station.streetName,
      station.postalCode,
      station.city,
    ];
    return parts.where((part) => part.trim().isNotEmpty).join(' ');
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
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

class _PageHeader extends StatelessWidget {
  const _PageHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C75FF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const Expanded(
            child: Center(
              child: Text(
                'Votre agenda',
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

enum DriverReservationFilter { upcoming, past }
