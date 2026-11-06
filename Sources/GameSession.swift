import SwiftUI
import AppKit
import Observation

@MainActor @Observable
final class GameSession {
    private(set) var game = GameEngine()
    private(set) var demo = false
    private(set) var sensorMessage = "正在寻找屏幕角度传感器…"
    private(set) var connected = false
    private(set) var now = ProcessInfo.processInfo.systemUptime
    private(set) var audioMessage: String?
    var names = ["玩家 1", "玩家 2", "玩家 3", "玩家 4", "玩家 5", "玩家 6", "玩家 7", "玩家 8"]
    var soundEnabled = true
    @ObservationIgnored private let audio = CreakAudioController()
    var playerCount = 2
    var rounds = 3
    @ObservationIgnored private var source: AngleSource?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var heartbeat: Timer?
    @ObservationIgnored private var observers: [NSObjectProtocol] = []
    @ObservationIgnored private var suspended = false

    init(startSensor: Bool = true) {
        if startSensor {
            connect()
            heartbeat = .scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            let center = NSWorkspace.shared.notificationCenter
            for name in [NSWorkspace.willSleepNotification, NSWorkspace.screensDidSleepNotification] {
                observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.sleep() }
                })
            }
            for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
                observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.wake() }
                })
            }
        }
    }

    #if DEBUG
    init(previewGame: GameEngine) {
        game = previewGame
        connected = true
        sensorMessage = ""
    }
    #endif

    var canLock: Bool { connected && game.stableAngle(at: now) != nil }
    var isSetup: Bool { game.phase == .setup }
    var statusLabel: String {
        if demo { return "演示模式 · 使用虚拟角度" }
        return connected ? "真实传感器已连接" : "传感器未就绪"
    }

    func connect() {
        generation += 1
        let current = generation
        source?.stop()
        audio.stop()
        game.sensorLost("正在重新检测，这轮重新来。")
        connected = false
        sensorMessage = "正在寻找屏幕角度传感器…"
        let newSource: AngleSource = demo ? DemoAngleSource() : HardwareAngleSource()
        source = newSource
        newSource.start { [weak self] event in
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == current, !self.suspended else { return }
                self.now = ProcessInfo.processInfo.systemUptime
                switch event {
                case .sample(let sample):
                    self.connected = true
                    self.sensorMessage = self.demo ? "虚拟读数仅供体验流程，不反映屏幕位置。" : "传感器正常，猜测时请保持屏幕位置。"
                    self.game.receive(sample)
                    if self.soundEnabled && !self.demo {
                        self.audio.receive(sample)
                        self.audioMessage = self.audio.error
                    }
                case .unavailable(let reason):
                    self.connected = false
                    self.audio.reset()
                    self.sensorMessage = reason
                    self.game.sensorLost(reason)
                }
            }
        }
    }

    private func tick() {
        now = ProcessInfo.processInfo.systemUptime
        game.checkFreshness(at: now)
        if connected && !game.isFresh(at: now) {
            connected = false
            audio.reset()
            sensorMessage = "读数已中断，请重新检测。"
        }
    }

    private func sleep() {
        audio.stop()
        suspended = true
        generation += 1
        source?.stop()
        connected = false
        sensorMessage = "电脑休眠了，唤醒后会重新检测。"
        game.sensorLost("电脑休眠了，这轮重新来。所有猜测已清空。")
    }

    private func wake() {
        guard suspended else { return }
        suspended = false
        connect()
    }

    func setDemo(_ enabled: Bool) {
        guard isSetup, enabled != demo else { return }
        demo = enabled
        game.resetSampling()
        connect()
    }

    func toggleSound() {
        soundEnabled.toggle()
        audioMessage = nil
        if !soundEnabled { audio.stop() }
    }

    func begin() {
        game.begin(names: Array(names.prefix(playerCount)), rounds: rounds)
        newDemoRound()
    }
    func lock() { game.lock(at: ProcessInfo.processInfo.systemUptime) }
    func submit(_ text: String) -> Bool { game.submit(text, at: ProcessInfo.processInfo.systemUptime) }
    func nextPlayer() { game.nextPlayer() }
    func reveal() { game.reveal(at: ProcessInfo.processInfo.systemUptime) }
    func advance() {
        game.advance()
        if game.phase == .positioning { newDemoRound() }
    }
    func returnToSetup() {
        game = GameEngine()
    }
    func replay() { begin() }
    private func newDemoRound() {
        guard let demoSource = source as? DemoAngleSource else { return }
        game.resetSampling()
        demoSource.newRound()
    }
}
