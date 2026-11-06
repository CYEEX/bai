import Foundation

/// Sound depends on movement speed only, never on the absolute hinge angle.
/// Rapid release: fully silent within 150 ms of the last detected movement.
struct MotionSoundEnvelope {
    private var previous: AngleSample?
    private var lastMovement: TimeInterval?
    private var speed = 0.0
    private var currentVolume = 0.0
    private var lastTick: TimeInterval?

    mutating func reset() { self = MotionSoundEnvelope() }
    mutating func receive(_ sample: AngleSample) {
        guard sample.isValid else { reset(); return }
        defer { previous = sample }
        guard let previous else { return }
        let dt = sample.time - previous.time
        guard dt > 0, dt <= GameEngine.freshness else { reset(); return }
        let distance = abs(sample.angle - previous.angle)
        if distance >= 0.2 {
            speed = min(160, distance / dt)
            lastMovement = sample.time
        }
    }
    mutating func output(at now: TimeInterval) -> (volume: Double, rate: Double) {
        let dt = max(0.001, min(0.05, now - (lastTick ?? (now - 0.02))))
        lastTick = now
        guard let lastMovement else { currentVolume = 0; return (0, 1) }
        let elapsed = max(0, now - lastMovement)
        guard elapsed < 0.15 else { currentVolume = 0; return (0, 1) }
        let strength = min(1, sqrt(speed / 80))
        let target = (0.20 + strength * 0.65) * exp(-max(0, elapsed - 0.025) / 0.025)
        // 15 ms attack, 25 ms exponential release. Hard stop at 150 ms.
        let response = 1 - exp(-dt / (target > currentVolume ? 0.015 : 0.025))
        currentVolume += (target - currentVolume) * response
        return (currentVolume < 0.002 ? 0 : currentVolume, 0.80 + strength * 0.30)
    }
}
