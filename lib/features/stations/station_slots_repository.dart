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
        .select()
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
}
