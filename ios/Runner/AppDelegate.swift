import Flutter
import UIKit
import AVFAudio
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var airPlayHandler: AirPlayHandler?
  private var carPlayHandler: CarPlayHandler?
  private var voiceControlHandler: VoiceControlHandler?
  private var widgetHandler: WidgetHandler?
  private var lyricsMetadataWriterHandler: LyricsMetadataWriterHandler?
  private var ffmpegRingtoneHandler: FFmpegRingtoneHandler?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure audio session for background playback
    let audioSession = AVAudioSession.sharedInstance()
    try? audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers])
    try? audioSession.setActive(true)

    // Register platform channel handlers
    let controller = window?.rootViewController as! FlutterViewController
    let messenger = controller.binaryMessenger
    let spotifyAuthChannel = FlutterMethodChannel(name: "com.melodi/spotify_auth", binaryMessenger: messenger)
    spotifyAuthChannel.setMethodCallHandler { call, result in
      guard call.method == "getCookies" else {
        result(FlutterMethodNotImplemented)
        return
      }
      WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
        result(cookies.map { ["name": $0.name, "value": $0.value, "domain": $0.domain] })
      }
    }
    let storageChannel = FlutterMethodChannel(name: "com.melodi/storage", binaryMessenger: messenger)
    storageChannel.setMethodCallHandler { call, result in
      guard call.method == "excludeFromBackup",
            let arguments = call.arguments as? [String: Any],
            let path = arguments["path"] as? String else {
        result(FlutterMethodNotImplemented)
        return
      }
      var url = URL(fileURLWithPath: path, isDirectory: true)
      do {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
        result(nil)
      } catch {
        result(FlutterError(code: "exclude_from_backup_failed", message: error.localizedDescription, details: nil))
      }
    }
    airPlayHandler = AirPlayHandler(messenger: messenger)
    carPlayHandler = CarPlayHandler(messenger: messenger)
    voiceControlHandler = VoiceControlHandler(messenger: messenger)
    widgetHandler = WidgetHandler(messenger: messenger)
    lyricsMetadataWriterHandler = LyricsMetadataWriterHandler(messenger: messenger)
    ffmpegRingtoneHandler = FFmpegRingtoneHandler(messenger: messenger)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
