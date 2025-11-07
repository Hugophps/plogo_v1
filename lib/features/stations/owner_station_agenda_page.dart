import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_timezone.dart';
import '../../core/supabase_bootstrap.dart';
import '../profile/models/profile.dart';
import '../profile/profile_repository.dart';
import 'driver_station_booking_page.dart';
import 'member_slot_details_page.dart';
import 'models/station.dart';
import 'models/station_recurring_rule.dart';
import 'models/station_slot.dart';
import 'owner_block_slot_page.dart';
import 'recurring_unavailability_page.dart';
import 'station_repository.dart';
import 'station_slots_repository.dart';

enum StationAgendaViewer { owner, member }

const double _timeColumnWidth = 60;
const double _eventHorizontalPadding = 6;

class OwnerStationAgendaPage extends StatefulWidget {
  const OwnerStationAgendaPage({
    super.key,
    required this.station,
    this.viewer = StationAgendaViewer.owner,
    this.viewerProfile,
    this.membershipId,
  });

  final Station station;
  final StationAgendaViewer viewer;
  final Profile? viewerProfile;
  final String? membershipId;

  @override
  State<OwnerStationAgendaPage> createState() => _OwnerStationAgendaPageState();
}

class _OwnerStationAgendaPageState extends State<OwnerStationAgendaPage> {
  final _slotsRepository = const StationSlotsRepository();
  final _stationRepository = const StationRepository();
  final _profileRepository = const ProfileRepository();

  late Station _station;
  late tz.TZDateTime _weekStart;
  late tz.TZDateTime _weekEnd;

  bool _loading = false;
  String? _error;
  List<StationSlot> _slots = const [];

  bool get _isOwnerViewer => widget.viewer == StationAgendaViewer.owner;
  bool get _hasMemberContext =>
      widget.viewerProfile != null && widget.membershipId != null;
  Color get _accentColor =>
      _isOwnerViewer ? const Color(0xFFFFB347) : const Color(0xFF2C75FF);
  Color get _accentForeground =>
      _isOwnerViewer ? Colors.black : Colors.white;
  String get _primaryButtonLabel =>
      _isOwnerViewer ? 'Bloquer un cr\u00e9neau' : 'R\u00e9server un cr\u00e9neau';
  String? _currentProfileId;

