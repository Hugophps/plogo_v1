import 'package:flutter/material.dart';

import '../profile/models/profile.dart';
import '../profile/profile_repository.dart';

class RoleSelectionPage extends StatefulWidget {
  const RoleSelectionPage({
    super.key,
    required this.profile,
    required this.onRoleSelected,
  });

  final Profile profile;
  final void Function(Profile updated) onRoleSelected;

  @override
  State<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends State<RoleSelectionPage> {
  final _repo = const ProfileRepository();
  bool _saving = false;

  Future<void> _chooseRole(String role) async {
    setState(() => _saving = true);
    try {
      final updated = await _repo.updateRole(role);
      if (!mounted) return;
      widget.onRoleSelected(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sauvegarde: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF2C75FF),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: const Center(
                child: Text(
                  'Type d’utilisateur',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'L’app Plogo vous permet d’être soit un conducteur cherchant à louer la borne de recharge d’autres utilisateurs, soit d’être un propriétaire souhaitant louer sa borne. Choisissez le rôle lié à ce compte (un seul rôle par compte dans cette version).',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 32),
                    _RoleButton(
                      label: 'Je veux partager ma borne',
                      isPrimary: true,
                      onTap: _saving ? null : () => _chooseRole('owner'),
                    ),
                    const SizedBox(height: 16),
                    _RoleButton(
                      label: 'Je cherche une borne',
                      isPrimary: false,
                      onTap: _saving ? null : () => _chooseRole('driver'),
                    ),
                    if (_saving) ...[
                      const SizedBox(height: 24),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleButton extends StatelessWidget {
  const _RoleButton({
    required this.label,
    required this.isPrimary,
    required this.onTap,
  });

  final String label;
  final bool isPrimary;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final background = isPrimary ? const Color(0xFF2C75FF) : Colors.white;
    final borderColor = isPrimary
        ? Colors.transparent
        : const Color(0xFF2C75FF);
    final textColor = isPrimary ? Colors.white : const Color(0xFF2C75FF);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: textColor,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: borderColor, width: 1.4),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
    );
  }
}
