class Station {
  const Station({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.brand,
    required this.model,
    required this.useProfileAddress,
    required this.streetName,
    required this.streetNumber,
    required this.postalCode,
    required this.city,
    required this.country,
    this.photoUrl,
    this.additionalInfo,
  });

  final String id;
  final String ownerId;
  final String name;
  final String brand;
  final String model;
  final bool useProfileAddress;
  final String streetName;
  final String streetNumber;
  final String postalCode;
  final String city;
  final String country;
  final String? photoUrl;
  final String? additionalInfo;

  Station copyWith({
    String? name,
    String? brand,
    String? model,
    bool? useProfileAddress,
    String? streetName,
    String? streetNumber,
    String? postalCode,
    String? city,
    String? country,
    String? photoUrl,
    String? additionalInfo,
  }) {
    return Station(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      useProfileAddress: useProfileAddress ?? this.useProfileAddress,
      streetName: streetName ?? this.streetName,
      streetNumber: streetNumber ?? this.streetNumber,
      postalCode: postalCode ?? this.postalCode,
      city: city ?? this.city,
      country: country ?? this.country,
      photoUrl: photoUrl ?? this.photoUrl,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }

  factory Station.fromMap(Map<String, dynamic> map) {
    return Station(
      id: map['id'] as String,
      ownerId: map['owner_id'] as String,
      name: map['name'] as String,
      brand: map['brand'] as String,
      model: map['model'] as String,
      useProfileAddress: (map['use_profile_address'] as bool?) ?? false,
      streetName: map['street_name'] as String,
      streetNumber: map['street_number'] as String,
      postalCode: map['postal_code'] as String,
      city: map['city'] as String,
      country: map['country'] as String,
      photoUrl: map['photo_url'] as String?,
      additionalInfo: map['additional_info'] as String?,
    );
  }
}
