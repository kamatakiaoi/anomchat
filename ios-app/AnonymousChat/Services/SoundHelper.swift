import Foundation
import AVFoundation

public class SoundHelper {
    public static let shared = SoundHelper()

    private var popPlayer: AVAudioPlayer?
    private var clickPlayer: AVAudioPlayer?

    private init() {
        if let popUrl = Bundle.main.url(forResource: "pop", withExtension: "wav") {
            popPlayer = try? AVAudioPlayer(contentsOf: popUrl)
            popPlayer?.prepareToPlay()
        }
        if let clickUrl = Bundle.main.url(forResource: "click", withExtension: "wav") {
            clickPlayer = try? AVAudioPlayer(contentsOf: clickUrl)
            clickPlayer?.prepareToPlay()
        }
    }

    public func playPop() {
        guard PreferenceManager.shared.isSoundEnabled else { return }
        popPlayer?.currentTime = 0
        popPlayer?.play()
    }

    public func playClick() {
        guard PreferenceManager.shared.isSoundEnabled else { return }
        clickPlayer?.currentTime = 0
        clickPlayer?.play()
    }
}
