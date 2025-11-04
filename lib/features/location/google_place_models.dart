import 'dart:math';

class GooglePlacePrediction {
  const GooglePlacePrediction({
    required this.placeId,
    required this.description,
  });

  final String placeId;
  final String description;
}

class GoogleAddressComponent {
  const GoogleAddressComponent({
    required this.longName,
    required this.shortName,
    required this.types,
  });

  final String longName;
  final String shortName;
  final List<String> types;

  factory GoogleAddressComponent.fromJson(Map<String, dynamic> json) {
    return GoogleAddressComponent(
      longName: json['long_name'] as String? ?? '',
      shortName: json['short_name'] as String? ?? '',
      types: (json['types'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'long_name': longName, 'short_name': shortName, 'types': types};
  }

  bool hasType(String type) => types.contains(type);
}

class GooglePlaceDetails {
  const GooglePlaceDetails({
    required this.placeId,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    required this.components,
  });

  final String placeId;
  final String formattedAddress;
  final double lat;
  final double lng;
  final List<GoogleAddressComponent> components;

  Map<String, dynamic> toJson() {
    return {
      'place_id': placeId,
      'formatted_address': formattedAddress,
      'lat': lat,
      'lng': lng,
      'components': components.map((e) => e.toJson()).toList(),
    };
  }

  static GooglePlaceDetails? fromStoredData({
    String? placeId,
    String? formattedAddress,
    double? lat,
    double? lng,
    dynamic components,
  }) {
    if (placeId == null ||
        formattedAddress == null ||
        lat == null ||
        lng == null ||
        components == null) {
      return null;
    }

    final list = (components as List<dynamic>? ?? [])
        .map(
          (item) => GoogleAddressComponent.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();

    return GooglePlaceDetails(
      placeId: placeId,
      formattedAddress: formattedAddress,
      lat: lat,
      lng: lng,
      components: list,
    );
  }
}

class GoogleAddressParser {
  static GoogleAddressComponent? _firstComponent(
    List<GoogleAddressComponent> components,
    String type,
  ) {
    for (final component in components) {
      if (component.hasType(type)) {
        return component;
      }
    }
    return null;
  }

  static String? _findLongName(
    List<GoogleAddressComponent> components,
    String type,
  ) {
    return _firstComponent(components, type)?.longName;
  }

  static Map<String, String?> toProfileFields(GooglePlaceDetails details) {
    final components = details.components;
    final streetName = _findLongName(components, 'route');
    final streetNumber = _findLongName(components, 'street_number');
    final postalCode = _findLongName(components, 'postal_code');
    final locality =
        _findLongName(components, 'locality') ??
        _findLongName(components, 'administrative_area_level_2') ??
        _findLongName(components, 'administrative_area_level_1');
    final country = _findLongName(components, 'country');

    return {
      'street_name': streetName,
      'street_number': streetNumber,
      'postal_code': postalCode,
      'city': locality,
      'country': country,
    };
  }
}

String generateSessionToken() {
  const chars =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final rand = Random.secure();
  final buffer = StringBuffer();
  for (var i = 0; i < 24; i++) {
    buffer.write(chars[rand.nextInt(chars.length)]);
  }
  return buffer.toString();
}
