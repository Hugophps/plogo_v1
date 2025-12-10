import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../core/app_timezone.dart';
import '../profile/models/profile.dart';
import 'models/station.dart';
import 'models/station_slot.dart';
import 'station_slots_repository.dart';

enum StationSlotEditorMode { ownerBlock, memberBooking }

class OwnerBlockSlotPage extends StatefulWidget {
  const OwnerBlockSlotPage({
    super.key,
    required this.station,
    required this.repository,
    this.slot,
    this.initialDate,
    this.mode = StationSlotEditorMode.ownerBlock,
    this.memberProfile,
    this.membershipId,
  });

  final Station station;
  final StationSlotsRepository repository;
  final StationSlot? slot;
  final tz.TZDateTime? initialDate;
  final StationSlotEditorMode mode;
  final Profile? memberProfile;
  final String? membershipId;

  bool get isEditing => slot != null;
  bool get isMemberBooking => mode == StationSlotEditorMode.memberBooking;

  @override
  State<OwnerBlockSlotPage> createState() => _OwnerBlockSlotPageState();
}

class _OwnerBlockSlotPageState extends State<OwnerBlockSlotPage> {
  late tz.TZDateTime _selectedDate;
  late String _startTime;
  late String _endTime;
  bool _loadingDay = false;
  bool _saving = false;
  String? _error;
  List<StationSlot> _daySlots = const [];
  List<_DayInterval> _availableIntervals = const [];
  List<String> _startOptions = const [];
  List<String> _endOptions = const [];

  Color get _accentColor => widget.isMemberBooking
      ? const Color(0xFF2C75FF)
      : const Color(0xFFFFB347);
  Color get _accentForeground =>
      widget.isMemberBooking ? Colors.white : Colors.black;
  String get _pageTitle => widget.isMemberBooking
      ? (widget.isEditing
            ? "Modifier ce créneau"
            : "Choisir un créneau")
      : (widget.isEditing
            ? "Modifier ce créneau"
            : "Bloquer un créneau");
  String get _primaryButtonLabel => widget.isMemberBooking
      ? (widget.isEditing
            ? 'Enregistrer les modifications'
            : "Réserver ce créneau")
      : (widget.isEditing
            ? 'Enregistrer les modifications'
            : "Bloquer ce créneau");
  String get _submitErrorText => widget.isMemberBooking
      ? "Impossible d\u2019enregistrer la réservation."
      : "Impossible d\u2019enregistrer le créneau.";
  String get _deleteErrorText => widget.isMemberBooking
      ? "Impossible d\u2019annuler ce créneau."
      : "Impossible d\u2019annuler ce créneau.";
  Color get _secondaryButtonColor => widget.isMemberBooking
      ? const Color(0xFF2C75FF)
      : const Color(0xFFFF6B6B);
  bool get _isPastSlot =>
      widget.slot != null &&
      !widget.slot!.endAt.toUtc().isAfter(DateTime.now().toUtc());

  @override
  void initState() {
    super.initState();
    _seedInitialValues();
    _loadDaySlots();
  }

  void _seedInitialValues() {
    final slot = widget.slot;
    if (slot != null) {
      final start = brusselsFromUtc(slot.startAt.toUtc());
      final end = brusselsFromUtc(slot.endAt.toUtc());
      _selectedDate = tz.TZDateTime(
        brusselsLocation,
        start.year,
        start.month,
        start.day,
      );
      _startTime = _formatMinutes(_minutesWithinSelectedDay(start));
      final endMinutes = _minutesWithinSelectedDay(end);
      _endTime = _formatMinutes(endMinutes == 0 ? 24 * 60 : endMinutes);
      return;
    }

    final initial = widget.initialDate ?? nowInBrussels();
    final dayStart = tz.TZDateTime(
      brusselsLocation,
      initial.year,
      initial.month,
      initial.day,
    );
    final baseline = initial.isBefore(dayStart) ? dayStart : initial;
    final roundedMinutes = _roundToQuarter(
      baseline.hour * 60 + baseline.minute,
    );
    _selectedDate = dayStart;
    _startTime = _formatMinutes(roundedMinutes.clamp(0, 23 * 60 + 45));
    _endTime = _formatMinutes(
      (_minutesFromTime(_startTime) + 30).clamp(15, 24 * 60),
    );
  }

