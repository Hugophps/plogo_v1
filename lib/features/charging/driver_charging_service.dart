import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_bootstrap.dart';
import 'models/charging_session.dart';

class DriverChargingActionResult {
  const DriverChargingActionResult({
    required this.session,
    this.message,
  });

  final ChargingSession session;
  final String? message;
}

class DriverChargingService {
  const DriverChargingService();

  SupabaseClient get _client => supabase;

  Future<DriverChargingActionResult> startCharging(
    String stationId,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'driver-start-charging',
        body: {'station_id': stationId},
      );
      final session = _parseSession(response.data);
      final message = _parseMessage(response.data);
      return DriverChargingActionResult(session: session, message: message);
    } on FunctionException catch (error) {
      throw Exception(
        error.details ?? "Impossible de démarrer la charge.",
      );
    } catch (_) {
      throw Exception(
        "Impossible de démarrer la charge. Réessayez dans un instant.",
      );
    }
  }

  Future<DriverChargingActionResult> stopCharging(
    String stationId,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'driver-stop-charging',
        body: {'station_id': stationId},
      );
      final session = _parseSession(response.data);
      final message = _parseMessage(response.data);
      return DriverChargingActionResult(session: session, message: message);
    } on FunctionException catch (error) {
      throw Exception(
        error.details ?? "Impossible d'arrêter la charge.",
      );
    } catch (_) {
      throw Exception(
        "Impossible d'arrêter la charge pour le moment.",
      );
    }
  }

  ChargingSession _parseSession(dynamic payload) {
    if (payload is Map) {
      final sessionMap = payload['session'];
      if (sessionMap is Map<String, dynamic>) {
        return ChargingSession.fromMap(sessionMap);
      }
    }
    throw Exception("Réponse inattendue du service Enode.");
  }

  String? _parseMessage(dynamic payload) {
    if (payload is Map && payload['message'] is String) {
      final message = payload['message'] as String;
      return message.trim().isEmpty ? null : message.trim();
    }
    return null;
  }
}
