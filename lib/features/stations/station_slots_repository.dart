import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_bootstrap.dart';
import 'models/station_slot.dart';

class StationSlotsRepository {
  const StationSlotsRepository();

  SupabaseClient get _client => supabase;

  Future<List<StationSlot>> fetchSlots({
    required String stationId,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) async {
    final response = await _client
        .from('station_slots')
        .select(
          'id, station_id, start_at, end_at, type, created_at, metadata, created_by',
        )
        .eq('station_id', stationId)
        .lt('start_at', rangeEnd.toUtc().toIso8601String())
        .gt('end_at', rangeStart.toUtc().toIso8601String())
        .order('start_at', ascending: true);

    if (response is! List) {
      return const [];
    }

    return response
        .whereType<Map<String, dynamic>>()
        .map(StationSlot.fromMap)
        .toList();
  }

  Future<StationSlot> createOwnerBlock({
    required String stationId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final response = await _client
        .from('station_slots')
        .insert({
          'station_id': stationId,
          'start_at': startAt.toUtc().toIso8601String(),
          'end_at': endAt.toUtc().toIso8601String(),
          'type': 'owner_block',
          if (userId != null) 'created_by': userId,
        })
        .select(
          'id, station_id, start_at, end_at, type, created_at, metadata, created_by',
        )
        .single();

    return StationSlot.fromMap(response as Map<String, dynamic>);
  }

  Future<StationSlot> createMemberBooking({
    required String stationId,
    required DateTime startAt,
    required DateTime endAt,
    required Map<String, dynamic> metadata,
  }) async {
    final userId = _client.auth.currentUser?.id;
    final response = await _client
        .from('station_slots')
        .insert({
          'station_id': stationId,
          'start_at': startAt.toUtc().toIso8601String(),
          'end_at': endAt.toUtc().toIso8601String(),
          'type': 'member_booking',
          'metadata': metadata,
          if (userId != null) 'created_by': userId,
        })
        .select(
          'id, station_id, start_at, end_at, type, created_at, metadata, created_by',
        )
        .single();

    return StationSlot.fromMap(response as Map<String, dynamic>);
  }

  Future<StationSlot> updateSlot({
    required String slotId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final response = await _client
        .from('station_slots')
        .update({
          'start_at': startAt.toUtc().toIso8601String(),
          'end_at': endAt.toUtc().toIso8601String(),
        })
        .eq('id', slotId)
        .select(
          'id, station_id, start_at, end_at, type, created_at, metadata, created_by',
        )
        .single();

    return StationSlot.fromMap(response as Map<String, dynamic>);
  }

  Future<void> deleteSlot(String slotId) async {
    await _client.from('station_slots').delete().eq('id', slotId);
  }
}
