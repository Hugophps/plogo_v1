import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_timezone.dart';
import '../profile/models/profile.dart';
import '../driver_map/driver_station_detail_page.dart';
import '../driver_map/driver_station_repository.dart';
import '../stations/driver_station_booking_page.dart';
import '../stations/models/station.dart';
import '../stations/models/station_slot.dart';
import '../stations/station_slots_repository.dart';
import '../stations/widgets/station_address_display.dart';
import '../stations/widgets/station_maps_launcher.dart';
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
  final _stationRepository = const DriverStationRepository();
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
              station: station,
              title: station.name,
              subtitle: _formatDate(start),
              timeRange: '${_formatHour(start)} - ${_formatHour(end)}',
              photoUrl: station.photoUrl,
              onTap: _openStationDetails,
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
              onPressed: _processing ? null : _openCalendarOptions,
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

  void _openCalendarOptions() {
    final station = _reservation.station;
    final address = station.locationFormatted ?? _formatAddress(station);
    final start = _slot.startAt.toUtc();
    final end = _slot.endAt.toUtc();
    final title = 'Recharge ${station.name}';
    final description = _calendarDescription(station, address);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Ajouter ce creneau',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Google Agenda'),
                  subtitle: const Text('Ouvrir Google Agenda'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _launchCalendarUrl(
                      _googleCalendarUri(
                        title: title,
                        description: description,
                        location: address,
                        start: start,
                        end: end,
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.email_outlined),
                  title: const Text('Outlook Calendar'),
                  subtitle: const Text('Ouvrir Outlook'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _launchCalendarUrl(
                      _outlookCalendarUri(
                        title: title,
                        description: description,
                        location: address,
                        start: start,
                        end: end,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _calendarDescription(Station station, String address) {
    final buffer = StringBuffer()
      ..writeln('Borne : ${station.name}')
      ..writeln('Adresse : $address');
    final info = station.additionalInfo;
    if (info != null && info.trim().isNotEmpty) {
      buffer.writeln('Infos : ${info.trim()}');
    }
    buffer.writeln('Reservation creee dans Plogo.');
    return buffer.toString();
  }

  Uri _googleCalendarUri({
    required String title,
    required String description,
    required String location,
    required DateTime start,
    required DateTime end,
  }) {
    final dates = '${_googleDate(start)}/${_googleDate(end)}';
    return Uri(
      scheme: 'https',
      host: 'calendar.google.com',
      path: '/calendar/render',
      queryParameters: {
        'action': 'TEMPLATE',
        'text': title,
        'details': description,
        'location': location,
        'dates': dates,
      },
    );
  }

  Uri _outlookCalendarUri({
    required String title,
    required String description,
    required String location,
    required DateTime start,
    required DateTime end,
  }) {
    return Uri(
      scheme: 'https',
      host: 'outlook.live.com',
      path: '/calendar/0/action/compose',
      queryParameters: {
        'rru': 'addevent',
        'subject': title,
        'body': description,
        'location': location,
        'startdt': _isoString(start),
        'enddt': _isoString(end),
      },
    );
  }

  String _googleDate(DateTime date) {
    final utc = date.toUtc();
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    return '${year}${month}${day}T$hour$minute${second}Z';
  }

  String _isoString(DateTime date) {
    final utc = date.toUtc();
    final year = utc.year.toString().padLeft(4, '0');
    final month = utc.month.toString().padLeft(2, '0');
    final day = utc.day.toString().padLeft(2, '0');
    final hour = utc.hour.toString().padLeft(2, '0');
    final minute = utc.minute.toString().padLeft(2, '0');
    final second = utc.second.toString().padLeft(2, '0');
    return '${year}-${month}-${day}T$hour:$minute:${second}Z';
  }

  Future<void> _launchCalendarUrl(Uri uri) async {
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Impossible d\'ouvrir le calendrier. Reessayez plus tard.',
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Impossible d\'ouvrir le calendrier. Reessayez plus tard.',
          ),
        ),
      );
    }
  }

  Future<void> _openStationDetails() async {
    try {
      final view = await _stationRepository.fetchStationViewById(
        _reservation.station.id,
      );
      if (!mounted) return;
      if (view == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Borne introuvable.')));
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DriverStationDetailPage(
            initialStation: view,
            repository: _stationRepository,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Impossible d\'ouvrir la borne pour le moment.'),
        ),
      );
    }
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
    required this.station,
    required this.title,
    required this.subtitle,
    required this.timeRange,
    this.photoUrl,
    this.onTap,
  });

  final Station station;
  final String title;
  final String subtitle;
  final String timeRange;
  final String? photoUrl;
  final VoidCallback? onTap;
  static const _mapsLauncher = StationMapsLauncher();

  @override
  Widget build(BuildContext context) {
    final card = Container(
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
                const SizedBox(height: 8),
                StationAddressDisplay(
                  station: station,
                  mapsLauncher: _mapsLauncher,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) {
      return card;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: card,
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
