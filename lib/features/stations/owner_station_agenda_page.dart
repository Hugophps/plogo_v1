import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_timezone.dart';
import 'models/station.dart';
import 'models/station_recurring_rule.dart';
import 'models/station_slot.dart';
import 'station_slots_repository.dart';

const double _hourHeight = 64;
const double _timeColumnWidth = 60;
const double _eventHorizontalPadding = 6;

class OwnerStationAgendaPage extends StatefulWidget {
  const OwnerStationAgendaPage({super.key, required this.station});

  final Station station;

  @override
  State<OwnerStationAgendaPage> createState() => _OwnerStationAgendaPageState();
}

class _OwnerStationAgendaPageState extends State<OwnerStationAgendaPage> {
  final _slotsRepository = const StationSlotsRepository();

  late tz.TZDateTime _weekStart;
  late tz.TZDateTime _weekEnd;

  bool _loading = false;
  String? _error;
  List<StationSlot> _slots = const [];

  @override
  void initState() {
    super.initState();
    _weekStart = _startOfWeek(nowInBrussels());
    _weekEnd = _weekStart.add(const Duration(days: 7));
    _loadSlots();
  }

  tz.TZDateTime _startOfWeek(tz.TZDateTime date) {
    final difference = date.weekday - DateTime.monday;
    final monday = date.subtract(Duration(days: difference));
    return tz.TZDateTime(brusselsLocation, monday.year, monday.month, monday.day);
  }

