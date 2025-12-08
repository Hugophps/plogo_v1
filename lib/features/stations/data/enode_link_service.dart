import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_bootstrap.dart';

class EnodeLinkService {
  const EnodeLinkService();

  SupabaseClient get _client => supabase;

  Future<String> createLinkSession(String stationId) async {
    try {
      final response = await _client.functions.invoke(
        'enode-link-station',
        body: {'station_id': stationId},
      );
      final linkUrl = _extractLinkUrl(response.data);
      if (linkUrl == null) {
        throw Exception(
          'Lien de connexion Enode indisponible pour cette station.',
        );
      }
      return linkUrl;
    } on FunctionException catch (error) {
      throw Exception(
        error.details ?? "Service Enode indisponible pour le moment.",
      );
    } catch (_) {
      throw Exception(
        'Impossible de préparer la connexion Enode. Réessayez dans un instant.',
      );
    }
  }

  String? _extractLinkUrl(dynamic payload) {
    if (payload is String && payload.startsWith('http')) {
      return payload;
    }
    if (payload is Map<String, dynamic>) {
      for (final key in ['link_url', 'linkUrl', 'url']) {
        final value = payload[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
    }
    return null;
  }
}
