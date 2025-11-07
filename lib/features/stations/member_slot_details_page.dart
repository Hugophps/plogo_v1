import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_timezone.dart';
import '../profile/models/profile.dart';
import 'models/station_slot.dart';

class MemberSlotDetailsPage extends StatelessWidget {
  const MemberSlotDetailsPage({
    super.key,
    required this.slot,
    required this.profile,
  });

  final StationSlot slot;
  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final start = brusselsFromUtc(slot.startAt.toUtc());
    final end = brusselsFromUtc(slot.endAt.toUtc());

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2C75FF),
        foregroundColor: Colors.white,
        title: const Text('Cr\u00e9neau d\u2019un membre'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _MemberHeader(profile: profile),
            const SizedBox(height: 24),
            _InfoRow(
              label: 'Date',
              value: _formatDate(start),
            ),
            const SizedBox(height: 16),
            _InfoRow(
              label: 'Horaires',
              value:
                  'De ${_formatHour(start)} \u00e0 ${_formatHour(end)}',
            ),
            const SizedBox(height: 24),
            const Text(
              'Informations sur le v\u00e9hicule',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            _InfoRow(label: 'Marque', value: profile.vehicleBrand ?? 'Non renseign\u00e9'),
            const SizedBox(height: 8),
            _InfoRow(label: 'Mod\u00e8le', value: profile.vehicleModel ?? 'Non renseign\u00e9'),
            const SizedBox(height: 8),
            _InfoRow(label: 'Plaque', value: profile.vehiclePlate ?? 'Non renseign\u00e9'),
            const SizedBox(height: 8),
            _InfoRow(label: 'Type de prise', value: profile.vehiclePlugType ?? 'Non renseign\u00e9'),
            const SizedBox(height: 32),
            _WhatsappButton(phoneNumber: profile.phoneNumber),
          ],
        ),
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
      'f\u00e9vrier',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'ao\u00fbt',
      'septembre',
      'octobre',
      'novembre',
      'd\u00e9cembre',
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

class _MemberHeader extends StatelessWidget {
  const _MemberHeader({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final name = profile.fullName?.trim();
    final phone = profile.phoneNumber?.trim();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: const Color(0xFFE7ECFF),
            child: profile.avatarUrl == null
                ? const Icon(Icons.person_outline, color: Color(0xFF2C75FF))
                : ClipOval(
                    child: Image.network(
                      profile.avatarUrl!,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null || name.isEmpty ? 'Membre' : name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                if (phone != null && phone.isNotEmpty)
                  Text(
                    phone,
                    style: const TextStyle(color: Colors.black54),
                  ),
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
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
  }
}

class _WhatsappButton extends StatelessWidget {
  const _WhatsappButton({this.phoneNumber});

  final String? phoneNumber;

  @override
  Widget build(BuildContext context) {
    final canContact = phoneNumber != null && phoneNumber!.trim().isNotEmpty;
    return OutlinedButton.icon(
      onPressed: canContact ? () => _openWhatsapp(context) : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: const Color(0xFF25D366),
        side: const BorderSide(color: Color(0xFF25D366)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      ),
      icon: const Icon(Icons.chat),
      label: const Text('Contacter sur WhatsApp'),
    );
  }

  Future<void> _openWhatsapp(BuildContext context) async {
    final sanitized = phoneNumber!.replaceAll(' ', '');
    final uri = Uri.parse('https://wa.me/$sanitized');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\u2019ouvrir WhatsApp.')),
      );
    }
  }
}
