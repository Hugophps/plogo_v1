import 'package:flutter/material.dart';

import '../profile/models/profile.dart';
import 'models/station_member.dart';
import 'station_members_repository.dart';

class MemberDetailPage extends StatefulWidget {
  const MemberDetailPage({
    super.key,
    required this.membershipId,
    required this.repository,
    required this.initialMember,
  });

  final String membershipId;
  final StationMembersRepository repository;
  final StationMember initialMember;

  @override
  State<MemberDetailPage> createState() => _MemberDetailPageState();
}

class _MemberDetailPageState extends State<MemberDetailPage> {
  late StationMember _member;
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _member = widget.initialMember;
    _loadMember();
  }

  Future<void> _loadMember() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fetched = await widget.repository.fetchMember(widget.membershipId);
      if (!mounted) return;
      setState(() {
        _member = fetched;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger ce membre.';
      });
    }
  }

  Future<void> _approveMember() async {
    setState(() => _submitting = true);
    try {
      await widget.repository.approveMember(_member);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showError('Erreur lors de l’acceptation du membre.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _deleteMembership({required bool fromPending}) async {
    final confirmed = await _confirmAction(
      title: fromPending ? 'Refuser cette demande ?' : 'Supprimer ce membre ?',
      message: fromPending
          ? 'Cette personne ne pourra pas accéder à votre borne tant qu’elle n’aura pas fait une nouvelle demande.'
          : 'Le membre perdra son accès à votre borne. Vous pourrez l’accepter à nouveau plus tard.',
      confirmLabel: fromPending ? 'Refuser' : 'Supprimer',
    );
    if (!confirmed) return;

    setState(() => _submitting = true);
    try {
      await widget.repository.deleteMembership(_member.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _showError('Impossible de mettre à jour ce membre.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFB347),
              foregroundColor: Colors.black,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final profile = _member.profile;
    final statusChip = _member.isPending
        ? const _StatusChip(
            label: 'Demande en attente',
            backgroundColor: Color(0xFFFFF1DC),
            textColor: Color(0xFFCC8400),
          )
        : const _StatusChip(
            label: 'Membre',
            backgroundColor: Color(0xFFE7ECFF),
            textColor: Color(0xFF2C75FF),
          );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFB347),
        elevation: 0,
        centerTitle: true,
        foregroundColor: Colors.black,
        title: const Text('Membres de la borne'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadMember,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 24,
                    ),
                    children: [
                      Center(
                        child: CircleAvatar(
                          radius: 42,
                          backgroundColor: const Color(0xFFE7ECFF),
                          backgroundImage: profile.avatarUrl != null
                              ? NetworkImage(profile.avatarUrl!)
                              : null,
                          child: profile.avatarUrl == null
                              ? Text(
                                  _initials(profile.fullName),
                                  style: const TextStyle(
                                    color: Color(0xFF2C75FF),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 20,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(child: statusChip),
                      const SizedBox(height: 16),
                      Text(
                        profile.fullName ?? 'Membre sans nom',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if ((profile.city ?? '').isNotEmpty ||
                          (profile.country ?? '').isNotEmpty)
                        Text(
                          [
                            if ((profile.city ?? '').isNotEmpty) profile.city,
                            if ((profile.country ?? '').isNotEmpty)
                              profile.country,
                          ].whereType<String>().join(', '),
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.black54),
                        ),
                      const SizedBox(height: 16),
                      _VehicleCard(profile: profile),
                      const SizedBox(height: 24),
                      if ((profile.description ?? '').isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE0E3EB)),
                          ),
                          child: Text(
                            profile.description!,
                            style: const TextStyle(fontSize: 15, height: 1.4),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE0E3EB)),
                          ),
                          child: const Text(
                            'Aucune description fournie.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  color: Colors.white,
                  child: _member.isPending
                      ? Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: _submitting ? null : _approveMember,
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFB347),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: _submitting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Accepter ce membre'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _submitting
                                    ? null
                                    : () =>
                                          _deleteMembership(fromPending: true),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF2C75FF),
                                  side: const BorderSide(
                                    color: Color(0xFF2C75FF),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                child: const Text('Refuser ce membre'),
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _submitting
                                ? null
                                : () => _deleteMembership(fromPending: false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFFCC8400),
                              side: const BorderSide(color: Color(0xFFFFB347)),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: const Text('Supprimer ce membre'),
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return 'M';
    final parts = name.trim().split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.last : '';
    final buffer = StringBuffer();
    if (first.isNotEmpty) buffer.write(first[0]);
    if (last.isNotEmpty) buffer.write(last[0]);
    return buffer.isEmpty ? 'M' : buffer.toString().toUpperCase();
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  final String label;
  final Color backgroundColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E3EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Détails du véhicule',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 12),
          _VehicleInfoRow(
            label: 'Marque',
            value: profile.vehicleBrand,
          ),
          const SizedBox(height: 8),
          _VehicleInfoRow(
            label: 'Mod\u00e8le',
            value: profile.vehicleModel,
          ),
          const SizedBox(height: 8),
          _VehicleInfoRow(
            label: 'Plaque',
            value: profile.vehiclePlate,
          ),
        ],
      ),
    );
  }
}

class _VehicleInfoRow extends StatelessWidget {
  const _VehicleInfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(value?.isNotEmpty == true ? value! : 'Non renseigné'),
      ],
    );
  }
}
