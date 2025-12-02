import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_bootstrap.dart';
import '../driver_map/driver_station_models.dart';
import '../stations/models/station.dart';
import '../stations/models/station_slot.dart';

class DriverReservation {
  const DriverReservation({
    required this.slot,
    required this.station,
    required this.membership,
  });

  final StationSlot slot;
  final Station station;
  final DriverStationMembership membership;

  String get membershipId => membership.id;
}

class DriverReservationsRepository {
  const DriverReservationsRepository();

  SupabaseClient get _client => supabase;

  Future<List<DriverReservation>> fetchReservations({
    Duration pastWindow = const Duration(days: 45),
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Aucun utilisateur connecte');
    }

    final membershipsResponse = await _client
        .from('station_memberships')
        .select('''
          id,
          station_id,
          status,
          created_at,
          approved_at,
          station:stations(
            id,
            owner_id,
            name,
            charger_brand,
            charger_model,
            charger_vendor,
            use_profile_address,
            street_name,
            street_number,
            postal_code,
            city,
            country,
            photo_url,
            additional_info,
            whatsapp_group_url,
            location_place_id,
            location_lat,
            location_lng,
            location_formatted,
            location_components,
            recurring_rules
          )
        ''')
        .eq('profile_id', user.id)
        .eq('status', 'approved');

    final membershipMaps = (membershipsResponse as List<dynamic>)
        .cast<Map<String, dynamic>>();

    if (membershipMaps.isEmpty) {
      return const [];
    }

    final memberships = <String, DriverStationMembership>{};
    final stations = <String, Station>{};

    for (final map in membershipMaps) {
      final stationMap = map['station'] as Map<String, dynamic>?;
      if (stationMap == null) continue;
      final membership = DriverStationMembership.fromMap(map);
      final station = Station.fromMap(stationMap);
      memberships[membership.id] = membership;
      stations[station.id] = station;
    }

    if (memberships.isEmpty) {
      return const [];
    }

    final membershipIds = memberships.keys.toList();
    final fromDate = DateTime.now()
        .toUtc()
        .subtract(pastWindow)
        .toIso8601String();

    final slotsResponse = await _client
        .from('station_slots')
        .select(
          'id, station_id, start_at, end_at, type, created_at, metadata, created_by',
        )
        .eq('type', 'member_booking')
        .inFilter('metadata->>membership_id', membershipIds)
        .gte('start_at', fromDate)
        .order('start_at');

    if (slotsResponse is! List) {
      return const [];
    }

    final reservations = <DriverReservation>[];

    for (final item in slotsResponse.cast<Map<String, dynamic>>()) {
      final slot = StationSlot.fromMap(item);
      final metadata = slot.metadata ?? const <String, dynamic>{};
      final membershipId = metadata['membership_id'] as String?;
      if (membershipId == null) continue;

      final membership = memberships[membershipId];
      if (membership == null) continue;

      final station = stations[membership.stationId];
      if (station == null) continue;

      reservations.add(
        DriverReservation(slot: slot, station: station, membership: membership),
      );
    }

    reservations.sort((a, b) => a.slot.startAt.compareTo(b.slot.startAt));
    return reservations;
  }
}
