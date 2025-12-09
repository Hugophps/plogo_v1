import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/supabase_bootstrap.dart';
import '../location/google_place_models.dart';
import '../location/widgets/google_address_field.dart';
import '../profile/models/profile.dart';
import 'data/enode_link_service.dart';
import 'models/station.dart';

typedef StationSubmission =
    Future<Station> Function(Map<String, dynamic> payload, String? photoUrl);

class StationFormPage extends StatefulWidget {
  const StationFormPage({
    super.key,
    required this.profile,
    required this.onSubmit,
    required this.title,
    required this.submitLabel,
    this.initialStation,
  });

  final Profile profile;
  final Station? initialStation;
  final StationSubmission onSubmit;
  final String title;
  final String submitLabel;

  @override
  State<StationFormPage> createState() => _StationFormPageState();
}

class _StationFormPageState extends State<StationFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _whatsappController;
  late final TextEditingController _infoController;
  bool _sameAddress = true;
  bool _saving = false;
  bool _linkingEnode = false;
  bool _refreshingStation = false;
  bool _loadingChargers = false;
  Uint8List? _photoBytes;
  String? _remotePhotoUrl;
  GooglePlaceDetails? _stationAddress;
  late final GooglePlaceDetails? _profileAddress;
  Station? _currentStation;
  final EnodeLinkService _linkService = const EnodeLinkService();

  @override
  void initState() {
    super.initState();
    final station = widget.initialStation;
    _currentStation = station;
    _sameAddress = station?.useProfileAddress ?? true;

    _nameController = TextEditingController(text: station?.name ?? '');
    _priceController = TextEditingController(
      text: station?.pricePerKwh != null
          ? _formatPriceValue(station!.pricePerKwh!)
          : '',
    );
    _whatsappController = TextEditingController(
      text: station?.whatsappGroupUrl ?? '',
    );
    _infoController = TextEditingController(
      text: station?.additionalInfo ?? '',
    );
    _remotePhotoUrl = station?.photoUrl;
    _profileAddress = GooglePlaceDetails.fromStoredData(
      placeId: widget.profile.addressPlaceId,
      formattedAddress: widget.profile.addressFormatted,
      lat: widget.profile.addressLat,
      lng: widget.profile.addressLng,
      components: widget.profile.addressComponents,
    );
    _stationAddress = GooglePlaceDetails.fromStoredData(
      placeId: station?.locationPlaceId,
      formattedAddress: station?.locationFormatted,
      lat: station?.locationLat,
      lng: station?.locationLng,
      components: station?.locationComponents,
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _whatsappController.dispose();
    _infoController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null) {
        throw Exception('Impossible de lire le fichier selectionne.');
      }

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception("Format d'image non supporte.");
      }

      final resized = img.copyResize(decoded, width: 600);
      int quality = 90;
      late List<int> encoded;
      do {
        encoded = img.encodeJpg(resized, quality: quality);
        quality -= 10;
      } while (encoded.length > 350 * 1024 && quality >= 30);

      if (encoded.length > 350 * 1024) {
        throw Exception('Impossible de compresser la photo sous 350 Ko.');
      }

      setState(() {
        _photoBytes = Uint8List.fromList(encoded);
        _remotePhotoUrl = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement de la photo: $e')),
      );
    }
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

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Champ requis';
    }
    return null;
  }

  String? _validateOptionalUrl(String? value) {
    final link = value?.trim() ?? '';
    if (link.isEmpty) return null;

    final parsed = Uri.tryParse(link);
    if (parsed == null || !parsed.hasScheme || !parsed.hasAuthority) {
      return 'Lien WhatsApp invalide';
    }
    return null;
  }

  String _formatPriceValue(double value) {
    final isInt = value.truncateToDouble() == value;
    return isInt ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  String? _validatePrice(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) {
      return 'Indiquez le prix du kWh';
    }
    final parsed = double.tryParse(input.replaceAll(',', '.'));
    if (parsed == null) {
      return 'Format invalide';
    }
    if (parsed <= 0) {
      return 'Le prix doit etre positif';
    }
    return null;
  }

  Future<Station?> _persistStation({required bool exitOnSuccess}) async {
    if (!_formKey.currentState!.validate()) return null;
    FocusScope.of(context).unfocus();

    setState(() => _saving = true);
    try {
      late final GooglePlaceDetails resolvedAddress;
      if (_sameAddress) {
        final profileAddress = _profileAddress;
        if (profileAddress == null) {
          throw Exception(
            'Ajoutez une adresse Google a votre profil avant de continuer.',
          );
        }
        resolvedAddress = profileAddress;
      } else {
        final stationAddress = _stationAddress;
        if (stationAddress == null) {
          throw Exception(
            'Selectionnez une adresse pour la borne via Google Maps.',
          );
        }
        resolvedAddress = stationAddress;
      }

      final parsedAddress = GoogleAddressParser.toProfileFields(
        resolvedAddress,
      );

      final requirements = {
        'street_name': 'nom de rue',
        'street_number': 'numero',
        'postal_code': 'code postal',
        'city': 'ville',
        'country': 'pays',
      };

      final missingParts = requirements.entries
          .where((entry) => ((parsedAddress[entry.key] ?? '').trim().isEmpty))
          .map((entry) => entry.value)
          .toList();

      if (missingParts.isNotEmpty) {
        throw Exception(
          'Adresse incomplete. Selectionnez une adresse plus precise.',
        );
      }

      String? photoUrl = _remotePhotoUrl;
      if (_photoBytes != null) {
        final user = supabase.auth.currentUser;
        if (user == null) throw Exception('Utilisateur non connecte');

        final path =
            'stations/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await supabase.storage
            .from('stations')
            .uploadBinary(
              path,
              _photoBytes!,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );
        photoUrl = supabase.storage.from('stations').getPublicUrl(path);
      }

      final info = _infoController.text.trim();
      final whatsappLink = _whatsappController.text.trim();
      final priceInput = _priceController.text.trim().replaceAll(',', '.');
      final pricePerKwh = double.tryParse(priceInput);
      if (pricePerKwh == null || pricePerKwh <= 0) {
        throw Exception('Le prix du kWh est invalide.');
      }

      final payload = {
        'name': _nameController.text.trim(),
        'price_per_kwh': pricePerKwh,
        'use_profile_address': _sameAddress,
        'street_name': parsedAddress['street_name'],
        'street_number': parsedAddress['street_number'],
        'postal_code': parsedAddress['postal_code'],
        'city': parsedAddress['city'],
        'country': parsedAddress['country'],
        'additional_info': info.isEmpty ? null : info,
        'whatsapp_group_url': whatsappLink.isEmpty ? null : whatsappLink,
        'location_place_id': resolvedAddress.placeId,
        'location_lat': resolvedAddress.lat,
        'location_lng': resolvedAddress.lng,
        'location_formatted': resolvedAddress.formattedAddress,
        'location_components': resolvedAddress.components
            .map((component) => component.toJson())
            .toList(),
      };

      final station = await widget.onSubmit(payload, photoUrl);

      if (!mounted) {
        return station;
      }

      setState(() {
        _currentStation = station;
        _remotePhotoUrl = station.photoUrl ?? _remotePhotoUrl;
        _photoBytes = null;
      });

      if (exitOnSuccess) {
        Navigator.of(context).pop(station);
      }

      return station;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
      return null;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _submit() async {
    await _persistStation(exitOnSuccess: true);
  }

  Future<void> _linkEnode() async {
    if (_saving || _linkingEnode) return;
    final station = await _persistStation(exitOnSuccess: false);
    if (station == null || !mounted) return;

    setState(() => _linkingEnode = true);
    try {
      final linkUrl = await _linkService.createLinkSession(station.id);
      final uri = Uri.tryParse(linkUrl);
      if (uri == null) {
        throw Exception('Lien Enode invalide.');
      }

      bool launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (!launched) {
        launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }

      if (!launched) {
        throw Exception(
          "Ouverture du flux Enode impossible sur cet appareil.",
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Complétez la connexion Enode dans la fenêtre ouverte.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur Enode: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _linkingEnode = false);
      }
    }
  }

  Future<void> _refreshStationStatus({bool showToast = true}) async {
    final stationId = _currentStation?.id ?? widget.initialStation?.id;
    if (stationId == null || _refreshingStation) {
      if (stationId == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Créez et enregistrez la station avant de la connecter.'),
          ),
        );
      }
      return;
    }

    setState(() => _refreshingStation = true);
    try {
      final response = await supabase
          .from('stations')
          .select()
          .eq('id', stationId)
          .single();
      final updated = Station.fromMap(
        Map<String, dynamic>.from(response as Map<String, dynamic>),
      );
      if (!mounted) return;
      setState(() {
        _currentStation = updated;
        _remotePhotoUrl = updated.photoUrl ?? _remotePhotoUrl;
      });
      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Station mise à jour.'),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Actualisation impossible: $e')),
      );
    } finally {
      if (mounted) setState(() => _refreshingStation = false);
    }
  }

  Future<void> _openChargerSelection() async {
    final stationId = _currentStation?.id ?? widget.initialStation?.id;
    if (stationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Créez d’abord la station avant de sélectionner une borne Enode.',
          ),
        ),
      );
      return;
    }

    setState(() => _loadingChargers = true);
    try {
      final chargers = await _linkService.fetchLinkedChargers();
      if (!mounted) return;
      if (chargers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucune borne Enode détectée. Terminez la connexion puis réessayez.',
            ),
          ),
        );
        return;
      }

      final selected = await showModalBottomSheet<LinkedEnodeCharger>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return _EnodeChargerPicker(
            chargers: chargers,
          );
        },
      );
      if (selected == null) return;

      await _linkService.attachCharger(
        stationId: stationId,
        chargerId: selected.id,
      );
      await _refreshStationStatus(showToast: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Borne sélectionnée : ${selected.label}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sélection impossible: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingChargers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAddress = _profileAddress;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFB347),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.title),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Informations de la borne',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: _fieldDecoration(
                  'Donnez un nom Ã  votre borne',
                  required: true,
                ),
                validator: _validateRequired,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _fieldDecoration(
                  'Prix du kWh',
                  required: true,
                ).copyWith(suffixText: '€/kWh'),
                validator: _validatePrice,
              ),
              const SizedBox(height: 16),
              const Text(
                'Connexion Enode',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _buildEnodeCard(),
              const SizedBox(height: 24),
              const Text(
                'Informations de la borne',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                activeTrackColor: const Color(0xFF2C75FF),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.black12,
                title: const Text(
                  "L'adresse de la borne est la meme que la mienne",
                ),
                value: _sameAddress,
                onChanged: (value) {
                  setState(() {
                    _sameAddress = value;
                    if (value) {
                      _stationAddress = null;
                    }
                  });
                },
              ),
              if (_sameAddress)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: profileAddress != null
                      ? Container(
                          width: double.infinity,
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
                                'Adresse utilisee',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C75FF),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(profileAddress.formattedAddress),
                            ],
                          ),
                        )
                      : Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE2E2),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFFFB3B3)),
                          ),
                          child: const Text(
                            'Ajoutez une adresse Google a votre profil pour utiliser cette option.',
                            style: TextStyle(
                              color: Color(0xFFB42321),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                )
              else ...[
                const SizedBox(height: 8),
                GoogleAddressField(
                  label: 'Adresse de la borne *',
                  helperText:
                      "Selectionnez l'adresse precise de votre borne via Google Maps.",
                  initialValue: _stationAddress,
                  onChanged: (value) {
                    setState(() {
                      _stationAddress = value;
                    });
                  },
                ),
              ],
              const SizedBox(height: 24),
              const Text(
                'Photographie de la borne',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickPhoto,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE0E3EB)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE7ECFF),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _buildPhotoPreview(),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Ajouter une photo de la borne',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(
                        Icons.add_a_photo_outlined,
                        color: Color(0xFF2C75FF),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Coordination via WhatsApp',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _whatsappController,
                decoration: _fieldDecoration('Lien du groupe WhatsApp'),
                validator: _validateOptionalUrl,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 24),
              const Text(
                'Information / instructions complÃ©mentaires',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _infoController,
                decoration: _fieldDecoration(
                  'Une petite description de la borne',
                ),
                maxLines: 4,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFB347),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.submitLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPreview() {
    if (_photoBytes != null) {
      return Image.memory(_photoBytes!, fit: BoxFit.cover);
    }
    if (_remotePhotoUrl != null && _remotePhotoUrl!.isNotEmpty) {
      return Image.network(_remotePhotoUrl!, fit: BoxFit.cover);
    }
    return const Icon(
      Icons.person_add_alt_1,
      color: Color(0xFF2C75FF),
      size: 32,
    );
  }

  Widget _buildEnodeCard() {
    final station = _currentStation;
    final brand = (station?.chargerBrand ?? '').trim();
    final model = (station?.chargerModel ?? '').trim();
    final hasCharger = brand.isNotEmpty || model.isNotEmpty;
    final subtitle = hasCharger
        ? '${brand.isNotEmpty ? brand : 'Borne'} · ${model.isNotEmpty ? model : 'Modèle'}'
        : "Une fois la connexion établie, sélectionnez la borne à associer à votre station.";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E3EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasCharger ? Icons.ev_station : Icons.link,
                color: hasCharger ? const Color(0xFF2C75FF) : Colors.black54,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasCharger
                          ? 'Borne connectée via Enode'
                          : 'Aucune borne connectée',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Nous sauvegarderons automatiquement vos informations avant d'ouvrir la fenêtre Enode.",
            style: const TextStyle(color: Colors.black87, fontSize: 13),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_saving || _linkingEnode) ? null : _linkEnode,
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2C75FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _linkingEnode
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Connecter ma borne via Enode'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: (_currentStation == null ||
                          _loadingChargers ||
                          _linkingEnode)
                      ? null
                      : _openChargerSelection,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2C75FF),
                    side: const BorderSide(color: Color(0xFF2C75FF)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _loadingChargers
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sélectionner la borne Enode'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: (_currentStation == null || _refreshingStation)
                    ? null
                    : _refreshStationStatus,
                icon: _refreshingStation
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: 'Actualiser la station',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EnodeChargerPicker extends StatelessWidget {
  const _EnodeChargerPicker({required this.chargers});

  final List<LinkedEnodeCharger> chargers;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E3EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Sélectionnez la borne détectée',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final charger = chargers[index];
                  return ListTile(
                    leading: const Icon(
                      Icons.ev_station,
                      color: Color(0xFF2C75FF),
                    ),
                    title: Text(
                      charger.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(charger.description),
                    onTap: () => Navigator.of(context).pop(charger),
                  );
                },
                separatorBuilder: (_, __) => const Divider(),
                itemCount: chargers.length,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
