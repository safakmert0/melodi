import Flutter
import UIKit
import AVFAudio
import AVFoundation
import MediaPlayer

// MARK: - AirPlay Handler
class AirPlayHandler: NSObject {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.melodi/airplay", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler(handle)
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

        case "showRoutePicker":
            DispatchQueue.main.async {
                let volumeView = MPVolumeView(frame: CGRect(x: -100, y: -100, width: 1, height: 1))
                volumeView.showsVolumeSlider = false
                if let routeButton = volumeView.subviews.compactMap({ $0 as? UIButton }).first {
                    routeButton.sendActions(for: .touchUpInside)
                }
                if let window = UIApplication.shared.windows.first {
                    window.rootViewController?.view.addSubview(volumeView)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        volumeView.removeFromSuperview()
                    }
                }
            }
            result(true)

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
class CarPlayHandler: NSObject {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.melodi/carplay", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler(handle)
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
class VoiceControlHandler: NSObject {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.melodi/voice_control", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler(handle)
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
class WidgetHandler: NSObject {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.melodi/widgets", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler(handle)
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
// MARK: - FFmpeg & Ringtone Handler
class FFmpegRingtoneHandler: NSObject {
    private let channel: FlutterMethodChannel
    private let fileManager = FileManager.default

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.melodi/ffmpeg_ringtone",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "extractAudio":
            guard let args = call.arguments as? [String: Any],
                  let inputPath = args["inputPath"] as? String,
                  let outputPath = args["outputPath"] as? String else {
                result(FlutterMethodNotImplemented)
                return
            }
            let startTime = (args["startTime"] as? Double) ?? 0
            let duration = (args["duration"] as? Double) ?? 30
            let outputFormat = (args["outputFormat"] as? String) ?? "m4a"
            extractAudio(
                inputPath: inputPath,
                outputPath: outputPath,
                startTime: startTime,
                duration: duration,
                outputFormat: outputFormat,
                result: result
            )

        case "saveAsRingtone":
            guard let args = call.arguments as? [String: Any],
                  let audioPath = args["audioPath"] as? String,
                  let ringtoneName = args["ringtoneName"] as? String else {
                result(FlutterMethodNotImplemented)
                return
            }
            let startTime = (args["startTime"] as? Double) ?? 0
            let duration = (args["duration"] as? Double) ?? 30
            saveAsRingtone(
                audioPath: audioPath,
                ringtoneName: ringtoneName,
                startTime: startTime,
                duration: duration,
                result: result
            )

        case "getVideoDuration":
            guard let args = call.arguments as? [String: Any],
                  let videoPath = args["videoPath"] as? String else {
                result(FlutterMethodNotImplemented)
                return
            }
            getVideoDuration(videoPath: videoPath, result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func extractAudio(
        inputPath: String,
        outputPath: String,
        startTime: Double,
        duration: Double,
        outputFormat: String,
        result: @escaping FlutterResult
    ) {
        let inputURL = URL(fileURLWithPath: inputPath)
        let outputURL = URL(fileURLWithPath: outputPath)

        guard fileManager.fileExists(atPath: inputPath) else {
            DispatchQueue.main.async {
                result(FlutterError(code: "file_not_found", message: "Input video not found", details: nil))
            }
            return
        }

        let asset = AVURLAsset(url: inputURL)

        // Check if duration exceeds asset duration
        let assetDuration = CMTimeGetSeconds(asset.duration)
        if assetDuration.isNaN || assetDuration.isInfinite {
            DispatchQueue.main.async {
                result(FlutterError(code: "invalid_duration", message: "Could not determine video duration", details: nil))
            }
            return
        }

        let actualDuration = min(duration, max(0, assetDuration - startTime))
        let endTime = startTime + actualDuration

        if actualDuration <= 0 {
            DispatchQueue.main.async {
                result(FlutterError(code: "invalid_range", message: "Invalid time range", details: nil))
            }
            return
        }

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            DispatchQueue.main.async {
                result(FlutterError(code: "exporter_failed", message: "Could not create exporter", details: nil))
            }
            return
        }

        exporter.outputURL = outputURL
        exporter.outputFileType = .m4a
        exporter.shouldOptimizeForNetworkUse = false

        let timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            duration: CMTime(seconds: actualDuration, preferredTimescale: 600)
        )
        exporter.timeRange = timeRange

