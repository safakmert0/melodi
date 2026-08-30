// ignore_for_file: avoid_classes_with_only_static_members
/// Melodi build configuration for App Store compliance (B - Hybrid).
///
/// Base IPA uploaded to App Store is "clean": no YouTube download/extract
/// capability out of the box. Premium features are unlocked only when the user
/// manually installs a community extension that provides a `ytdlpBackend`
/// server URL.
///
/// Usage:
///   flutter build ios --dart-define=APP_STORE=true   // App Store build
///   flutter build ios                               // sideload / dev (full)
///
/// All gating should go through [AppConfig.isAppStoreBuild] and
/// [AppConfig.isPremiumUnlocked] where possible so that binary analysis in
/// App Review does not see YouTube capabilities by default.
library;

class AppConfig {
  AppConfig._();

  /// True when built with `--dart-define=APP_STORE=true`.
  /// Set by Codemagic / GitHub Actions for the signed App Store IPA.
  static const bool isAppStoreBuild =
      bool.fromEnvironment('APP_STORE', defaultValue: false);

  /// True when built with `--dart-define=DISABLE_YTDLP_DIRECT=true`.
  /// For App Store we disable the direct `youtube_explode_dart` fallback and
  /// only allow downloads via an installed `backend` extension.
  static const bool disableYtDlpDirect =
      bool.fromEnvironment('DISABLE_YTDLP_DIRECT', defaultValue: isAppStoreBuild);

  /// Whether YouTube-origin sources should be shown in the catalog at all
  /// without an extension. App Store build hides them until an extension is
  /// installed.
  static bool youtubeCatalogVisible(bool hasYtExtension) {
    if (!isAppStoreBuild) return true;
    return hasYtExtension;
  }

  /// Whether direct Piped / youtube_explode network calls are allowed.
  /// App Store build: only if user has installed a community backend.
  static bool canUseDirectYouTubeFetch(bool hasBackendExtension) {
    if (disableYtDlpDirect && !hasBackendExtension) return false;
    return true;
  }
}
