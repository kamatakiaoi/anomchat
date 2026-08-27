import SwiftUI
import AVKit

public struct InlineVideoPlayerView: View {
    public let videoUrl: URL
    public var onExpandFullscreen: () -> Void

    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timeObserverToken: Any?
    @State private var isMuted: Bool = false
    @State private var showControls: Bool = true
    @State private var controlsTimer: Timer?

    public init(videoUrl: URL, onExpandFullscreen: @escaping () -> Void) {
        self.videoUrl = videoUrl
        self.onExpandFullscreen = onExpandFullscreen
    }

    public var body: some View {
        ZStack {
            Color.black

            if let player = player {
                NativeVideoRepresentable(player: player)
                    .onTapGesture {
                        toggleControls()
                    }
            } else {
                ZStack {
                    Color(hex: "#18181B")
                    ProgressView().tint(.white)
                }
            }

            // Controls Overlay
            if showControls {
                VStack {
                    // Top Right: Fullscreen Expansion Button
                    HStack {
                        Spacer()
                        Button(action: {
                            player?.pause()
                            isPlaying = false
                            onExpandFullscreen()
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.65))
                                .clipShape(Circle())
                        }
                        .padding(8)
                    }

                    Spacer()

                    // Center Play/Pause Overlay
                    Button(action: togglePlayPause) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .padding(14)
                            .background(Color.black.opacity(0.65))
                            .clipShape(Circle())
                    }

                    Spacer()

                    // Bottom Bar: Play/Pause, Progress Bar, Time, Mute
                    HStack(spacing: 8) {
                        Button(action: togglePlayPause) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }

                        // Seek Slider
                        Slider(
                            value: Binding(
                                get: { currentTime },
                                set: { seek(to: $0) }
                            ),
                            in: 0...max(duration, 0.1)
                        )
                        .accentColor(Color(hex: "#38BDF8"))

                        // Time
                        Text("\(formatTime(currentTime)) / \(formatTime(duration))")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))

                        // Mute
                        Button(action: toggleMute) {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.85)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                .transition(.opacity)
            }
        }
        .frame(height: 200)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#27272A"), lineWidth: 1)
        )
        .clipped()
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            teardownPlayer()
        }
    }

    private func setupPlayer() {
        if player == nil {
            let p = AVPlayer(url: videoUrl)
            self.player = p
            p.isMuted = isMuted

            let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserverToken = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak p] time in
                self.currentTime = time.seconds
                if let item = p?.currentItem, item.duration.isValid && !item.duration.isIndefinite {
                    self.duration = item.duration.seconds
                }
            }

            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main) { _ in
                self.player?.seek(to: .zero)
                self.isPlaying = false
                self.showControls = true
            }
        }
    }

    private func teardownPlayer() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil
        isPlaying = false
        controlsTimer?.invalidate()
    }

    private func togglePlayPause() {
        guard let p = player else { return }
        if isPlaying {
            p.pause()
            isPlaying = false
            showControls = true
            controlsTimer?.invalidate()
        } else {
            p.play()
            isPlaying = true
            resetControlsTimer()
        }
    }

    private func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
        currentTime = seconds
    }

    private func toggleMute() {
        isMuted.toggle()
        player?.isMuted = isMuted
    }

    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls.toggle()
        }
        if showControls && isPlaying {
            resetControlsTimer()
        }
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                if self.isPlaying {
                    self.showControls = false
                }
            }
        }
    }

    private func formatTime(_ sec: Double) -> String {
        guard sec.isFinite && !sec.isNaN && sec >= 0 else { return "00:00" }
        let total = Int(sec)
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }
}

public struct NativeVideoRepresentable: UIViewControllerRepresentable {
    public let player: AVPlayer

    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        return controller
    }

    public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}
