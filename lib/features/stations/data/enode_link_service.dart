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

  Future<List<LinkedEnodeCharger>> fetchLinkedChargers() async {
    try {
      final response = await _client.functions.invoke(
        'enode-owner-chargers',
        method: HttpMethod.get,
      );
      final data = response.data;
      final list = (data is Map<String, dynamic>)
          ? (data['chargers'] as List<dynamic>? ?? const [])
          : const [];
      if (list.isEmpty) {
        return const [];
      }
      return list
          .whereType<Map>()
          .map(
            (json) => LinkedEnodeCharger(
              id: (json['id'] ?? '').toString(),
              label: (json['label'] ?? 'Borne Enode').toString(),
              brand: (json['brand'] ?? '').toString(),
              model: (json['model'] ?? '').toString(),
            ),
          )
          .where((charger) => charger.id.isNotEmpty)
          .toList();
    } on FunctionException catch (error) {
      throw Exception(
        error.details ?? "Impossible de récupérer vos bornes Enode.",
      );
    } catch (_) {
      throw Exception(
        "Impossible de récupérer vos bornes Enode pour le moment.",
      );
    }
  }

  Future<void> attachCharger({
    required String stationId,
    required String chargerId,
  }) async {
    try {
      await _client.functions.invoke(
        'enode-select-charger',
        body: {
          'station_id': stationId,
          'charger_id': chargerId,
        },
      );
    } on FunctionException catch (error) {
      throw Exception(
        error.details ??
            "Impossible d'associer cette borne à votre station.",
      );
    } catch (_) {
      throw Exception(
        "Impossible d'associer cette borne à votre station pour le moment.",
      );
    }
  }
}

class LinkedEnodeCharger {
  const LinkedEnodeCharger({
    required this.id,
    required this.label,
    required this.brand,
    required this.model,
  });

  final String id;
  final String label;
  final String brand;
  final String model;
}
