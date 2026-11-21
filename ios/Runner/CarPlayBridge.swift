import Flutter
import MediaPlayer
import UIKit

/// CarPlay köprüsü (MVP): MPPlayableContentManager ile kuyruğu CarPlay'e
/// taşır. Dart tarafındaki `com.melodi/carplay` kanalından getQueue/playAt
/// çağrıları yapılır. Now Playing ekranı MPNowPlayingInfoCenter/remote
/// command'ları (audio_service) kullanır.
final class CarPlayBridge: NSObject {
  static let shared = CarPlayBridge()
  private var channel: FlutterMethodChannel?
  private var items: [[String: Any]] = []

  func setup(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "com.melodi/carplay", binaryMessenger: messenger)
    channel?.setMethodCallHandler { [weak self] call, result in
      if call.method == "refresh" {
        self?.refresh()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    let manager = MPPlayableContentManager.shared()
    manager.dataSource = self
    manager.delegate = self
    refresh()
  }

  func refresh() {
    channel?.invokeMethod("getQueue", arguments: nil) { [weak self] result in
      guard let self,
            let list = result as? [[String: Any]] else { return }
      self.items = list
      let manager = MPPlayableContentManager.shared()
      try? manager.beginUpdates()
      try? manager.endUpdates()
    }
  }
}

extension CarPlayBridge: MPPlayableContentManagerDataSource {
  func numberOfItems(in playableContentManager: MPPlayableContentManager) -> Int {
    items.count
  }

  func playableContentManager(
    _ playableContentManager: MPPlayableContentManager,
    childItemsAt indexPath: IndexPath
  ) async throws -> [MPPlayableContentItem] {
    return items.enumerated().map { i, item in
      let ci = MPPlayableContentItem()
      ci.title = (item["title"] as? String) ?? "Bilinmeyen"
      ci.detailText = item["artist"] as? String
      ci.playbackPosition = MPPlaybackPosition(position: Double(i))
      return ci
    }
  }

  func playableContentManager(
    _ playableContentManager: MPPlayableContentManager,
    playItemAt indexPath: IndexPath
  ) async throws {
    let index = items.indices.contains(indexPath.item)
        ? (items[indexPath.item]["index"] as? Int) ?? indexPath.item
        : indexPath.item
    channel?.invokeMethod("playAt", arguments: index)
  }
}

extension CarPlayBridge: MPPlayableContentManagerDelegate {
  func playableContentManager(
    _ playableContentManager: MPPlayableContentManager,
    initiatePlaybackOfContentItemAt indexPath: IndexPath,
    completionHandler: @escaping (Error?) -> Void
  ) {
    let index = items.indices.contains(indexPath.item)
        ? (items[indexPath.item]["index"] as? Int) ?? indexPath.item
        : indexPath.item
    channel?.invokeMethod("playAt", arguments: index)
    completionHandler(nil)
  }
}
