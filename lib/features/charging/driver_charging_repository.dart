import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_bootstrap.dart';
import '../driver_map/driver_station_models.dart';
import '../stations/models/station.dart';
import '../stations/models/station_slot.dart';
import 'models/charging_session.dart';
import 'models/driver_charging_view.dart';

class DriverChargingRepository {
  const DriverChargingRepository();

  SupabaseClient get _client => supabase;

  Future<DriverChargingView> fetchDashboardState() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('Aucun utilisateur connecté.');
    }

    final membershipRows = await _fetchMembershipRows(user.id);
    if (membershipRows.isEmpty) {
      return const DriverChargingView(
        status: DriverChargingStatus.noMembership,
        infoMessage: "Rejoignez une station pour planifier vos charges.",
      );
    }

    final memberships = <String, DriverStationMembership>{};
    final stations = <String, Station>{};
    for (final map in membershipRows) {
      final stationMap = map['station'] as Map<String, dynamic>?;
      if (stationMap == null) continue;
      final membership = DriverStationMembership.fromMap(map);
      final station = Station.fromMap(stationMap);
      memberships[membership.id] = membership;
      stations[station.id] = station;
    }

    if (memberships.isEmpty) {
      return const DriverChargingView(
        status: DriverChargingStatus.noMembership,
        infoMessage: "Rejoignez une station pour planifier vos charges.",
      );
    }

    final now = DateTime.now().toUtc();
    final slotInfo = await _loadSlotInfo(
      memberships.keys.toList(),
      now,
    );
    final sessions = await _loadRecentSessions(user.id);
    final activeSession = _firstWhereOrNull(
      sessions,
      (session) => session.isInProgress,
    );
    final lastCompletedSession = _firstWhereOrNull(
      sessions,
      (session) => session.isCompleted,
    );

    if (activeSession != null) {
      final membership = _membershipForStation(
        memberships.values,
        activeSession.stationId,
      );
      final station = activeSession.station ??
          (membership != null ? stations[membership.stationId] : null);
      return DriverChargingView(
        status: DriverChargingStatus.charging,
        station: station,
        membership: membership,
        activeSlot: activeSession.slot,
        session: activeSession,
        infoMessage: "Session en cours : surveillez votre véhicule.",
      );
    }

    final activeSelection = _pickSlotSelection(
      memberships,
      stations,
      slotInfo,
      active: true,
    );
    if (activeSelection != null) {
      return DriverChargingView(
        status: DriverChargingStatus.readyToCharge,
        station: activeSelection.station,
        membership: activeSelection.membership,
        activeSlot: activeSelection.slot,
        infoMessage:
            "Votre créneau est ouvert : branchez votre véhicule puis démarrez la charge.",
      );
    }

    final upcomingSelection = _pickSlotSelection(
      memberships,
      stations,
      slotInfo,
      active: false,
    );
    if (upcomingSelection != null) {
      return DriverChargingView(
        status: DriverChargingStatus.upcomingReservation,
        station: upcomingSelection.station,
        membership: upcomingSelection.membership,
        nextSlot: upcomingSelection.slot,
        infoMessage: "Votre prochaine session est planifiée.",
      );
    }

    if (lastCompletedSession != null &&
        lastCompletedSession.endAt != null &&
        now.difference(lastCompletedSession.endAt!).inHours <= 12) {
      final membership = _membershipForStation(
        memberships.values,
        lastCompletedSession.stationId,
      );
      final station = lastCompletedSession.station ??
          (membership != null ? stations[membership.stationId] : null);
      return DriverChargingView(
        status: DriverChargingStatus.completed,
        station: station,
        membership: membership,
        session: lastCompletedSession,
        infoMessage: "Dernière session terminée récemment.",
      );
    }

    return const DriverChargingView(
      status: DriverChargingStatus.noReservation,
      infoMessage: "Aucune session planifiée. Réservez votre prochain créneau.",
    );
  }

  Future<List<Map<String, dynamic>>> _fetchMembershipRows(
    String userId,
  ) async {
    final response = await _client
        .from('station_memberships')
        .select('''
          id,
          station_id,
          status,
          created_at,
          approved_at,
          station:stations(
            id,
            owner_id,
            name,
            charger_brand,
            charger_model,
            charger_vendor,
            price_per_kwh,
            enode_charger_id,
            enode_metadata,
            city,
            country,
            street_name,
            street_number,
            postal_code,
            photo_url,
            additional_info,
            whatsapp_group_url
          )
        ''')
        .eq('profile_id', userId)
        .eq('status', 'approved');

    if (response is List) {
      return response.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Future<Map<String, _MembershipSlotInfo>> _loadSlotInfo(
    List<String> membershipIds,
    DateTime now,
  ) async {
    if (membershipIds.isEmpty) return const {};

    final response = await _client
        .from('station_slots')
        .select(
          'id, station_id, start_at, end_at, type, metadata, created_at',
        )
        .eq('type', 'member_booking')
        .inFilter('metadata->>membership_id', membershipIds)
        .gte(
          'end_at',
          now.subtract(const Duration(days: 1)).toIso8601String(),
        )
        .order('start_at');

    if (response is! List) {
      return const {};
    }

    final info = <String, _MembershipSlotInfo>{};
    for (final item in response.whereType<Map<String, dynamic>>()) {
      final metadata = item['metadata'] as Map<String, dynamic>?;
      final membershipId = metadata?['membership_id'] as String?;
      if (membershipId == null) continue;
      StationSlot slot;
      try {
        slot = StationSlot.fromMap(item);
      } catch (_) {
        continue;
      }
      final entry = info.putIfAbsent(
        membershipId,
        () => _MembershipSlotInfo(),
      );
      final nowUtc = now;

      final start = slot.startAt.toUtc();
      final end = slot.endAt.toUtc();
      final isActive =
          !start.isAfter(nowUtc) && (end.isAfter(nowUtc) || end == nowUtc);

      if (isActive) {
        entry.activeSlot ??= slot;
      } else if (start.isAfter(nowUtc)) {
        if (entry.nextSlot == null ||
            start.isBefore(entry.nextSlot!.startAt.toUtc())) {
          entry.nextSlot = slot;
        }
      }
    }
    return info;
  }

  Future<List<ChargingSession>> _loadRecentSessions(String driverId) async {
    final response = await _client
        .from('station_charging_sessions')
        .select('''
          id,
          station_id,
          driver_profile_id,
          slot_id,
          status,
          start_at,
          end_at,
          energy_kwh,
          amount_eur,
          station:stations(
            id,
            owner_id,
            name,
            charger_brand,
            charger_model,
            charger_vendor,
            price_per_kwh,
            enode_charger_id,
            enode_metadata,
            city,
            country,
            street_name,
            street_number,
            postal_code,
            photo_url,
            additional_info
          ),
          slot:station_slots(
            id,
            station_id,
            start_at,
            end_at,
            type,
            metadata
          )
        ''')
        .eq('driver_profile_id', driverId)
        .order('created_at', ascending: false)
        .limit(5);

    if (response is! List) {
      return const [];
    }

    final sessions = <ChargingSession>[];
    for (final item in response.whereType<Map<String, dynamic>>()) {
      Station? station;
      final stationMap = item['station'] as Map<String, dynamic>?;
      if (stationMap != null) {
        station = Station.fromMap(stationMap);
      }

      StationSlot? slot;
      final slotMap = item['slot'] as Map<String, dynamic>?;
      if (slotMap != null) {
        try {
          slot = StationSlot.fromMap(slotMap);
        } catch (_) {
          slot = null;
        }
      }

      try {
        sessions.add(
          ChargingSession.fromMap(item, station: station, slot: slot),
        );
      } catch (_) {
        continue;
      }
    }
    return sessions;
  }

  DriverStationMembership? _membershipForStation(
    Iterable<DriverStationMembership> memberships,
    String stationId,
  ) {
    return _firstWhereOrNull(
      memberships,
      (membership) => membership.stationId == stationId,
    );
  }

  _MembershipSelection? _pickSlotSelection(
    Map<String, DriverStationMembership> memberships,
    Map<String, Station> stations,
    Map<String, _MembershipSlotInfo> slotInfo, {
    required bool active,
  }) {
    _MembershipSelection? selection;
    for (final entry in slotInfo.entries) {
      final membership = memberships[entry.key];
      if (membership == null) continue;
      final station = stations[membership.stationId];
      if (station == null) continue;
      final slot = active ? entry.value.activeSlot : entry.value.nextSlot;
      if (slot == null) continue;

      if (selection == null) {
        selection = _MembershipSelection(membership, station, slot);
      } else {
        final candidateDate = active
            ? slot.endAt
            : slot.startAt;
        final currentDate = active
            ? selection.slot.endAt
            : selection.slot.startAt;
        if (candidateDate.isBefore(currentDate)) {
          selection = _MembershipSelection(membership, station, slot);
        }
      }
    }
    return selection;
  }

  T? _firstWhereOrNull<T>(
    Iterable<T> items,
    bool Function(T item) test,
  ) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }
}

class _MembershipSlotInfo {
  StationSlot? activeSlot;
  StationSlot? nextSlot;
}

class _MembershipSelection {
  _MembershipSelection(this.membership, this.station, this.slot);

  final DriverStationMembership membership;
  final Station station;
  final StationSlot slot;
}
