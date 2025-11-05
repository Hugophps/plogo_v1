import '../stations/models/station.dart';

enum DriverStationAccessStatus { none, pending, approved }

class DriverStationOwnerSummary {
  const DriverStationOwnerSummary({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.addressLat,
    this.addressLng,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final double? addressLat;
  final double? addressLng;
}

class DriverStationMembership {
  const DriverStationMembership({
    required this.id,
    required this.stationId,
    required this.status,
    required this.createdAt,
    this.approvedAt,
  });

  final String id;
  final String stationId;
  final DriverStationAccessStatus status;
  final DateTime createdAt;
  final DateTime? approvedAt;

  bool get isPending => status == DriverStationAccessStatus.pending;
  bool get isApproved => status == DriverStationAccessStatus.approved;

  DriverStationMembership copyWith({
    DriverStationAccessStatus? status,
    DateTime? approvedAt,
  }) {
    return DriverStationMembership(
      id: id,
      stationId: stationId,
      status: status ?? this.status,
      createdAt: createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }

  static DriverStationMembership fromMap(Map<String, dynamic> map) {
    final statusText = (map['status'] as String?) ?? 'pending';
    return DriverStationMembership(
      id: map['id'] as String,
      stationId: map['station_id'] as String,
      status: _statusFromText(statusText),
      createdAt: DateTime.parse(map['created_at'] as String),
      approvedAt: map['approved_at'] != null
          ? DateTime.tryParse(map['approved_at'] as String)
          : null,
    );
  }

  static DriverStationAccessStatus _statusFromText(String value) {
    switch (value) {
      case 'approved':
        return DriverStationAccessStatus.approved;
      case 'pending':
      default:
        return DriverStationAccessStatus.pending;
    }
  }
}

class DriverStationView {
  const DriverStationView({
    required this.station,
    required this.owner,
    this.membership,
  });

  final Station station;
  final DriverStationOwnerSummary owner;
  final DriverStationMembership? membership;

  DriverStationAccessStatus get status =>
      membership?.status ?? DriverStationAccessStatus.none;

  DriverStationView copyWith({
    Station? station,
    DriverStationMembership? membership,
  }) {
    return DriverStationView(
      station: station ?? this.station,
      owner: owner,
      membership: membership,
    );
  }
}