  Future<void> _loadSlots() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final fetched = await _slotsRepository.fetchSlots(
        stationId: widget.station.id,
        rangeStart: _weekStart.toUtc(),
        rangeEnd: _weekEnd.toUtc(),
      );
      if (!mounted) return;
      setState(() {
        _slots = fetched;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Impossible de charger les cr\u00e9neaux.';
      });
    }
  }

  void _goToPreviousWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
      _weekEnd = _weekStart.add(const Duration(days: 7));
    });
    _loadSlots();
  }

  void _goToNextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
      _weekEnd = _weekStart.add(const Duration(days: 7));
    });
    _loadSlots();
  }

  String get _monthLabel {
    final endDay = _weekStart.add(const Duration(days: 6));
    if (_weekStart.month == endDay.month) {
      return _monthNamesFull[_weekStart.month - 1];
    }
    final first = _monthNamesShort[_weekStart.month - 1];
    final second = _monthNamesShort[endDay.month - 1];
    return '$first / $second';
  }

  List<StationAgendaEntry> get _entries {
    final items = <StationAgendaEntry>[];
    for (final slot in _slots) {
      final start = brusselsFromUtc(slot.startAt.toUtc());
      final end = brusselsFromUtc(slot.endAt.toUtc());
      items.add(
        StationAgendaEntry(
          start: start,
          end: end,
          color: _colorForType(slot.type),
          type: slot.type,
          isDerived: false,
        ),
      );
    }
    items.addAll(_rulesToEntries(widget.station.recurringRules));
    return items;
  }

  List<StationAgendaEntry> _rulesToEntries(
    List<StationRecurringRule> rules,
  ) {
    final dayMap = <int, tz.TZDateTime>{};
    for (var i = 0; i < 7; i++) {
      final day = _weekStart.add(Duration(days: i));
      dayMap[day.weekday] = day;
    }

    final entries = <StationAgendaEntry>[];
    for (final rule in rules) {
      final day = dayMap[rule.weekday];
      if (day == null) continue;
      final startTime = _parseTime(rule.startTime);
      final endTime = _parseTime(rule.endTime);

      var start = tz.TZDateTime(
        brusselsLocation,
        day.year,
        day.month,
        day.day,
        startTime.$1,
        startTime.$2,
      );
      var end = tz.TZDateTime(
        brusselsLocation,
        day.year,
        day.month,
        day.day,
        endTime.$1,
        endTime.$2,
      );

      if (!end.isAfter(start)) {
        end = end.add(const Duration(days: 1));
      }

      entries.add(
        StationAgendaEntry(
          start: start,
          end: end,
          color: _greyRecurringColor,
          type: StationSlotType.recurringUnavailability,
          isDerived: true,
        ),
      );
    }
    return entries;
  }

  (int, int) _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return (0, 0);
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return (hour.clamp(0, 23), minute.clamp(0, 59));
  }

  Color _colorForType(StationSlotType type) {
    switch (type) {
      case StationSlotType.recurringUnavailability:
        return _greyRecurringColor;
      case StationSlotType.ownerBlock:
        return const Color(0xFFFFB347);
      case StationSlotType.memberBooking:
        return const Color(0xFF2C75FF);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = _entries;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFB347),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          'Agenda de la borne',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(color: Colors.white),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  color: const Color(0xFF2C75FF),
                  onPressed: _loading ? null : _goToPreviousWeek,
                ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_weekStart.year}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _monthLabel,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  color: const Color(0xFF2C75FF),
                  onPressed: _loading ? null : _goToNextWeek,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
          if (_error != null)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Color(0xFFCC8400),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black87),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _loadSlots,
                        child: const Text('R\u00e9essayer'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  _buildWeekHeader(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final totalWidth = constraints.maxWidth;
                        return Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            child: SizedBox(
                              width: totalWidth,
                              height: _hourHeight * 24,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    width: _timeColumnWidth,
                                    child: _buildTimeColumn(),
                                  ),
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, gridConstraints) {
                                        final columnWidth =
                                            gridConstraints.maxWidth / 7;
                                        final segments =
                                            _buildSegments(entries);
                                        return Stack(
                                          children: [
                                            Positioned.fill(
                                              child: CustomPaint(
                                                painter: _AgendaGridPainter(
                                                  columnCount: 7,
                                                  hourHeight: _hourHeight,
                                                ),
                                              ),
                                            ),
                                            if (_loading)
                                              const Positioned.fill(
                                                child: IgnorePointer(
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                ),
                                              ),
                                            ...segments.map(
                                              (segment) =>
                                                  _buildEventSegment(
                                                segment,
                                                columnWidth,
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB347),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      // Navigation vers la creation d'un creneau ponctuel (a implementer plus tard).
                    },
                    child: const Text(
                      'Bloquer un cr\u00e9neau',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB347),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.more_horiz),
                    color: Colors.black87,
                    onPressed: () {
                      // Navigation vers la gestion des indisponibilites recurrentes a venir.
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn() {
    final labels = List<String>.generate(
      24,
      (index) => '${index.toString().padLeft(2, '0')}:00',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final label in labels)
          SizedBox(
            height: _hourHeight,
            child: Align(
              alignment: Alignment.topRight,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        Align(
          alignment: Alignment.topRight,
          child: Text(
            '24:00',
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekHeader() {
    final today = nowInBrussels();
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          const SizedBox(width: _timeColumnWidth),
          Expanded(
            child: Row(
              children: List.generate(7, (index) {
                final date = _weekStart.add(Duration(days: index));
                final isToday = _isSameDay(date, today);

                final numberStyle = TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isToday ? const Color(0xFF2C75FF) : Colors.black87,
                );

                final letterStyle = TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isToday ? const Color(0xFF2C75FF) : Colors.black54,
                );

                return Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${date.day}', style: numberStyle),
                      const SizedBox(height: 4),
                      Text(_dayLetters[date.weekday - 1], style: letterStyle),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  List<_AgendaSegment> _buildSegments(List<StationAgendaEntry> entries) {
    final segments = <_AgendaSegment>[];
    final weekEndExclusive = _weekStart.add(const Duration(days: 7));
    for (final entry in entries) {
      var currentStart = entry.start;
      final end = entry.end;

      if (end.isBefore(_weekStart) || currentStart.isAfter(weekEndExclusive)) {
        continue;
      }

      currentStart = currentStart.isBefore(_weekStart) ? _weekStart : currentStart;
      var remainingEnd = end.isAfter(weekEndExclusive) ? weekEndExclusive : end;

      while (currentStart.isBefore(remainingEnd)) {
        final dayStart = tz.TZDateTime(
          brusselsLocation,
          currentStart.year,
          currentStart.month,
          currentStart.day,
        );
        final nextDay = dayStart.add(const Duration(days: 1));
        final segmentEnd = remainingEnd.isBefore(nextDay) ? remainingEnd : nextDay;
        final dayIndex = dayStart.difference(_weekStart).inDays;

        if (dayIndex >= 0 && dayIndex < 7) {
          final startMinutes = currentStart.difference(dayStart).inMinutes.toDouble();
          final endMinutes = segmentEnd.difference(dayStart).inMinutes.toDouble();
          segments.add(
            _AgendaSegment(
              dayIndex: dayIndex,
              startMinutes: startMinutes,
              endMinutes: endMinutes,
              type: entry.type,
              isDerived: entry.isDerived,
              color: entry.color,
            ),
          );
        }

        currentStart = segmentEnd;
      }
    }
    return segments;
  }

  Widget _buildEventSegment(_AgendaSegment segment, double columnWidth) {
    final double top = (segment.startMinutes / 60) * _hourHeight;
    final double height = math
        .max(
          ((segment.endMinutes - segment.startMinutes) / 60) * _hourHeight,
          10,
        )
        .toDouble();
    final double left =
        segment.dayIndex * columnWidth + _eventHorizontalPadding;
    final double width = columnWidth - (_eventHorizontalPadding * 2);

    final baseColor = segment.color;
    final color = segment.isDerived ? baseColor.withOpacity(0.5) : baseColor;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class StationAgendaEntry {
  const StationAgendaEntry({
    required this.start,
    required this.end,
    required this.color,
    required this.type,
    required this.isDerived,
  });

  final DateTime start;
  final DateTime end;
  final Color color;
  final StationSlotType type;
  final bool isDerived;
}

class _AgendaSegment {
  _AgendaSegment({
    required this.dayIndex,
    required this.startMinutes,
    required this.endMinutes,
    required this.type,
    required this.isDerived,
    required this.color,
  });

  final int dayIndex;
  final double startMinutes;
  final double endMinutes;
  final StationSlotType type;
  final bool isDerived;
  final Color color;
}

class _AgendaGridPainter extends CustomPainter {
  _AgendaGridPainter({
    required this.columnCount,
    required this.hourHeight,
  });

  final int columnCount;
  final double hourHeight;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;

    for (var hour = 0; hour <= 24; hour++) {
      final y = hour * hourHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    final columnWidth = size.width / columnCount;
    for (var column = 0; column <= columnCount; column++) {
      final x = column * columnWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AgendaGridPainter oldDelegate) {
    return oldDelegate.columnCount != columnCount ||
        oldDelegate.hourHeight != hourHeight;
  }
}

const _monthNamesFull = [
  'Janvier',
  'F\u00e9vrier',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Ao\u00fbt',
  'Septembre',
  'Octobre',
  'Novembre',
  'D\u00e9cembre',
];

const _monthNamesShort = [
  'Jan.',
  'F\u00e9v.',
  'Mar.',
  'Avr.',
  'Mai',
  'Jun.',
  'Jul.',
  'Ao\u00fbt',
  'Sep.',
  'Oct.',
  'Nov.',
  'D\u00e9c.',
];

const _dayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

const _greyRecurringColor = Color(0xFFE6E9EF);
