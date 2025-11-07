import 'dart:math';

import 'package:flutter/material.dart';

import 'models/station.dart';
import 'models/station_recurring_rule.dart';

class RecurringUnavailabilityPage extends StatefulWidget {
  const RecurringUnavailabilityPage({
    super.key,
    required this.station,
    required this.onSave,
  });

  final Station station;
  final Future<Station> Function(List<StationRecurringRule>) onSave;

  @override
  State<RecurringUnavailabilityPage> createState() =>
      _RecurringUnavailabilityPageState();
}

class _RecurringUnavailabilityPageState
    extends State<RecurringUnavailabilityPage> {
  late final List<_DaySchedule> _schedules;
  bool _saving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _schedules = List.generate(7, (index) {
      final weekday = index + 1;
      final rules =
          widget.station.recurringRules.where((rule) => rule.weekday == weekday);
      late final List<_DayInterval> intervals;
      if (rules.isEmpty) {
        intervals = _defaultIntervals();
      } else {
        intervals = rules
            .map(
              (rule) => _DayInterval(
                startMinutes: _parseTime(rule.startTime),
                endMinutes: _parseTime(rule.endTime),
              ),
            )
            .toList()
          ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      }

      return _DaySchedule(
        weekday: weekday,
        intervals: intervals,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFB347),
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Indisponibilites recurrentes',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              color: const Color(0xFFFFF2E2),
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                _errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFCC8400),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: _schedules.length,
              itemBuilder: (context, index) {
                final schedule = _schedules[index];
                final isExpanded = schedule.expanded;
                return Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isExpanded ? const Color(0xFFF1F4FB) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        offset: Offset(0, 4),
                        blurRadius: 12,
                        color: Color.fromRGBO(0, 0, 0, 0.05),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          setState(() {
                            schedule.expanded = !schedule.expanded;
                          });
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 18,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _weekdayLabels[schedule.weekday]!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Icon(
                                schedule.expanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_right,
                                color: Colors.black54,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (schedule.expanded)
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Column(
                            children: [
                              ...schedule.intervals.asMap().entries.map(
                                (entry) {
                                  final intervalIndex = entry.key;
                                  final interval = entry.value;
                                  return Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                intervalIndex == 0
                                                    ? 'Bloque de'
                                                    : 'Et de',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: _TimeDropdown(
                                                      value: _formatMinutes(
                                                        interval.startMinutes,
                                                      ),
                                                      onChanged: (value) {
                                                        _onIntervalStartChanged(
                                                          schedule,
                                                          intervalIndex,
                                                          value,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: _TimeDropdown(
                                                      value: _formatMinutes(
                                                        interval.endMinutes,
                                                      ),
                                                      onChanged: (value) {
                                                        _onIntervalEndChanged(
                                                          schedule,
                                                          intervalIndex,
                                                          value,
                                                        );
                                                      },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        IconButton(
                                          icon: const Icon(Icons.close),
                                          color: Colors.black54,
                                          onPressed: () {
                                            setState(() {
                                              schedule.intervals
                                                  .removeAt(intervalIndex);
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(height: 4),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => _addInterval(schedule),
                                  icon: const Icon(Icons.add,
                                      color: Color(0xFF2C75FF)),
                                  label: const Text(
                                    'Ajouter un cr\\u00e9neau',
                                    style: TextStyle(
                                      color: Color(0xFF2C75FF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            color: Colors.white,
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C75FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Enregistrer',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onIntervalStartChanged(
    _DaySchedule schedule,
    int index,
    String? value,
  ) {
    if (value == null) return;
    final minutes = _parseTime(value);
    setState(() {
      final interval = schedule.intervals[index];
      final newStart = minutes.clamp(0, 1440).toInt();
      interval.startMinutes = newStart;
      if (interval.endMinutes <= newStart) {
        interval.endMinutes = min(newStart + 15, 1440).toInt();
      }
      schedule.intervals.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    });
  }

  void _onIntervalEndChanged(
    _DaySchedule schedule,
    int index,
    String? value,
  ) {
    if (value == null) return;
    final minutes = _parseTime(value);
    setState(() {
      final interval = schedule.intervals[index];
      var newEnd = minutes.clamp(0, 1440).toInt();
      if (newEnd <= interval.startMinutes) {
        newEnd = min(interval.startMinutes + 15, 1440).toInt();
      }
      interval.endMinutes = newEnd;
      schedule.intervals.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    });
  }

  void _addInterval(_DaySchedule schedule) {
    final proposed = _findNextGap(schedule.intervals);
    if (proposed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun creneau supplementaire disponible ce jour-la.'),
        ),
      );
      return;
    }
    setState(() {
      schedule.intervals.add(proposed);
      schedule.intervals.sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    });
  }

  _DayInterval? _findNextGap(List<_DayInterval> intervals) {
    for (final targetDuration in const [60, 30, 15]) {
      final gap = _findGapWithDuration(intervals, targetDuration);
      if (gap != null) return gap;
    }
    return null;
  }

  _DayInterval? _findGapWithDuration(
    List<_DayInterval> intervals,
    int durationMinutes,
  ) {
    final sorted = [...intervals]
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    var cursor = 0;
    for (final interval in sorted) {
      if (cursor + durationMinutes <= interval.startMinutes) {
        return _DayInterval(
          startMinutes: cursor,
          endMinutes: cursor + durationMinutes,
        );
      }
      cursor = max(cursor, interval.endMinutes);
    }
    if (cursor + durationMinutes <= 1440) {
      return _DayInterval(
        startMinutes: cursor,
        endMinutes: cursor + durationMinutes,
      );
    }
    return null;
  }

  Future<void> _submit() async {
    final validation = _validate();
    if (validation != null) {
      setState(() => _errorMessage = validation);
      return;
    }

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    final rules = <StationRecurringRule>[];
    for (final schedule in _schedules) {
      for (final interval in schedule.intervals) {
        rules.add(
          StationRecurringRule(
            weekday: schedule.weekday,
            startTime: _formatMinutes(interval.startMinutes),
            endTime: _formatMinutes(interval.endMinutes),
          ),
        );
      }
    }

    try {
      final updatedStation = await widget.onSave(rules);
      if (!mounted) return;
      Navigator.of(context).pop(updatedStation);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _errorMessage = 'Impossible d’enregistrer les indisponibilités. Réessayez.';
        _errorMessage = 'Impossible denregistrer les indisponibilites. Reessayez.';
      });
    }
  }

  String? _validate() {
    for (final schedule in _schedules) {
      final sorted = [...schedule.intervals]
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
      for (var i = 0; i < sorted.length; i++) {
        final current = sorted[i];
        if (current.endMinutes <= current.startMinutes) {
          return 'Les horaires doivent être supérieurs aux heures de début pour ${_weekdayLabels[schedule.weekday]!.toLowerCase()}.';
        }
        if (i > 0) {
          final previous = sorted[i - 1];
          if (previous.endMinutes > current.startMinutes) {
            return 'Les créneaux ne peuvent pas se chevaucher pour ${_weekdayLabels[schedule.weekday]!.toLowerCase()}.';
          }
        }
      }
    }
    return null;
  }
}

class _DaySchedule {
  _DaySchedule({
    required this.weekday,
    required this.intervals,
    this.expanded = false,
  });

  final int weekday;
  final List<_DayInterval> intervals;
  bool expanded;
}

class _DayInterval {
  _DayInterval({
    required this.startMinutes,
    required this.endMinutes,
  });

  int startMinutes;
  int endMinutes;
}

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      items: _timeOptions
          .map(
            (time) => DropdownMenuItem<String>(
              value: time,
              child: Text(time),
            ),
          )
          .toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E3EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E3EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2C75FF)),
        ),
      ),
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.black54),
      style: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      dropdownColor: Colors.white,
    );
  }
}

List<_DayInterval> _defaultIntervals() {
  return [
    _DayInterval(startMinutes: 0, endMinutes: 8 * 60),
    _DayInterval(startMinutes: 22 * 60, endMinutes: 24 * 60),
  ];
}

int _parseTime(String value) {
  if (value == '24:00') return 24 * 60;
  final parts = value.split(':');
  final hours = int.tryParse(parts.first) ?? 0;
  final minutes = int.tryParse(parts.last) ?? 0;
  return (hours * 60) + minutes;
}

String _formatMinutes(int minutes) {
  final clamped = minutes.clamp(0, 1440).toInt();
  if (clamped == 1440) return '24:00';
  final hours = (clamped ~/ 60).toString().padLeft(2, '0');
  final mins = (clamped % 60).toString().padLeft(2, '0');
  return '$hours:$mins';
}

final Map<int, String> _weekdayLabels = {
  DateTime.monday: 'Lundi',
  DateTime.tuesday: 'Mardi',
  DateTime.wednesday: 'Mercredi',
  DateTime.thursday: 'Jeudi',
  DateTime.friday: 'Vendredi',
  DateTime.saturday: 'Samedi',
  DateTime.sunday: 'Dimanche',
};

final List<String> _timeOptions = List<String>.generate(
  97,
  (index) {
    final minutes = index * 15;
    final hours = (minutes ~/ 60).toString().padLeft(2, '0');
    final mins = (minutes % 60).toString().padLeft(2, '0');
    return '$hours:$mins';
  },
);
















