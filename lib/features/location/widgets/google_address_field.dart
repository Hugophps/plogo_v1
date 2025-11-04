import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';

import '../google_place_models.dart';
import '../google_place_service.dart';

class GoogleAddressField extends StatefulWidget {
  const GoogleAddressField({
    super.key,
    required this.label,
    required this.onChanged,
    this.initialValue,
    this.helperText,
  });

  final String label;
  final String? helperText;
  final GooglePlaceDetails? initialValue;
  final ValueChanged<GooglePlaceDetails?> onChanged;

  @override
  State<GoogleAddressField> createState() => _GoogleAddressFieldState();
}

class _GoogleAddressFieldState extends State<GoogleAddressField> {
  final _service = const GooglePlaceService();
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  GooglePlaceDetails? _selected;
  bool _loadingDetails = false;
  bool _serviceUnavailable = false;
  late String _sessionToken;

  @override
  void initState() {
    super.initState();
    _sessionToken = generateSessionToken();
    if (widget.initialValue != null) {
      _selected = widget.initialValue;
      _searchController.text = widget.initialValue!.formattedAddress;
    }
  }

  @override
  void didUpdateWidget(covariant GoogleAddressField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue?.placeId != widget.initialValue?.placeId) {
      _selected = widget.initialValue;
      if (_selected != null) {
        _searchController.text = _selected!.formattedAddress;
      } else {
        _searchController.clear();
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<List<GooglePlacePrediction>> _fetchSuggestions(String pattern) async {
    if (pattern.trim().length < 3) {
      return const [];
    }
    try {
      final results = await _service.searchAddresses(
        pattern,
        sessionToken: _sessionToken,
      );
      if (_serviceUnavailable) {
        setState(() => _serviceUnavailable = false);
      }
      return results;
    } catch (_) {
      if (mounted) {
        setState(() => _serviceUnavailable = true);
      }
      return const [];
    }
  }

  Future<void> _selectPrediction(GooglePlacePrediction prediction) async {
    setState(() {
      _loadingDetails = true;
      _serviceUnavailable = false;
    });
    try {
      final details = await _service.fetchDetails(
        prediction.placeId,
        sessionToken: _sessionToken,
      );
      if (!mounted) return;
      setState(() {
        _selected = details;
        _loadingDetails = false;
        _sessionToken = generateSessionToken();
        _searchController.text = details.formattedAddress;
      });
      widget.onChanged(details);
      _focusNode.unfocus();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingDetails = false;
        _serviceUnavailable = true;
      });
      widget.onChanged(null);
    }
  }

  void _resetSelection() {
    setState(() {
      _selected = null;
      _searchController.clear();
      _sessionToken = generateSessionToken();
    });
    widget.onChanged(null);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2C75FF),
          ),
        ),
        const SizedBox(height: 8),
        if (widget.helperText != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              widget.helperText!,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
          ),
        if (_serviceUnavailable)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE2E2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFB3B3)),
            ),
            child: const Text(
              'Service d’adresses indisponible pour le moment. Réessayez plus tard.',
              style: TextStyle(
                color: Color(0xFFB42321),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (_selected != null)
          _SelectedAddressSummary(
            details: _selected!,
            onChange: _serviceUnavailable ? null : _resetSelection,
            loading: _loadingDetails,
          )
        else
          TypeAheadField<GooglePlacePrediction>(
            controller: _searchController,
            focusNode: _focusNode,
            hideOnEmpty: true,
            debounceDuration: const Duration(milliseconds: 250),
            suggestionsCallback: _fetchSuggestions,
            loadingBuilder: (context) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            ),
            builder: (context, controller, focusNode) => TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: !_serviceUnavailable && !_loadingDetails,
              decoration: InputDecoration(
                hintText: 'Rechercher une adresse',
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
                  borderSide: const BorderSide(
                    color: Color(0xFF2C75FF),
                    width: 1.5,
                  ),
                ),
                prefixIcon: const Icon(Icons.location_on_outlined),
              ),
            ),
            itemBuilder: (context, suggestion) => ListTile(
              title: Text(
                suggestion.description,
                style: const TextStyle(fontSize: 14),
              ),
            ),
            onSelected: _selectPrediction,
            errorBuilder: (context, error) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aucune adresse trouvée.',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
            emptyBuilder: (context) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Aucune suggestion. Ajoutez plus de détails.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectedAddressSummary extends StatelessWidget {
  const _SelectedAddressSummary({
    required this.details,
    required this.onChange,
    required this.loading,
  });

  final GooglePlaceDetails details;
  final VoidCallback? onChange;
  final bool loading;

  @override
  Widget build(BuildContext context) {
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
              const Icon(Icons.check_circle, color: Color(0xFF2C75FF)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  details.formattedAddress,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (onChange != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: loading ? null : onChange,
                child: const Text('Changer d’adresse'),
              ),
            ),
        ],
      ),
    );
  }
}
