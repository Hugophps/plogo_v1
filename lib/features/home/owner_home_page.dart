import 'package:flutter/material.dart';

import '../profile/models/profile.dart';
import '../stations/models/station.dart';

class OwnerHomePage extends StatelessWidget {
  const OwnerHomePage({
    super.key,
    required this.profile,
    required this.onOpenProfile,
    required this.onCreateStation,
    required this.onEditStation,
    this.station,
  });

  final Profile profile;
  final VoidCallback onOpenProfile;
  final VoidCallback onCreateStation;
  final VoidCallback onEditStation;
  final Station? station;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    onTap: onOpenProfile,
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
                station: station,
                onCreateStation: onCreateStation,
                onEditStation: onEditStation,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  children: const [
                    _HomeSectionCard(
                      title: 'Calendrier',
                      description:
                          'Consultez et gérez les créneaux réservés ou disponibles.',
                      icon: Icons.calendar_today,
                    ),
                    SizedBox(height: 16),
                    _HomeSectionCard(
                      title: 'Membres',
                      description:
                          'Retrouvez l’historique des conducteurs et leurs évaluations.',
                      icon: Icons.people_outline,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

class _HomeSectionCard extends StatelessWidget {
  const _HomeSectionCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                ? Image.network(
                    station!.photoUrl!,
                    fit: BoxFit.cover,
                  )
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
                const SizedBox(height: 4),
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
