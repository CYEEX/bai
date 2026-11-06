import Foundation

struct AngleSample: Equatable, Sendable {
    let angle: Double
    let time: TimeInterval
    var isValid: Bool { angle.isFinite && (0...180).contains(angle) && time.isFinite }
}

enum GamePhase: Equatable, Sendable {
    case setup, positioning, guessing, handoff, readyToReveal, revealed, finished
    var protectsAngle: Bool { self == .guessing || self == .handoff || self == .readyToReveal }
}

struct RoundResult: Equatable, Sendable {
    let actual: Double
    let guesses: [Int]
    var errors: [Double] { guesses.map { abs(Double($0) - actual) } }
}

struct Standing: Equatable, Sendable {
    let player: Int
    let value: Double
    let rank: Int
}

/// Deterministic rules, independent of hardware and UI. Times use a monotonic clock.
struct GameEngine {
    static let freshness: TimeInterval = 0.75
    private(set) var phase: GamePhase = .setup
    private(set) var players: [String] = []
    private(set) var roundCount = 3
    private(set) var results: [RoundResult] = []
    private(set) var guesses: [Int] = []
    private(set) var notice: String?
    private(set) var latest: AngleSample?
    private var samples: [AngleSample] = []
    private var lockedAngle: Double?
    private var driftStarted: TimeInterval?
    var playerIndex: Int { guesses.count }
    var roundNumber: Int { phase == .revealed || phase == .finished ? max(1, results.count) : results.count + 1 }
    var revealedAngle: Double? { phase == .revealed ? results.last?.actual : nil }

    mutating func begin(names: [String], rounds: Int = 3) {
        guard (2...8).contains(names.count), (1...10).contains(rounds) else { return }
        players = names.enumerated().map { index, name in
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "玩家 \(index + 1)" : String(trimmed.prefix(12))
        }
        roundCount = rounds
        results = []
        guesses = []
        lockedAngle = nil
        driftStarted = nil
        notice = nil
        phase = .positioning
    }

    mutating func receive(_ sample: AngleSample) {
        guard sample.isValid else { sensorLost("读数异常，请重新检测传感器。"); return }
        if let latest, sample.time <= latest.time { return }
        // A gap cannot be counted as stable time, even when the angles happen to match.
        if let latest, sample.time - latest.time > Self.freshness {
            sensorLost("读数中断了，这轮重新来。"); samples = []
        }
        latest = sample
        samples.append(sample)
        samples.removeAll { sample.time - $0.time > 0.65 }
        guard phase.protectsAngle, let lockedAngle else { return }
        if abs(sample.angle - lockedAngle) > 2 {
            if let driftStarted {
                if sample.time - driftStarted >= 0.5 {
                    invalidate("屏幕动了，这轮重新来。所有猜测已清空。")
                }
            } else { driftStarted = sample.time }
        } else { driftStarted = nil }
    }

    func stableAngle(at now: TimeInterval) -> Double? {
        guard let latest, now >= latest.time, now - latest.time <= Self.freshness else { return nil }
        let window = samples.filter { latest.time - $0.time <= 0.6 }
        guard window.count >= 6, let first = window.first,
              latest.time - first.time >= 0.49,
              let low = window.map(\.angle).min(), let high = window.map(\.angle).max(),
              high - low <= 1 else { return nil }
        let sorted = window.map(\.angle).sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    func isFresh(at now: TimeInterval) -> Bool {
        guard let latest else { return false }
        return now >= latest.time && now - latest.time <= Self.freshness
    }

    mutating func lock(at now: TimeInterval) {
        guard phase == .positioning, let angle = stableAngle(at: now) else { return }
        lockedAngle = angle
        guesses = []
        driftStarted = nil
        notice = nil
        phase = .guessing
    }

    mutating func submit(_ text: String, at now: TimeInterval) -> Bool {
        checkFreshness(at: now)
        guard phase == .guessing, isFresh(at: now),
              let guess = Int(text), (0...180).contains(guess) else { return false }
        guesses.append(guess)
        phase = guesses.count == players.count ? .readyToReveal : .handoff
        return true
    }

    mutating func nextPlayer() {
        guard phase == .handoff else { return }
        phase = .guessing
    }

    mutating func reveal(at now: TimeInterval) {
        checkFreshness(at: now)
        guard phase == .readyToReveal, isFresh(at: now), let lockedAngle else { return }
        // A deviation must settle back before revealing; sustained movement invalidates the round.
        guard driftStarted == nil else { return }
        results.append(RoundResult(actual: lockedAngle, guesses: guesses))
        self.lockedAngle = nil
        phase = .revealed
    }

    var canReveal: Bool { phase == .readyToReveal && driftStarted == nil }

    mutating func advance() {
        guard phase == .revealed else { return }
        guesses = []
        driftStarted = nil
        notice = nil
        samples = []
        phase = results.count >= roundCount ? .finished : .positioning
    }

    mutating func checkFreshness(at now: TimeInterval) {
        guard phase.protectsAngle, !isFresh(at: now) else { return }
        sensorLost("读数中断了，这轮重新来。所有猜测已清空。")
    }

    mutating func sensorLost(_ reason: String) {
        latest = nil
        samples = []
        if phase.protectsAngle || phase == .positioning { invalidate(reason) }
    }

    mutating func resetSampling() { latest = nil; samples = []; driftStarted = nil }

    private mutating func invalidate(_ reason: String) {
        phase = .positioning
        lockedAngle = nil
        guesses = []
        driftStarted = nil
        samples = []
        notice = reason
    }

    static func ranked(_ values: [Double]) -> [Standing] {
        values.indices.sorted { values[$0] == values[$1] ? $0 < $1 : values[$0] < values[$1] }
            .map { index in Standing(player: index, value: values[index], rank: 1 + values.filter { $0 < values[index] }.count) }
    }

    var roundStandings: [Standing] { Self.ranked(results.last?.errors ?? []) }
    var finalStandings: [Standing] {
        guard !results.isEmpty else { return [] }
        return Self.ranked(players.indices.map { index in
            results.reduce(0) { $0 + $1.errors[index] } / Double(results.count)
        })
    }
}
