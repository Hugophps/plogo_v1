import 'station_recurring_rule.dart';

class Station {
  const Station({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.chargerBrand,
    required this.chargerModel,
    this.chargerVendor,
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
  final String chargerBrand;
  final String chargerModel;
  final String? chargerVendor;
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
      chargerBrand: map['charger_brand'] as String,
      chargerModel: map['charger_model'] as String,
      chargerVendor: map['charger_vendor'] as String?,
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
}
