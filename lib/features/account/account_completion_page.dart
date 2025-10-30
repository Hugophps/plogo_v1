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
  final _phoneController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _streetNameController = TextEditingController();
  final _streetNumberController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _cityController = TextEditingController();
  final _countryController = TextEditingController(text: 'France');
  final _descriptionController = TextEditingController();
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehiclePlugController = TextEditingController();

  bool _saving = false;
  Uint8List? _avatarBytes;
  String? _remoteAvatarUrl;

  String get _initials {
    final name = _fullNameController.text.trim();
    if (name.isEmpty) return 'PL';
    final parts = name.split(RegExp(r'\s+'));
    final first = parts.isNotEmpty ? parts.first : '';
    final last = parts.length > 1 ? parts.last : '';
    return ((first.isNotEmpty ? first[0] : '') +
            (last.isNotEmpty ? last[0] : 'P'))
        .toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _emailController = TextEditingController(text: profile?.email ?? '');
    _fullNameController.text = profile?.fullName ?? '';
    _phoneController.text = profile?.phoneNumber ?? '';
    _descriptionController.text = profile?.description ?? '';
    _remoteAvatarUrl = profile?.avatarUrl;
    _fullNameController.addListener(() {
      if (mounted) {
        setState(() {});
      }
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

  Future<void> _pickAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Impossible de lire le fichier selectionne.');
      }

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Format d\'image non supporte.');
      }

      final resized = img.copyResize(decoded, width: 100, height: 100);
      int quality = 90;
      late List<int> encoded;
      do {
        encoded = img.encodeJpg(resized, quality: quality);
        quality -= 10;
      } while (encoded.length > 100 * 1024 && quality >= 30);

      if (encoded.length > 100 * 1024) {
        throw Exception('Impossible de compresser l\'image sous 100 Ko.');
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

  Widget _buildAvatarPicker() {
    Widget avatarContent;
    if (_avatarBytes != null) {
      avatarContent = CircleAvatar(
        radius: 36,
        backgroundImage: MemoryImage(_avatarBytes!),
      );
    } else if (_remoteAvatarUrl != null && _remoteAvatarUrl!.isNotEmpty) {
      avatarContent = CircleAvatar(
        radius: 36,
        backgroundImage: NetworkImage(_remoteAvatarUrl!),
      );
    } else {
      avatarContent = CircleAvatar(
        radius: 36,
        backgroundColor: const Color(0xFFE7ECFF),
        child: Text(
          _initials,
          style: const TextStyle(
            color: Color(0xFF2C75FF),
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
            avatarContent,
            const SizedBox(width: 16),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickAvatar,
                icon: const Icon(Icons.upload_outlined),
                label: const Text('Telecharger une photo'),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _saving = true);
    try {
      String? avatarUrl = _remoteAvatarUrl;
      if (_avatarBytes != null) {
        final user = supabase.auth.currentUser;
        if (user == null) {
          throw Exception('Utilisateur non connecte');
        }
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
                  'Creation du compte',
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
                        'Bienvenue !\nVous \u00EAtes \u00E0 quelques informations d\'avoir votre compte \u2705',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildAvatarPicker(),
                      const SizedBox(height: 24),
                      _buildSection('Informations generales', [
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
                            'Telephone',
                            required: true,
                          ),
                          validator: _validateRequired,
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildSection('A propos de vous', [
                        TextFormField(
                          controller: _fullNameController,
                          decoration: _fieldDecoration(
                            'Prenom et nom',
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
                            'Numero de rue',
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
                            'Une petite presentation de vous',
                          ).copyWith(counterText: ''),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildSection('Votre vehicule electrique principal', [
                        TextFormField(
                          controller: _vehicleBrandController,
                          decoration: _fieldDecoration('Marque'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _vehicleModelController,
                          decoration: _fieldDecoration('Modele'),
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
                        'Je declare que ces informations sont correctes. En m\'inscrivant, je valide avoir pris connaissance des CGU et de la politique de confidentialite de Plogo.',
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
                              : const Text('Valider et creer'),
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
}
