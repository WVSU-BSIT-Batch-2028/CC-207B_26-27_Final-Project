/// Build-time configuration, supplied with `--dart-define-from-file=env.json`.
/// Copy `env.example.json` to `env.json` (gitignored) and fill it in.
/// Only PUBLIC values belong here: the Supabase publishable key and a MapTiler key restricted
/// to this app. Never a service-role/secret key.
class AppConfig {
  const AppConfig({
    this.supabaseUrl = '',
    this.supabasePublishableKey = '',
    this.mapTilerKey = '',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
        supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
        supabasePublishableKey: String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY'),
        mapTilerKey: String.fromEnvironment('MAPTILER_KEY'),
      );

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String mapTilerKey;

  /// Live mode needs both Supabase values. Otherwise the app runs on labeled DEMO records.
  bool get isLive => supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
  bool get hasMapTiler => mapTilerKey.isNotEmpty;

  String get restBase => '${supabaseUrl.replaceAll(RegExp(r'/+$'), '')}/rest/v1';
}
