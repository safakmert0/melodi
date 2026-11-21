import Flutter
import UIKit
import AVFoundation
import Accelerate

// MARK: - Tap DSP state (real-time thread'de sadece okunur)
final class EqualizerTapState {
    var setup: vDSP_biquad_Setup?
    var gains: [Float] = Array(repeating: 0, count: 10)
    var sampleRate: Double = 44100
    var channels: Int = 2
    var interleaved: Bool = true
    var passthrough: Bool = true
}

// MARK: - 10-band parametric EQ over AVPlayer via MTAudioProcessingTap
final class EqualizerHandler: NSObject {
    static var shared: EqualizerHandler?

    private let channel: FlutterMethodChannel
    private let players = NSHashTable<AVPlayer>.weakObjects()
    private var itemObservations = NSMapTable<AVPlayer, NSArray>.weakToStrongObjects()
    private let lock = NSLock()

    private var gains: [Float] = Array(repeating: 0, count: 10)
    private var enabled = false

    private static let centerFreqs: [Float] = [
        60, 170, 310, 600, 1000, 3000, 6000, 12000, 14000, 16000,
    ]

    private init(messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(name: "com.melodi/equalizer", binaryMessenger: messenger)
        super.init()
        channel.setMethodCallHandler(handle)
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        shared = EqualizerHandler(messenger: registrar.messenger())
        installPlayerHook()
    }

    // MARK: - AVPlayer hook (registry)
    private static var hookInstalled = false

