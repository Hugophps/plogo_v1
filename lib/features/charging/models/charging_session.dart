import '../../stations/models/station.dart';
import '../../stations/models/station_slot.dart';

class ChargingSession {
  const ChargingSession({
    required this.id,
    required this.stationId,
    required this.status,
    required this.startAt,
    this.driverProfileId,
    this.slotId,
    this.endAt,
    this.energyKwh,
    this.amountEur,
    this.station,
    this.slot,
  });

  final String id;
  final String stationId;
  final String status;
  final DateTime startAt;
  final String? driverProfileId;
  final String? slotId;
  final DateTime? endAt;
  final double? energyKwh;
  final double? amountEur;
  final Station? station;
  final StationSlot? slot;

  bool get isInProgress => status == 'in_progress';
  bool get isCompleted => status == 'completed';

  factory ChargingSession.fromMap(
    Map<String, dynamic> map, {
    Station? station,
    StationSlot? slot,
  }) {
    return ChargingSession(
      id: map['id'] as String,
      stationId: map['station_id'] as String,
      status: map['status'] as String? ?? 'pending',
      startAt: DateTime.parse(map['start_at'] as String),
      driverProfileId: map['driver_profile_id'] as String?,
      slotId: map['slot_id'] as String?,
      endAt: map['end_at'] != null
          ? DateTime.tryParse(map['end_at'] as String)
          : null,
      energyKwh: (map['energy_kwh'] as num?)?.toDouble(),
      amountEur: (map['amount_eur'] as num?)?.toDouble(),
      station: station,
      slot: slot,
    );
  }
}
