import 'package:flutter/foundation.dart';

enum BookingPaymentStatus { upcoming, inProgress, toPay, driverMarked, paid }

enum BookingPaymentRole { driver, owner }

@immutable
class BookingPaymentStation {
  const BookingPaymentStation({
    required this.id,
    required this.name,
    required this.streetName,
    required this.streetNumber,
    required this.postalCode,
    required this.city,
    this.pricePerKwh,
  });

  final String? id;
  final String? name;
  final String? streetName;
  final String? streetNumber;
  final String? postalCode;
  final String? city;
  final double? pricePerKwh;

  String get addressLine {
    final buffer = StringBuffer();
    if (streetNumber != null && streetNumber!.trim().isNotEmpty) {
      buffer.write(streetNumber!.trim());
      buffer.write(' ');
    }
    if (streetName != null && streetName!.trim().isNotEmpty) {
      buffer.write(streetName!.trim());
    }
    final hasAddress = buffer.isNotEmpty;
    final cityPart = _joinClean([
      postalCode?.trim(),
      city?.trim(),
    ], separator: ' ');
    if (cityPart.isNotEmpty) {
      if (hasAddress) buffer.write(' · ');
      buffer.write(cityPart);
    }
    return buffer.isEmpty ? 'Adresse indisponible' : buffer.toString();
  }
}

@immutable
class BookingPaymentSlot {
  const BookingPaymentSlot({
    required this.id,
    required this.startAt,
    required this.endAt,
  });

  final String? id;
  final DateTime startAt;
  final DateTime endAt;

  String get rangeLabel {
    final sameDay = startAt.year == endAt.year &&
        startAt.month == endAt.month &&
        startAt.day == endAt.day;
    final datePart =
        '${_twoDigits(startAt.day)}/${_twoDigits(startAt.month)}/${startAt.year}';
    final startTime = '${_twoDigits(startAt.hour)}h${_twoDigits(startAt.minute)}';
    final endTime = '${_twoDigits(endAt.hour)}h${_twoDigits(endAt.minute)}';
    if (sameDay) {
      return '$datePart · $startTime - $endTime';
    }
    final endDatePart =
        '${_twoDigits(endAt.day)}/${_twoDigits(endAt.month)}/${endAt.year}';
    return '$datePart $startTime → $endDatePart $endTime';
  }

  bool get isPast => endAt.isBefore(DateTime.now());
  bool get isActive =>
      startAt.isBefore(DateTime.now()) && !endAt.isBefore(DateTime.now());
}

@immutable
class BookingPaymentDriverInfo {
  const BookingPaymentDriverInfo({
    required this.id,
    required this.fullName,
    required this.vehicleBrand,
    required this.vehicleModel,
    required this.vehiclePlate,
  });

  final String? id;
  final String? fullName;
  final String? vehicleBrand;
  final String? vehicleModel;
  final String? vehiclePlate;

  String get label {
    final name = (fullName ?? '').trim();
    if (vehicleBrand == null && vehicleModel == null && vehiclePlate == null) {
      return name.isEmpty ? 'Membre' : name;
    }
    final vehicle = _joinClean([
      vehicleBrand?.trim(),
      vehicleModel?.trim(),
    ]);
    final plate = (vehiclePlate ?? '').trim();
    final vehicleLine = vehicle.isEmpty
        ? plate
        : plate.isEmpty
            ? vehicle
            : '$vehicle · $plate';
    if (name.isEmpty) return vehicleLine.isEmpty ? 'Membre' : vehicleLine;
    if (vehicleLine.isEmpty) return name;
    return '$name · $vehicleLine';
  }
}

@immutable
class BookingPayment {
  const BookingPayment({
    required this.id,
    required this.stationId,
    required this.slotId,
    required this.status,
    required this.role,
    required this.station,
    required this.slot,
    required this.paymentReference,
    this.driver,
    this.totalEnergyKwh,
    this.totalAmount,
    this.driverMarkedAt,
    this.ownerMarkedAt,
  });

  final String? id;
  final String? stationId;
  final String? slotId;
  final BookingPaymentStatus status;
  final BookingPaymentRole role;
  final BookingPaymentStation station;
  final BookingPaymentSlot slot;
  final BookingPaymentDriverInfo? driver;
  final double? totalEnergyKwh;
  final double? totalAmount;
  final String paymentReference;
  final DateTime? driverMarkedAt;
  final DateTime? ownerMarkedAt;

  bool get hasAmount => (totalAmount ?? 0) > 0;

  bool get canDriverMark =>
      role == BookingPaymentRole.driver &&
      status == BookingPaymentStatus.toPay &&
      hasAmount;

  bool get canDriverCancel =>
      role == BookingPaymentRole.driver &&
      status == BookingPaymentStatus.driverMarked &&
      ownerMarkedAt == null;

  bool get canOwnerConfirm =>
      role == BookingPaymentRole.owner &&
      status == BookingPaymentStatus.driverMarked;

  bool get canOwnerRevert =>
      role == BookingPaymentRole.owner &&
      status == BookingPaymentStatus.paid;