  @override
  void initState() {
    super.initState();
    _station = widget.station;
    _currentProfileId = supabase.auth.currentUser?.id;
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
        stationId: _station.id,
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
          slot: slot,
        ),
      );
    }
    final recurringRules = _resolveRecurringRules(_station);
    items.addAll(_rulesToEntries(recurringRules));
    return items;
  }

  List<StationRecurringRule> _resolveRecurringRules(Station station) {
    final grouped = <int, List<StationRecurringRule>>{};
    for (final rule in station.recurringRules) {
      grouped.putIfAbsent(rule.weekday, () => []).add(rule);
    }

    final resolved = <StationRecurringRule>[];
    for (var day = DateTime.monday; day <= DateTime.sunday; day++) {
      final daily = grouped[day];
      if (daily == null || daily.isEmpty) {
        resolved.addAll(_defaultRecurringRulesForDay(day));
      } else {
        final sorted = [...daily]
          ..sort((a, b) => _compareTimeStrings(a.startTime, b.startTime));
        resolved.addAll(sorted);
      }
    }
    return resolved;
  }

  List<StationRecurringRule> _defaultRecurringRulesForDay(int weekday) {
    return [
      StationRecurringRule(
        weekday: weekday,
        startTime: '00:00',
        endTime: '08:00',
      ),
      StationRecurringRule(
        weekday: weekday,
        startTime: '22:00',
        endTime: '24:00',
      ),
    ];
  }

  int _compareTimeStrings(String a, String b) {
    return _timeStringToMinutes(a).compareTo(_timeStringToMinutes(b));
  }

  int _timeStringToMinutes(String time) {
    if (time == '24:00') return 24 * 60;
    final parts = time.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    return (hours * 60) + minutes;
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
          slot: null,
        ),
      );
    }
    return entries;
  }

  (int, int) _parseTime(String value) {
    if (value == '24:00') return (24, 0);
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

    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(_station);
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          backgroundColor: _accentColor,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'Agenda de la borne',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_station),
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
                        final availableHeight = constraints.maxHeight;
                        final rowHeight = math.max(availableHeight - 1, 0).toDouble();
                        final hourHeight = rowHeight / 24;
                        final gridWidth =
                            math.max(constraints.maxWidth - _timeColumnWidth, 0);
                        final columnWidth = gridWidth / 7;
                        final segments = _buildSegments(entries);

                        return SizedBox(
                          height: rowHeight,
                          width: constraints.maxWidth,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: _timeColumnWidth,
                                child: _buildTimeColumn(hourHeight),
                              ),
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: CustomPaint(
                                        painter: _AgendaGridPainter(
                                          columnCount: 7,
                                          hourHeight: hourHeight,
                                        ),
                                      ),
                                    ),
                                    if (_loading)
                                      const Positioned.fill(
                                        child: IgnorePointer(
                                          child: Center(
                                            child: CircularProgressIndicator(),
                                          ),
                                        ),
                                      ),
                                    ...segments.map(
                                      (segment) => _buildEventSegment(
                                        segment,
                                        columnWidth,
                                        hourHeight,
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
                      backgroundColor: _accentColor,
                      foregroundColor: _accentForeground,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isOwnerViewer
                        ? _openOwnerBlockForm
                        : (_hasMemberContext ? _openMemberBookingForm : null),
                    child: Text(
                      _primaryButtonLabel,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                if (_isOwnerViewer) ...[
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: _accentColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.more_horiz),
                      color: _accentForeground,
                      onPressed: _openRecurringManagement,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
  }

  Widget _buildTimeColumn(double hourHeight) {
    final labels = List<String>.generate(
      24,
      (index) => '${index.toString().padLeft(2, '0')}:00',
    );

    return Stack(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: labels.length,
          itemBuilder: (context, index) {
            return SizedBox(
              height: hourHeight,
              child: Align(
                alignment: Alignment.topRight,
                child: Text(
                  labels[index],
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        ),
        Align(
          alignment: Alignment.bottomRight,
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
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columnWidth = constraints.maxWidth / 7;
                return Row(
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

                    return SizedBox(
                      width: columnWidth,
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
                );
              },
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
              slot: entry.slot,
            ),
          );
        }

        currentStart = segmentEnd;
      }
    }
    return segments;
  }

  Widget _buildEventSegment(
    _AgendaSegment segment,
    double columnWidth,
    double hourHeight,
  ) {
    final double top = (segment.startMinutes / 60) * hourHeight;
    final double height = math
        .max(
          ((segment.endMinutes - segment.startMinutes) / 60) * hourHeight,
          10,
        )
        .toDouble();
    final double left =
        segment.dayIndex * columnWidth + _eventHorizontalPadding;
    final double width =
        math.max(columnWidth - (_eventHorizontalPadding * 2), 0);

    final slot = segment.slot;
    final isMemberBooking = segment.type == StationSlotType.memberBooking;
    final isOwnerBlock = segment.type == StationSlotType.ownerBlock;
    final isOwnMemberSlot =
        isMemberBooking && slot?.createdBy != null && slot!.createdBy == _currentProfileId;

    Color background;
    Color borderColor = Colors.transparent;
    double borderWidth = 1;

    if (segment.type == StationSlotType.recurringUnavailability) {
      background = _greyRecurringColor;
    } else if (isOwnerBlock) {
      background = const Color(0xFFFFE2BF);
      borderColor = const Color(0xFFB96500);
      borderWidth = 1.5;
    } else if (isMemberBooking) {
      background = isOwnMemberSlot
          ? const Color(0xFFD2E1FF)
          : const Color(0xFFF8FAFF);
      borderColor = const Color(0xFF2C75FF);
      borderWidth = 1.2;
    } else {
      background = segment.color;
      borderColor = segment.color;
    }

    if (segment.isDerived) {
      background = background.withOpacity(0.6);
    }

    final showTimeLabel =
        (isOwnerBlock || isMemberBooking) && slot != null;

    final child = Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      alignment: Alignment.topLeft,
      child: showTimeLabel
          ? Text(
              '${_shortTime(slot!.startAt)} - ${_shortTime(slot.endAt)}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: borderColor,
              ),
            )
          : const SizedBox.shrink(),
    );

    Widget current = child;
    VoidCallback? onTap;
    if (slot != null) {
      if (_isOwnerViewer) {
        if (isOwnerBlock) {
          onTap = () => _openOwnerBlockForm(slot: slot);
        } else if (isMemberBooking) {
          onTap = () => _openMemberSlotDetails(slot);
        }
      } else if (isMemberBooking && isOwnMemberSlot) {
        onTap = () => _openMemberBookingForm(slot: slot);
      }
    }

    if (onTap != null) {
      current = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: child,
      );
    }

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: current,
    );
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _shortTime(DateTime? date) {
    if (date == null) return '';
    final local = brusselsFromUtc(date.toUtc());
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return local.minute == 0 ? '${hour}h' : '${hour}h$minute';
  }

  Future<void> _openOwnerBlockForm({StationSlot? slot}) async {
    final station = _station;
    if (station == null) return;
    final now = nowInBrussels();
    final initialDate = slot != null
        ? brusselsFromUtc(slot.startAt.toUtc())
        : (_weekStart.isBefore(now) ? now : _weekStart);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OwnerBlockSlotPage(
          station: station,
          repository: _slotsRepository,
          slot: slot,
          initialDate: initialDate,
        ),
      ),
    );
    if (result == true) {
      await _loadSlots();
    }
  }

  Future<void> _openMemberBookingForm({StationSlot? slot}) async {
    if (!_hasMemberContext) {
      _showMissingMemberContext();
      return;
    }
    final station = _station;
    final initialDate = slot != null
        ? brusselsFromUtc(slot.startAt.toUtc())
        : (_weekStart.isBefore(nowInBrussels()) ? nowInBrussels() : _weekStart);
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => DriverStationBookingPage(
          station: station,
          repository: _slotsRepository,
          slot: slot,
          initialDate: initialDate,
          profile: widget.viewerProfile!,
          membershipId: widget.membershipId!,
        ),
      ),
    );
    if (result == true) {
      await _loadSlots();
    }
  }

  void _showMissingMemberContext() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profil membre indisponible pour cette action.'),
      ),
    );
  }

  Future<void> _openMemberSlotDetails(StationSlot slot) async {
    final profileId = slot.createdBy;
    if (profileId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil du membre introuvable.')),
      );
      return;
    }
    try {
      final profile = await _profileRepository.fetchProfileById(profileId);
      if (!mounted) return;
      if (profile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil du membre introuvable.')),
        );
        return;
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MemberSlotDetailsPage(
            slot: slot,
            profile: profile,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\u2019ouvrir ce cr\u00e9neau.')),
      );
    }
  }

  Future<void> _openRecurringManagement() async {
    final result = await Navigator.of(context).push<Station>(
      MaterialPageRoute(
        builder: (_) => RecurringUnavailabilityPage(
          station: _station,
          onSave: (rules) async {
            final updated = await _stationRepository.updateStation(
              _station.id,
              {
                'recurring_rules': rules.map((rule) => rule.toMap()).toList(),
              },
            );
            return updated;
          },
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _station = result;
      });
      await _loadSlots();
    }
  }
}

class StationAgendaEntry {
  const StationAgendaEntry({
    required this.start,
    required this.end,
    required this.color,
    required this.type,
    required this.isDerived,
    this.slot,
  });

  final DateTime start;
  final DateTime end;
  final Color color;
  final StationSlotType type;
  final bool isDerived;
  final StationSlot? slot;
}

class _AgendaSegment {
  _AgendaSegment({
    required this.dayIndex,
    required this.startMinutes,
    required this.endMinutes,
    required this.type,
    required this.isDerived,
    required this.color,
    this.slot,
  });

  final int dayIndex;
  final double startMinutes;
  final double endMinutes;
  final StationSlotType type;
  final bool isDerived;
  final Color color;
  final StationSlot? slot;
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

const _greyRecurringColor = Color(0xFFD1D6E2);





