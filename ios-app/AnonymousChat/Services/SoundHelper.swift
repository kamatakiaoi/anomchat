import Foundation
import AVFoundation

public class SoundHelper {
    public static let shared = SoundHelper()

    private var popPlayer: AVAudioPlayer?
    private var clickPlayer: AVAudioPlayer?

    private init() {
        setupAudioSession()
        if let popUrl = Bundle.main.url(forResource: "pop", withExtension: "wav") {
            popPlayer = try? AVAudioPlayer(contentsOf: popUrl)
            popPlayer?.prepareToPlay()
        }
        if let clickUrl = Bundle.main.url(forResource: "click", withExtension: "wav") {
            clickPlayer = try? AVAudioPlayer(contentsOf: clickUrl)
            clickPlayer?.prepareToPlay()
        }
    }

    private func setupAudioSession() {
        do {
            // Category .playback overrides the hardware silent switch so sounds are audible
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("SoundHelper audio session setup notice: \(error.localizedDescription)")
        }
    }

    public func playPop() {
        guard PreferenceManager.shared.isSoundEnabled else { return }
        setupAudioSession()
        popPlayer?.currentTime = 0
        popPlayer?.play()
    }

    public func playClick() {
        guard PreferenceManager.shared.isSoundEnabled else { return }
        setupAudioSession()
        clickPlayer?.currentTime = 0
        clickPlayer?.play()
    }
}
