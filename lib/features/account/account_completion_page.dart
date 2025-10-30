import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_bootstrap.dart';
import '../profile/models/profile.dart';
import '../profile/profile_repository.dart';

class AccountCompletionPage extends StatefulWidget {
  const AccountCompletionPage({
    super.key,
    required this.onCompleted,
    this.profile,
  });

  final VoidCallback onCompleted;
  final Profile? profile;

  @override
  State<AccountCompletionPage> createState() => _AccountCompletionPageState();
}

class _AccountCompletionPageState extends State<AccountCompletionPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = const ProfileRepository();

  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _fullNameController;
  late final TextEditingController _streetNameController;
  late final TextEditingController _streetNumberController;
  late final TextEditingController _postalCodeController;
  late final TextEditingController _cityController;
  late final TextEditingController _countryController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _vehicleBrandController;
  late final TextEditingController _vehicleModelController;
  late final TextEditingController _vehiclePlateController;
  late final TextEditingController _vehiclePlugController;

  Uint8List? _avatarBytes;
  String? _remoteAvatarUrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _emailController = TextEditingController(text: profile?.email ?? '');
    _phoneController = TextEditingController(text: profile?.phoneNumber ?? '');
    _fullNameController = TextEditingController(text: profile?.fullName ?? '');
    _streetNameController = TextEditingController(
      text: profile?.streetName ?? '',
    );
    _streetNumberController = TextEditingController(
      text: profile?.streetNumber ?? '',
    );
    _postalCodeController = TextEditingController(
      text: profile?.postalCode ?? '',
    );
    _cityController = TextEditingController(text: profile?.city ?? '');
    _countryController = TextEditingController(
      text: profile?.country ?? 'France',
    );
    _descriptionController = TextEditingController(
      text: profile?.description ?? '',
    );
    _vehicleBrandController = TextEditingController(
      text: profile?.vehicleBrand ?? '',
    );
    _vehicleModelController = TextEditingController(
      text: profile?.vehicleModel ?? '',
    );
    _vehiclePlateController = TextEditingController(
      text: profile?.vehiclePlate ?? '',
    );
    _vehiclePlugController = TextEditingController(
      text: profile?.vehiclePlugType ?? '',
    );
    _remoteAvatarUrl = profile?.avatarUrl;
    _fullNameController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _fullNameController.dispose();
    _streetNameController.dispose();
    _streetNumberController.dispose();
    _postalCodeController.dispose();
    _cityController.dispose();
    _countryController.dispose();
    _descriptionController.dispose();
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _vehiclePlugController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Champ requis';
    }
    return null;
  }

  InputDecoration _fieldDecoration(String label, {bool required = false}) {
    final labelText = required ? '$label *' : label;
    return InputDecoration(
      labelText: labelText,
      hintText: label,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE0E3EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE0E3EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2C75FF), width: 1.5),
      ),
    );
  }

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Impossible de lire le fichier sÃ©lectionnÃ©.');
      }

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Format dâ€™image non supportÃ©.');
      }

      final resized = img.copyResize(decoded, width: 100, height: 100);
      int quality = 90;
      late List<int> encoded;
      do {
        encoded = img.encodeJpg(resized, quality: quality);
        quality -= 10;
      } while (encoded.length > 100 * 1024 && quality >= 30);

      if (encoded.length > 100 * 1024) {
        throw Exception('Impossible de compresser la photo sous 100 Ko.');
      }

      setState(() {
        _avatarBytes = Uint8List.fromList(encoded);
        _remoteAvatarUrl = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement de la photo: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      String? avatarUrl = _remoteAvatarUrl;
      if (_avatarBytes != null) {
        final user = supabase.auth.currentUser;
        if (user == null) throw Exception('Utilisateur non connectÃ©');
        final path = 'avatars/${user.id}.jpg';
        await supabase.storage
            .from('avatars')
            .uploadBinary(
              path,
              _avatarBytes!,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );
        avatarUrl = supabase.storage.from('avatars').getPublicUrl(path);
      }

      final description = _descriptionController.text.trim();

      await _repo.upsertProfile({
        'full_name': _fullNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'street_name': _streetNameController.text.trim(),
        'street_number': _streetNumberController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'city': _cityController.text.trim(),
        'country': _countryController.text.trim(),
        'description': description.isEmpty ? null : description,
        'vehicle_brand': _vehicleBrandController.text.trim(),
        'vehicle_model': _vehicleModelController.text.trim(),
        'vehicle_plate': _vehiclePlateController.text.trim(),
        'vehicle_plug_type': _vehiclePlugController.text.trim(),
        'avatar_url': avatarUrl,
        'profile_completed': true,
      });

      if (!mounted) return;
      widget.onCompleted();
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
    final initials = _initialsFromName(_fullNameController.text);
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
                  'CrÃ©ation du compte',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        "Bienvenue !\nVous Ãªtes Ã  quelques informations d'avoir votre compte âœ…",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildAvatarPicker(initials),
                      const SizedBox(height: 24),
                      _buildSection('Informations gÃ©nÃ©rales', [
                        TextFormField(
                          controller: _emailController,
                          readOnly: true,
                          decoration: _fieldDecoration('Email'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _fieldDecoration(
                            'TÃ©lÃ©phone',
                            required: true,
                          ),
                          validator: _validateRequired,
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildSection('Ã€ propos de vous', [
                        TextFormField(
                          controller: _fullNameController,
                          decoration: _fieldDecoration(
                            'PrÃ©nom et nom',
                            required: true,
                          ),
                          validator: _validateRequired,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _streetNameController,
                          decoration: _fieldDecoration(
                            'Nom de rue',
                            required: true,
                          ),
                          validator: _validateRequired,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _streetNumberController,
                          decoration: _fieldDecoration(
                            'NÂ° de rue',
                            required: true,
                          ),
                          validator: _validateRequired,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _postalCodeController,
                          decoration: _fieldDecoration(
                            'Code postal',
                            required: true,
                          ),
                          validator: _validateRequired,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _cityController,
                          decoration: _fieldDecoration('Ville', required: true),
                          validator: _validateRequired,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _countryController,
                          decoration: _fieldDecoration('Pays', required: true),
                          validator: _validateRequired,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _descriptionController,
                          minLines: 3,
                          maxLines: null,
                          maxLength: 150,
                          decoration: _fieldDecoration(
                            'Une petite prÃ©sentation de vous',
                          ).copyWith(counterText: ''),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildSection('Votre vÃ©hicule Ã©lectrique principal', [
                        TextFormField(
                          controller: _vehicleBrandController,
                          decoration: _fieldDecoration('Marque'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _vehicleModelController,
                          decoration: _fieldDecoration('ModÃ¨le'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _vehiclePlateController,
                          decoration: _fieldDecoration(
                            "Plaque d'immatriculation",
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _vehiclePlugController,
                          decoration: _fieldDecoration(
                            'Type de prise de charge',
                          ),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      const Text(
                        'Je dÃ©clare que ces informations sont correctes. En mâ€™inscrivant, je confirme avoir pris connaissance des CGU et de la politique de confidentialitÃ© de Plogo.',
                        style: TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _saving ? null : _submit,
                          child: _saving
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Valider et crÃ©er'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPicker(String initials) {
    Widget avatar;
    if (_avatarBytes != null) {
      avatar = CircleAvatar(
        radius: 40,
        backgroundImage: MemoryImage(_avatarBytes!),
      );
    } else if (_remoteAvatarUrl != null && _remoteAvatarUrl!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(_remoteAvatarUrl!),
      );
    } else {
      avatar = CircleAvatar(
        radius: 40,
        backgroundColor: const Color(0xFFE7ECFF),
        child: Text(
          initials,
          style: const TextStyle(
            color: Color(0xFF2C75FF),
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photo de profil (optionnel)',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C75FF),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2C75FF), width: 2),
              ),
              child: avatar,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickAvatar,
                icon: const Icon(Icons.upload_outlined),
                label: const Text('TÃ©lÃ©charger une photo'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2C75FF),
                  side: const BorderSide(color: Color(0xFF2C75FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C75FF),
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  String _initialsFromName(String? name) {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) return 'P';
    final parts = trimmed.split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.last : '';
    final buffer = StringBuffer();
    if (first.isNotEmpty) buffer.write(first[0]);
    if (last.isNotEmpty) buffer.write(last[0]);
    return buffer.isEmpty ? 'P' : buffer.toString().toUpperCase();
  }
}
