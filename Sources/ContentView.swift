import SwiftUI
import AppKit

private let brandIcon: NSImage = {
    if let url = Bundle.main.url(forResource: "BrandIcon", withExtension: "png"),
       let image = NSImage(contentsOf: url) {
        return image
    }
    return NSImage(systemSymbolName: "angle", accessibilityDescription: nil) ?? NSImage()
}()

struct PartyButtonStyle: ButtonStyle {
    var secondary = false
    @Environment(\.colorScheme) private var colorScheme
    private var theme: PartyPalette { PartyPalette(colorScheme) }
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(secondary ? theme.foreground : Color(red: 0.13, green: 0.12, blue: 0.10))
            .padding(.horizontal, 32).frame(height: 54)
            .frame(minWidth: secondary ? 100 : 250)
            .background {
                Capsule().fill(secondary ? AnyShapeStyle(theme.foreground.opacity(0.07)) : AnyShapeStyle(LinearGradient(colors: [Color(red: 1, green: 0.80, blue: 0.57), Color(red: 1, green: 0.62, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing)))
            }
            .overlay(Capsule().strokeBorder(secondary ? theme.foreground.opacity(0.09) : theme.foreground.opacity(0.16), lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.72 : 1) : 0.3)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .contentShape(Capsule())
    }
}

struct ContentView: View {
    @Bindable var session: GameSession
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @Environment(\.colorScheme) private var colorScheme
    private var theme: PartyPalette { PartyPalette(colorScheme) }
    private var ember: Color { theme.accent }
    private var peach: Color { theme.highlight }
    private var muted: Color { theme.muted }
    private var ink: Color { theme.background }
    private var selectedAppearance: AppAppearance { AppAppearance(rawValue: appearance) ?? .system }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var guess = ""
    @State private var inputError = false
    @State private var confirmExit = false
    @State private var showHelp = false
    @State private var resultsVisible = false
    @FocusState private var guessFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                Group {
                    switch session.game.phase {
                    case .setup: setup
                    case .positioning: positioning
                    case .guessing: guessing
                    case .handoff: handoff
                    case .readyToReveal: ready
                    case .revealed: revealed
                    case .finished: finished
                    }
                }
                .frame(maxWidth: 1000)
                .frame(maxWidth: .infinity, minHeight: 530)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
            footer
        }
        .padding(.horizontal, 48).padding(.top, 42).padding(.bottom, 20)
        .background {
            ZStack {
                ink
                RadialGradient(colors: [ember.opacity(0.045), .clear], center: .top, startRadius: 20, endRadius: 700)
            }.ignoresSafeArea()
        }
        .foregroundStyle(theme.foreground)
        .preferredColorScheme(selectedAppearance.colorScheme)
        .frame(minWidth: 820, minHeight: 700)
        .onChange(of: session.game.phase) { _, phase in
            guess = ""
            inputError = false
            guessFocused = phase == .guessing
            if phase == .revealed { resultsVisible = false }
        }
        .task(id: session.game.phase) {
            guard session.game.phase == .revealed else { return }
            if !reduceMotion { try? await Task.sleep(for: .milliseconds(750)) }
            guard !Task.isCancelled, session.game.phase == .revealed else { return }
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) { resultsVisible = true }
        }
        .confirmationDialog("结束这场比赛？", isPresented: $confirmExit, titleVisibility: .visible) {
            Button("结束并返回开局", role: .destructive) { session.returnToSetup() }
            Button("继续比赛", role: .cancel) { }
        } message: { Text("本场成绩将清空。") }
        .sheet(isPresented: $showHelp) { help }
    }

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 12) {
                Image(nsImage: brandIcon).resizable().scaledToFit().frame(width: 44, height: 50)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("掰").font(.system(size: 22, weight: .bold))
                    Text("— 猜角度的派对游戏").font(.system(size: 11)).foregroundStyle(muted)
                }
            }
            Spacer()
            Picker("外观", selection: $appearance) {
                ForEach(AppAppearance.allCases) { mode in
                    Text(mode.title).tag(mode.rawValue)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .font(.system(size: 12))
            .tint(muted)
            .padding(.trailing, 12)
            if !session.isSetup {
                Text(session.game.phase == .finished ? "本场结束" : "第 \(min(session.game.roundNumber, session.game.roundCount)) / \(session.game.roundCount) 轮")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(theme.foreground.opacity(0.05), in: Capsule())
                Button { confirmExit = true } label: {
                    Image(systemName: "xmark").frame(width: 30, height: 30)
                }.buttonStyle(.plain).foregroundStyle(muted).help("结束比赛")
                    .accessibilityLabel("结束比赛")
            } else {
                Button { showHelp = true } label: { Label("怎么玩", systemImage: "questionmark.circle") }
                    .buttonStyle(.plain).font(.system(size: 13)).foregroundStyle(muted)
            }
        }.padding(.bottom, 12)
    }

    private var setup: some View {
        HStack(alignment: .center, spacing: 56) {
            VStack(alignment: .leading, spacing: 24) {
                eyebrow("凭眼力，见高下")
                VStack(alignment: .leading, spacing: 2) {
                    Text("一眼，").foregroundStyle(theme.foreground)
                    Text("能有多准？").foregroundStyle(ember)
                }.font(.system(size: 56, weight: .black)).tracking(-2)
                Text("摆好屏幕，藏住答案。\n叫上朋友，猜猜眼前是几度。")
                    .font(.system(size: 16)).foregroundStyle(muted).lineSpacing(8)
                HStack(spacing: 18) {
                    miniFeature("person.2", "2–8 人")
                    miniFeature("eye.slash", "秘密作答")
                    miniFeature("sparkles", "一起揭晓")
                }.padding(.top, 10)
            }.frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("今晚谁来猜？").font(.system(size: 21, weight: .bold))
                    Spacer()
                    counter(value: $session.playerCount, range: 2...8, suffix: "人")
                }
                HStack(spacing: 8) {
                    choice("双人", selected: session.playerCount == 2) { session.playerCount = 2 }
                    choice("三人", selected: session.playerCount == 3) { session.playerCount = 3 }
                    Spacer()
                    Text("也可用 ± 调整人数").font(.system(size: 10)).foregroundStyle(muted)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(0..<session.playerCount, id: \.self) { index in
                        HStack(spacing: 8) {
                            Text(String(format: "%02d", index + 1)).font(.system(size: 10, design: .monospaced)).foregroundStyle(ember)
                            TextField("玩家 \(index + 1)", text: $session.names[index])
                                .textFieldStyle(.plain).font(.system(size: 13))
                                .onChange(of: session.names[index]) { _, value in
                                    session.names[index] = String(value.prefix(12))
                                }
                                .accessibilityLabel("玩家 \(index + 1) 昵称")
                        }.padding(12).background(theme.foreground.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                Divider().overlay(theme.foreground.opacity(0.04))
                HStack {
                    Text("玩几轮").font(.system(size: 13)).foregroundStyle(muted)
                    Spacer()
                    counter(value: $session.rounds, range: 1...10, suffix: "轮")
                }
                HStack(spacing: 8) {
                    choice("3 轮", selected: session.rounds == 3) { session.rounds = 3 }
                    choice("5 轮", selected: session.rounds == 5) { session.rounds = 5 }
                    Spacer()
                }
                Button { session.begin() } label: {
                    HStack { Spacer(); Text("开一局"); Image(systemName: "arrow.right"); Spacer() }
                }.buttonStyle(PartyButtonStyle()).disabled(!session.connected)
                Text(session.demo ? "演示模式 · 虚拟角度，仅供体验" : "误差越小，排名越高。")
                    .font(.system(size: 11)).foregroundStyle(session.demo ? ember : muted)
                    .frame(maxWidth: .infinity)
            }
            .padding(28).frame(width: 360)
            .background(theme.foreground.opacity(0.025), in: RoundedRectangle(cornerRadius: 26))
            .overlay(RoundedRectangle(cornerRadius: 26).strokeBorder(theme.foreground.opacity(0.07)))
        }.padding(.horizontal, 10)
    }

    private var positioning: some View {
        VStack(spacing: 24) {
            eyebrow("第 \(session.game.roundNumber) 轮 · 准备")
            Image(systemName: "hand.raised.fingers.spread")
                .font(.system(size: 65, weight: .ultraLight)).foregroundStyle(ember).padding(.top, 8)
            Text(session.demo ? "虚拟角度，已就位。" : "随手一停，就是谜题。")
                .font(.system(size: 38, weight: .bold))
            Text(session.demo ? "本轮使用随机虚拟角度，不读取屏幕位置。" : "把屏幕调到一个舒服的位置，让所有人都能观察。\n锁定后请保持屏幕不动。")
                .font(.system(size: 15)).foregroundStyle(muted).multilineTextAlignment(.center).lineSpacing(7)
            HStack(spacing: 8) {
                Circle().fill(session.canLock ? Color.green.opacity(0.8) : ember).frame(width: 6, height: 6)
                Text(session.canLock ? "已稳定，可以锁定" : (session.connected ? "等屏幕稳定一下…" : "等待传感器连接…"))
                    .font(.system(size: 12)).foregroundStyle(muted)
            }.padding(.top, 8)
            Button("就这个角度") { session.lock() }.buttonStyle(PartyButtonStyle()).disabled(!session.canLock)
            if let notice = session.game.notice {
                Text(notice).font(.system(size: 12)).foregroundStyle(ember).multilineTextAlignment(.center).frame(maxWidth: 550)
            }
        }.frame(maxWidth: .infinity)
    }

    private var guessing: some View {
        VStack(spacing: 14) {
            eyebrow("第 \(session.game.playerIndex + 1) 位 / 共 \(session.game.players.count) 位")
            Text("\(currentPlayer)，你猜几度？").font(.system(size: 30, weight: .bold)).lineLimit(1).minimumScaleFactor(0.6)
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                TextField("?", text: $guess)
                    .textFieldStyle(.plain).multilineTextAlignment(.trailing)
                    .font(.system(size: 144, weight: .heavy, design: .rounded))
                    .frame(width: 280).focused($guessFocused)
                    .onSubmit { submit() }
                    .onChange(of: guess) { _, _ in inputError = false }
                    .accessibilityLabel("猜测角度，0 到 180 度")
                Text("°").font(.system(size: 144, weight: .heavy, design: .rounded)).foregroundStyle(ember).padding(.trailing, 25)
            }.padding(.top, 2)
            HStack(spacing: 24) {
                adjustButton("minus", label: "减一度") { adjustGuess(-1) }
                Text(inputError ? "请输入 0–180 的整数" : "输入角度，也可以点 − / ＋ 调整")
                    .font(.system(size: 12)).foregroundStyle(inputError ? ember : muted)
                adjustButton("plus", label: "加一度") { adjustGuess(1) }
            }
            Button("我猜好了") { submit() }.buttonStyle(PartyButtonStyle()).padding(.top, 16)
            Text("答案会保密，等所有人提交后再揭晓。")
                .font(.system(size: 12)).foregroundStyle(muted).padding(.top, 5)
        }.frame(maxWidth: .infinity)
    }

    private var handoff: some View {
        VStack(spacing: 25) {
            eyebrow("答案已收好")
            Image(systemName: "lock.fill").font(.system(size: 52, weight: .light)).foregroundStyle(ember).padding(.vertical, 10)
            Text("轮到下一位").font(.system(size: 42, weight: .bold))
            Text(currentPlayer).font(.system(size: 25, weight: .semibold)).foregroundStyle(peach)
            Text("把操作交给 TA，屏幕保持原位。")
                .font(.system(size: 14)).foregroundStyle(muted)
            Button("我是 \(currentPlayer)") { session.nextPlayer() }
                .buttonStyle(PartyButtonStyle()).padding(.top, 12)
        }.frame(maxWidth: .infinity)
    }

    private var ready: some View {
        VStack(spacing: 25) {
            eyebrow("\(session.game.players.count) 份答案，全部到齐")
            Text("?").font(.system(size: 160, weight: .heavy, design: .rounded)).foregroundStyle(ember)
            Text("谁的眼力最好？").font(.system(size: 34, weight: .bold))
            Text("猜测已锁定。叫上大家，一起看答案。")
                .font(.system(size: 14)).foregroundStyle(muted)
            Button("揭晓答案") { session.reveal() }.buttonStyle(PartyButtonStyle())
                .disabled(!session.game.canReveal || !session.connected)
            Text(session.game.canReveal ? "揭晓前，请保持屏幕不动。" : "屏幕偏离了原位，请放回；持续移动将重开本轮。")
                .font(.system(size: 12)).foregroundStyle(muted)
        }.frame(maxWidth: .infinity)
    }

    private var revealed: some View {
        VStack(spacing: 16) {
            eyebrow("答案揭晓 · 传感器测得")
            Text("\(format(session.game.results.last?.actual ?? 0))°")
                .font(.system(size: 118, weight: .heavy, design: .rounded)).foregroundStyle(ember)
                .contentTransition(.numericText())
            if resultsVisible {
                VStack(spacing: 8) {
                    Text(roundFeedback).font(.system(size: 26, weight: .bold))
                    Text(winnerText).font(.system(size: 14)).foregroundStyle(peach)
                }.transition(.opacity)
                standings(final: false).transition(.opacity).padding(.top, 6)
                Button(session.game.results.count >= session.game.roundCount ? "看看总排名" : "再猜一轮") { session.advance() }
                    .buttonStyle(PartyButtonStyle()).padding(.top, 8)
                Text("现在可以调整屏幕了。")
                    .font(.system(size: 11)).foregroundStyle(muted)
            } else {
                Text("实际角度").foregroundStyle(muted).font(.system(size: 14))
                Color.clear.frame(height: 200)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 12)
    }

    private var finished: some View {
        VStack(spacing: 18) {
            eyebrow("\(session.game.roundCount) 轮比拼 · 最终排名")
            Image(systemName: "crown.fill").font(.system(size: 40)).foregroundStyle(ember)
            Text(finalWinnerText).font(.system(size: 32, weight: .bold)).lineLimit(2).multilineTextAlignment(.center)
            Text("平均误差越小，眼力越好。")
                .font(.system(size: 14)).foregroundStyle(muted)
            standings(final: true).padding(.vertical, 5)
            HStack(spacing: 14) {
                Button("换人再玩") { session.returnToSetup() }.buttonStyle(PartyButtonStyle(secondary: true))
                Button("再来一局") { session.replay() }.buttonStyle(PartyButtonStyle())
            }
        }.frame(maxWidth: .infinity)
    }

    private func standings(final: Bool) -> some View {
        let rows = final ? session.game.finalStandings : session.game.roundStandings
        return VStack(spacing: 0) {
            HStack {
                Text("排名 / 玩家")
                Spacer()
                if !final { Text("你的猜测").frame(width: 100, alignment: .trailing) }
                Text(final ? "平均误差" : "相差").frame(width: 100, alignment: .trailing)
            }.font(.system(size: 10)).foregroundStyle(muted).padding(.horizontal, 18).padding(.bottom, 9)
            ForEach(rows, id: \.player) { row in
                HStack(spacing: 12) {
                    Text(String(format: "%02d", row.rank)).font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(row.rank == 1 ? ember : muted).frame(width: 26)
                    Text(session.game.players[row.player]).font(.system(size: 14, weight: .semibold)).lineLimit(1)
                    Spacer()
                    if !final, let result = session.game.results.last {
                        Text("\(result.guesses[row.player])°").font(.system(size: 23, weight: .bold, design: .rounded))
                            .frame(width: 100, alignment: .trailing)
                    }
                    Text("\(format(row.value, decimal: final))°")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .foregroundStyle(row.rank == 1 ? ember : theme.foreground)
                        .frame(width: 100, alignment: .trailing)
                }
                .padding(.horizontal, 18).padding(.vertical, 10)
                .background(row.rank == 1 ? ember.opacity(0.075) : theme.foreground.opacity(0.018))
                if row.player != rows.last?.player { Divider().overlay(theme.foreground.opacity(0.025)) }
            }
        }.frame(maxWidth: 570)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            if let message = session.audioMessage {
                Text(message).font(.system(size: 11)).foregroundStyle(ember)
            }
            if !session.connected {
                Text(session.sensorMessage).font(.system(size: 11)).foregroundStyle(ember)
                    .multilineTextAlignment(.center).textSelection(.enabled)
            }
            HStack {
                HStack(spacing: 7) {
                    Circle().fill(session.demo ? ember : (session.connected ? Color.green.opacity(0.8) : muted)).frame(width: 5, height: 5)
                    Text(session.statusLabel).font(.system(size: 10))
                }.foregroundStyle(session.demo ? ember : muted)
                Spacer()
                Button { session.toggleSound() } label: {
                    Label(session.soundEnabled ? "嘎吱音效 · 开" : "嘎吱音效 · 关", systemImage: session.soundEnabled ? "speaker.wave.2" : "speaker.slash")
                }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(session.soundEnabled ? peach : muted)
                    .help("只随屏幕移动发声，停手后约 0.15 秒内收声；演示模式不播放")
                    .padding(.trailing, 12)
                if !session.connected {
                    Button("重新检测") { session.connect() }.buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(peach)
                }
                if session.isSetup {
                    Button(session.demo ? "切回真实传感器" : "体验演示模式") { session.setDemo(!session.demo) }
                        .buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(muted)
                } else {
                    Text(footerHint)
                        .font(.system(size: 10)).foregroundStyle(muted)
                }
            }
        }.padding(.top, 16)
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("把屏幕变成一道谜题。").font(.system(size: 28, weight: .bold))
            ForEach(Array(["填好昵称，选好轮数，开一局。", "随手调整屏幕，稳定后锁定角度。", "所有人观察同一个角度，轮流秘密作答。", "一起揭晓！误差最小的人赢得这一轮。", "全部轮次结束，按平均误差排名。"].enumerated()), id: \.offset) { index, text in
                HStack(alignment: .top, spacing: 14) {
                    Text("0\(index + 1)").foregroundStyle(ember).font(.system(size: 13, weight: .bold, design: .monospaced))
                    Text(text).font(.system(size: 14))
                }
            }
            Text("屏幕与键盘合上时为 0°，垂直时为 90°。只在铰链正常范围内调整。\n锁定后移动超过 2° 并持续半秒，这轮作废重来。")
                .font(.system(size: 12)).foregroundStyle(muted).lineSpacing(6)
            Button("懂了，来猜") { showHelp = false }.buttonStyle(PartyButtonStyle()).frame(maxWidth: .infinity)
        }.padding(40).frame(width: 590).background(ink).foregroundStyle(theme.foreground).preferredColorScheme(selectedAppearance.colorScheme)
    }

    private var footerHint: String {
        if session.demo { return "虚拟读数，不反映真实屏幕角度" }
        if session.game.phase.protectsAngle { return "猜测期间，保持屏幕不动" }
        if session.game.phase == .positioning { return "随手调整，稳定后锁定" }
        if session.game.phase == .finished { return "比赛结束，随时再开一局" }
        return "本轮已揭晓，可以调整屏幕"
    }
    private var currentPlayer: String {
        session.game.players.indices.contains(session.game.playerIndex) ? session.game.players[session.game.playerIndex] : "下一位"
    }
    private var roundFeedback: String {
        let error = session.game.roundStandings.first?.value ?? 0
        if error == 0 { return "一度不差！" }
        if error <= 3 { return "眼力真准！" }
        if error <= 10 { return "就差一点！" }
        return "这次看走眼了！"
    }
    private var winnerText: String {
        let winners = session.game.roundStandings.filter { $0.rank == 1 }
        let names = winners.map { session.game.players[$0.player] }.joined(separator: "、")
        let error = winners.first?.value ?? 0
        return "\(names)\(winners.count > 1 ? " 并列领先" : " 领先") · 只差 \(format(error))°"
    }
    private var finalWinnerText: String {
        let winners = session.game.finalStandings.filter { $0.rank == 1 }
        return winners.map { session.game.players[$0.player] }.joined(separator: "、") + (winners.count > 1 ? "，并列第一！" : "，今晚眼力最佳！")
    }
    private func eyebrow(_ text: String) -> some View {
        Text(text).font(.system(size: 11, weight: .medium)).tracking(3).foregroundStyle(muted)
    }
    private func miniFeature(_ icon: String, _ text: String) -> some View {
        Label(text, systemImage: icon).font(.system(size: 11)).foregroundStyle(muted)
    }
    private func choice(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(selected ? ember : muted)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selected ? ember.opacity(0.12) : theme.foreground.opacity(0.04), in: Capsule())
                .overlay(Capsule().strokeBorder(selected ? ember.opacity(0.4) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func counter(value: Binding<Int>, range: ClosedRange<Int>, suffix: String) -> some View {
        HStack(spacing: 10) {
            adjustButton("minus", label: "减少\(suffix)") { value.wrappedValue -= 1 }.disabled(value.wrappedValue <= range.lowerBound)
            Text("\(value.wrappedValue) \(suffix)").font(.system(size: 12, weight: .semibold)).monospacedDigit().frame(width: 34)
            adjustButton("plus", label: "增加\(suffix)") { value.wrappedValue += 1 }.disabled(value.wrappedValue >= range.upperBound)
        }
    }
    private func adjustButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: icon).font(.system(size: 11, weight: .semibold)).frame(width: 28, height: 28).background(theme.foreground.opacity(0.07), in: Circle()) }
            .buttonStyle(.plain).accessibilityLabel(label)
    }
    private func submit() {
        if !session.submit(guess) { inputError = true }
        else { guess = ""; guessFocused = false }
    }
    private func adjustGuess(_ amount: Int) {
        guess = String(min(180, max(0, (Int(guess) ?? 90) + amount)))
        inputError = false
    }
    private func format(_ value: Double, decimal: Bool = false) -> String {
        if decimal { return String(format: "%.1f", value) }
        return value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
}
