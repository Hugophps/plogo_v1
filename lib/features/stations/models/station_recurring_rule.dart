class StationRecurringRule {
  const StationRecurringRule({
    required this.weekday,
    required this.startTime,
    required this.endTime,
  })  : assert(weekday >= DateTime.monday && weekday <= DateTime.sunday),
        assert(startTime.length == 5),
        assert(endTime.length == 5);

  /// ISO weekday index, Monday = 1, Sunday = 7.
  final int weekday;

  /// Heure de début au format 24h `HH:mm`.
  final String startTime;

  /// Heure de fin au format 24h `HH:mm`.
  final String endTime;

  Map<String, dynamic> toMap() {
    return {
      'weekday': weekday,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  static StationRecurringRule? tryParse(Map<String, dynamic> map) {
    final weekday = map['weekday'];
    final start = map['start_time'];
    final end = map['end_time'];

    if (weekday is! int || start is! String || end is! String) {
      return null;
    }

    return StationRecurringRule(
      weekday: weekday,
      startTime: start,
      endTime: end,
    );
  }

  factory StationRecurringRule.fromMap(Map<String, dynamic> map) {
    final rule = tryParse(map);
    if (rule == null) {
      throw ArgumentError('Règle récurrente invalide: $map');
    }
    return rule;
  }
}
