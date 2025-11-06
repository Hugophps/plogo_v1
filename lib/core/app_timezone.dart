import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

const _brusselsZoneId = 'Europe/Brussels';

late final tz.Location brusselsLocation;

Future<void> initAppTimezone() async {
  tz.initializeTimeZones();
  brusselsLocation = tz.getLocation(_brusselsZoneId);
}

tz.TZDateTime nowInBrussels() => tz.TZDateTime.now(brusselsLocation);

tz.TZDateTime brusselsFromUtc(DateTime utcDateTime) {
  if (!utcDateTime.isUtc) {
    throw ArgumentError('La date doit être en UTC pour la conversion.');
  }
  return tz.TZDateTime.from(utcDateTime, brusselsLocation);
}

DateTime brusselsToUtc(DateTime brusselsDateTime) {
  if (brusselsDateTime.isUtc) return brusselsDateTime;
  if (brusselsDateTime is tz.TZDateTime) {
    return brusselsDateTime.toUtc();
  }
  return tz.TZDateTime.from(brusselsDateTime, brusselsLocation).toUtc();
}
