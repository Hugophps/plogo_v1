import 'package:flutter/material.dart';

import '../../core/app_metadata.dart';
import '../profile/models/profile.dart';
import 'profile_data_page.dart';
import 'profile_edit_page.dart';
import 'profile_legal_page.dart';
import 'profile_settings_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
    required this.onSignOut,
    required this.onAccountDeleted,
    required this.refreshProfile,
  });

  final Profile profile;
  final ValueChanged<Profile> onProfileUpdated;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onAccountDeleted;
  final Future<Profile?> Function() refreshProfile;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Profile _profile;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
  }

  Future<void> _refreshProfile() async {
    final refreshed = await widget.refreshProfile();
    if (refreshed != null) {
      setState(() => _profile = refreshed);
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<Profile?>(
      MaterialPageRoute(builder: (_) => ProfileEditPage(profile: _profile)),
    );
    if (updated != null) {
      setState(() => _profile = updated);
      widget.onProfileUpdated(updated);
    }
  }

  Future<void> _openData() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ProfileDataPage()));
  }

  Future<void> _openSettings() async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProfileSettingsPage(
          appVersion: AppMetadata.version,
          onDeleteAccount: () async {
            await widget.onAccountDeleted();
          },
        ),
      ),
    );

    if (deleted == true && mounted) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _openLegal({required bool isPrivacy}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfileLegalPage(
          title: isPrivacy ? 'Confidentialités' : 'CGU',
          heading: isPrivacy
              ? "Politique de confidentialités"
              : "Conditions Générales d'Utilisation",
          body: _legalPlaceholder,
        ),
      ),
    );
  }

  static const _legalPlaceholder =
      'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.';

  @override
  Widget build(BuildContext context) {
    final initials = _initialsFromName(_profile.fullName);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Retour',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Mon profil'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: _refreshProfile,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF2C75FF),
                      width: 3,
                    ),
                  ),
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: const Color(0xFFE7ECFF),
                    backgroundImage: _profile.avatarUrl != null
                        ? NetworkImage(_profile.avatarUrl!)
                        : null,
                    child: _profile.avatarUrl == null
                        ? Text(
                            initials,
                            style: const TextStyle(
                              color: Color(0xFF2C75FF),
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Text(
                      _profile.fullName ?? 'Nom utilisateur',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _profile.roleLabel,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _ProfileMenuButton(
                label: 'Modifier mon profil',
                onTap: _openEdit,
              ),
              _ProfileMenuButton(label: 'Données', onTap: _openData),
              _ProfileMenuButton(label: 'Paramètres', onTap: _openSettings),
              _ProfileMenuButton(
                label: 'CGU',
                onTap: () => _openLegal(isPrivacy: false),
              ),
              _ProfileMenuButton(
                label: 'Politique de confidentialités',
                onTap: () => _openLegal(isPrivacy: true),
              ),
              const SizedBox(height: 32),
              TextButton.icon(
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  await widget.onSignOut();
                  if (!mounted) return;
                  navigator.pop();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2C75FF),
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

class _ProfileMenuButton extends StatelessWidget {
  const _ProfileMenuButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        height: 52,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.black87,
            side: const BorderSide(color: Color(0xFF2C75FF), width: 1.4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
