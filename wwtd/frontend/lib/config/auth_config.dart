class AuthConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const redirect = String.fromEnvironment('AUTH_REDIRECT_URL');
  static const mode = String.fromEnvironment(
    'AUTH_MODE',
    defaultValue: 'password',
  );
  static bool get googleEnabled =>
      mode != 'password' && url.isNotEmpty && key.isNotEmpty;
}
