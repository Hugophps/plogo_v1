import 'package:flutter/material.dart';

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
  final _vehicleBrandController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  final _vehiclePlateController = TextEditingController();
  final _vehiclePlugController = TextEditingController();

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final profile = widget.profile;
    _emailController = TextEditingController(text: profile?.email ?? '');
    _fullNameController.text = profile?.fullName ?? '';
    _phoneController.text = profile?.phoneNumber ?? '';
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
    _vehicleBrandController.dispose();
    _vehicleModelController.dispose();
    _vehiclePlateController.dispose();
    _vehiclePlugController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await _repo.upsertProfile({
        'full_name': _fullNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'street_name': _streetNameController.text.trim(),
        'street_number': _streetNumberController.text.trim(),
        'postal_code': _postalCodeController.text.trim(),
        'city': _cityController.text.trim(),
        'country': _countryController.text.trim(),
        'vehicle_brand': _vehicleBrandController.text.trim(),
        'vehicle_model': _vehicleModelController.text.trim(),
        'vehicle_plate': _vehiclePlateController.text.trim(),
        'vehicle_plug_type': _vehiclePlugController.text.trim(),
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

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
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
                  'Création du compte',
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
                      _buildSection('Informations générales', [
                        TextFormField(
                          controller: _emailController,
                          readOnly: true,
                          decoration: _fieldDecoration('Email'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: _fieldDecoration('Téléphone'),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Champ requis'
                              : null,
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildSection('À propos de vous', [
                        TextFormField(
                          controller: _fullNameController,
                          decoration: _fieldDecoration('Prénom et nom'),
                          validator: (value) =>
                              (value == null || value.trim().isEmpty)
                              ? 'Champ requis'
                              : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _streetNameController,
                          decoration: _fieldDecoration('Nom de rue'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _streetNumberController,
                          decoration: _fieldDecoration('N° de rue'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _postalCodeController,
                          decoration: _fieldDecoration('Code postal'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _cityController,
                          decoration: _fieldDecoration('Ville'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _countryController,
                          decoration: _fieldDecoration('Pays'),
                        ),
                      ]),
                      const SizedBox(height: 24),
                      _buildSection('Votre véhicule électrique principal', [
                        TextFormField(
                          controller: _vehicleBrandController,
                          decoration: _fieldDecoration('Marque'),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _vehicleModelController,
                          decoration: _fieldDecoration('Modèle'),
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
                        'Je déclare que ces informations sont correctes. En m’inscrivant, je valide avoir pris connaissance des CGU et de la politique de confidentialité de Plogo.',
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
                              : const Text('Valider et créer'),
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
