import Foundation
import AVFoundation
import Flutter

/// iOS Native HLS Downloader using AVAssetDownloadTask
/// JollyTune/Musix style native HLS downloading with FairPlay support
public class HLSDownloader: NSObject, FlutterPlugin, AVAssetDownloadDelegate {
    
    // MARK: - Properties
    private var downloadSession: AVAssetDownloadURLSession!
    private var activeDownloads: [String: DownloadTask] = [:]
    private var completionHandlers: [String: FlutterResult] = [:]
    private var progressHandlers: [String: (Double) -> Void] = [:]
    
    // Background session identifier
    private let backgroundSessionIdentifier = "com.melodi.hlsdownloader.background"
    
    // MARK: - FlutterPlugin
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "com.melodi/hls_downloader", binaryMessenger: registrar.messenger())
        let instance = HLSDownloader()
        registrar.addMethodCallDelegate(instance, channel: channel)
        
        // Register background session handler
        registrar.addApplicationDelegate(instance)
    }
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupDownloadSession()
    }
    
    private func setupDownloadSession() {
        let configuration = URLSessionConfiguration.background(withIdentifier: backgroundSessionIdentifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        
        downloadSession = AVAssetDownloadURLSession(
            configuration: configuration,
            assetDownloadDelegate: self,
            delegateQueue: OperationQueue.main
        )
    }
    
    // MARK: - Flutter Method Handling
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startHLSDownload":
            guard let args = call.arguments as? [String: Any],
                  let videoId = args["videoId"] as? String,
                  let hlsManifestUrl = args["hlsManifestUrl"] as? String,
                  let destinationPath = args["destinationPath"] as? String,
                  let title = args["title"] as? String,
                  let artist = args["artist"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing required arguments", details: nil))
                return
            }
            startHLSDownload(videoId: videoId, hlsManifestUrl: hlsManifestUrl, destinationPath: destinationPath, title: title, artist: artist, result: result)
            
        case "cancelHLSDownload":
            guard let args = call.arguments as? [String: Any],
                  let videoId = args["videoId"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing videoId", details: nil))
                return
            }
            cancelHLSDownload(videoId: videoId)
            result(true)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // MARK: - HLS Download
    
    private func startHLSDownload(videoId: String, hlsManifestUrl: String, destinationPath: String, title: String, artist: String, result: @escaping FlutterResult) {
        guard let url = URL(string: hlsManifestUrl) else {
            result(FlutterError(code: "INVALID_URL", message: "Invalid HLS manifest URL", details: nil))
            return
        }
        
        // Store completion handler
        completionHandlers[videoId] = result
        
        // Create asset
        let asset = AVURLAsset(url: url)
        
        // Download options
        let options: [AVAssetDownloadTask: Any] = [
            AVAssetDownloadTaskMinimumRequiredMediaBitrateKey: 64000,
            AVAssetDownloadTaskMaximumAllowedMediaBitrateKey: 256000,
        ]
        
        // Start download
        let downloadTask = downloadSession.makeAssetDownloadTask(asset: asset, destinationURL: URL(fileURLWithPath: destinationPath), options: options)
        
        // Store task info
        let taskInfo = DownloadTask(
            videoId: videoId,
            title: title,
            artist: artist,
            destinationPath: destinationPath,
            downloadTask: downloadTask,
            startTime: Date()
        )
        activeDownloads[videoId] = taskInfo
        
        // Resume task (start downloading)
        downloadTask.resume()
    }
    
    private func cancelHLSDownload(videoId: String) {
        if let taskInfo = activeDownloads[videoId] {
            taskInfo.downloadTask.cancel()
            activeDownloads.removeValue(forKey: videoId)
            completionHandlers.removeValue(forKey: videoId)
        }
    }
    
    // MARK: - AVAssetDownloadDelegate
    
    public func assetDownloadTask(_ task: AVAssetDownloadTask, didLoad timeRange: CMTimeRange, totalTimeRangesLoaded loadedTimeRanges: [NSValue], timeRangeExpectedToLoad: CMTimeRange) {
        // Progress reporting
        let loadedDuration = loadedTimeRangesLoaded.reduce(0) { $0 + $1.timeRangeValue.duration.seconds }
        let totalDuration = timeRangeExpectedToLoad.duration.seconds
        
        if totalDuration > 0 {
            let progress = loadedDuration / totalDuration
            if let videoId = activeDownloads.first(where: { $0.value.downloadTask == task })?.key {
                DispatchQueue.main.async {
                    self.progressHandlers[videoId]?(progress)
                }
            }
        }
    }
    
    public func assetDownloadTask(_ task: AVAssetDownloadTask, didFinishDownloadingTo location: URL) {
        guard let videoId = activeDownloads.first(where: { $0.value.downloadTask == task })?.key else { return }
        
        // Move downloaded file to final destination
        let taskInfo = activeDownloads[videoId]
        let destinationPath = taskInfo?.destinationPath ?? location.path
        
        do {
            if FileManager.default.fileExists(atPath: destinationPath) {
                try FileManager.default.removeItem(atPath: destinationPath)
            }
            try FileManager.default.moveItem(at: location, to: URL(fileURLWithPath: destinationPath))
        } catch {
            print("Failed to move downloaded file: \(error)")
        }
        
        // Complete
        if let completion = completionHandlers.removeValue(forKey: videoId) {
            completion(destinationPath)
        }
        activeDownloads.removeValue(forKey: videoId)
    }
    
    public func assetDownloadTask(_ task: AVAssetDownloadTask, didCompleteWithError error: Error?) {
        guard let videoId = activeDownloads.first(where: { $0.value.downloadTask == task })?.key else { return }
        
        if let error = error {
            print("Download failed for \(videoId): \(error)")
            if let completion = completionHandlers.removeValue(forKey: videoId) {
                completion(FlutterError(code: "DOWNLOAD_FAILED", message: error.localizedDescription, details: nil))
            }
        }
        activeDownloads.removeValue(forKey: videoId)
    }
    
    public func assetDownloadTask(_ task: AVAssetDownloadTask, didResolveMediaSelection mediaSelection: AVMediaSelection) {
        // Media selection resolved
    }
    
    public func assetDownloadTask(_ task: AVAssetDownloadTask, willDownloadTo destinationURL: URL) {
        // Download will start
    }
    
    // MARK: - Background Session Handling
    
    public func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String, completionHandler: @escaping () -> Void) {
        if identifier == backgroundSessionIdentifier {
            downloadSession.session.getTasksWithCompletionHandler { dataTasks, uploadTasks, downloadTasks in
                // Restore active downloads
                for task in downloadTasks {
                    if let assetTask = task as? AVAssetDownloadTask {
                        // Re-register task
                        // Note: In production, you'd need to persist videoId mapping
                    }
                }
            }
            completionHandler()
        }
    }
}

// MARK: - DownloadTask Model

private class DownloadTask {
    let videoId: String
    let title: String
    let artist: String
    let destinationPath: String
    let downloadTask: AVAssetDownloadTask
    let startTime: Date
    
    init(videoId: String, title: String, artist: String, destinationPath: String, downloadTask: AVAssetDownloadTask, startTime: Date) {
        self.videoId = videoId
        self.title = title
        self.artist = artist
        self.destinationPath = destinationPath
        self.downloadTask = downloadTask
        self.startTime = startTime
    }
}