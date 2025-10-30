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
    required this.isCompleted,
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
  final bool isCompleted;

  bool get hasRole => role == 'owner' || role == 'driver';
  bool get isOwner => role == 'owner';
  bool get isDriver => role == 'driver';

  Profile copyWith({
    String? fullName,
    String? phoneNumber,
    String? role,
    String? avatarUrl,
    String? stationName,
    String? nextSessionStatus,
    String? description,
    bool? isCompleted,
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
      isCompleted: isCompleted ?? this.isCompleted,
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
      isCompleted: (map['profile_completed'] as bool?) ?? false,
    );
  }
}
