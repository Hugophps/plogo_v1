import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../profile/models/profile.dart';
import 'models/station.dart';
import 'models/station_slot.dart';
import 'owner_block_slot_page.dart';
import 'station_slots_repository.dart';

class DriverStationBookingPage extends StatelessWidget {
  const DriverStationBookingPage({
    super.key,
    required this.station,
    required this.repository,
    required this.profile,
    required this.membershipId,
    this.slot,
    this.initialDate,
  });

  final Station station;
  final StationSlotsRepository repository;
  final Profile profile;
  final String membershipId;
  final StationSlot? slot;
  final tz.TZDateTime? initialDate;

  @override
  Widget build(BuildContext context) {
    return OwnerBlockSlotPage(
      station: station,
      repository: repository,
      slot: slot,
      initialDate: initialDate,
      mode: StationSlotEditorMode.memberBooking,
      memberProfile: profile,
      membershipId: membershipId,
    );
  }
}
