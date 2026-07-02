import Flutter
import UIKit
import AVFAudio
import MediaPlayer

// MARK: - AirPlay Handler
class AirPlayHandler: NSObject, FlutterPlugin {
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "com.melodi/airplay", binaryMessenger: messenger)
        let instance = AirPlayHandler()
        channel.setMethodCallHandler(instance.handle)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getAvailableDevices":
            let route = AVAudioSession.sharedInstance().currentRoute
            var devices: [[String: Any]] = []
            for output in route.outputs {
                let device: [String: Any] = [
                    "id": output.uid,
                    "name": output.portName,
                    "model": output.portType.rawValue,
                    "isAvailable": true
                ]
                devices.append(device)
            }
            result(["devices": devices])

        case "streamToDevice":
            guard let args = call.arguments as? [String: Any],
                  let deviceId = args["deviceId"] as? String else {
                result(false)
                return
            }
            NotificationCenter.default.post(
                name: NSNotification.Name("MelodiAirPlayRoute"),
                object: nil,
                userInfo: ["deviceId": deviceId]
            )
            result(true)

        case "stopStreaming":
            do {
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("AirPlay stop error: \(error)")
            }
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - CarPlay Handler
class CarPlayHandler: NSObject, FlutterPlugin {
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "com.melodi/carplay", binaryMessenger: messenger)
        let instance = CarPlayHandler()
        channel.setMethodCallHandler(instance.handle)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setNowPlaying":
            guard let args = call.arguments as? [String: Any],
                  let title = args["title"] as? String,
                  let artist = args["artist"] as? String else {
                result(false)
                return
            }
            let album = args["album"] as? String ?? ""
            let durationMs = args["durationMs"] as? Double ?? 0

            var info = [String: Any]()
            info[MPMediaItemPropertyTitle] = title
            info[MPMediaItemPropertyArtist] = artist
            info[MPMediaItemPropertyAlbumTitle] = album
            info[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: durationMs / 1000.0)
            info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0

            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

// MARK: - Voice Control Handler
class VoiceControlHandler: NSObject, FlutterPlugin {
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "com.melodi/voice_control", binaryMessenger: messenger)
        let instance = VoiceControlHandler()
        channel.setMethodCallHandler(instance.handle)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "registerShortcuts":
            setupRemoteCommands()
            result(true)

        case "playPause":
            MPRemoteCommandCenter.shared().togglePlayPauseCommand.isEnabled = true
            result(true)

        case "nextTrack":
            MPRemoteCommandCenter.shared().nextTrackCommand.isEnabled = true
            result(true)

        case "previousTrack":
            MPRemoteCommandCenter.shared().previousTrackCommand.isEnabled = true
            result(true)

        case "shuffleToggle":
            result(true)

        case "repeatToggle":
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        center.playCommand.addTarget { _ in
            NotificationCenter.default.post(name: NSNotification.Name("MelodiRemotePlay"), object: nil)
            return .success
        }
        center.pauseCommand.addTarget { _ in
            NotificationCenter.default.post(name: NSNotification.Name("MelodiRemotePause"), object: nil)
            return .success
        }
        center.togglePlayPauseCommand.addTarget { _ in
            NotificationCenter.default.post(name: NSNotification.Name("MelodiRemoteToggle"), object: nil)
            return .success
        }
        center.nextTrackCommand.addTarget { _ in
            NotificationCenter.default.post(name: NSNotification.Name("MelodiRemoteNext"), object: nil)
            return .success
        }
        center.previousTrackCommand.addTarget { _ in
            NotificationCenter.default.post(name: NSNotification.Name("MelodiRemotePrevious"), object: nil)
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { event in
            if let posEvent = event as? MPChangePlaybackPositionCommandEvent {
                NotificationCenter.default.post(
                    name: NSNotification.Name("MelodiRemoteSeek"),
                    object: nil,
                    userInfo: ["position": posEvent.positionTime]
                )
            }
            return .success
        }

        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.togglePlayPauseCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.changePlaybackPositionCommand.isEnabled = true
        center.skipForwardCommand.isEnabled = true
        center.skipBackwardCommand.isEnabled = true
        center.skipForwardCommand.preferredIntervals = [10]
        center.skipBackwardCommand.preferredIntervals = [10]
    }
}

// MARK: - Widget Handler
class WidgetHandler: NSObject, FlutterPlugin {
    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "com.melodi/widgets", binaryMessenger: messenger)
        let instance = WidgetHandler()
        channel.setMethodCallHandler(instance.handle)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let sharedDefaults = UserDefaults(suiteName: "group.com.melodi.app")

        switch call.method {
        case "updateNowPlaying":
            guard let args = call.arguments as? [String: Any],
                  let title = args["title"] as? String,
                  let artist = args["artist"] as? String else {
                result(false)
                return
            }
            let album = args["album"] as? String ?? ""
            let albumArt = args["albumArt"] as? String ?? ""

            sharedDefaults?.set(title, forKey: "widget_now_playing_title")
            sharedDefaults?.set(artist, forKey: "widget_now_playing_artist")
            sharedDefaults?.set(album, forKey: "widget_now_playing_album")
            sharedDefaults?.set(albumArt, forKey: "widget_now_playing_art")
            sharedDefaults?.synchronize()
            result(true)

        case "updateRecentlyPlayed":
            guard let args = call.arguments as? [String: Any],
                  let songs = args["songs"] as? [[String: Any]] else {
                result(false)
                return
            }
            let titles = songs.compactMap { $0["title"] as? String }
            let artists = songs.compactMap { $0["artist"] as? String }
            sharedDefaults?.set(titles, forKey: "widget_recent_titles")
            sharedDefaults?.set(artists, forKey: "widget_recent_artists")
            sharedDefaults?.synchronize()
            result(true)

        case "updateFavorites":
            guard let args = call.arguments as? [String: Any],
                  let songs = args["songs"] as? [[String: Any]] else {
                result(false)
                return
            }
            let titles = songs.compactMap { $0["title"] as? String }
            let artists = songs.compactMap { $0["artist"] as? String }
            sharedDefaults?.set(titles, forKey: "widget_fav_titles")
            sharedDefaults?.set(artists, forKey: "widget_fav_artists")
            sharedDefaults?.synchronize()
            result(true)

        case "handleWidgetAction":
            guard let args = call.arguments as? [String: Any],
                  let action = args["action"] as? String else {
                result(false)
                return
            }
            NotificationCenter.default.post(
                name: NSNotification.Name("MelodiWidgetAction"),
                object: nil,
                userInfo: ["action": action]
            )
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
