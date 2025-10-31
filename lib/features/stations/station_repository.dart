import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_bootstrap.dart';
import 'models/station.dart';

class StationRepository {
  const StationRepository();

  SupabaseClient get _client => supabase;

  Future<Station?> fetchOwnStation() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('stations')
        .select()
        .eq('owner_id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return Station.fromMap(response);
  }

  Future<Station> createStation(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Aucun utilisateur connecté');
    }

    final response = await _client
        .from('stations')
        .insert({
          'owner_id': user.id,
          ...data,
        })
        .select()
        .single();

    return Station.fromMap(response);
  }

  Future<Station> updateStation(String stationId, Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Aucun utilisateur connecté');
    }

    final response = await _client
        .from('stations')
        .update({
          ...data,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', stationId)
        .eq('owner_id', user.id)
        .select()
        .single();

    return Station.fromMap(response);
  }
}
