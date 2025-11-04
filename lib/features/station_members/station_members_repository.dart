import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_bootstrap.dart';
import 'models/station_member.dart';

const _memberSelect = '''
            id,
            station_id,
            status,
            created_at,
            approved_at,
            profile:profiles!station_memberships_profile_id_fkey (
              id,
              email,
              full_name,
              phone_number,
              role,
              avatar_url,
              station_name,
              next_session_status,
              description,
              street_name,
              street_number,
              postal_code,
              city,
              country,
              vehicle_brand,
              vehicle_model,
              vehicle_plate,
              vehicle_plug_type,
              profile_completed
            )
          ''';

class StationMembersRepository {
  const StationMembersRepository();

  SupabaseClient get _client => supabase;

  Future<List<StationMember>> fetchMembers(String stationId) async {
    final response = await _client
        .from('station_memberships')
        .select(_memberSelect)
        .eq('station_id', stationId)
        .order('status', ascending: false)
        .order('created_at', ascending: true);

    final data = response as List<dynamic>;
    return data
        .map((item) => StationMember.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<StationMember> fetchMember(String membershipId) async {
    final response = await _client
        .from('station_memberships')
        .select(_memberSelect)
        .eq('id', membershipId)
        .maybeSingle();

    final data = response;
    if (data is Map<String, dynamic>) {
      return StationMember.fromMap(data);
    }
    throw Exception('Membre introuvable');
  }

  Future<void> approveMember(StationMember member) async {
    await _client
        .from('station_memberships')
        .update({
          'status': 'approved',
          'approved_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', member.id);
  }

  Future<void> deleteMembership(String membershipId) async {
    await _client.from('station_memberships').delete().eq('id', membershipId);
  }
}
