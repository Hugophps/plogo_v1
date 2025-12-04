import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../profile/models/profile.dart';
import '../profile/profile_repository.dart';
import '../stations/driver_station_booking_page.dart';
import '../stations/models/station.dart';
import '../stations/owner_station_agenda_page.dart';
import '../stations/station_slots_repository.dart';
import '../stations/widgets/station_maps_launcher.dart';
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
  static const _mapsLauncher = StationMapsLauncher();

  @override
  Widget build(BuildContext context) {
    final address = _formatAddress(station);
    final canLaunchMaps = _hasLaunchableAddress(station);
    final streetLine = _streetLine(station);
    final cityLine = _cityLine(station);

    String? line1 =
        streetLine != null && streetLine.trim().isNotEmpty ? streetLine : null;
    String? line2 =
        cityLine != null && cityLine.trim().isNotEmpty ? cityLine : null;

    if ((line1 == null || line1.isEmpty) &&
        (line2 == null || line2.isEmpty)) {
      final formatted = station.locationFormatted?.trim();
      if (formatted != null && formatted.isNotEmpty) {
        final segments = formatted.split(',');
        if (segments.length == 1) {
          line1 = segments.first.trim();
        } else {
          line1 = segments.first.trim();
          line2 = segments.skip(1).join(', ').trim();
        }
      } else {
        line1 = address;
      }
    } else if (line1 == null || line1.isEmpty) {
      line1 = line2;
      line2 = null;
    }

    final structuredLine1 = line1 ?? address;
    final structuredLine2 = line2;
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
                    if (station.chargerLabel != null)
                      Text(
                        station.chargerLabel!,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    if (station.priceLabel != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          station.priceLabel!,
                          style: const TextStyle(
                            color: Color(0xFF2C75FF),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _StationAddressBlock(
            line1: structuredLine1,
            line2: structuredLine2,
            canLaunchMaps: canLaunchMaps,
            onOpenMaps: () =>
                _mapsLauncher.open(context: context, station: station),
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

class _StationAddressBlock extends StatelessWidget {
  const _StationAddressBlock({
    required this.line1,
    this.line2,
    required this.canLaunchMaps,
    required this.onOpenMaps,
  });

  final String line1;
  final String? line2;
  final bool canLaunchMaps;
  final VoidCallback onOpenMaps;

  @override
  Widget build(BuildContext context) {
    final background = const Color(0xFFF1F4FF);
    final textColor = Colors.black87;
    final secondaryColor = Colors.black54;
    final showLine2 = line2 != null && line2!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
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
                  text: line1,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    fontSize: 14,
                  ),
                  backgroundColor: background,
                ),
                if (showLine2) ...[
                  const SizedBox(height: 4),
                  _ScrollingAddressLine(
                    text: line2!.trim(),
                    style: TextStyle(
                      color: secondaryColor,
                      fontSize: 13,
                    ),
                    backgroundColor: background,
                  ),
                ],
              ],
            ),
          ),
          if (canLaunchMaps) ...[
            const SizedBox(width: 8),
            _OpenInMapsButton(onPressed: onOpenMaps),
          ],
        ],
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
    return SizedBox(
      height:
          widget.style.fontSize != null ? widget.style.fontSize! * 1.4 : null,
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
    final begin =
        alignment == Alignment.centerLeft ? Alignment.centerLeft : Alignment.centerRight;
    final end =
        alignment == Alignment.centerLeft ? Alignment.centerRight : Alignment.centerLeft;
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
