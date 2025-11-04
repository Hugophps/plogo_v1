import 'package:flutter/foundation.dart';

import '../../profile/models/profile.dart';

enum StationMemberStatus { pending, approved }

@immutable
class StationMember {
  const StationMember({
    required this.id,
    required this.stationId,
    required this.profile,
    required this.status,
    required this.createdAt,
    this.approvedAt,
  });

  final String id;
  final String stationId;
  final Profile profile;
  final StationMemberStatus status;
  final DateTime createdAt;
  final DateTime? approvedAt;

  bool get isPending => status == StationMemberStatus.pending;
  bool get isApproved => status == StationMemberStatus.approved;

  StationMember copyWith({StationMemberStatus? status, DateTime? approvedAt}) {
    return StationMember(
      id: id,
      stationId: stationId,
      profile: profile,
      status: status ?? this.status,
      createdAt: createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }

  factory StationMember.fromMap(Map<String, dynamic> map) {
    final statusText = (map['status'] as String?) ?? 'pending';
    final profileMap = map['profile'] as Map<String, dynamic>? ?? {};
    return StationMember(
      id: map['id'] as String,
      stationId: map['station_id'] as String,
      profile: Profile.fromMap(profileMap),
      status: statusText == 'approved'
          ? StationMemberStatus.approved
          : StationMemberStatus.pending,
      createdAt: DateTime.parse(map['created_at'] as String),
      approvedAt: map['approved_at'] != null
          ? DateTime.tryParse(map['approved_at'] as String)
          : null,
    );
  }
}
