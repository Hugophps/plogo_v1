import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../env.dart';

class AuthService {
  AuthService();

  SupabaseClient get _client => Supabase.instance.client;

  String get _emailRedirectTo {
    if (Env.redirectUrl.isNotEmpty) return Env.redirectUrl;
    if (kIsWeb) {
      // On web, default to current origin if not provided.
      return Uri.base.origin;
    }
    // For non-web, leave empty to let Supabase console/config handle it.
    return '';
  }

  Future<void> sendMagicLink(String email) async {
    final redirect = _emailRedirectTo.isNotEmpty ? _emailRedirectTo : null;
    await _client.auth.signInWithOtp(
      email: email,
      emailRedirectTo: redirect,
      // PKCE is enabled globally via Supabase.initialize(AuthFlowType.pkce)
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}

