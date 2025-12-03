class Profile {
  Profile({
    required this.id,
    this.email,
    this.fullName,
    this.phoneNumber,
    this.role,
    this.avatarUrl,
    this.stationName,
    this.nextSessionStatus,
    this.description,
    this.streetName,
    this.streetNumber,
    this.postalCode,
    this.city,
    this.country,
    this.vehicleBrand,
    this.vehicleModel,
    this.vehiclePlate,
    required this.isCompleted,
    this.addressPlaceId,
    this.addressLat,
    this.addressLng,
    this.addressFormatted,
    this.addressComponents,
  });

  final String id;
  final String? email;
  final String? fullName;
  final String? phoneNumber;
  final String? role;
  final String? avatarUrl;
  final String? stationName;
  final String? nextSessionStatus;
  final String? description;
  final String? streetName;
  final String? streetNumber;
  final String? postalCode;
  final String? city;
  final String? country;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehiclePlate;
  final bool isCompleted;
  final String? addressPlaceId;
  final double? addressLat;
  final double? addressLng;
  final String? addressFormatted;
  final List<dynamic>? addressComponents;

  bool get hasRole => role == 'owner' || role == 'driver';
  bool get isOwner => role == 'owner';
  bool get isDriver => role == 'driver';

  String get roleLabel {
    if (isOwner) return 'Propriétaire';
    if (isDriver) return 'Conducteur';
    return 'Profil';
  }

  Profile copyWith({
    String? fullName,
    String? phoneNumber,
    String? role,
    String? avatarUrl,
    String? stationName,
    String? nextSessionStatus,
    String? description,
    String? streetName,
    String? streetNumber,
    String? postalCode,
    String? city,
    String? country,
    String? vehicleBrand,
    String? vehicleModel,
    String? vehiclePlate,
    bool? isCompleted,
    String? addressPlaceId,
    double? addressLat,
    double? addressLng,
    String? addressFormatted,
    List<dynamic>? addressComponents,
  }) {
    return Profile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      stationName: stationName ?? this.stationName,
      nextSessionStatus: nextSessionStatus ?? this.nextSessionStatus,
      description: description ?? this.description,
      streetName: streetName ?? this.streetName,
      streetNumber: streetNumber ?? this.streetNumber,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      country: country ?? this.country,
      vehicleBrand: vehicleBrand ?? this.vehicleBrand,
      vehicleModel: vehicleModel ?? this.vehicleModel,
      vehiclePlate: vehiclePlate ?? this.vehiclePlate,
      isCompleted: isCompleted ?? this.isCompleted,
      addressPlaceId: addressPlaceId ?? this.addressPlaceId,
      addressLat: addressLat ?? this.addressLat,
      addressLng: addressLng ?? this.addressLng,
      addressFormatted: addressFormatted ?? this.addressFormatted,
      addressComponents: addressComponents ?? this.addressComponents,
    );
  }

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      email: map['email'] as String?,
      fullName: map['full_name'] as String?,
      phoneNumber: map['phone_number'] as String?,
      role: map['role'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      stationName: map['station_name'] as String?,
      nextSessionStatus: map['next_session_status'] as String?,
      description: map['description'] as String?,
      streetName: map['street_name'] as String?,
      streetNumber: map['street_number'] as String?,
      postalCode: map['postal_code'] as String?,
      city: map['city'] as String?,
      country: map['country'] as String?,
      vehicleBrand: map['vehicle_brand'] as String?,
      vehicleModel: map['vehicle_model'] as String?,
      vehiclePlate: map['vehicle_plate'] as String?,
      isCompleted: (map['profile_completed'] as bool?) ?? false,
      addressPlaceId: map['address_place_id'] as String?,
      addressLat: (map['address_lat'] as num?)?.toDouble(),
      addressLng: (map['address_lng'] as num?)?.toDouble(),
      addressFormatted: map['address_formatted'] as String?,
      addressComponents: map['address_components'] as List<dynamic>?,
    );
  }
}
