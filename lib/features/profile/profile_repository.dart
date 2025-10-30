import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_bootstrap.dart';
import 'models/profile.dart';

class ProfileRepository {
  const ProfileRepository();

  SupabaseClient get _client => supabase;

  Future<Profile?> fetchCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return Profile.fromMap(response);
  }

  Future<Profile> upsertProfile(Map<String, dynamic> data) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Aucun utilisateur connecté');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final payload = {
      'id': user.id,
      'email': user.email,
      'updated_at': now,
      ...data,
    };

    final response = await _client
        .from('profiles')
        .upsert(payload)
        .select()
        .single();

    return Profile.fromMap(response);
  }

  Future<Profile> updateRole(String role) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Aucun utilisateur connecté');
    }

    final response = await _client
        .from('profiles')
        .update({
          'role': role,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', user.id)
        .select()
        .single();

    return Profile.fromMap(response);
  }
}
