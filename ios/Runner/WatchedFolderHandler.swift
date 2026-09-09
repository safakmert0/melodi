import Flutter
import UIKit
import UniformTypeIdentifiers

// MARK: - Watched Folder Handler (security-scoped bookmarks)
//
// iOS kum havuzu: uygulama kutusu disindaki bir klasor, secim aninda verilen
// gecici erisim disinda okunamaz. Klasoru "izlemek" (kopyalamadan) icin:
//  1. UIDocumentPicker ile klasor sectirilir,
//  2. security-scoped bookmark UserDefaults'a kaydedilir,
//  3. her acilista/taramada bookmark cozulup startAccessingSecurityScopedResource
//     ile erisim yeniden alinir, oturum boyunca tutulur.
//
// Kanal: com.melodi/watched_folders
//   pickFolder     -> {"path": String, "name": String} | nil (iptal)
//   resolveFolders -> {"folders": [{"key": String, "path": String}]}
//   removeFolder   {path} -> Bool
//   clearFolders   -> Bool
class WatchedFolderHandler: NSObject {
    private let channel: FlutterMethodChannel
    private let defaultsKey = "melodi.watchedFolderBookmarks"

    // Oturum boyunca tutulan erisimler (key -> URL). start/stop dengeli.
    private var accessedURLs: [String: URL] = [:]

    private var pendingPickResult: FlutterResult?
    private var pickerDelegate: WatchedFolderPickerDelegate?

    init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.melodi/watched_folders", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler(handle)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "pickFolder":
            pickFolder(result: result)
        case "resolveFolders":
            result(["folders": resolveFolders()])
        case "removeFolder":
            guard let args = call.arguments as? [String: Any],
                  let path = args["path"] as? String else {
                result(false)
                return
            }
            result(removeFolder(path: path))
        case "clearFolders":
            clearFolders()
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Klasor secimi

    private func pickFolder(result: @escaping FlutterResult) {
        DispatchQueue.main.async {
            guard self.pendingPickResult == nil else {
                result(FlutterError(code: "pick_in_progress",
                                    message: "Folder picker already open",
                                    details: nil))
                return
            }
            guard let presenter = self.topViewController() else {
                result(FlutterError(code: "no_presenter",
                                    message: "No view controller to present picker",
                                    details: nil))
                return
            }
            let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
            picker.allowsMultipleSelection = false
            let delegate = WatchedFolderPickerDelegate(
                onPick: { [weak self] url in self?.finishPick(url: url) },
                onCancel: { [weak self] in self?.finishPick(url: nil) }
            )
            self.pickerDelegate = delegate
            picker.delegate = delegate
            self.pendingPickResult = result
            presenter.present(picker, animated: true)
        }
    }

    private func finishPick(url: URL?) {
        guard let result = pendingPickResult else { return }
        pendingPickResult = nil
        pickerDelegate = nil
        guard let url = url else {
            result(nil) // iptal
            return
        }
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        // Proje karari: yalnizca yerel (On My iPhone) klasorler izlenir.
        // iCloud ogeleri indirilmeyi bekleyebilir, tasinabilir; sessizce
        // atlamak yerine secimi reddet.
        if let values = try? url.resourceValues(forKeys: [.isUbiquitousItemKey]),
           values.isUbiquitousItem == true {
            result(FlutterError(code: "icloud_not_supported",
                                message: "iCloud klasorleri izlenmiyor; Dosyalar > iPhone'umda altindan yerel bir klasor sec",
                                details: nil))
            return
        }
        do {
            let bookmark = try url.bookmarkData(options: [.withSecurityScope],
                                                 includingResourceValuesForKeys: nil,
                                                 relativeTo: nil)
            var stored = loadBookmarks()
            stored[url.standardized.path] = bookmark
            saveBookmarks(stored)
            result(["path": url.standardized.path,
                    "name": url.lastPathComponent])
        } catch {
            result(FlutterError(code: "bookmark_failed",
                                message: error.localizedDescription,
                                details: nil))
        }
    }

    // MARK: - Bookmark cozumu

    private func resolveFolders() -> [[String: String]] {
        var stored = loadBookmarks()
        var out: [[String: String]] = []
        var changed = false
        for (key, data) in stored {
            var stale = false
            guard let url = try? URL(resolvingBookmarkData: data,
                                     options: [.withSecurityScope, .withoutUI],
                                     relativeTo: nil,
                                     bookmarkDataIsStale: &stale) else {
                stored.removeValue(forKey: key)
                changed = true
                continue
            }
            if stale {
                // Yenilemeyi dene, olmazsa kaydi dusur.
                if let fresh = try? url.bookmarkData(options: [.withSecurityScope],
                                                     includingResourceValuesForKeys: nil,
                                                     relativeTo: nil) {
                    stored[key] = fresh
                    changed = true
                } else {
                    stored.removeValue(forKey: key)
                    stopAccess(for: key)
                    changed = true
                    continue
                }
            }
            let resolvedPath = url.standardized.path
            if accessedURLs[key] == nil {
                if url.startAccessingSecurityScopedResource() {
                    accessedURLs[key] = url
                } else {
                    continue
                }
            }
            out.append(["key": key, "path": resolvedPath])
        }
        if changed { saveBookmarks(stored) }
        // Artik kaydi olmayan erisimleri birak.
        for key in Array(accessedURLs.keys) where stored[key] == nil {
            stopAccess(for: key)
        }
        return out
    }

    private func removeFolder(path: String) -> Bool {
        var stored = loadBookmarks()
        let norm = (path as NSString).standardizingPath
        var removedKeys = stored.keys.filter { $0 == norm }
        // Cozulmus yolu tutan kayit da olabilir (klasor tasinmissa).
        if removedKeys.isEmpty {
            for entry in resolveFolders() where entry["path"] == norm {
                if let key = entry["key"] { removedKeys.append(key) }
            }
        }
        guard !removedKeys.isEmpty else { return false }
        for key in removedKeys {
            stored.removeValue(forKey: key)
            stopAccess(for: key)
        }
        saveBookmarks(stored)
        stopAccess(for: norm)
        return true
    }

    private func clearFolders() {
        for key in Array(accessedURLs.keys) { stopAccess(for: key) }
        UserDefaults.standard.removeObject(forKey: defaultsKey)
    }

    private func stopAccess(for key: String) {
        if let url = accessedURLs.removeValue(forKey: key) {
            url.stopAccessingSecurityScopedResource()
        }
    }

    // MARK: - Yardimcilar

    private func loadBookmarks() -> [String: Data] {
        (UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Data]) ?? [:]
    }

    private func saveBookmarks(_ bookmarks: [String: Data]) {
        UserDefaults.standard.set(bookmarks, forKey: defaultsKey)
    }

    private func topViewController() -> UIViewController? {
        var root = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        while let presented = root?.presentedViewController { root = presented }
        return root
    }
}

// UIDocumentPickerDelegate ayri sinif olmali (zayif referans dongusu yok).
private class WatchedFolderPickerDelegate: NSObject, UIDocumentPickerDelegate {
    private let onPick: (URL) -> Void
    private let onCancel: () -> Void

    init(onPick: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
        self.onPick = onPick
        self.onCancel = onCancel
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        if let url = urls.first {
            onPick(url)
        } else {
            onCancel()
        }
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        onCancel()
    }
}
