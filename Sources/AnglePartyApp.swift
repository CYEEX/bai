import SwiftUI
import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct AnglePartyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var session: GameSession

    init() {
        if CommandLine.arguments.contains("--diagnose") {
            Self.diagnose()
            exit(0)
        }
        let session = GameSession()
        if CommandLine.arguments.contains("--demo") { session.setDemo(true) }
        _session = State(initialValue: session)
    }

    var body: some Scene {
        Window("掰", id: "party") {
            ContentView(session: session)
        }
        .defaultSize(width: 1100, height: 800)
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .help) {
                Button("打开使用说明") {
                    if let url = Bundle.main.url(forResource: "使用说明", withExtension: "md") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
    }

    private static func diagnose() {
        let duration = 5.0
        let semaphore = DispatchSemaphore(value: 0)
        let source = HardwareAngleSource()
        // Callback runs on one serial sensor queue, so this state is never raced.
        final class ProbeState: @unchecked Sendable { var count = 0; var low = 180.0; var high = 0.0 }
        let state = ProbeState()
        print("掰 · 真实角度诊断（5 秒）")
        source.start { event in
            switch event {
            case .sample(let sample):
                state.count += 1
                state.low = min(state.low, sample.angle)
                state.high = max(state.high, sample.angle)
                if state.count % 10 == 1 { print("有效读数：\(sample.angle)°") }
            case .unavailable(let message): print(message)
            }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + duration) { semaphore.signal() }
        semaphore.wait()
        source.stop()
        // Snapshot on the same queue via a final one-shot diagnostic is unnecessary;
        // output counts are intentionally not read from another thread.
        print("诊断结束。请以以上有效读数判断是否读通。")
    }
}
