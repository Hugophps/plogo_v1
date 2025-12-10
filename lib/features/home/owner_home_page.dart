import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../profile/models/profile.dart';
import '../station_members/members_management_page.dart';
import '../station_members/models/station_member.dart';
import '../station_members/station_members_repository.dart';
import '../stations/models/station.dart';
import '../stations/owner_station_agenda_page.dart';

class OwnerHomePage extends StatefulWidget {
  const OwnerHomePage({
    super.key,
    required this.profile,
    required this.onOpenProfile,
    required this.onCreateStation,
    required this.onEditStation,
    this.station,
    this.onStationUpdated,
  });

  final Profile profile;
  final VoidCallback onOpenProfile;
  final VoidCallback onCreateStation;
  final VoidCallback onEditStation;
  final Station? station;
  final ValueChanged<Station>? onStationUpdated;

  @override
  State<OwnerHomePage> createState() => _OwnerHomePageState();
}

class _OwnerHomePageState extends State<OwnerHomePage> {
  final _membersRepository = const StationMembersRepository();
  Station? _station;
  List<StationMember>? _members;
  bool _loadingMembers = false;
  String? _membersError;

  @override
  void initState() {
    super.initState();
    _station = widget.station;
    if (_station != null) {
      _loadMembers();
    }
  }

