import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_bootstrap.dart';
import 'google_place_models.dart';

class GooglePlaceService {
  const GooglePlaceService();

  SupabaseClient get _client => supabase;

  Future<List<GooglePlacePrediction>> searchAddresses(
    String input, {
    String? sessionToken,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'google-places',
        body: {
          'action': 'autocomplete',
          'input': input,
          if (sessionToken != null) 'sessionToken': sessionToken,
        },
      );

      final data = response.data as Map<String, dynamic>? ?? {};
      final predictions = data['predictions'] as List<dynamic>? ?? const [];
      return predictions
          .map((item) {
            final map = item as Map<String, dynamic>;
            final description = map['description'] as String?;
            final placeId = map['place_id'] as String?;
            if (description == null || placeId == null) return null;
            return GooglePlacePrediction(
              placeId: placeId,
              description: description,
            );
          })
          .whereType<GooglePlacePrediction>()
          .toList();
    } on FunctionException catch (e) {
      throw Exception(e.details ?? 'Service Google Maps indisponible.');
    } catch (_) {
      throw Exception('Service Google Maps indisponible.');
    }
  }

  Future<GooglePlaceDetails> fetchDetails(
    String placeId, {
    String? sessionToken,
  }) async {
    try {
      final response = await _client.functions.invoke(
        'google-places',
        body: {
          'action': 'details',
          'placeId': placeId,
          if (sessionToken != null) 'sessionToken': sessionToken,
        },
      );

      final data = response.data as Map<String, dynamic>? ?? {};
      final formattedAddress = data['formattedAddress'] as String?;
      final location = data['location'] as Map<String, dynamic>?;
      final components =
          data['addressComponents'] as List<dynamic>? ?? const [];

      if (formattedAddress == null ||
          location == null ||
          location['lat'] == null ||
          location['lng'] == null) {
        throw Exception('Reponse Google Places invalide');
      }

      final parsedComponents = components
          .map(
            (item) => GoogleAddressComponent.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList();

      return GooglePlaceDetails(
        placeId: data['placeId'] as String? ?? placeId,
        formattedAddress: formattedAddress,
        lat: (location['lat'] as num).toDouble(),
        lng: (location['lng'] as num).toDouble(),
        components: parsedComponents,
      );
    } on FunctionException catch (e) {
      throw Exception(e.details ?? 'Impossible de recuperer le lieu.');
    } catch (_) {
      throw Exception('Impossible de recuperer le lieu.');
    }
  }
}
