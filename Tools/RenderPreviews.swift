import AppKit
import SwiftUI

@main
struct RenderPreviews {
    @MainActor static func main() async throws {
        let destination = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let app = NSApplication.shared
        app.setActivationPolicy(.prohibited)
        let names = ["小陈", "小李", "阿宁", "小王", "小赵", "小林", "小周", "小吴"]
        let setupGame = GameEngine()
        var guessingGame = GameEngine()
        guessingGame.begin(names: Array(names.prefix(4)))
        for i in 0..<13 { guessingGame.receive(AngleSample(angle: 112, time: 100 + Double(i) * 0.05)) }
        guessingGame.lock(at: 100.6)
        var resultGame = guessingGame
        for guess in [110, 106, 127, 112] {
            _ = resultGame.submit(String(guess), at: 100.6)
            resultGame.nextPlayer()
        }
        resultGame.reveal(at: 100.6)
        var manyGame = GameEngine()
        manyGame.begin(names: names, rounds: 1)
        for i in 0..<13 { manyGame.receive(AngleSample(angle: 112, time: 100 + Double(i) * 0.05)) }
        manyGame.lock(at: 100.6)
        for guess in [110, 106, 127, 112, 90, 105, 120, 117] {
            _ = manyGame.submit(String(guess), at: 100.6)
            manyGame.nextPlayer()
        }
        manyGame.reveal(at: 100.6)
        manyGame.advance()
        for (name, game, size, scheme) in [
            ("开局-深色", setupGame, NSSize(width: 1100, height: 800), ColorScheme.dark),
            ("开局-浅色", setupGame, NSSize(width: 1100, height: 800), ColorScheme.light),
            ("猜测-浅色", guessingGame, NSSize(width: 1100, height: 800), ColorScheme.light),
            ("揭晓-深色", resultGame, NSSize(width: 1100, height: 800), ColorScheme.dark),
            ("揭晓-浅色", resultGame, NSSize(width: 1100, height: 800), ColorScheme.light),
            ("八人排名-浅色", manyGame, NSSize(width: 820, height: 700), ColorScheme.light)
        ] {
            let model = GameSession(previewGame: game)
            if name.hasPrefix("开局") { model.playerCount = 3 }
            let view = NSHostingView(rootView: ContentView(session: model).environment(\.colorScheme, scheme))
            view.frame = NSRect(origin: .zero, size: size)
            let window = NSWindow(contentRect: view.frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = view
            view.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(1300))
            view.layoutSubtreeIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { fatalError("Unable to render") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            try bitmap.representation(using: .png, properties: [:])!.write(to: destination.appendingPathComponent(name + ".png"))
            window.contentView = nil
            window.close()
            print("Rendered \(name) \(size)")
        }
        // Bundle.main resolves assets from the diagnostic test bundle built by its runner.
        let audio = CreakAudioController()
        let time = ProcessInfo.processInfo.systemUptime
        audio.receive(AngleSample(angle: 100, time: time))
        audio.receive(AngleSample(angle: 101, time: time + 0.05))
        try await Task.sleep(for: .milliseconds(60))
        let moving = audio.debugState
        print("Audio engine running=\(moving.running), moving volume=\(moving.volume), error=\(audio.error ?? "none")")
        try await Task.sleep(for: .milliseconds(220))
        print("Audio stopped volume=\(audio.debugState.volume)")
        audio.stop()
    }
}
