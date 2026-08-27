import SwiftUI
import AVKit
import Combine

public struct VideoPlayerView: View {
    public let videoUrl: URL
    @Environment(\.dismiss) var dismiss

    @State private var player: AVPlayer?
    @State private var isLandscape: Bool = false
    @State private var isPlaying: Bool = true
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var isMuted: Bool = false
    @State private var showControls: Bool = true
    @State private var timeObserverToken: Any?
    @State private var controlsTimer: Timer?
    @State private var isDraggingSlider: Bool = false
    @State private var dragOffset: CGSize = .zero

    public init(videoUrl: URL) {
        self.videoUrl = videoUrl
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()

                // Video Surface
                if let player = player {
                    NativeVideoRepresentable(player: player)
                        .ignoresSafeArea()
                        .onTapGesture {
                            toggleControls()
                        }
                } else {
                    ProgressView().tint(.white)
                }

                // Controls Overlay
                if showControls {
                    ZStack {
                        // Background gradient for readability
                        VStack {
                            LinearGradient(
                                gradient: Gradient(colors: [Color.black.opacity(0.75), Color.clear]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 90)

                            Spacer()

                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.85)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 110)
                        }
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                        VStack(spacing: 0) {
                            // Top Bar
                            HStack(spacing: 16) {
                                Button(action: closePlayer) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 26))
                                            .foregroundColor(.white)
                                    }
                                    .padding(10)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                                }

                                Spacer()

                                // Rotate Landscape / Portrait Toggle
                                Button(action: toggleOrientation) {
                                    HStack(spacing: 6) {
                                        Image(systemName: isLandscape ? "iphone.portrait" : "iphone.landscape")
                                            .font(.system(size: 16, weight: .bold))
                                        Text(isLandscape ? "Portrait" : "Landscape")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.55))
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, isLandscape ? 12 : 20)

                            Spacer()

                            // Center Playback Action Controls (Rewind 10s, Play/Pause, Forward 10s)
                            HStack(spacing: 40) {
                                Button(action: { seekRelative(-10) }) {
                                    Image(systemName: "gobackward.10")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(Color.black.opacity(0.45))
                                        .clipShape(Circle())
                                }

                                Button(action: togglePlayPause) {
                                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.system(size: 64))
                                        .foregroundColor(.white)
                                }

                                Button(action: { seekRelative(10) }) {
                                    Image(systemName: "goforward.10")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(Color.black.opacity(0.45))
                                        .clipShape(Circle())
                                }
                            }

                            Spacer()

                            // Bottom Bar: Progress Slider, Duration, Volume Mute
                            VStack(spacing: 6) {
                                // Slider
                                Slider(
                                    value: Binding(
                                        get: { currentTime },
                                        set: { val in
                                            currentTime = val
                                            seek(to: val)
                                        }
                                    ),
                                    in: 0...max(duration, 0.1)
                                )
                                .accentColor(Color(hex: "#38BDF8"))

                                HStack {
                                    Text(formatTime(currentTime))
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(.white)

                                    Spacer()

                                    Button(action: toggleMute) {
                                        Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                            .font(.system(size: 16))
                                            .foregroundColor(.white)
                                    }
                                    .padding(.trailing, 8)

                                    Text(formatTime(duration))
                                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                                        .foregroundColor(Color(hex: "#A1A1AA"))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, isLandscape ? 16 : 28)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .offset(y: dragOffset.height > 0 ? dragOffset.height : 0)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        if gesture.translation.height > 0 {
                            dragOffset = gesture.translation
                        }
                    }
                    .onEnded { gesture in
                        if gesture.translation.height > 120 {
                            closePlayer()
                        } else {
                            withAnimation(.spring()) {
                                dragOffset = .zero
                            }
                        }
                    }
            )
        }
        .statusBar(hidden: isLandscape || !showControls)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            teardownPlayer()
            restorePortraitOrientation()
        }
    }

    // MARK: - Player Setup & Teardown
    private func setupPlayer() {
        if player == nil {
            let p = AVPlayer(url: videoUrl)
            self.player = p
            p.isMuted = isMuted

            let interval = CMTime(seconds: 0.25, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserverToken = p.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak p] time in
                if !self.isDraggingSlider {
                    self.currentTime = time.seconds
                }
                if let item = p?.currentItem, item.duration.isValid && !item.duration.isIndefinite {
                    self.duration = item.duration.seconds
                }
            }

            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: p.currentItem, queue: .main) { _ in
                self.player?.seek(to: .zero)
                self.isPlaying = false
                self.showControls = true
            }

            p.play()
            self.isPlaying = true
            resetControlsTimer()
        }
    }

    private func teardownPlayer() {
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        player?.pause()
        player = nil
        controlsTimer?.invalidate()
    }

    private func closePlayer() {
        restorePortraitOrientation()
        teardownPlayer()
        dismiss()
    }

    // MARK: - Orientation Management
    private func toggleOrientation() {
        isLandscape.toggle()
        applyOrientation(isLandscape: isLandscape)
    }

    private func applyOrientation(isLandscape: Bool) {
        if #available(iOS 16.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                let mask: UIInterfaceOrientationMask = isLandscape ? .landscapeRight : .portrait
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: mask)) { error in
                    print("Geometry update notice: \(error.localizedDescription)")
                }
            }
        } else {
            let val = isLandscape ? UIInterfaceOrientation.landscapeRight.rawValue : UIInterfaceOrientation.portrait.rawValue
            UIDevice.current.setValue(val, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    private func restorePortraitOrientation() {
        if #available(iOS 16.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in }
            }
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }

    // MARK: - Playback Controls
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
    }

    private func seekRelative(_ delta: Double) {
        let target = max(0, min(duration, currentTime + delta))
        seek(to: target)
        currentTime = target
        resetControlsTimer()
    }

    private func toggleMute() {
        isMuted.toggle()
        player?.isMuted = isMuted
        resetControlsTimer()
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
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
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
