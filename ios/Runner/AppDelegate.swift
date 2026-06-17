import UIKit
import Flutter
import MediaPlayer
import CarPlay

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var carplayChannel: FlutterMethodChannel?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller = window?.rootViewController as! FlutterViewController
        carplayChannel = FlutterMethodChannel(
            name: "com.melodi/carplay",
            binaryMessenger: controller.binaryMessenger
        )

        carplayChannel?.setMethodCallHandler { [weak self] call, result in
            switch call.method {
            case "setNowPlaying":
                let args = call.arguments as? [String: Any]
                self?.updateNowPlayingInfo(args)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        return config
    }

    private func updateNowPlayingInfo(_ args: [String: Any]?) {
        guard let args = args else { return }
        var info: [String: Any] = [:]

        if let title = args["title"] as? String {
            info[MPMediaItemPropertyTitle] = title
        }
        if let artist = args["artist"] as? String {
            info[MPMediaItemPropertyArtist] = artist
        }
        if let album = args["album"] as? String {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        if let duration = args["durationMs"] as? Double {
            info[MPMediaItemPropertyPlaybackDuration] = duration / 1000.0
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}
