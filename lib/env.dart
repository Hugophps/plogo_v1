class Env {
  // Provided via --dart-define at build/run time. Do not hardcode values.
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Optional: explicit redirect/callback URL for email link/PKCE on web.
  // If not set, you can pass the current origin when sending the magic link.
  static const redirectUrl = String.fromEnvironment(
    'SUPABASE_REDIRECT_URL',
    defaultValue: '',
  );

  static const googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );
}
