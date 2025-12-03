import 'package:flutter/material.dart';

class EnodeChargerModel {
  const EnodeChargerModel({
    required this.vendor,
    required this.brandLabel,
    required this.model,
    required this.brandColor,
  });

  final String vendor;
  final String brandLabel;
  final String model;
  final Color brandColor;

  String get optionId => '$vendor::$model';

  factory EnodeChargerModel.fromEnodePayload(Map<String, dynamic> json) {
    final vendorValue = _extractVendor(json);
    final vendor = vendorValue.isEmpty ? 'INCONNU' : vendorValue;
    final brandValue = (json['brand'] ??
            json['manufacturer'] ??
            (json['vendor'] is String ? json['vendor'] : null))
        ?.toString()
        .trim();
    final modelValue =
        (json['model'] ?? json['name'] ?? json['product_name'] ?? json['id'])
            ?.toString()
            .trim();
    final label = (brandValue?.isNotEmpty == true)
        ? brandValue!
        : _formatVendorLabel(vendor);
    final model =
        (modelValue?.isNotEmpty == true) ? modelValue! : 'Modele Enode';

    return EnodeChargerModel(
      vendor: vendor,
      brandLabel: label,
      model: model,
      brandColor: _brandColorForVendor(vendor),
    );
  }

  static String _extractVendor(Map<String, dynamic> json) {
    final vendorField = json['vendor'];
    if (vendorField is String && vendorField.trim().isNotEmpty) {
      return vendorField.trim().toUpperCase();
    }
    if (vendorField is Map<String, dynamic>) {
      final name = vendorField['name'] ?? vendorField['label'];
      if (name is String && name.trim().isNotEmpty) {
        return name.trim().toUpperCase();
      }
      final slug = vendorField['slug'];
      if (slug is String && slug.trim().isNotEmpty) {
        return slug.trim().toUpperCase();
      }
    }
    final manufacturer = json['manufacturer'];
    if (manufacturer is String && manufacturer.trim().isNotEmpty) {
      return manufacturer.trim().toUpperCase();
    }
    return '';
  }
}

const _brandColors = <String, Color>{
  'CHARGE AMPS': Color(0xFFEAF2FF),
  'CHARGEPOINT': Color(0xFFFFF2E5),
  'CTEK': Color(0xFFEFF5F2),
  'DEFA': Color(0xFFFFE9EC),
  'EASEE': Color(0xFFE7FFF8),
  'GARO': Color(0xFFF4F0FF),
  'INDRA': Color(0xFFEFF6FF),
  'KEBA': Color(0xFFE9F7EA),
  'KEMPOWER': Color(0xFFFBEFFF),
  'MONTA': Color(0xFFEFF9FF),
  'POD POINT': Color(0xFFEFF5FF),
  'SCHNEIDER ELECTRIC': Color(0xFFEFF8FF),
  'SMAPPEE': Color(0xFFE6FBF5),
  'TIBBER': Color(0xFFE8F4FF),
  'WALLBOX': Color(0xFFF3F4FF),
  'ZAPTEC': Color(0xFFE8FFF2),
};

Color _brandColorForVendor(String vendor) {
  return _brandColors[vendor.toUpperCase()] ?? const Color(0xFFE6E9F5);
}

String _formatVendorLabel(String vendor) {
  return vendor
      .split(RegExp(r'[_\s]+'))
      .where((part) => part.trim().isNotEmpty)
      .map(
        (part) =>
            part[0].toUpperCase() + part.substring(1).toLowerCase(),
      )
      .join(' ');
}

EnodeChargerModel _entry(String brand, String model) {
  return EnodeChargerModel(
    vendor: brand.toUpperCase(),
    brandLabel: brand,
    model: model,
    brandColor: _brandColorForVendor(brand),
  );
}

final List<EnodeChargerModel> enodeChargerCatalog = List.unmodifiable([
  _entry('Charge Amps', 'AURA'),
  _entry('Charge Amps', 'DAWN'),
  _entry('Charge Amps', 'HALO'),
  _entry('Charge Amps', 'LUNA'),
  _entry('ChargePoint', 'Home Flex Hardwire'),
  _entry('ChargePoint', 'Home Flex Plug'),
  _entry('ChargePoint', 'Home Pro'),
  _entry('CTEK', 'Chargestorm Connected 2'),
  _entry('DEFA', 'Home Charger'),
  _entry('Easee', 'Charge Max'),
  _entry('Easee', 'Charge Up'),
  _entry('Easee', 'Home'),
  _entry('Easee', 'One'),
  _entry('Garo', 'Entity Compact'),
  _entry('Garo', 'Entity Pro'),
  _entry('Garo', 'GLB'),
  _entry('Garo', 'GLB Twin'),
  _entry('Garo', 'GLC'),
  _entry('Garo', 'GLC Twin'),
  _entry('Garo', 'GLC Wallbox'),
  _entry('Garo', 'LS4 Wallbox'),
  _entry('Garo', 'Wallbox'),
  _entry('Indra', 'Smart PRO'),
  _entry('Indra', 'Smart+ Charger'),
  _entry('Keba', 'P30'),
  _entry('Kempower', 'T-Series'),
  _entry('Monta', 'Hub'),
  _entry('Pod Point', 'Home'),
  _entry('Pod Point', 'Home Single Phase'),
  _entry('Pod Point', 'Home Three Phase'),
  _entry('Schneider Electric', 'EVlink Pro AC'),
  _entry('Schneider Electric', 'EVlink Wallbox'),
  _entry('Schneider Electric', 'Resi9'),
  _entry('Smappee', 'EV Wall'),
  _entry('Smappee', 'EV Wall Business'),
  _entry('Smappee', 'EV Wall Home'),
  _entry('Smappee', 'EV Wall Lite'),
  _entry('Smappee', 'EV Wall Lite Home'),
  _entry('Smappee', 'EV Wall Smart'),
  _entry('Smappee', 'EV Wall Smart Home'),
  _entry('Tibber', 'Pulse Charger'),
  _entry('Wallbox', 'Commander 2'),
  _entry('Wallbox', 'Commander 2s'),
  _entry('Wallbox', 'Copper SB'),
  _entry('Wallbox', 'Pulsar Max'),
  _entry('Wallbox', 'Pulsar Plus'),
  _entry('Wallbox', 'Quasar 1'),
  _entry('Wallbox', 'Quasar 2'),
  _entry('Zaptec', 'Go'),
  _entry('Zaptec', 'Pro'),
  _entry('Zaptec', 'Pro Plus'),
  _entry('Zaptec', 'Pro+ Dual'),
  _entry('Zaptec', 'Pro+ Single'),
  _entry('Zaptec', 'Pro+ Wall'),
  _entry('Zaptec', 'Pro+ Wall Dual'),
  _entry('Zaptec', 'Pro+ Wall Single'),
  _entry('Zaptec', 'Pro+ Wallbox'),
  _entry('Zaptec', 'Pro+ Wallbox Dual'),
  _entry('Zaptec', 'Pro+ Wallbox Single'),
  _entry('Zaptec', 'Pro+ Wallbox Triple'),
  _entry('Zaptec', 'Pro+ Wallbox Twin'),
]);
