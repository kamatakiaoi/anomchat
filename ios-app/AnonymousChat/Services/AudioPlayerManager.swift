import Foundation
import AVFoundation

public class AudioPlayerManager: NSObject, ObservableObject {
    public static let shared = AudioPlayerManager()

    private var player: AVPlayer?
    private var timeObserver: Any?

    @Published public var currentUrl: String?
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0
    @Published public var duration: Double = 0

    private override init() {
        super.init()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    public func playOrPause(urlStr: String) {
        if currentUrl == urlStr {
            if isPlaying {
                pause()
            } else {
                player?.play()
                isPlaying = true
            }
            return
        }

        stop()
        guard let url = URL(string: urlStr) else { return }
        currentUrl = urlStr

        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.play()
        isPlaying = true

        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidReachEnd), name: .AVPlayerItemDidPlayToEndTime, object: item)

        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
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

    public func seek(to progress: Double) {
        guard let player = player, duration > 0 else { return }
        let target = duration * progress
        let cmTime = CMTime(seconds: target, preferredTimescale: 600)
        player.seek(to: cmTime)
    }

    @objc private func playerItemDidReachEnd() {
        isPlaying = false
        currentTime = 0
    }
}
