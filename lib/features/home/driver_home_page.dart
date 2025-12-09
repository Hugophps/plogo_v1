import 'package:flutter/material.dart';

import '../charging/driver_charging_repository.dart';
import '../charging/driver_charging_service.dart';
import '../charging/models/driver_charging_view.dart';
import '../profile/models/profile.dart';
import '../stations/models/station_slot.dart';

class DriverHomePage extends StatefulWidget {
  const DriverHomePage({
    super.key,
    required this.profile,
    required this.onOpenProfile,
    required this.onOpenMap,
    required this.onOpenStationSelection,
    required this.onOpenReservations,
  });

  final Profile profile;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenStationSelection;
  final VoidCallback onOpenReservations;

  @override
  State<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends State<DriverHomePage> {
  final _chargingRepository = const DriverChargingRepository();
  final _chargingService = const DriverChargingService();

  DriverChargingView? _chargingView;
  bool _loadingCharging = true;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _loadChargingState();
  }

  Future<void> _loadChargingState() async {
    setState(() {
      _loadingCharging = true;
    });
    try {
      final view = await _chargingRepository.fetchDashboardState();
      if (!mounted) return;
      setState(() {
        _chargingView = view;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _chargingView = DriverChargingView(
          status: DriverChargingStatus.error,
          errorMessage: error.toString(),
        );
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loadingCharging = false;
      });
    }
  }

