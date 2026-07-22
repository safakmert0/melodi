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
    airPlayHandler = AirPlayHandler(messenger: messenger)
    carPlayHandler = CarPlayHandler(messenger: messenger)
    voiceControlHandler = VoiceControlHandler(messenger: messenger)
    widgetHandler = WidgetHandler(messenger: messenger)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
