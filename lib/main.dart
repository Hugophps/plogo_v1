import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/app_timezone.dart';
import 'core/supabase_bootstrap.dart';
import 'features/account/account_completion_page.dart';
import 'features/account/role_selection_page.dart';
import 'features/driver_map/driver_map_page.dart';
import 'features/driver_map/driver_station_selection_page.dart';
import 'features/home/driver_home_page.dart';
import 'features/home/owner_home_page.dart';
import 'features/landing/landing_page.dart';
import 'features/profile/models/profile.dart';
import 'features/profile/profile_page.dart';
import 'features/profile/profile_repository.dart';
import 'features/stations/models/station.dart';
import 'features/stations/station_form_page.dart';
import 'features/stations/station_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initAppTimezone();
  await initSupabase();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plogo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2C75FF)),
        scaffoldBackgroundColor: const Color(0xFFF7F8FC),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2C75FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

enum AuthDestination {
  landing,
  completion,
  roleSelection,
  ownerHome,
  driverHome,
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _repo = const ProfileRepository();
  final _stationRepo = const StationRepository();
  AuthDestination _destination = AuthDestination.landing;
  Profile? _profile;
  Station? _station;
  bool _loading = true;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = supabase.auth.onAuthStateChange.listen((event) {
      _handleSession(event.session);
    });
    _handleSession(supabase.auth.currentSession);
  }

  void _handleSession(Session? session) {
    if (session == null) {
      setState(() {
        _profile = null;
        _destination = AuthDestination.landing;
        _loading = false;
      });
      return;
    }
    _loadProfile(session);
  }

  Future<void> _loadProfile(Session session) async {
    setState(() => _loading = true);
    try {
      final fetched = await _repo.fetchCurrentProfile();
      final profile =
          fetched ??
          Profile(
            id: session.user.id,
            email: session.user.email,
            isCompleted: false,
          );
      Station? station;
      var resolvedProfile = profile;
      if (profile.isOwner) {
        station = await _stationRepo.fetchOwnStation();
        if (station != null) {
          resolvedProfile = profile.copyWith(stationName: station.name);
        }
      }
      setState(() {
        _profile = resolvedProfile;
        _station = station;
        _destination = _resolveDestination(profile);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de chargement du profil: $e')),
        );
      }
    }
  }

  AuthDestination _resolveDestination(Profile profile) {
    if (!profile.isCompleted) return AuthDestination.completion;
    if (!profile.hasRole) return AuthDestination.roleSelection;
    return profile.isOwner
        ? AuthDestination.ownerHome
        : AuthDestination.driverHome;
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
  }

  Future<void> _deleteAccount() async {
    try {
      await _repo.deleteAccount();
      await supabase.auth.signOut();
      if (mounted) {
        setState(() {
          _profile = null;
          _destination = AuthDestination.landing;
        });
      }
    } catch (e) {
      rethrow;
    }
  }

  void _onAccountCompleted() {
    final session = supabase.auth.currentSession;
    if (session != null) {
      _loadProfile(session);
    }
  }

  void _onRoleSelected(Profile profile) {
    setState(() {
      _profile = profile;
      _destination = _resolveDestination(profile);
    });
  }

  void _onProfileUpdated(Profile profile) {
    setState(() {
      _profile = profile;
      _destination = _resolveDestination(profile);
    });
  }

  Future<Profile?> _refreshProfile() async {
    final refreshed = await _repo.fetchCurrentProfile();
    if (refreshed != null) {
      Station? station;
      var resolvedProfile = refreshed;
      if (refreshed.isOwner) {
        station = await _stationRepo.fetchOwnStation();
        if (station != null) {
          resolvedProfile = refreshed.copyWith(stationName: station.name);
        }
      }
      setState(() {
        _profile = resolvedProfile;
        _station = station;
        _destination = _resolveDestination(refreshed);
      });
    }
    return refreshed;
  }

  Future<void> _openDriverMap(BuildContext context) async {
    final profile = _profile;
    if (profile == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => DriverMapPage(profile: profile)),
    );
    await _refreshProfile();
  }

  Future<void> _openDriverStationSelection(BuildContext context) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const DriverStationSelectionPage(),
      ),
    );
    if (result == 'open_map') {
      await _openDriverMap(context);
    } else {
      await _refreshProfile();
    }
  }

  Future<void> _openProfilePage(BuildContext context) async {
    final current = _profile;
    if (current == null) return;

    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          profile: current,
          onProfileUpdated: _onProfileUpdated,
          onSignOut: _signOut,
          onAccountDeleted: _deleteAccount,
          refreshProfile: _refreshProfile,
        ),
      ),
    );

    if (deleted == true && mounted) {
      setState(() {
        _profile = null;
        _destination = AuthDestination.landing;
      });
    }
  }

  Future<void> _openStationCreate(BuildContext context) async {
    final currentProfile = _profile;
    if (currentProfile == null) return;

    final created = await Navigator.of(context).push<Station?>(
      MaterialPageRoute(
        builder: (_) => StationFormPage(
          profile: currentProfile,
          onSubmit: (payload, photoUrl) async {
            final station = await _stationRepo.createStation({
              ...payload,
              if (photoUrl != null) 'photo_url': photoUrl,
            });
            return station;
          },
          title: 'CrÃƒÂ©ation de votre borne',
          submitLabel: 'Valider et crÃƒÂ©er',
          initialStation: null,
        ),
      ),
    );

    if (created != null && mounted) {
      setState(() {
        _station = created;
        _profile = _profile?.copyWith(stationName: created.name);
      });
    }
  }

  Future<void> _openStationEdit(BuildContext context) async {
    final currentProfile = _profile;
    final currentStation = _station;
    if (currentProfile == null || currentStation == null) return;

    final updated = await Navigator.of(context).push<Station?>(
      MaterialPageRoute(
        builder: (_) => StationFormPage(
          profile: currentProfile,
          initialStation: currentStation,
          title: 'Modifier ma borne',
          submitLabel: 'Enregistrer les modifications',
          onSubmit: (payload, photoUrl) async {
            final station = await _stationRepo.updateStation(
              currentStation.id,
              {...payload, if (photoUrl != null) 'photo_url': photoUrl},
            );
            return station;
          },
        ),
      ),
    );

    if (updated != null && mounted) {
      setState(() {
        _station = updated;
        _profile = _profile?.copyWith(stationName: updated.name);
      });
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    switch (_destination) {
      case AuthDestination.landing:
        return const LandingPage();
      case AuthDestination.completion:
        return AccountCompletionPage(
          profile: _profile,
          onCompleted: _onAccountCompleted,
        );
      case AuthDestination.roleSelection:
        return RoleSelectionPage(
          profile: _profile!,
          onRoleSelected: _onRoleSelected,
        );
      case AuthDestination.ownerHome:
        return OwnerHomePage(
          profile: _profile!,
          onOpenProfile: () => _openProfilePage(context),
          onCreateStation: () => _openStationCreate(context),
          onEditStation: () => _openStationEdit(context),
          station: _station,
        );
      case AuthDestination.driverHome:
        return DriverHomePage(
          profile: _profile!,
          onOpenProfile: () => _openProfilePage(context),
          onOpenMap: () => _openDriverMap(context),
          onOpenStationSelection: () => _openDriverStationSelection(context),
        );
    }
  }
}
