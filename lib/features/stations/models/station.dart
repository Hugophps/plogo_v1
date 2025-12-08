import 'station_recurring_rule.dart';

class Station {
  const Station({
    required this.id,
    required this.ownerId,
    required this.name,
    this.chargerBrand,
    this.chargerModel,
    this.chargerVendor,
    this.enodeChargerId,
    this.enodeMetadata,
    this.pricePerKwh,
    required this.useProfileAddress,
    required this.streetName,
    required this.streetNumber,
    required this.postalCode,
    required this.city,
    required this.country,
    this.photoUrl,
    this.additionalInfo,
    this.whatsappGroupUrl,
    this.locationPlaceId,
    this.locationLat,
    this.locationLng,
    this.locationFormatted,
    this.locationComponents,
    this.recurringRules = const [],
  });

  final String id;
  final String ownerId;
  final String name;
  final String? chargerBrand;
  final String? chargerModel;
  final String? chargerVendor;
  final String? enodeChargerId;
  final Map<String, dynamic>? enodeMetadata;
  final double? pricePerKwh;
  final bool useProfileAddress;
  final String streetName;
  final String streetNumber;
  final String postalCode;
  final String city;
  final String country;
  final String? photoUrl;
  final String? additionalInfo;
  final String? whatsappGroupUrl;
  final String? locationPlaceId;
  final double? locationLat;
  final double? locationLng;
  final String? locationFormatted;
  final List<dynamic>? locationComponents;
  final List<StationRecurringRule> recurringRules;

  Station copyWith({
    String? name,
    String? chargerBrand,
    String? chargerModel,
    String? chargerVendor,
    String? enodeChargerId,
    Map<String, dynamic>? enodeMetadata,
    double? pricePerKwh,
    bool? useProfileAddress,
    String? streetName,
    String? streetNumber,
    String? postalCode,
    String? city,
    String? country,
    String? photoUrl,
    String? additionalInfo,
    String? whatsappGroupUrl,
    String? locationPlaceId,
    double? locationLat,
    double? locationLng,
    String? locationFormatted,
    List<dynamic>? locationComponents,
    List<StationRecurringRule>? recurringRules,
  }) {
    return Station(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      chargerBrand: chargerBrand ?? this.chargerBrand,
      chargerModel: chargerModel ?? this.chargerModel,
      chargerVendor: chargerVendor ?? this.chargerVendor,
      enodeChargerId: enodeChargerId ?? this.enodeChargerId,
      enodeMetadata: enodeMetadata ?? this.enodeMetadata,
      pricePerKwh: pricePerKwh ?? this.pricePerKwh,
      useProfileAddress: useProfileAddress ?? this.useProfileAddress,
      streetName: streetName ?? this.streetName,
      streetNumber: streetNumber ?? this.streetNumber,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      country: country ?? this.country,
      photoUrl: photoUrl ?? this.photoUrl,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      whatsappGroupUrl: whatsappGroupUrl ?? this.whatsappGroupUrl,
      locationPlaceId: locationPlaceId ?? this.locationPlaceId,
      locationLat: locationLat ?? this.locationLat,
      locationLng: locationLng ?? this.locationLng,
      locationFormatted: locationFormatted ?? this.locationFormatted,
      locationComponents: locationComponents ?? this.locationComponents,
      recurringRules: recurringRules ?? this.recurringRules,
    );
  }

  factory Station.fromMap(Map<String, dynamic> map) {
    return Station(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      chargerBrand: map['charger_brand'] as String?,
      chargerModel: map['charger_model'] as String?,
      chargerVendor: map['charger_vendor'] as String?,
      enodeChargerId: map['enode_charger_id'] as String?,
      enodeMetadata: _parseMetadata(map['enode_metadata']),
      pricePerKwh: (map['price_per_kwh'] as num?)?.toDouble(),
      useProfileAddress: (map['use_profile_address'] as bool?) ?? false,
      streetName: map['street_name'] as String,
      streetNumber: map['street_number'] as String,
      postalCode: map['postal_code'] as String,
      city: map['city'] as String,
      country: map['country'] as String,
      photoUrl: map['photo_url'] as String?,
      additionalInfo: map['additional_info'] as String?,
      whatsappGroupUrl: map['whatsapp_group_url'] as String?,
      locationPlaceId: map['location_place_id'] as String?,
      locationLat: (map['location_lat'] as num?)?.toDouble(),
      locationLng: (map['location_lng'] as num?)?.toDouble(),
      locationFormatted: map['location_formatted'] as String?,
      locationComponents: map['location_components'] as List<dynamic>?,
      recurringRules: _parseRecurringRules(map['recurring_rules']),
    );
  }

  static List<StationRecurringRule> _parseRecurringRules(dynamic value) {
    if (value is! List) return const [];
    final rules = <StationRecurringRule>[];
    for (final element in value) {
      if (element is Map<String, dynamic>) {
        final rule = StationRecurringRule.tryParse(element);
        if (rule != null) {
          rules.add(rule);
        }
      }
    }
    return rules;
  }

  static Map<String, dynamic>? _parseMetadata(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value as Map);
    }
    return null;
  }
}

extension StationChargerLabel on Station {
  String? get chargerLabel {
    final brand = (chargerBrand ?? '').trim();
    final model = (chargerModel ?? '').trim();
    final hasBrand = brand.isNotEmpty;
    final hasModel = model.isNotEmpty;
    if (!hasBrand && !hasModel) return null;
    if (!hasBrand) return model;
    if (!hasModel) return brand;
    return '$brand · $model';
  }
}

extension StationPricing on Station {
  String? get priceLabel {
    final value = pricePerKwh;
    if (value == null) return null;
    final bool isInt = value == value.roundToDouble();
    final text = isInt ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
    return '$text €/kWh';
  }
}
