import Flutter
import UIKit
import AVFAudio

@main
@objc class AppDelegate: FlutterAppDelegate {
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
    AirPlayHandler.register(with: messenger)
    CarPlayHandler.register(with: messenger)
    VoiceControlHandler.register(with: messenger)
    WidgetHandler.register(with: messenger)

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
