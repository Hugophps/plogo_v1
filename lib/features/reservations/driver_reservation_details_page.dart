import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_timezone.dart';
import '../profile/models/profile.dart';
import '../stations/driver_station_booking_page.dart';
import '../stations/models/station.dart';
import '../stations/models/station_slot.dart';
import '../stations/station_slots_repository.dart';
import 'driver_reservations_repository.dart';

class DriverReservationDetailsPage extends StatefulWidget {
  const DriverReservationDetailsPage({
    super.key,
    required this.reservation,
    required this.profile,
  });

  final DriverReservation reservation;
  final Profile profile;

  @override
  State<DriverReservationDetailsPage> createState() =>
      _DriverReservationDetailsPageState();
}

class _DriverReservationDetailsPageState
    extends State<DriverReservationDetailsPage> {
  final _repository = const StationSlotsRepository();
  bool _processing = false;

  DriverReservation get _reservation => widget.reservation;

  StationSlot get _slot => _reservation.slot;
  bool get _isPastSlot => !_slot.endAt.isAfter(DateTime.now().toUtc());

  @override
  Widget build(BuildContext context) {
    final start = brusselsFromUtc(_slot.startAt.toUtc());
    final end = brusselsFromUtc(_slot.endAt.toUtc());
    final station = _reservation.station;
    final address = station.locationFormatted ?? _formatAddress(station);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C75FF),
        foregroundColor: Colors.white,
        title: const Text('Votre agenda'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StationSummaryCard(
              title: station.name,
              subtitle: _formatDate(start),
              timeRange: '${_formatHour(start)} - ${_formatHour(end)}',
              address: address,
              photoUrl: station.photoUrl,
            ),
            const SizedBox(height: 24),
            _InfoRow(label: 'Date', value: _formatDate(start)),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'Horaires',
              value: 'De ${_formatHour(start)} a ${_formatHour(end)}',
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Borne', value: station.name),
            const SizedBox(height: 16),
            _InfoRow(label: 'Adresse', value: address),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: _processing ? null : _showCalendarPlaceholder,
              icon: const Icon(Icons.event_available_outlined),
              label: const Text('Importer dans mon calendrier'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2C75FF),
                side: const BorderSide(color: Color(0xFF2C75FF)),
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 20,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _processing || _isPastSlot ? null : _openEditSlot,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Modifier le creneau'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _processing || _isPastSlot ? null : _confirmCancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2C75FF),
                side: const BorderSide(color: Color(0xFF2C75FF)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Annuler ce creneau'),
            ),
            if (_isPastSlot) ...[
              const SizedBox(height: 12),
              const Text(
                'Ce creneau est deja termine. Modification et annulation desactivees.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openEditSlot() async {
    final station = _reservation.station;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DriverStationBookingPage(
          station: station,
          repository: _repository,
          profile: widget.profile,
          membershipId: _reservation.membership.id,
          slot: _slot,
          initialDate: tz.TZDateTime.from(_slot.startAt, brusselsLocation),
        ),
      ),
    );
    if (result == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _confirmCancel() async {
    final shouldCancel =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Annuler ce creneau ?'),
            content: const Text(
              'Cette action liberera le creneau pour les autres membres. Voulez-vous continuer ?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Non'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Oui, annuler'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldCancel) return;
    setState(() => _processing = true);
    try {
      await _repository.deleteSlot(_slot.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _processing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d\'annuler ce creneau. Reessayez plus tard.',
          ),
        ),
      );
    }
  }

  void _showCalendarPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('L\'export calendrier arrive bientot.')),
    );
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

  String _formatHour(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

class _StationSummaryCard extends StatelessWidget {
  const _StationSummaryCard({
    required this.title,
    required this.subtitle,
    required this.timeRange,
    required this.address,
    this.photoUrl,
  });

  final String title;
  final String subtitle;
  final String timeRange;
  final String address;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE7ECFF),
              image: photoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(photoUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: photoUrl == null
                ? const Icon(Icons.ev_station, color: Color(0xFF2C75FF))
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 4),
                Text(
                  timeRange,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(address, style: const TextStyle(color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ],
    );
  }
}