        exporter.exportAsynchronously {
            let success = exporter.status == .completed
            if success {
                DispatchQueue.main.async {
                    result(["outputPath": outputPath, "duration": actualDuration])
                }
            } else {
                try? self.fileManager.removeItem(at: outputURL)
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "export_failed",
                        message: exporter.error?.localizedDescription ?? "Unknown error",
                        details: nil
                    ))
                }
            }
        }
    }

    private func saveAsRingtone(
        audioPath: String,
        ringtoneName: String,
        startTime: Double,
        duration: Double,
        result: @escaping FlutterResult
    ) {
        let sourceURL = URL(fileURLWithPath: audioPath)

        guard fileManager.fileExists(atPath: audioPath) else {
            DispatchQueue.main.async {
                result(FlutterError(code: "file_not_found", message: "Audio file not found", details: nil))
            }
            return
        }

        // For iOS, we need to export as .m4r (AAC format, max 30 seconds)
        // First, trim if needed
        let asset = AVURLAsset(url: sourceURL)
        let assetDuration = CMTimeGetSeconds(asset.duration)

        let actualDuration = min(duration, max(0, assetDuration - startTime))
        let maxRingtoneDuration = 30.0 // iOS limit
        let finalDuration = min(actualDuration, maxRingtoneDuration)

        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            DispatchQueue.main.async {
                result(FlutterError(code: "exporter_failed", message: "Could not create exporter", details: nil))
            }
            return
        }

        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let ringtoneURL = documentsPath.appendingPathComponent("\(ringtoneName).m4r")

        // Remove existing file
        try? fileManager.removeItem(at: ringtoneURL)

        exporter.outputURL = ringtoneURL
        exporter.outputFileType = .m4a
        exporter.shouldOptimizeForNetworkUse = false

        let timeRange = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            duration: CMTime(seconds: finalDuration, preferredTimescale: 600)
        )
        exporter.timeRange = timeRange

        exporter.exportAsynchronously {
            guard exporter.status == .completed else {
                try? self.fileManager.removeItem(at: ringtoneURL)
                DispatchQueue.main.async {
                    result(FlutterError(
                        code: "export_failed",
                        message: exporter.error?.localizedDescription ?? "Ringtone export failed",
                        details: nil
                    ))
                }
                return
            }

            // Now we need to save it to the Ringtones library
            // This requires using the UIDocumentPickerViewController or shared container
            // For simplicity, we return the path and let the Flutter side handle sharing
            DispatchQueue.main.async {
                result([
                    "ringtonePath": ringtoneURL.path,
                    "duration": finalDuration,
                    "name": ringtoneName
                ])
            }
        }
    }

    private func getVideoDuration(videoPath: String, result: @escaping FlutterResult) {
        let url = URL(fileURLWithPath: videoPath)
        guard fileManager.fileExists(atPath: videoPath) else {
            DispatchQueue.main.async {
                result(FlutterError(code: "file_not_found", message: "Video file not found", details: nil))
            }
            return
        }

        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)

        if duration.isNaN || duration.isInfinite {
            DispatchQueue.main.async {
                result(FlutterError(code: "invalid_duration", message: "Could not determine duration", details: nil))
            }
        } else {
            DispatchQueue.main.async {
                result(["duration": duration])
            }
        }
    }
}