  bool get noChargeCompleted =>
      status == BookingPaymentStatus.inProgress && slot.isPast && !hasAmount;

  String get amountLabel {
    final amount = totalAmount;
    if (amount == null) return '0 €';
    final isInt = amount == amount.roundToDouble();
    final formatted =
        isInt ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2);
    return '$formatted €';
  }

  String get energyLabel {
    final energy = totalEnergyKwh;
    if (energy == null || energy <= 0) return '0 kWh';
    final isInt = energy == energy.roundToDouble();
    return '${isInt ? energy.toStringAsFixed(0) : energy.toStringAsFixed(2)} kWh';
  }

  String statusLabel(BookingPaymentRole displayRole) {
    if (noChargeCompleted) return 'Terminé';
    switch (status) {
      case BookingPaymentStatus.upcoming:
        return 'À venir';
      case BookingPaymentStatus.inProgress:
        return slot.isActive ? 'En cours' : 'Planifié';
      case BookingPaymentStatus.toPay:
        return displayRole == BookingPaymentRole.driver
            ? 'À payer'
            : 'En attente de paiement';
      case BookingPaymentStatus.driverMarked:
        return displayRole == BookingPaymentRole.driver
            ? 'Paiement indiqué'
            : 'Paiement signalé';
      case BookingPaymentStatus.paid:
        return 'Paiement reçu';
    }
  }

  BookingPayment copyForRole(BookingPaymentRole newRole) {
    return BookingPayment(
      id: id,
      stationId: stationId,
      slotId: slotId,
      status: status,
      role: newRole,
      station: station,
      slot: slot,
      driver: driver,
      totalEnergyKwh: totalEnergyKwh,
      totalAmount: totalAmount,
      paymentReference: paymentReference,
      driverMarkedAt: driverMarkedAt,
      ownerMarkedAt: ownerMarkedAt,
    );
  }

  factory BookingPayment.fromMap(Map<String, dynamic> map) {
    final roleString = (map['role'] as String?) ?? 'driver';
    final statusText = (map['status'] as String?) ?? 'upcoming';
    final slotMap = map['slot'] as Map<String, dynamic>? ?? {};
    final stationMap = map['station'] as Map<String, dynamic>? ?? {};
    final driverMap = map['driver'] as Map<String, dynamic>?;

    return BookingPayment(
      id: map['id'] as String?,
      stationId: map['station_id'] as String?,
      slotId: map['slot_id'] as String?,
      status: _statusFromText(statusText),
      role: roleString == 'owner'
          ? BookingPaymentRole.owner
          : BookingPaymentRole.driver,
      station: BookingPaymentStation(
        id: stationMap['id'] as String?,
        name: stationMap['name'] as String?,
        streetName: stationMap['street_name'] as String?,
        streetNumber: stationMap['street_number'] as String?,
        postalCode: stationMap['postal_code'] as String?,
        city: stationMap['city'] as String?,
        pricePerKwh: _parseDouble(stationMap['price_per_kwh']),
      ),
      slot: BookingPaymentSlot(
        id: slotMap['id'] as String?,
        startAt: _parseDate(slotMap['start_at']),
        endAt: _parseDate(slotMap['end_at']),
      ),
      driver: driverMap == null
          ? null
          : BookingPaymentDriverInfo(
              id: driverMap['id'] as String?,
              fullName: driverMap['full_name'] as String?,
              vehicleBrand: driverMap['vehicle_brand'] as String?,
              vehicleModel: driverMap['vehicle_model'] as String?,
              vehiclePlate: driverMap['vehicle_plate'] as String?,
            ),
      totalEnergyKwh: _parseDouble(map['total_energy_kwh']),
      totalAmount: _parseDouble(map['total_amount']),
      paymentReference: (map['payment_reference'] as String?) ?? 'PLOGO',
      driverMarkedAt: _parseNullableDate(map['driver_marked_at']),
      ownerMarkedAt: _parseNullableDate(map['owner_marked_at']),
    );
  }
}

BookingPaymentStatus _statusFromText(String text) {
  switch (text) {
    case 'in_progress':
      return BookingPaymentStatus.inProgress;
    case 'to_pay':
      return BookingPaymentStatus.toPay;
    case 'driver_marked':
      return BookingPaymentStatus.driverMarked;
    case 'paid':
      return BookingPaymentStatus.paid;
    case 'upcoming':
    default:
      return BookingPaymentStatus.upcoming;
  }
}

DateTime _parseDate(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value).toLocal();
  }
  return DateTime.now().toLocal();
}

DateTime? _parseNullableDate(dynamic value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.parse(value).toLocal();
  }
  return null;
}

double? _parseDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String && value.isNotEmpty) {
    final parsed = double.tryParse(value);
    return parsed;
  }
  return null;
}

String _joinClean(List<String?> values, {String separator = ' · '}) {
  return values
      .where((value) => value != null && value!.isNotEmpty)
      .map((value) => value!.trim())
      .where((value) => value.isNotEmpty)
      .join(separator);
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');
