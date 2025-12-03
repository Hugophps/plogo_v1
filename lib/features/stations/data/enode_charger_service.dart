import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_bootstrap.dart';
import 'enode_charger_catalog.dart';

class EnodeChargerService {
  const EnodeChargerService();

  SupabaseClient get _client => supabase;

  Future<List<EnodeChargerModel>> fetchChargers() async {
    try {
      final response = await _client.functions.invoke(
        'enode-chargers',
        body: const {'action': 'list_chargers'},
      );
      final mapped = _extractItems(response.data);
      if (mapped.isEmpty) {
        throw Exception('Aucun modèle de borne renvoyé par Enode.');
      }
      return mapped
          .map((item) => EnodeChargerModel.fromEnodePayload(item))
          .toList();
    } on FunctionException catch (e) {
      throw Exception(e.details ?? 'Service Enode indisponible.');
    } catch (_) {
      throw Exception('Impossible de récupérer les bornes compatibles Enode.');
    }
  }

  List<Map<String, dynamic>> _extractItems(dynamic data) {
    final List<dynamic> rawList;
    if (data is List) {
      rawList = data;
    } else if (data is Map<String, dynamic>) {
      final knownKeys = ['data', 'chargers', 'items'];
      List<dynamic>? firstList;
      for (final key in knownKeys) {
        final value = data[key];
        if (value is List) {
          firstList = value;
          break;
        }
      }
      rawList = firstList ?? const [];
    } else {
      rawList = const [];
    }

    return rawList
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }
}