// MARK: - Downloaded media metadata writer
class LyricsMetadataWriterHandler: NSObject {
    private let channel: FlutterMethodChannel

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "com.melodi/metadata_writer",
            binaryMessenger: messenger
        )
        super.init()
        channel.setMethodCallHandler(handle)
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "embedLyrics" || call.method == "embedArtwork",
              let arguments = call.arguments as? [String: Any],
              let path = arguments["path"] as? String else {
            result(FlutterMethodNotImplemented)
            return
        }

        let lyrics = arguments["lyrics"] as? String
        let coverArt = (arguments["coverArt"] as? FlutterStandardTypedData)?.data
        let expectedDurationMs =
            (arguments["expectedDurationMs"] as? NSNumber)?.doubleValue ?? 0
        process(
            path: path,
            lyrics: lyrics,
            coverArt: coverArt,
            expectedDurationMs: expectedDurationMs,
            result: result
        )
    }

    private func process(
        path: String,
        lyrics: String?,
        coverArt: Data?,
        expectedDurationMs: Double,
        result: @escaping FlutterResult
    ) {
        let sourceURL = URL(fileURLWithPath: path)
        guard sourceURL.pathExtension.lowercased() == "m4a" else {
            result(false)
            return
        }

        let asset = AVURLAsset(url: sourceURL)
        guard let exporter = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            result(false)
            return
        }

        let temporaryURL = sourceURL.deletingLastPathComponent()
            .appendingPathComponent(".melodi-\(UUID().uuidString).m4a")
        try? FileManager.default.removeItem(at: temporaryURL)

        exporter.outputURL = temporaryURL
        exporter.outputFileType = .m4a
        exporter.shouldOptimizeForNetworkUse = false

        var metadata = asset.metadata.filter { item in
            if lyrics != nil && item.identifier == .iTunesMetadataLyrics {
                return false
            }
            if coverArt != nil &&
                (item.identifier == .commonIdentifierArtwork ||
                 item.identifier == .iTunesMetadataCoverArt) {
                return false
            }
            return true
        }
        if let lyrics, !lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let lyricsItem = AVMutableMetadataItem()
            lyricsItem.identifier = .iTunesMetadataLyrics
            lyricsItem.value = lyrics as NSString
            metadata.append(lyricsItem)
        }
        if let coverArt, !coverArt.isEmpty {
            let artworkItem = AVMutableMetadataItem()
            artworkItem.identifier = .commonIdentifierArtwork
            artworkItem.value = coverArt as NSData
            let pngSignature: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
            artworkItem.dataType = coverArt.starts(with: pngSignature)
                ? kCMMetadataBaseDataType_PNG as String
                : kCMMetadataBaseDataType_JPEG as String
            metadata.append(artworkItem)
        }
        exporter.metadata = metadata

        if expectedDurationMs > 0 {
            let expectedSeconds = expectedDurationMs / 1000.0
            let actualSeconds = CMTimeGetSeconds(asset.duration)
            let tolerance = min(max(expectedSeconds * 0.15, 20), 60)
            if actualSeconds.isFinite &&
                actualSeconds > expectedSeconds + tolerance {
                exporter.timeRange = CMTimeRange(
                    start: .zero,
                    duration: CMTime(seconds: expectedSeconds, preferredTimescale: 600)
                )
            }
        }

        exporter.exportAsynchronously {
            let succeeded = exporter.status == .completed
            if succeeded {
                do {
                    _ = try FileManager.default.replaceItemAt(
                        sourceURL,
                        withItemAt: temporaryURL,
                        backupItemName: nil,
                        options: []
                    )
                } catch {
                    try? FileManager.default.removeItem(at: temporaryURL)
                    DispatchQueue.main.async {
                        result(FlutterError(
                            code: "metadata_replace_failed",
                            message: error.localizedDescription,
                            details: nil
                        ))
                    }
                    return
                }
            } else {
                try? FileManager.default.removeItem(at: temporaryURL)
            }

            DispatchQueue.main.async {
                if succeeded {
                    result(true)
                } else {
                    result(FlutterError(
                        code: "metadata_export_failed",
                        message: exporter.error?.localizedDescription,
                        details: nil
                    ))
                }
            }
        }
    }
}
