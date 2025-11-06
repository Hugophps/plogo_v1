enum StationSlotType {
  recurringUnavailability,
  ownerBlock,
  memberBooking,
}

extension StationSlotTypeParsing on StationSlotType {
  String get value {
    switch (this) {
      case StationSlotType.recurringUnavailability:
        return 'recurring_unavailability';
      case StationSlotType.ownerBlock:
        return 'owner_block';
      case StationSlotType.memberBooking:
        return 'member_booking';
    }
  }

  static StationSlotType? tryParse(String? value) {
    switch (value) {
      case 'recurring_unavailability':
        return StationSlotType.recurringUnavailability;
      case 'owner_block':
        return StationSlotType.ownerBlock;
      case 'member_booking':
        return StationSlotType.memberBooking;
      default:
        return null;
    }
  }
}

class StationSlot {
  const StationSlot({
    required this.id,
    required this.stationId,
    required this.startAt,
    required this.endAt,
    required this.type,
    this.createdAt,
    this.metadata,
  });

  final String id;
  final String stationId;
  final DateTime startAt;
  final DateTime endAt;
  final StationSlotType type;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;

  Duration get duration => endAt.difference(startAt);

  bool get isAllDay =>
      startAt.hour == 0 &&
      startAt.minute == 0 &&
      endAt.difference(startAt).inHours >= 24;

  factory StationSlot.fromMap(Map<String, dynamic> map) {
    final typeString = map['type'] as String?;
    final type = StationSlotTypeParsing.tryParse(typeString);
    if (type == null) {
      throw ArgumentError('Type de créneau invalide: $typeString');
    }

    return StationSlot(
      id: map['id'] as String,
      stationId: map['station_id'] as String,
      startAt: DateTime.parse(map['start_at'] as String),
      endAt: DateTime.parse(map['end_at'] as String),
      type: type,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      metadata: map['metadata'] is Map<String, dynamic>
          ? (map['metadata'] as Map<String, dynamic>)
          : null,
    );
  }
}
