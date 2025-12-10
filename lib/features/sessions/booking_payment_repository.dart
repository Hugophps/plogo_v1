import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_bootstrap.dart';
import 'models/booking_payment.dart';

enum BookingPaymentDriverAction { markAsPaid, cancelMark }

enum BookingPaymentOwnerAction { confirm, revert }

class BookingPaymentRepository {
  const BookingPaymentRepository();

  SupabaseClient get _client => supabase;

  Future<List<BookingPayment>> fetchPayments(BookingPaymentRole role) async {
    try {
      final response = await _client.functions.invoke(
        'booking-payments',
        method: HttpMethod.get,
        queryParameters: {'role': role == BookingPaymentRole.owner ? 'owner' : 'driver'},
      );
      final data = response.data;
      if (data is Map && data['items'] is List) {
        final items = (data['items'] as List)
            .whereType<Map<String, dynamic>>()
            .map(BookingPayment.fromMap)
            .toList();
        return items;
      }
      throw Exception('Réponse inattendue du serveur.');
    } on FunctionException catch (error) {
      throw Exception(error.details ?? "Impossible de récupérer les sessions.");
    } catch (_) {
      throw Exception("Impossible de récupérer les sessions.");
    }
  }

  Future<BookingPayment> updateDriverPayment(
    String slotId,
    BookingPaymentDriverAction action,
  ) async {
    return _invokeAction(
      functionName: 'booking-payments-driver-action',
      body: {
        'slot_id': slotId,
        'action': action == BookingPaymentDriverAction.cancelMark ? 'cancel' : 'mark',
      },
    );
  }

  Future<BookingPayment> updateOwnerPayment(
    String slotId,
    BookingPaymentOwnerAction action,
  ) async {
    return _invokeAction(
      functionName: 'booking-payments-owner-action',
      body: {
        'slot_id': slotId,
        'action': action == BookingPaymentOwnerAction.revert ? 'cancel' : 'confirm',
      },
    );
  }

  Future<BookingPayment> _invokeAction({
    required String functionName,
    required Map<String, dynamic> body,
  }) async {
    try {
      final response = await _client.functions.invoke(
        functionName,
        body: body,
      );
      final data = response.data;
      if (data is Map && data['item'] is Map<String, dynamic>) {
        return BookingPayment.fromMap(data['item'] as Map<String, dynamic>);
      }
      throw Exception('Réponse inattendue du serveur.');
    } on FunctionException catch (error) {
      throw Exception(error.details ?? "Action impossible");
    } catch (_) {
      throw Exception("Action impossible pour le moment.");
    }
  }
}
