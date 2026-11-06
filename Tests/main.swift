import Foundation

var passed = 0
func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError("FAIL: \(message)") }
    passed += 1
}
func sample(_ game: inout GameEngine, _ angle: Double, from: Double, count: Int = 13) {
    for index in 0..<count { game.receive(AngleSample(angle: angle, time: from + Double(index) * 0.05)) }
}
func prepared(_ names: [String] = ["甲", "乙"], rounds: Int = 5) -> GameEngine {
    var game = GameEngine()
    game.begin(names: names, rounds: rounds)
    sample(&game, 100, from: 10)
    return game
}
var game = prepared()
expect(game.stableAngle(at: 10.6) == 100, "稳定半秒可锁定")
expect(game.revealedAngle == nil, "锁定前不公开角度")
game.lock(at: 10.6)
expect(game.phase == .guessing, "锁定进入猜测")
expect(game.revealedAngle == nil, "猜测期间不公开角度")
expect(!game.submit("", at: 10.6), "拒绝空答案")
expect(!game.submit("181", at: 10.6), "拒绝超范围")
expect(!game.submit("-1", at: 10.6), "拒绝负数")
expect(!game.submit("90.2", at: 10.6), "拒绝小数")
expect(!game.submit("a", at: 10.6), "拒绝字母")
expect(game.submit("97", at: 10.6), "接受整数")
expect(game.phase == .handoff && game.playerIndex == 1, "第一人提交后交接")
expect(!game.submit("100", at: 10.6), "交接页禁止提交")
game.nextPlayer()
expect(game.submit("103", at: 10.6), "第二人可提交")
expect(game.phase == .readyToReveal && game.results.isEmpty, "全员提交不提前揭晓")
game.reveal(at: 10.6)
expect(game.revealedAngle == 100, "揭晓锁定读数")
expect(game.roundNumber == 1, "揭晓仍显示当前轮次")
expect(game.results[0].errors == [3, 3], "绝对误差")
expect(game.roundStandings.map(\.rank) == [1, 1], "相同误差并列")

// Five complete rounds, with one player's average consistently smaller.
game = prepared(rounds: 5)
for round in 0..<5 {
    let time = 20 + Double(round) * 2
    if round > 0 { sample(&game, 100, from: time) }
    else { sample(&game, 100, from: time) }
    game.lock(at: time + 0.6)
    expect(game.submit("99", at: time + 0.6), "五轮玩家一提交")
    game.nextPlayer()
    expect(game.submit("105", at: time + 0.6), "五轮玩家二提交")
    game.reveal(at: time + 0.6)
    game.advance()
}
expect(game.phase == .finished && game.results.count == 5, "五轮完整结算")
expect(game.finalStandings.map(\.value) == [1, 5], "平均误差正确")
expect(game.finalStandings.map(\.rank) == [1, 2], "总排名正确")

// Drift must last half a second, across handoff and reveal-ready phases too.
for phase in 0..<3 {
    game = prepared(); game.lock(at: 10.6)
    if phase > 0 { _ = game.submit("90", at: 10.6) }
    if phase > 1 { game.nextPlayer(); _ = game.submit("90", at: 10.6) }
    game.receive(AngleSample(angle: 103, time: 10.7))
    expect(game.phase.protectsAngle, "短暂抖动不立即作废")
    if phase == 2 { game.reveal(at: 10.7); expect(game.results.isEmpty, "偏离期间不可揭晓") }
    sample(&game, 103, from: 10.75, count: 11)
    expect(game.phase == .positioning && game.guesses.isEmpty, "持续偏移清空本轮")
    expect(game.results.isEmpty, "作废不计入成绩")
}

game = prepared(); game.lock(at: 10.6)
game.receive(AngleSample(angle: 103, time: 10.7))
game.receive(AngleSample(angle: 100, time: 10.9))
sample(&game, 100, from: 10.95)
expect(game.phase == .guessing, "短暂偏移恢复后可继续")
game.receive(AngleSample(angle: 102, time: 11.6))
sample(&game, 102, from: 11.65)
expect(game.phase == .guessing, "恰好两度不作废")

game = prepared(); game.lock(at: 10.6); _ = game.submit("90", at: 10.6)
game.checkFreshness(at: 11.36)
expect(game.phase == .positioning && game.guesses.isEmpty, "过期读数使本轮作废")
expect(game.stableAngle(at: 11.36) == nil, "过期不可锁定")

