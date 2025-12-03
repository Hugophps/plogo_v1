import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../stations/models/station.dart';
import 'member_detail_page.dart';
import 'models/station_member.dart';
import 'station_members_repository.dart';

class MembersManagementPage extends StatefulWidget {
  const MembersManagementPage({
    super.key,
    required this.station,
    required this.repository,
  });

  final Station station;
  final StationMembersRepository repository;

  @override
  State<MembersManagementPage> createState() => _MembersManagementPageState();
}

class _MembersManagementPageState extends State<MembersManagementPage> {
  late Future<List<StationMember>> _membersFuture;
  bool _hasUpdated = false;

  @override
  void initState() {
    super.initState();
    _membersFuture = _loadMembers();
  }

  Future<List<StationMember>> _loadMembers() {
    return widget.repository.fetchMembers(widget.station.id);
  }

  Future<void> _refresh() async {
    final future = _loadMembers();
    setState(() {
      _membersFuture = future;
    });
    await future;
  }

  Future<void> _openMemberDetail(StationMember member) async {
    final refreshed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MemberDetailPage(
          membershipId: member.id,
          repository: widget.repository,
          initialMember: member,
        ),
      ),
    );
    if (refreshed == true) {
      _hasUpdated = true;
      await _refresh();
    }
  }

  Future<void> _copyLinkToClipboard() async {
    final link = widget.station.whatsappGroupUrl;
    if (link == null || link.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Lien copié'),
        content: const Text(
          'Le lien du groupe WhatsApp a bien été copié. Partagez-le aux conducteurs pour qu’ils rejoignent le groupe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _openWhatsAppLink() async {
    final link = widget.station.whatsappGroupUrl;
    if (link == null || link.isEmpty) return;

    final uri = Uri.tryParse(link);
    if (uri == null) {
      _showSnackBar('Lien WhatsApp invalide.');
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      _showSnackBar('Impossible d’ouvrir le lien WhatsApp.');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkAvailable =
        widget.station.whatsappGroupUrl != null &&
        widget.station.whatsappGroupUrl!.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.of(context).pop(_hasUpdated);
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFFFFB347),
          elevation: 0,
          title: const Text('Membres de la borne'),
          centerTitle: true,
          foregroundColor: Colors.black,
        ),
        body: FutureBuilder<List<StationMember>>(
          future: _membersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Impossible de charger les membres.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _refresh,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final members = snapshot.data ?? [];
            final approved = members
                .where(
                  (member) => member.status == StationMemberStatus.approved,
                )
                .toList();
            final pending = members
                .where((member) => member.status == StationMemberStatus.pending)
                .toList();

            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
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
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE7ECFF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.group,
                                color: Color(0xFF2C75FF),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${approved.length} membre${approved.length > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${pending.length} demande${pending.length > 1 ? 's' : ''} en attente',
                                    style: const TextStyle(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: linkAvailable ? _openWhatsAppLink : null,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              side: const BorderSide(color: Color(0xFFE0E3EB)),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.chat),
                            label: const Text('Ouvrir le groupe WhatsApp'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: linkAvailable
                                ? _copyLinkToClipboard
                                : null,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: linkAvailable
                                  ? const Color(0xFF2C75FF)
                                  : Colors.black38,
                              side: BorderSide(
                                color: linkAvailable
                                    ? const Color(0xFF2C75FF)
                                    : Colors.black26,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            icon: const Icon(Icons.share),
                            label: const Text('Partager le lien de la borne'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (approved.isNotEmpty) ...[
                    Text(
                      'Membres',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...approved.map(
                      (member) => _MemberListTile(
                        member: member,
                        onTap: () => _openMemberDetail(member),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                  Text(
                    'Demandes d’accès',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (pending.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE0E3EB)),
                      ),
                      child: const Text(
                        'Aucune demande en cours.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  else
                    ...pending.map(
                      (member) => _MemberListTile(
                        member: member,
                        onTap: () => _openMemberDetail(member),
                        showStatus: true,
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MemberListTile extends StatelessWidget {
  const _MemberListTile({
    required this.member,
    required this.onTap,
    this.showStatus = false,
  });

  final StationMember member;
  final VoidCallback onTap;
  final bool showStatus;

  @override
  Widget build(BuildContext context) {
    final profile = member.profile;
    final vehicleInfo = _vehicleSummary();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: CircleAvatar(
          radius: 26,
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
                  ),
                )
              : null,
        ),
        title: Text(
          profile.fullName ?? 'Membre sans nom',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((profile.city ?? '').isNotEmpty ||
                (profile.country ?? '').isNotEmpty)
              Text(
                [
                  if ((profile.city ?? '').isNotEmpty) profile.city,
                  if ((profile.country ?? '').isNotEmpty) profile.country,
                ].whereType<String>().join(', '),
              ),
            if (vehicleInfo != null)
              Text(
                vehicleInfo,
                style: const TextStyle(color: Colors.black87),
              ),
            if (showStatus)
              Container(
                margin: const EdgeInsets.only(top: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1DC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Demande en attente',
                  style: TextStyle(
                    color: Color(0xFFCC8400),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.black38),
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

  String? _vehicleSummary() {
    final profile = member.profile;
    final brand = profile.vehicleBrand?.trim() ?? '';
    final model = profile.vehicleModel?.trim() ?? '';
    final plate = profile.vehiclePlate?.trim() ?? '';
    final parts = <String>[];
    final car = [brand, model].where((v) => v.isNotEmpty).join(' ');
    if (car.isNotEmpty) parts.add(car);
    if (plate.isNotEmpty) parts.add(plate);
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }
}
