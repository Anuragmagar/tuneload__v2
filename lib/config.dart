/// App-wide configuration.
class AppConfig {
  /// Base URL of the TuneLoad stream-resolver server.
  ///
  /// This is the FREE backend (see `server/` in the repo). Deploy it to any
  /// always-on host and put its public URL here. The app uses it as a
  /// fallback when direct client-side extraction is blocked by YouTube
  /// (e.g. the user's IP is bot-flagged).
  ///
  /// Set to an empty string to disable the server fallback entirely.
  static const String streamServerBaseUrl = 'https://tuneload-v2.onrender.com';

  /// Optional HTTP Basic auth username/password if the server is protected.
  /// Leave empty if the server has no auth.
  static const String streamServerUser = '';
  static const String streamServerPass = '';

  /// When true, the app skips direct youtube_explode_dart extraction entirely
  /// and plays straight through the server proxy. Faster and more reliable,
  /// but depends on the server being up. When false, it tries direct
  /// extraction first and only uses the server as a fallback.
  static const bool preferServer = true;
}
