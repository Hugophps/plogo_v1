import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../profile/models/profile.dart';
import '../profile/profile_repository.dart';
import '../stations/driver_station_booking_page.dart';
import '../stations/models/station.dart';
import '../stations/owner_station_agenda_page.dart';
import '../stations/station_slots_repository.dart';
import 'driver_station_models.dart';
import 'driver_station_repository.dart';

class DriverStationDetailPage extends StatefulWidget {
  const DriverStationDetailPage({
    super.key,
    required this.initialStation,
    required this.repository,
  });

  final DriverStationView initialStation;
  final DriverStationRepository repository;

  @override
  State<DriverStationDetailPage> createState() =>
      _DriverStationDetailPageState();
}

class _DriverStationDetailPageState extends State<DriverStationDetailPage> {
  final _slotsRepository = const StationSlotsRepository();
  final _profileRepository = const ProfileRepository();

  late DriverStationView _stationView;
  bool _requestInProgress = false;
  bool _leaveInProgress = false;
  Profile? _currentProfile;

  DriverStationMembership? get _membership => _stationView.membership;

  DriverStationAccessStatus get _status =>
      _membership?.status ?? DriverStationAccessStatus.none;

  @override
  void initState() {
    super.initState();
    _stationView = widget.initialStation;
  }

  @override
  Widget build(BuildContext context) {
    final station = _stationView.station;
    final owner = _stationView.owner;

    return WillPopScope(
      onWillPop: () async {
        _closeWithResult();
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2C75FF),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _closeWithResult,
          ),
          title: const Text('Selectionner une borne'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StationSummaryCard(
                station: station,
                owner: owner,
                status: _status,
              ),
              const SizedBox(height: 24),
              _buildActions(context, station),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions(BuildContext context, Station station) {
    switch (_status) {
      case DriverStationAccessStatus.none:
        return FilledButton(
          onPressed: _requestInProgress ? null : () => _requestAccess(),
          child: _requestInProgress
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text("Demander l'acces a la borne"),
        );
      case DriverStationAccessStatus.pending:
        return FilledButton(
          onPressed: null,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE7ECFF),
            foregroundColor: const Color(0xFF2C75FF),
          ),
          child: const Text('Demande en attente'),
        );
      case DriverStationAccessStatus.approved:
        return _buildApprovedActions(context, station);
    }
  }

  Widget _buildApprovedActions(BuildContext context, Station station) {
    final widgets = <Widget>[];

    if (station.whatsappGroupUrl != null &&
        station.whatsappGroupUrl!.isNotEmpty) {
      widgets.add(
        OutlinedButton.icon(
          onPressed: () => _openWhatsappGroup(station.whatsappGroupUrl!),
          icon: const Icon(Icons.chat_outlined),
          label: const Text('Ouvrir le groupe WhatsApp de la borne'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2C75FF),
            side: const BorderSide(color: Color(0xFF2C75FF)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          ),
        ),
      );
      widgets.add(const SizedBox(height: 16));
    }

    widgets.add(
      FilledButton(
        onPressed: () => _openBookingFlow(station),
        child: const Text('R\u00e9server un cr\u00e9neau'),
      ),
    );
    widgets.add(const SizedBox(height: 12));
    widgets.add(
      OutlinedButton(
        onPressed: () => _openAgenda(station),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF2C75FF),
          side: const BorderSide(color: Color(0xFF2C75FF)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        child: const Text("Voir l'agenda de la borne"),
      ),
    );
    widgets.add(const SizedBox(height: 12));
    widgets.add(
      Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          onPressed: _leaveInProgress ? null : _showLeaveSheet,
          icon: const Icon(Icons.more_horiz),
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: widgets,
    );
  }

  Future<Profile?> _ensureProfile() async {
    if (_currentProfile != null) return _currentProfile;
    final profile = await _profileRepository.fetchCurrentProfile();
    if (mounted) {
      setState(() => _currentProfile = profile);
    } else {
      _currentProfile = profile;
    }
    return profile;
  }