    private static func installPlayerHook() {
        guard !hookInstalled else { return }
        hookInstalled = true
        let original = #selector(AVPlayer.play)
        let swizzled = #selector(AVPlayer.melodi_play)
        guard let originalMethod = class_getInstanceMethod(AVPlayer.self, original),
              let swizzledMethod = class_getInstanceMethod(AVPlayer.self, swizzled) else { return }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    func registerPlayer(_ player: AVPlayer) {
        lock.lock()
        let isNew = !players.contains(player)
        if isNew {
            players.add(player)
        }
        lock.unlock()

        if isNew {
            let observation = player.observe(\.currentItem, options: [.new]) { [weak self] _, _ in
                DispatchQueue.main.async {
                    self?.reapplyAll()
                }
            }
            itemObservations.setObject([observation] as NSArray, forKey: player)
        }
        DispatchQueue.main.async { [weak self] in
            self?.apply(to: player)
        }
    }

    // MARK: - MethodChannel
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "setEnabled":
            let value = call.arguments as? Bool ?? false
            lock.lock()
            enabled = value
            lock.unlock()
            DispatchQueue.main.async { self.reapplyAll() }
            result(nil)

        case "setBands":
            if let arr = call.arguments as? [Double] {
                lock.lock()
                for i in 0..<min(10, arr.count) {
                    gains[i] = Float(arr[i])
                }
                lock.unlock()
                DispatchQueue.main.async { self.reapplyAll() }
            }
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func reapplyAll() {
        lock.lock()
        let all = players.allObjects
        lock.unlock()
        for player in all {
            apply(to: player)
        }
    }

    private func apply(to player: AVPlayer) {
        guard let item = player.currentItem else { return }

        lock.lock()
        let on = enabled
        let currentGains = gains
        lock.unlock()

        guard on else {
            item.audioMix = nil
            return
        }

        guard let track = item.asset.tracks(withMediaType: .audio).first else {
            item.audioMix = nil
            return
        }

        let params = AVMutableAudioMixInputParameters(track: track)

        let state = EqualizerTapState()
        state.gains = currentGains

        var callbacks = MTAudioProcessingTapCallbacks(
            version: kMTAudioProcessingTapVersion,
            clientInfo: Unmanaged.passRetained(state).toOpaque(),
            init: tapInit,
            finalize: tapFinalize
        )
        callbacks.prepare = tapPrepare
        callbacks.unprepare = tapUnprepare
        callbacks.process = tapProcess

        var tap: MTAudioProcessingTap?
        let status = MTAudioProcessingTapCreate(
            kCFAllocatorDefault,
            &callbacks,
            kMTAudioProcessingTapCreationFlag_PostEffects,
            &tap
        )

        guard status == noErr, let tap = tap else {
            Unmanaged<EqualizerTapState>.fromOpaque(Unmanaged.passUnretained(state).toOpaque()).release()
            item.audioMix = nil
            return
        }

        MTAudioProcessingTapSetStorage(tap, Unmanaged.passUnretained(state).toOpaque())

        params.audioTapProcessor = tap
        let mix = AVMutableAudioMix()
        mix.inputParameters = [params]
        item.audioMix = mix
    }

    // MARK: - MTAudioProcessingTap C callbacks
    private let tapInit: MTAudioProcessingTapInitCallback = { _, _ in }

    private let tapFinalize: MTAudioProcessingTapFinalizeCallback = { tap in
        guard let pointer = MTAudioProcessingTapGetStorage(tap) else { return }
        let state = Unmanaged<EqualizerTapState>.fromOpaque(pointer).takeUnretainedValue()
        if let setup = state.setup {
            vDSP_biquad_DestroySetup(setup)
            state.setup = nil
        }
        Unmanaged<EqualizerTapState>.fromOpaque(pointer).release()
    }

    private let tapPrepare: MTAudioProcessingTapPrepareCallback = { tap, _, format in
        guard let pointer = MTAudioProcessingTapGetStorage(tap) else { return }
        let state = Unmanaged<EqualizerTapState>.fromOpaque(pointer).takeUnretainedValue()

        state.sampleRate = format.mSampleRate
        state.channels = Int(format.mChannelsPerFrame)
        let isFloat = (format.mFormatFlags & kAudioFormatFlagIsFloat) != 0
        let isPacked = (format.mFormatFlags & kAudioFormatFlagIsPacked) != 0
        let isInterleaved = (format.mFormatFlags & kAudioFormatFlagIsNonInterleaved) == 0
        let bits = Int(format.mBitsPerChannel)

        state.interleaved = isInterleaved
        state.passthrough = !(isFloat && isPacked && bits == 32)

        if let old = state.setup {
            vDSP_biquad_DestroySetup(old)
            state.setup = nil
        }
        guard !state.passthrough else { return }
        state.setup = EqualizerHandler.makeSetup(
            gains: state.gains,
            sampleRate: Float(state.sampleRate),
            channels: state.channels,
            interleaved: state.interleaved
        )
    }

    private let tapUnprepare: MTAudioProcessingTapUnprepareCallback = { tap in
        guard let pointer = MTAudioProcessingTapGetStorage(tap) else { return }
        let state = Unmanaged<EqualizerTapState>.fromOpaque(pointer).takeUnretainedValue()
        if let setup = state.setup {
            vDSP_biquad_DestroySetup(setup)
            state.setup = nil
        }
    }

    private let tapProcess: MTAudioProcessingTapGetAudioProcessingCallback = { tap, _, frameCount, bufferListInOut, _, bufferListOut in
        guard let pointer = MTAudioProcessingTapGetStorage(tap) else { return }
        let state = Unmanaged<EqualizerTapState>.fromOpaque(pointer).takeUnretainedValue()

        let buffers = Int(bufferListInOut.mNumberBuffers)
        for i in 0..<buffers {
            let inBuf = bufferListInOut[i]
            let outBuf = bufferListOut[i]
            guard let inData = inBuf.mData, let outData = outBuf.mData else { continue }
            let byteCount = Int(inBuf.mDataByteSize)
            memcpy(outData, inData, byteCount)

            if state.passthrough { continue }
            guard let setup = state.setup else { continue }

            let floatOut = outData.assumingMemoryBound(to: Float.self)
            vDSP_biquad_Process(
                setup,
                1,
                floatOut,
                0,
                floatOut,
                0,
                vDSP_Length(frameCount)
            )
        }
    }

    // MARK: - Biquad set
    private static func makeSetup(
        gains: [Float],
        sampleRate: Float,
        channels: Int,
        interleaved: Bool
    ) -> vDSP_biquad_Setup? {
        let partCount = interleaved ? max(1, channels) : 1
        let sectionCount = gains.count
        let coefCount = sectionCount * partCount * 3

        var aCoefs = [Float](repeating: 0, count: coefCount)
        var bCoefs = [Float](repeating: 0, count: coefCount)

        for s in 0..<sectionCount {
            let (b0, b1, b2, a1, a2) = peaking(
                f0: centerFreqs[s],
                gainDb: gains[s],
                fs: sampleRate
            )
            for p in 0..<partCount {
                let idx = (s * partCount + p) * 3
                aCoefs[idx] = a1
                aCoefs[idx + 1] = a2
                aCoefs[idx + 2] = 0
                bCoefs[idx] = b0
                bCoefs[idx + 1] = b1
                bCoefs[idx + 2] = b2
            }
        }

        return aCoefs.withUnsafeBufferPointer { aPtr in
            bCoefs.withUnsafeBufferPointer { bPtr in
                vDSP_biquad_CreateBiquadSet(
                    kCFAllocatorDefault,
                    vDSP_Length(partCount),
                    1,
                    aPtr.baseAddress,
                    bPtr.baseAddress
                )
            }
        }
    }

    private static func peaking(
        f0: Float,
        gainDb: Float,
        fs: Float
    ) -> (Float, Float, Float, Float, Float) {
        guard gainDb != 0, fs > 0, f0 > 0, f0 < fs / 2 else {
            return (1, 0, 0, 0, 0)
        }
        let A = powf(10, gainDb / 40)
        let w0 = 2 * Float.pi * f0 / fs
        let sinW0 = sinf(w0)
        let cosW0 = cosf(w0)
        let alpha = sinW0 * sinh(logf(2) / 2 * 1.0 * w0 / sinW0)
        let b0 = 1 + alpha * A
        let b1 = -2 * cosW0
        let b2 = 1 - alpha * A
        let a0 = 1 + alpha / A
        let a1 = -2 * cosW0
        let a2 = 1 - alpha / A
        return (b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0)
    }
}

// MARK: - AVPlayer hook
extension AVPlayer {
    @objc func melodi_play() {
        self.melodi_play()
        EqualizerHandler.shared?.registerPlayer(self)
    }
}