  Future<void> _startCharging() async {
    final view = _chargingView;
    final stationId = view?.station?.id ?? view?.membership?.stationId;
    if (stationId == null || _actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final result = await _chargingService.startCharging(stationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Charge démarrée.'),
        ),
      );
      await _loadChargingState();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (!mounted) return;
      setState(() => _actionInProgress = false);
    }
  }

  Future<void> _stopCharging() async {
    final view = _chargingView;
    final stationId = view?.station?.id ?? view?.membership?.stationId;
    if (stationId == null || _actionInProgress) return;
    setState(() => _actionInProgress = true);
    try {
      final result = await _chargingService.stopCharging(stationId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Charge arrêtée.'),
        ),
      );
      await _loadChargingState();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (!mounted) return;
      setState(() => _actionInProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initials = _initialsFromName(widget.profile.fullName);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadChargingState,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.profile.fullName ?? 'Nom utilisateur',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  InkWell(
                    onTap: widget.onOpenProfile,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: const EdgeInsets.all(2.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF2C75FF),
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 26,
                        backgroundColor: const Color(0xFFE7ECFF),
                        backgroundImage: widget.profile.avatarUrl != null
                            ? NetworkImage(widget.profile.avatarUrl!)
                            : null,
                        child: widget.profile.avatarUrl == null
                            ? Text(
                                initials,
                                style: const TextStyle(
                                  color: Color(0xFF2C75FF),
                                  fontWeight: FontWeight.w700,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildChargingCard(context),
              const SizedBox(height: 24),
              _DriverMapPreviewCard(onTap: widget.onOpenMap),
              const SizedBox(height: 16),
              _DriverSectionCard(
                title: 'Calendrier',
                description: "Suivez vos sessions à venir.",
                icon: Icons.calendar_today,
                onTap: widget.onOpenReservations,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChargingCard(BuildContext context) {
    final view = _chargingView;
    final theme = Theme.of(context);
    final stationName = view?.station?.name ?? "Borne Plogo";
    final statusLabel = _statusLabelFor(view);
    final description = _statusDescriptionFor(view);
    final showStart = view?.canStart ?? false;
    final showStop = view?.canStop ?? false;
    final slotLabel = _slotLabelFor(view);
    final summaryLabel = _sessionSummaryFor(view);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.06),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColorFor(view),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Actualiser le statut',
                onPressed: _loadingCharging ? null : _loadChargingState,
                icon: _loadingCharging
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            stationName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (slotLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              slotLabel,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          if (view?.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              view!.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (summaryLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              summaryLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 20),
          if (showStart)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_actionInProgress || _loadingCharging) ? null : _startCharging,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFF2C75FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _actionInProgress ? 'Connexion...' : "Démarrer la charge",
                ),
              ),
            ),
          if (showStop)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_actionInProgress || _loadingCharging) ? null : _stopCharging,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: const Color(0xFFFFB347),
                  foregroundColor: Colors.black87,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _actionInProgress ? 'Arrêt...' : "Arrêter la charge",
                ),
              ),
            ),
          SizedBox(height: showStart || showStop ? 12 : 0),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: widget.onOpenStationSelection,
              icon: const Icon(Icons.flash_on_outlined),
              label: const Text("Réserver une session de charge"),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                foregroundColor: const Color(0xFF2C75FF),
                side: const BorderSide(
                  color: Color(0xFF2C75FF),
                  width: 1.4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColorFor(DriverChargingView? view) {
    switch (view?.status) {
      case DriverChargingStatus.readyToCharge:
        return const Color(0xFF2C75FF);
      case DriverChargingStatus.charging:
        return const Color(0xFF3B5AFF);
      case DriverChargingStatus.completed:
        return const Color(0xFF22C55E);
      case DriverChargingStatus.upcomingReservation:
        return const Color(0xFFFFB347);
      case DriverChargingStatus.error:
        return Colors.red.shade600;
      default:
        return Colors.grey.shade500;
    }
  }

  String _statusLabelFor(DriverChargingView? view) {
    switch (view?.status) {
      case DriverChargingStatus.readyToCharge:
        return "Statut : prêt à charger";
      case DriverChargingStatus.charging:
        return "Statut : charge en cours";
      case DriverChargingStatus.completed:
        return "Statut : session terminée";
      case DriverChargingStatus.upcomingReservation:
        return "Statut : session planifiée";
      case DriverChargingStatus.noMembership:
        return "Statut : aucune borne reliée";
      case DriverChargingStatus.noReservation:
        return "Statut : aucune session planifiée";
      case DriverChargingStatus.error:
        return "Statut : indisponible";
      default:
        return "Statut : préparation";
    }
  }

  String _statusDescriptionFor(DriverChargingView? view) {
    if (view == null) {
      return "Chargement du statut en cours...";
    }
    switch (view.status) {
      case DriverChargingStatus.readyToCharge:
        return "Votre créneau est actif. Branchez votre véhicule puis lancez la charge depuis Plogo.";
      case DriverChargingStatus.charging:
        return "La borne est en charge. Vous pourrez l'arrêter dès que vous le souhaitez.";
      case DriverChargingStatus.completed:
        return "La dernière session est terminée. Vérifiez les informations ci-dessous.";
      case DriverChargingStatus.upcomingReservation:
        return "Votre prochaine session est prête. Soyez à l'heure pour démarrer la charge.";
      case DriverChargingStatus.noMembership:
        return "Rejoignez une station pour accéder au contrôle à distance de la borne.";
      case DriverChargingStatus.noReservation:
        return "Planifiez une session pour accéder au contrôle de charge.";
      case DriverChargingStatus.error:
        return view.errorMessage ??
            "Impossible de récupérer le statut de la borne actuellement.";
    }
  }

  String? _slotLabelFor(DriverChargingView? view) {
    if (view == null) return null;
    final slot = view.activeSlot ?? view.nextSlot;
    if (slot == null) return null;
    final prefix =
        view.activeSlot != null ? "Créneau en cours" : "Prochaine session";
    return "$prefix : ${_formatSlotRange(slot)}";
  }

  String? _sessionSummaryFor(DriverChargingView? view) {
    final session = view?.session;
    if (session == null) return null;
    final parts = <String>[];
    if (session.energyKwh != null) {
      parts.add("${session.energyKwh!.toStringAsFixed(1)} kWh");
    }
    if (session.amountEur != null) {
      parts.add("${session.amountEur!.toStringAsFixed(2)} €");
    }
    if (parts.isEmpty) return null;
    return "Résumé session : ${parts.join(' · ')}";
  }

  String _formatSlotRange(StationSlot slot) {
    final start = slot.startAt.toLocal();
    final end = slot.endAt.toLocal();
    final day =
        "${_twoDigits(start.day)}/${_twoDigits(start.month)}";
    final startTime =
        "${_twoDigits(start.hour)}h${_twoDigits(start.minute)}";
    final endTime =
        "${_twoDigits(end.hour)}h${_twoDigits(end.minute)}";
    return "$day · $startTime - $endTime";
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  String _initialsFromName(String? fullName) {
    if (fullName == null || fullName.trim().isEmpty) return 'P';
    final parts = fullName.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.last : '';
    final buffer = StringBuffer();
    if (first.isNotEmpty) buffer.write(first[0]);
    if (last.isNotEmpty) buffer.write(last[0]);
    return buffer.isEmpty ? 'P' : buffer.toString().toUpperCase();
  }
}

class _DriverSectionCard extends StatelessWidget {
  const _DriverSectionCard({
    required this.title,
    required this.description,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 15,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color.fromRGBO(44, 117, 255, 0.1),
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(icon, color: const Color(0xFF2C75FF)),
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
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}

class _DriverMapPreviewCard extends StatelessWidget {
  const _DriverMapPreviewCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.05),
              blurRadius: 15,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color.fromRGBO(44, 117, 255, 0.12),
              ),
              child: const Icon(
                Icons.map_outlined,
                color: Color(0xFF2C75FF),
                size: 30,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Trouver une borne proche de moi',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Ouvrez la carte pour explorer les bornes Plogo autour de vous.',
                    style: TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