  @override
  void didUpdateWidget(covariant OwnerHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.station?.id != widget.station?.id) {
      _station = widget.station;
      if (_station != null) {
        _loadMembers();
      } else {
        setState(() {
          _members = null;
          _membersError = null;
          _loadingMembers = false;
        });
      }
    }
  }

  Future<void> _loadMembers() async {
    final station = _station;
    if (station == null) return;
    setState(() {
      _loadingMembers = true;
      _membersError = null;
    });
    try {
      final members = await _membersRepository.fetchMembers(station.id);
      if (!mounted) return;
      setState(() {
        _members = members;
        _loadingMembers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingMembers = false;
        _membersError = 'Impossible de charger les membres.';
      });
    }
  }

  Future<void> _openMembersManagement() async {
    final station = _station;
    if (station == null) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MembersManagementPage(
          station: station,
          repository: _membersRepository,
        ),
      ),
    );
    if (updated == true) {
      await _loadMembers();
    }
  }

  Future<void> _openWhatsAppGroup() async {
    final link = _station?.whatsappGroupUrl;
    if (link == null || link.isEmpty) {
      _showSnackBar(
        "Ajoutez le lien du groupe WhatsApp depuis les paramètres de la borne.",
      );
      return;
    }
    final uri = Uri.tryParse(link);
    if (uri == null) {
      _showSnackBar('Lien WhatsApp invalide.');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar("Impossible d'ouvrir WhatsApp.");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openAgenda() async {
    final station = _station;
    if (station == null) {
      _showSnackBar(
        "Publiez votre borne pour accéder à son agenda.",
      );
      return;
    }
    final updated = await Navigator.of(context).push<Station>(
      MaterialPageRoute(
        builder: (_) => OwnerStationAgendaPage(station: station),
      ),
    );
    if (updated != null) {
      setState(() {
        _station = updated;
      });
      widget.onStationUpdated?.call(updated);
      await _loadMembers();
    }
  }

  bool _isOwnerMember(StationMember member) {
    final station = _station;
    if (station == null) return false;
    return member.profile.id == station.ownerId;
  }

  int get _approvedCount =>
      _members
          ?.where(
              (member) => member.isApproved && !_isOwnerMember(member))
          .length ??
      0;

  int get _pendingCount =>
      _members
          ?.where(
              (member) => member.isPending && !_isOwnerMember(member))
          .length ??
      0;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = widget.profile;
    final initials = _initialsFromName(profile.fullName);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    profile.fullName ?? 'Nom utilisateur',
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
                        backgroundImage: profile.avatarUrl != null
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: profile.avatarUrl == null
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
              _StationSection(
                station: _station,
                onCreateStation: widget.onCreateStation,
                onEditStation: widget.onEditStation,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: [
                    _HomeSectionCard(
                      title: 'Calendrier',
                      description:
                          'Consultez et g\u00e9rez les cr\u00e9neaux r\u00e9serv\u00e9s ou disponibles.',
                      icon: Icons.calendar_today,
                      onTap: () => _openAgenda(),
                    ),
                    const SizedBox(height: 16),
                    if (_station != null)
                      _MembersOverviewCard(
                        loading: _loadingMembers,
                        error: _membersError,
                        approvedCount: _approvedCount,
                        pendingCount: _pendingCount,
                        onRetry: _loadMembers,
                        onOpenManagement: _openMembersManagement,
                        onOpenWhatsApp: _openWhatsAppGroup,
                        hasWhatsAppLink:
                            (_station?.whatsappGroupUrl ?? '').isNotEmpty,
                      )
                    else
                      const _MembersPlaceholderCard(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeSectionCard extends StatelessWidget {
  const _HomeSectionCard({
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
    final card = Container(
      padding: const EdgeInsets.all(20),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE7ECFF),
              borderRadius: BorderRadius.circular(16),
            ),
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
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(color: Colors.black54, height: 1.4),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.black26),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: card,
      ),
    );
  }
}

class _MembersOverviewCard extends StatelessWidget {
  const _MembersOverviewCard({
    required this.loading,
    required this.error,
    required this.approvedCount,
    required this.pendingCount,
    required this.onRetry,
    required this.onOpenManagement,
    required this.onOpenWhatsApp,
    required this.hasWhatsAppLink,
  });

  final bool loading;
  final String? error;
  final int approvedCount;
  final int pendingCount;
  final Future<void> Function() onRetry;
  final VoidCallback onOpenManagement;
  final VoidCallback onOpenWhatsApp;
  final bool hasWhatsAppLink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Membres',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: loading ? null : onOpenManagement,
                icon: const Icon(
                  Icons.group_outlined,
                  color: Color(0xFF2C75FF),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(),
              ),
            )
          else if (error != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(error!, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => onRetry(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2C75FF),
                    side: const BorderSide(color: Color(0xFF2C75FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Actualiser'),
                ),
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CountChip(
                      label:
                          '$approvedCount membre${approvedCount > 1 ? 's' : ''}',
                    ),
                    _CountChip(
                      label:
                          '$pendingCount demande${pendingCount > 1 ? 's' : ''}',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: hasWhatsAppLink ? onOpenWhatsApp : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF1DC),
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w600),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.chat),
                  label: const Text('Ouvrir le groupe WhatsApp'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: onOpenManagement,
                  child: const Text("Gérer les membres"),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1DC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFCC8400),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MembersPlaceholderCard extends StatelessWidget {
  const _MembersPlaceholderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E3EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Membres',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 12),
          Text(
            "Publiez votre borne pour inviter des conducteurs et gérer leurs demandes depuis cette section.",
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _StationSection extends StatelessWidget {
  const _StationSection({
    required this.station,
    required this.onCreateStation,
    required this.onEditStation,
  });

  final Station? station;
  final VoidCallback onCreateStation;
  final VoidCallback onEditStation;

  @override
  Widget build(BuildContext context) {
    if (station == null) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onCreateStation,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2C75FF),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text(
            'Ajouter ma borne',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFE7ECFF),
            ),
            clipBehavior: Clip.antiAlias,
            child: station!.photoUrl != null && station!.photoUrl!.isNotEmpty
                ? Image.network(station!.photoUrl!, fit: BoxFit.cover)
                : const Icon(
                    Icons.ev_station,
                    size: 36,
                    color: Color(0xFF2C75FF),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        station!.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: onEditStation,
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Color(0xFF2C75FF),
                      ),
                    ),
                  ],
                ),
                if (station!.chargerLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    station!.chargerLabel!,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (station!.priceLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    station!.priceLabel!,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDDE6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Statut borne: disponible',
                    style: TextStyle(
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
    );
  }
}














