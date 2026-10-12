import Foundation
import AVFoundation

public class AudioPlayerManager: NSObject, ObservableObject {
    public static let shared = AudioPlayerManager()

    private var player: AVPlayer?
    private var timeObserver: Any?

    @Published public var currentUrl: String?
    public var currentPlayingUrl: String? { return currentUrl }
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0

    private override init() {
        super.init()
    }

    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    public func playOrPause(urlStr: String) {
        if currentUrl == urlStr {
            if isPlaying {
                pause()
            } else {
                setupAudioSession()
                player?.play()
                isPlaying = true
            }
            return
        }

        stop()
        guard let url = URL(string: urlStr) else { return }
        currentUrl = urlStr

        setupAudioSession()
        
        // Optimizations for FLAC/WAV/OGG fast loading and chunk buffering
        let asset = AVURLAsset(url: url, options: [
            "AVURLAssetPreferPreciseDurationAndTimingKey": false
        ])
        
        let item = AVPlayerItem(asset: asset)
        // Buffer minimal initial slice (1.0s) so uncompressed WAV/FLAC starts in < 100ms
        item.preferredForwardBufferDuration = 1.0
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = true
        
        let p = AVPlayer(playerItem: item)
        // Crucial: do NOT wait for multi-megabyte buffers before starting audio
        p.automaticallyWaitsToMinimizeStalling = false
        self.player = p
        p.play()
        isPlaying = true

        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd), name: .AVPlayerItemDidPlayToEndTime, object: item)

        // 0.1s observer gives butter-smooth scrubber response without UI lag
        timeObserver = p.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
            if let d = self.player?.currentItem?.duration.seconds, !d.isNaN && d > 0 {
                self.duration = d
            }
        }
    }

    public func pause() {
        player?.pause()
        isPlaying = false
    }

    public func stop() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        player?.pause()
        player = nil
        currentUrl = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }

    public func seek(toSeconds: Double) {
        guard let player = player else { return }
        let clamped = max(0, min(duration > 0 ? duration : 3600, toSeconds))
        self.currentTime = clamped
        let cmTime = CMTime(seconds: clamped, preferredTimescale: 600)
        player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
    }

    public func seek(to progress: Double) {
        guard duration > 0 else { return }
        let target = max(0, min(1.0, progress)) * duration
        seek(toSeconds: target)
    }

    public func seekRelative(_ delta: Double) {
        seek(toSeconds: currentTime + delta)
    }

    @objc private func playerItemDidReachEnd() {
        isPlaying = false
        currentTime = 0
    }
}