  Future<void> _loadDaySlots() async {
    setState(() => _loadingDay = true);
    final dayStart = tz.TZDateTime(
      brusselsLocation,
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final dayEnd = dayStart.add(const Duration(days: 1));
    try {
      final slots = await widget.repository.fetchSlots(
        stationId: widget.station.id,
        rangeStart: dayStart.toUtc(),
        rangeEnd: dayEnd.toUtc(),
      );
      if (!mounted) return;
      setState(() {
        _daySlots = slots;
        _loadingDay = false;
      });
      _rebuildAvailability();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _daySlots = const [];
        _loadingDay = false;
        _error = "Impossible de charger les créneaux existants.";
      });
      _rebuildAvailability();
    }
  }

  void _rebuildAvailability() {
    final recurring = _recurringIntervalsForWeekday(_selectedDate.weekday);
    final dayIntervals = _mergeIntervals([
      ...recurring,
      ..._daySlots.where((slot) => widget.slot?.id != slot.id).map((slot) {
        final startLocal = brusselsFromUtc(slot.startAt.toUtc());
        final endLocal = brusselsFromUtc(slot.endAt.toUtc());
        return _DayInterval(
          startMinutes: _minutesWithinSelectedDay(startLocal),
          endMinutes: _minutesWithinSelectedDay(endLocal),
        );
      }),
    ]);

    final freeIntervals = _invertIntervals(dayIntervals);
    final options = <String>[];
    for (final interval in freeIntervals) {
      for (
        var minute = interval.startMinutes;
        minute < interval.endMinutes;
        minute += 15
      ) {
        options.add(_formatMinutes(minute));
      }
    }

    final startOptions = options;

    if (startOptions.isEmpty) {
      setState(() {
        _availableIntervals = freeIntervals;
        _startOptions = const [];
        _endOptions = const [];
        _startTime = '00:00';
        _endTime = '00:00';
        _error = "Aucun créneau disponible ce jour-là.";
      });
      return;
    }

    var startValue = _startTime;
    if (!startOptions.contains(startValue)) {
      final preferredMinutes = _preferredStartMinutes();
      if (preferredMinutes != null) {
        final preferredOption = startOptions.firstWhere(
          (option) => _minutesFromTime(option) >= preferredMinutes,
          orElse: () => startOptions.last,
        );
        startValue = preferredOption;
      } else {
        startValue = startOptions.first;
      }
    }

    final newEndOptions = _buildEndOptionsForStart(
      startValue,
      intervals: freeIntervals,
    );
    var endValue = _endTime;
    if (!newEndOptions.contains(endValue)) {
      endValue = newEndOptions.isNotEmpty ? newEndOptions.first : startValue;
    }

    setState(() {
      _availableIntervals = freeIntervals;
      _startOptions = startOptions;
      _endOptions = newEndOptions;
      _startTime = startValue;
      _endTime = endValue;
      _error = null;
    });
  }

  List<_DayInterval> _mergeIntervals(List<_DayInterval> intervals) {
    if (intervals.isEmpty) return [];
    final sorted = [...intervals]
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    final merged = <_DayInterval>[sorted.first];
    for (final interval in sorted.skip(1)) {
      final last = merged.last;
      if (interval.startMinutes <= last.endMinutes) {
        merged[merged.length - 1] = _DayInterval(
          startMinutes: last.startMinutes,
          endMinutes: math.max(last.endMinutes, interval.endMinutes),
        );
      } else {
        merged.add(interval);
      }
    }
    return merged;
  }

  List<_DayInterval> _invertIntervals(List<_DayInterval> intervals) {
    final result = <_DayInterval>[];
    var cursor = 0;
    for (final interval in intervals) {
      if (interval.startMinutes > cursor) {
        result.add(
          _DayInterval(startMinutes: cursor, endMinutes: interval.startMinutes),
        );
      }
      cursor = math.max(cursor, interval.endMinutes);
    }
    if (cursor < 24 * 60) {
      result.add(_DayInterval(startMinutes: cursor, endMinutes: 24 * 60));
    }
    return result;
  }

  List<String> _buildEndOptionsForStart(
    String startValue, {
    List<_DayInterval>? intervals,
  }) {
    final source = intervals ?? _availableIntervals;
    final startMinutes = _minutesFromTime(startValue);
    final interval = source.firstWhere(
      (element) =>
          startMinutes >= element.startMinutes &&
          startMinutes < element.endMinutes,
      orElse: () =>
          _DayInterval(startMinutes: startMinutes, endMinutes: startMinutes),
    );
    final options = <String>[];
    for (
      var minute = math.max(startMinutes + 15, interval.startMinutes + 15);
      minute <= interval.endMinutes;
      minute += 15
    ) {
      options.add(_formatMinutes(minute));
    }
    return options;
  }

  int _minutesWithinSelectedDay(tz.TZDateTime date) {
    final dayStart = tz.TZDateTime(
      brusselsLocation,
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final diff = date.difference(dayStart).inMinutes;
    return diff.clamp(0, 24 * 60);
  }

  void _handleStartChanged(String value) {
    final newEndOptions = _buildEndOptionsForStart(value);
    var nextEndTime = _endTime;
    if (!newEndOptions.contains(nextEndTime)) {
      nextEndTime = newEndOptions.isNotEmpty ? newEndOptions.first : value;
    }
    setState(() {
      _startTime = value;
      _endOptions = newEndOptions;
      _endTime = nextEndTime;
      _error = null;
    });
  }

  int? _preferredStartMinutes() {
    final now = nowInBrussels();
    final sameDay = now.year == _selectedDate.year &&
        now.month == _selectedDate.month &&
        now.day == _selectedDate.day;
    if (!sameDay) return null;
    return _roundToQuarter(_minutesFromDate(now));
  }

  Future<void> _pickDate() async {
    final initial = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(today) ? today : initial,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      locale: const Locale('fr'),
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = tz.TZDateTime(
        brusselsLocation,
        picked.year,
        picked.month,
        picked.day,
      );
      _error = null;
    });
    await _loadDaySlots();
  }

  Future<void> _saveSlot() async {
    if (_isPastSlot) {
      setState(() {
        _error = "Ce créneau est déjà terminé. Modification impossible.";
      });
      return;
    }
    final interval = _computeInterval();
    final validation = _validateInterval(interval.start, interval.end);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (widget.isEditing) {
        await widget.repository.updateSlot(
          slotId: widget.slot!.id,
          startAt: interval.start,
          endAt: interval.end,
        );
      } else if (widget.isMemberBooking) {
        final profile = widget.memberProfile;
        final membershipId = widget.membershipId;
        if (profile == null || membershipId == null) {
          throw Exception('Profil membre introuvable');
        }
        await widget.repository.createMemberBooking(
          stationId: widget.station.id,
          startAt: interval.start,
          endAt: interval.end,
          metadata: _buildMemberMetadata(profile, membershipId),
        );
      } else {
        await widget.repository.createOwnerBlock(
          stationId: widget.station.id,
          startAt: interval.start,
          endAt: interval.end,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _submitErrorText;
      });
    }
  }

  Future<void> _deleteSlot() async {
    final slot = widget.slot;
    if (slot == null) return;
    if (_isPastSlot) {
      setState(() {
        _error = "Impossible d'annuler un créneau passé.";
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.deleteSlot(slot.id);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _deleteErrorText;
      });
    }
  }

  _UtcInterval _computeInterval() {
    final startMinutes = _minutesFromTime(_startTime);
    final endMinutes = _minutesFromTime(_endTime);
    final start = tz.TZDateTime(
      brusselsLocation,
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      startMinutes ~/ 60,
      startMinutes % 60,
    );
    final endBase = endMinutes >= 24 * 60
        ? _selectedDate.add(const Duration(days: 1))
        : _selectedDate;
    final end = tz.TZDateTime(
      brusselsLocation,
      endBase.year,
      endBase.month,
      endBase.day,
      (endMinutes % (24 * 60)) ~/ 60,
      (endMinutes % 60),
    );

    return _UtcInterval(start.toUtc(), end.toUtc());
  }

  String? _validateInterval(DateTime startUtc, DateTime endUtc) {
    final start = tz.TZDateTime.from(startUtc, brusselsLocation);
    final end = tz.TZDateTime.from(endUtc, brusselsLocation);
    if (!end.isAfter(start)) {
      return "L'heure de fin doit être postérieure au début.";
    }

    final recurring = _recurringIntervalsForWeekday(_selectedDate.weekday);
    for (final interval in recurring) {
      final ruleStart = _selectedDate.add(
        Duration(minutes: interval.startMinutes),
      );
      final ruleEnd = _selectedDate.add(Duration(minutes: interval.endMinutes));
      if (_overlaps(start, end, ruleStart, ruleEnd)) {
        return "Ce créneau chevauche une indisponibilité récurente.";
      }
    }

    for (final slot in _daySlots) {
      if (widget.slot?.id == slot.id) continue;
      final slotStart = brusselsFromUtc(slot.startAt.toUtc());
      final slotEnd = brusselsFromUtc(slot.endAt.toUtc());
      if (_overlaps(start, end, slotStart, slotEnd)) {
        return "Ce créneau chevauche un autre créneau.";
      }
    }

    return null;
  }

  Map<String, dynamic> _buildMemberMetadata(
    Profile profile,
    String membershipId,
  ) {
    final data = <String, dynamic>{
      'membership_id': membershipId,
      'profile_id': profile.id,
      'profile_name': profile.fullName,
      'profile_phone': profile.phoneNumber,
      'vehicle_brand': profile.vehicleBrand,
      'vehicle_model': profile.vehicleModel,
      'vehicle_plate': profile.vehiclePlate,
    };
    data.removeWhere(
      (_, value) => value == null || (value is String && value.trim().isEmpty),
    );
    return data;
  }

  String get _durationLabel {
    final start = _minutesFromTime(_startTime);
    final end = _minutesFromTime(_endTime);
    final minutes = (end - start).clamp(0, 24 * 60);
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours == 0) return '${mins.toString().padLeft(2, '0')} min';
    if (mins == 0) return '${hours}h';
    return '${hours}h ${mins.toString().padLeft(2, '0')}';
  }

  List<_DayInterval> _recurringIntervalsForWeekday(int weekday) {
    final rules = widget.station.recurringRules
        .where((rule) => rule.weekday == weekday)
        .toList();
    if (rules.isEmpty) {
      return [
        _DayInterval(startMinutes: 0, endMinutes: 8 * 60),
        _DayInterval(startMinutes: 22 * 60, endMinutes: 24 * 60),
      ];
    }
    return rules
        .map(
          (rule) => _DayInterval(
            startMinutes: _minutesFromTime(rule.startTime),
            endMinutes: _minutesFromTime(rule.endTime),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.isEditing;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        backgroundColor: _accentColor,
        foregroundColor: Colors.white,
        title: Text(_pageTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StationHeader(station: widget.station),
            const SizedBox(height: 24),
            _DateField(
              label: 'Date',
              value: _formatDate(_selectedDate),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _TimeDropdown(
                    label: "Heure de début",
                    value: _startTime,
                    options: _startOptions,
                    enabled: _startOptions.isNotEmpty,
                    onChanged: (value) {
                      if (value == null) return;
                      _handleStartChanged(value);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeDropdown(
                    label: 'Heure de fin',
                    value: _endTime,
                    options: _endOptions,
                    enabled: _endOptions.isNotEmpty,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _endTime = value;
                        _error = null;
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: _accentColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Durée totale",
                    style: TextStyle(
                      color: _accentForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _durationLabel,
                    style: TextStyle(
                      color: _accentForeground,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingDay)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            if (_isPastSlot)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  "Ce créneau est déjà terminé. Les actions sont desactivées.",
                  style: TextStyle(
                    color: Colors.black54,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving || _isPastSlot ? null : _saveSlot,
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: _accentForeground,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _saving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _accentForeground,
                        ),
                      ),
                    )
                  : Text(_primaryButtonLabel),
            ),
            if (isEditing) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _saving || _isPastSlot ? null : _deleteSlot,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _secondaryButtonColor,
                  side: BorderSide(color: _secondaryButtonColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text("Annuler ce créneau"),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(tz.TZDateTime date) {
    final weekday = _weekdayLabels[date.weekday] ?? '';
    final month = _monthLabels[date.month - 1];
    return '$weekday ${date.day} $month ${date.year}';
  }

  int _minutesFromDate(tz.TZDateTime date) => date.hour * 60 + date.minute;

  int _minutesFromTime(String value) {
    if (value == '24:00') return 24 * 60;
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return hour * 60 + minute;
  }

  String _formatMinutes(int minutes) {
    if (minutes >= 24 * 60) return '24:00';
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _roundToQuarter(int minutes) {
    const step = 15;
    return ((minutes + step - 1) ~/ step) * step;
  }

  bool _overlaps(
    tz.TZDateTime startA,
    tz.TZDateTime endA,
    tz.TZDateTime startB,
    tz.TZDateTime endB,
  ) {
    final maxStart = startA.isAfter(startB) ? startA : startB;
    final minEnd = endA.isBefore(endB) ? endA : endB;
    return maxStart.isBefore(minEnd);
  }
}

class _StationHeader extends StatelessWidget {
  const _StationHeader({required this.station});

  final Station station;

  @override
  Widget build(BuildContext context) {
    final chargerLabel = station.chargerLabel;
    final priceLabel = station.priceLabel;
    final address = station.locationFormatted ?? _formatAddress();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.05),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: const Color(0xFFE7ECFF),
            ),
            clipBehavior: Clip.antiAlias,
            child: station.photoUrl != null && station.photoUrl!.isNotEmpty
                ? Image.network(station.photoUrl!, fit: BoxFit.cover)
                : const Icon(Icons.ev_station, color: Color(0xFF2C75FF)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  station.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (chargerLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    chargerLabel,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (priceLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    priceLabel,
                    style: const TextStyle(
                      color: Color(0xFF2C75FF),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAddress() {
    final parts = <String>[
      station.streetNumber,
      station.streetName,
      station.postalCode,
      station.city,
      station.country,
    ];
    parts.removeWhere((part) => part.trim().isEmpty);
    if (parts.isEmpty) return "Adresse non renseignée";
    return parts.join(' ');
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E3EB)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: Colors.black54,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeDropdown extends StatelessWidget {
  const _TimeDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.enabled,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        enabled
            ? DropdownButtonFormField<String>(
                value: value,
                items: options
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: onChanged,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                icon: const Icon(Icons.keyboard_arrow_down),
              )
            : Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E3EB)),
                ),
                child: const Text(
                  'Aucune heure',
                  style: TextStyle(color: Colors.black38),
                ),
              ),
      ],
    );
  }
}

class _DayInterval {
  _DayInterval({required this.startMinutes, required this.endMinutes});

  final int startMinutes;
  final int endMinutes;
}

class _UtcInterval {
  _UtcInterval(this.start, this.end);
  final DateTime start;
  final DateTime end;
}

const _weekdayLabels = {
  DateTime.monday: 'Lundi',
  DateTime.tuesday: 'Mardi',
  DateTime.wednesday: 'Mercredi',
  DateTime.thursday: 'Jeudi',
  DateTime.friday: 'Vendredi',
  DateTime.saturday: 'Samedi',
  DateTime.sunday: 'Dimanche',
};

const _monthLabels = [
  'janvier',
  "février",
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  "août",
  'septembre',
  'octobre',
  'novembre',
  "décembre",
];

final List<String> _timeOptions = List<String>.generate(97, (index) {
  final minutes = index * 15;
  final hour = (minutes ~/ 60).toString().padLeft(2, '0');
  final min = (minutes % 60).toString().padLeft(2, '0');
  return '$hour:$min';
});
