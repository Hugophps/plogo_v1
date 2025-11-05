import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_bootstrap.dart';
import '../stations/models/station.dart';
import 'driver_station_models.dart';

class DriverStationRepository {
  const DriverStationRepository();

  SupabaseClient get _client => supabase;

  Future<List<DriverStationView>> fetchStationsWithMemberships() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Aucun utilisateur connecte');
    }

    final results = await Future.wait([
      _client.from('stations').select('''
        id,
        owner_id,
        name,
        brand,
        model,
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
        owner:profiles!stations_owner_id_fkey (
          id,
          full_name,
          avatar_url
        )
      '''),
      _client
          .from('station_memberships')
          .select('id, station_id, status, created_at, approved_at')
          .eq('profile_id', user.id),
    ]);

    final stationList = (results[0] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final memberships = <String, DriverStationMembership>{};

    for (final item in (results[1] as List<dynamic>)) {
      final map = item as Map<String, dynamic>;
      final membership = DriverStationMembership.fromMap(map);
      memberships[membership.stationId] = membership;
    }

    final views = <DriverStationView>[];

    for (final stationMap in stationList) {
      final ownerMap = stationMap['owner'] as Map<String, dynamic>?;
      final normalized = Map<String, dynamic>.from(stationMap)..remove('owner');

      final station = Station.fromMap(normalized);
      final owner = DriverStationOwnerSummary(
        id: ownerMap?['id'] as String? ?? station.ownerId,
        displayName: (ownerMap?['full_name'] as String?) ?? 'Proprietaire',
        avatarUrl: ownerMap?['avatar_url'] as String?,
      );

      views.add(
        DriverStationView(
          station: station,
          owner: owner,
          membership: memberships[station.id],
        ),
      );
    }

    return views;
  }

  Future<DriverStationMembership> requestAccess(String stationId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Aucun utilisateur connecte');
    }

    try {
      final response = await _client
          .from('station_memberships')
          .insert({'station_id': stationId, 'profile_id': user.id})
          .select('id, station_id, status, created_at, approved_at')
          .single();

      return DriverStationMembership.fromMap(response);
    } on PostgrestException catch (error) {
      if (error.code == '23505') {
        final existing = await _client
            .from('station_memberships')
            .select('id, station_id, status, created_at, approved_at')
            .eq('station_id', stationId)
            .eq('profile_id', user.id)
            .maybeSingle();
        if (existing != null) {
          return DriverStationMembership.fromMap(existing);
        }
      }
      rethrow;
    }
  }

  Future<void> leaveStation(String membershipId) async {
    await _client.from('station_memberships').delete().eq('id', membershipId);
  }

  Future<DriverStationMembership?> fetchMembership(String stationId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Aucun utilisateur connecte');
    }

    final response = await _client
        .from('station_memberships')
        .select('id, station_id, status, created_at, approved_at')
        .eq('station_id', stationId)
        .eq('profile_id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return DriverStationMembership.fromMap(response);
  }
}
