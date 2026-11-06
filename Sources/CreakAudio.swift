import AVFoundation
import Foundation

/// User-requested wood creak loop from their installed LidAngleSensor app.
/// Attribution in THIRD-PARTY-NOTICES.txt; no microphone or network use.
@MainActor
final class CreakAudioController {
    private var engine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private var speed: AVAudioUnitVarispeed?
    private var timer: Timer?
    private var envelope = MotionSoundEnvelope()
    private(set) var error: String?

    func receive(_ sample: AngleSample) {
        if engine == nil { prepare() }
        guard engine != nil else { return }
        envelope.receive(sample)
    }

    private func prepare() {
        guard let url = Bundle.main.url(forResource: "Creak", withExtension: "wav") else {
            error = "找不到音效文件"; return
        }
        do {
            let file = try AVAudioFile(forReading: url)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else { return }
            try file.read(into: buffer)
            let engine = AVAudioEngine()
            let player = AVAudioPlayerNode()
            let speed = AVAudioUnitVarispeed()
            engine.attach(player); engine.attach(speed)
            engine.connect(player, to: speed, fromBus: 0, toBus: 0, format: buffer.format)
            engine.connect(speed, to: engine.mainMixerNode, fromBus: 0, toBus: 0, format: buffer.format)
            player.volume = 0
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            try engine.start()
            player.play(at: nil)
            self.engine = engine; self.player = player; self.speed = speed
            error = nil
            timer = .scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let output = self.envelope.output(at: ProcessInfo.processInfo.systemUptime)
                    self.player?.volume = Float(output.volume)
                    self.speed?.rate = Float(output.rate)
                }
            }
        } catch { self.error = "音效暂时无法播放：\(error.localizedDescription)" }
    }

    #if DEBUG
    var debugState: (running: Bool, volume: Float, rate: Float) {
        (engine?.isRunning ?? false, player?.volume ?? 0, speed?.rate ?? 1)
    }
    #endif
    func reset() { envelope.reset(); player?.volume = 0 }
    func stop() {
        timer?.invalidate(); timer = nil
        player?.volume = 0
        player?.stop(); engine?.stop()
        player = nil; speed = nil; engine = nil
        envelope.reset()
    }
}