game = prepared(); game.lock(at: 10.6)
expect(!game.submit("90", at: 11.4), "提交时再次校验新鲜度")
expect(game.phase == .positioning, "提交时读数过期返回准备")

game = prepared(); game.lock(at: 10.6); game.sensorLost("休眠")
expect(game.phase == .positioning && game.guesses.isEmpty, "睡眠或失联作废")
expect(game.stableAngle(at: 10.6) == nil, "恢复前无可用稳定读数")
sample(&game, 110, from: 12)
expect(game.stableAngle(at: 12.6) == 110, "恢复后重新稳定")

game = prepared(); game.lock(at: 10.6)
game.receive(AngleSample(angle: 100, time: 12))
expect(game.phase == .positioning, "采样中断即使新角度相同也作废")
expect(game.stableAngle(at: 12) == nil, "采样间隙不能算稳定")

game = prepared(); game.receive(AngleSample(angle: .nan, time: 12))
expect(game.latest == nil, "拒绝 NaN")
game.receive(AngleSample(angle: 181, time: 13))
expect(game.latest == nil, "拒绝异常硬件角度")

game = GameEngine(); game.begin(names: Array(repeating: "", count: 8))
expect(game.players.count == 8 && game.players[0] == "玩家 1", "八人及空昵称默认值")
game.begin(names: ["  小陈  ", "小李"])
expect(game.players[0] == "小陈", "清理昵称空白")
expect(GameEngine.ranked([1, 1, 4]).map(\.rank) == [1, 1, 3], "竞赛并列排名")

// Median remains independent of the last sample within allowed jitter.
game = GameEngine(); game.begin(names: ["甲", "乙"])
for index in 0..<13 { game.receive(AngleSample(angle: index == 12 ? 101 : 100, time: Double(index) * 0.05)) }
expect(game.stableAngle(at: 0.600001) == 100, "稳定窗口使用中位数")
game.receive(AngleSample(angle: 105, time: 0.65))
expect(game.stableAngle(at: 0.65) == nil, "移动期间不能锁定")
// Three players complete the default three-round game without an early reveal.
var trio = GameEngine()
trio.begin(names: ["甲", "乙", "丙"])
expect(trio.roundCount == 3, "默认三轮")
for round in 0..<3 {
    let start = 40 + Double(round) * 2
    sample(&trio, 100, from: start)
    trio.lock(at: start + 0.6)
    for (index, guess) in [99, 101, 105].enumerated() {
        expect(trio.submit(String(guess), at: start + 0.6), "三人答案可提交")
        if index < 2 {
            expect(trio.phase == .handoff, "三人全部提交前保持交接")
            trio.nextPlayer()
        }
    }
    expect(trio.phase == .readyToReveal, "第三人提交后允许揭晓")
    trio.reveal(at: start + 0.6)
    trio.advance()
}
expect(trio.phase == .finished && trio.results.count == 3, "三人三轮完整结算")
expect(trio.finalStandings.map(\.rank) == [1, 1, 3], "三人排名支持并列")

// Sound encodes velocity, not angle; moving then stopping must release quickly.
var audio = MotionSoundEnvelope()
audio.receive(AngleSample(angle: 90, time: 0))
expect(audio.output(at: 0).volume == 0, "静止和首读数无声音")
audio.receive(AngleSample(angle: 91, time: 0.05))
expect(audio.output(at: 0.05).volume > 0, "移动时起声")
let loud = audio.output(at: 0.07).volume
let faded = audio.output(at: 0.17).volume
expect(faded < loud * 0.25, "120 毫秒时音量已明显淡出")
expect(audio.output(at: 0.201).volume == 0, "150 毫秒内完全收声")
audio.reset()
expect(audio.output(at: 1).volume == 0, "关闭音效立即静音")
var audioA = MotionSoundEnvelope()
var audioB = MotionSoundEnvelope()
audioA.receive(AngleSample(angle: 30, time: 0))
audioB.receive(AngleSample(angle: 120, time: 0))
audioA.receive(AngleSample(angle: 31, time: 0.05))
audioB.receive(AngleSample(angle: 121, time: 0.05))
expect(audioA.output(at: 0.06).volume == audioB.output(at: 0.06).volume, "同速度的不同角度声音一致")
print("PASS: \(passed) assertions; game rules, five rounds, privacy boundary, drift, stale samples, recovery, ties, validation.")
