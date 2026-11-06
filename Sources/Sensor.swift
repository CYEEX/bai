import Foundation
import IOKit.hid

enum SensorEvent: Sendable {
    case sample(AngleSample)
    case unavailable(String)
}

protocol AngleSource: AnyObject {
    func start(handler: @escaping @Sendable (SensorEvent) -> Void)
    func stop()
}

/// HID matching and report decoding informed by Sam Gold's LidAngleSensor (Apache-2.0).
/// See Resources/THIRD-PARTY-NOTICES.txt. All mutable HID state stays on queue.
final class HardwareAngleSource: AngleSource, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.caicaijidu.sensor", qos: .userInitiated)
    private var timer: DispatchSourceTimer?
    private var manager: IOHIDManager?
    private var device: IOHIDDevice?
    private var nextProbe: TimeInterval = 0
    private var handler: (@Sendable (SensorEvent) -> Void)?

    func start(handler: @escaping @Sendable (SensorEvent) -> Void) {
        queue.async { [self] in
            cleanup()
            self.handler = handler
            nextProbe = 0
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(5))
            timer.setEventHandler { [weak self] in self?.poll() }
            self.timer = timer
            timer.resume()
        }
    }

    func stop() { queue.async { [self] in cleanup(); handler = nil } }

    private func cleanup() {
        timer?.cancel(); timer = nil
        closeDevice()
    }

    private func closeDevice() {
        if let device { IOHIDDeviceClose(device, 0) }
        device = nil
        if let manager { IOHIDManagerClose(manager, 0) }
        manager = nil
    }

    private func discover() -> String? {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, 0)
        self.manager = manager
        let matching: [String: Any] = [kIOHIDVendorIDKey: 0x05AC, kIOHIDProductIDKey: 0x8104,
                                      kIOHIDPrimaryUsagePageKey: 0x20, kIOHIDPrimaryUsageKey: 0x8A]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
        let status = IOHIDManagerOpen(manager, 0)
        guard status == kIOReturnSuccess else {
            return "传感器访问受限（\(status)）。请在 Finder 中直接打开应用，再点重新检测。"
        }
        let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> ?? []
        for candidate in devices {
            if IOHIDDeviceOpen(candidate, 0) == kIOReturnSuccess { device = candidate; return nil }
        }
        return devices.isEmpty ? "没有找到可读取的屏幕角度传感器。这台机型可能不支持。" : "找到传感器，但暂时无法打开。请重试。"
    }

    private func poll() {
        let now = ProcessInfo.processInfo.systemUptime
        if device == nil {
            guard now >= nextProbe else { return }
            if let error = discover() {
                closeDevice(); nextProbe = now + 2
                handler?(.unavailable(error)); return
            }
        }
        guard let device else { return }
        var report = [UInt8](repeating: 0, count: 8)
        var length = report.count
        let result = IOHIDDeviceGetReport(device, kIOHIDReportTypeFeature, 1, &report, &length)
        guard result == kIOReturnSuccess, length >= 3, report[0] == 1 else {
            handler?(.unavailable("角度读取中断（\(result)）。正在重新连接。"))
            closeDevice(); nextProbe = now + 1; return
        }
        let angle = Double(UInt16(report[1]) | UInt16(report[2]) << 8)
        let sample = AngleSample(angle: angle, time: ProcessInfo.processInfo.systemUptime)
        guard sample.isValid else {
            handler?(.unavailable("传感器返回异常读数。正在重新检测。"))
            closeDevice(); nextProbe = now + 1; return
        }
        handler?(.sample(sample))
    }
}

/// Explicit demonstration source. It never falls back silently from real hardware.
final class DemoAngleSource: AngleSource, @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.caicaijidu.demo")
    private var timer: DispatchSourceTimer?
    private var angle = 90.0
    func newRound() { queue.async { [self] in angle = Double(Int.random(in: 45...125)) } }
    func start(handler: @escaping @Sendable (SensorEvent) -> Void) {
        queue.async { [self] in
            timer?.cancel()
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(50))
            timer.setEventHandler { [weak self] in
                guard let self else { return }
                handler(.sample(AngleSample(angle: self.angle, time: ProcessInfo.processInfo.systemUptime)))
            }
            self.timer = timer
            timer.resume()
        }
    }
    func stop() { queue.async { [self] in timer?.cancel(); timer = nil } }
}