  Future<void> _openBookingFlow(Station station) async {
    final membership = _membership;
    if (membership == null || !membership.isApproved) return;
    final profile = await _ensureProfile();
    if (!mounted) return;
    if (profile == null) {
      _showProfileMissingSnack();
      return;
    }
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DriverStationBookingPage(
          station: station,
          repository: _slotsRepository,
          profile: profile,
          membershipId: membership.id,
        ),
      ),
    );
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cr\u00e9neau r\u00e9serv\u00e9.')),
      );
    }
  }

  Future<void> _openAgenda(Station station) async {
    final membership = _membership;
    if (membership == null || !membership.isApproved) return;
    final profile = await _ensureProfile();
    if (!mounted) return;
    if (profile == null) {
      _showProfileMissingSnack();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OwnerStationAgendaPage(
          station: station,
          viewer: StationAgendaViewer.member,
          viewerProfile: profile,
          membershipId: membership.id,
        ),
      ),
    );
  }

  void _showProfileMissingSnack() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profil conducteur incomplet.')),
    );
  }

  Future<void> _requestAccess() async {
    setState(() => _requestInProgress = true);
    try {
      final membership = await widget.repository.requestAccess(
        _stationView.station.id,
      );
      setState(() {
        _stationView = _stationView.copyWith(membership: membership);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande envoyee au proprietaire.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de demander l\'acces: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _requestInProgress = false);
      }
    }
  }

  Future<void> _openWhatsappGroup(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Lien WhatsApp invalide.')));
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir WhatsApp.')),
      );
    }
  }

  void _showLeaveSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ne plus etre membre de cette borne',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Vous perdrez l\'acces a cette borne immediatement. Vous pourrez refaire une demande plus tard.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2C75FF),
                          side: const BorderSide(color: Color(0xFF2C75FF)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _leaveInProgress
                            ? null
                            : () {
                                Navigator.of(context).pop();
                                _leaveStation();
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFFB347),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _leaveInProgress
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Confirmer'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _leaveStation() async {
    final membership = _membership;
    if (membership == null) return;
    setState(() => _leaveInProgress = true);
    try {
      await widget.repository.leaveStation(membership.id);
      setState(() {
        _stationView = _stationView.copyWith(membership: null);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vous avez quitte cette borne.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de quitter la borne: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _leaveInProgress = false);
      }
    }
  }

  void _closeWithResult() {
    Navigator.of(context).pop(_stationView.membership);
  }
}

class _StationSummaryCard extends StatelessWidget {
  const _StationSummaryCard({
    required this.station,
    required this.owner,
    required this.status,
  });

  final Station station;
  final DriverStationOwnerSummary owner;
  final DriverStationAccessStatus status;

  @override
  Widget build(BuildContext context) {
    final address = _formatAddress(station);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.08),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: const Color(0xFFE7ECFF),
                backgroundImage: station.photoUrl != null
                    ? NetworkImage(station.photoUrl!)
                    : null,
                child: station.photoUrl == null
                    ? const Icon(
                        Icons.image_outlined,
                        size: 36,
                        color: Color(0xFF2C75FF),
                      )
                    : null,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusChip(status: status),
                    const SizedBox(height: 8),
                    Text(
                      station.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      station.chargerBrand.isNotEmpty
                          ? '${station.chargerBrand} · ${station.chargerModel}'
                          : station.chargerModel,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            address,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          if (station.additionalInfo != null &&
              station.additionalInfo!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              station.additionalInfo!,
              style: const TextStyle(color: Colors.black87),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE7ECFF),
                backgroundImage: owner.avatarUrl != null
                    ? NetworkImage(owner.avatarUrl!)
                    : null,
                child: owner.avatarUrl == null
                    ? const Icon(Icons.person_outline, color: Color(0xFF2C75FF))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  owner.displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAddress(Station station) {
    final parts = <String>[
      station.streetNumber,
      station.streetName,
      station.postalCode,
      station.city,
      station.country,
    ];
    parts.removeWhere((part) => part.trim().isEmpty);
    if (parts.isEmpty) return 'Adresse non renseignÃƒÆ’Ã‚Â©e';
    return parts.where((part) => part.trim().isNotEmpty).join(' ');
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final DriverStationAccessStatus status;

  @override
  Widget build(BuildContext context) {
    late Color background;
    late Color textColor;
    late String label;

    switch (status) {
      case DriverStationAccessStatus.none:
        background = const Color(0xFFE7ECFF);
        textColor = const Color(0xFF2C75FF);
        label = 'Non admis';
        break;
      case DriverStationAccessStatus.pending:
        background = const Color(0xFFFFF1DC);
        textColor = const Color(0xFFCC8400);
        label = 'En attente';
        break;
      case DriverStationAccessStatus.approved:
        background = const Color(0xFFE5F6E9);
        textColor = const Color(0xFF2E8B57);
        label = 'Admis';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}
