import '../../driver_map/driver_station_models.dart';
import '../../stations/models/station.dart';
import '../../stations/models/station_slot.dart';
import 'charging_session.dart';

enum DriverChargingStatus {
  noMembership,
  noReservation,
  upcomingReservation,
  readyToCharge,
  charging,
  completed,
  error,
}

class DriverChargingView {
  const DriverChargingView({
    required this.status,
    this.station,
    this.membership,
    this.activeSlot,
    this.nextSlot,
    this.session,
    this.infoMessage,
    this.errorMessage,
  });

  final DriverChargingStatus status;
  final Station? station;
  final DriverStationMembership? membership;
  final StationSlot? activeSlot;
  final StationSlot? nextSlot;
  final ChargingSession? session;
  final String? infoMessage;
  final String? errorMessage;

  bool get canStart => status == DriverChargingStatus.readyToCharge;
  bool get canStop => status == DriverChargingStatus.charging;
  bool get hasStation => station != null;

  DriverChargingView copyWith({
    DriverChargingStatus? status,
    Station? station,
    DriverStationMembership? membership,
    StationSlot? activeSlot,
    StationSlot? nextSlot,
    ChargingSession? session,
    String? infoMessage,
    String? errorMessage,
  }) {
    return DriverChargingView(
      status: status ?? this.status,
      station: station ?? this.station,
      membership: membership ?? this.membership,
      activeSlot: activeSlot ?? this.activeSlot,
      nextSlot: nextSlot ?? this.nextSlot,
      session: session ?? this.session,
      infoMessage: infoMessage ?? this.infoMessage,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
