import Foundation

// 送信文面の生成。SPEC-v2 §2の文面テンプレートそのままではなく、Web版(index.html)の
// regeneratePreview / buildDistributeText の実装（得意分野を独立した1行として足す版）と一字一句そろえてある。
// 「友達の名前が空なら先頭行に「、」を出さない」というSPEC-v2の注記もここで満たしている。
enum ShareText {
    /// 紹介1画面の文面プレビュー。
    static func referral(supporterName: String, skill: String, friendName: String?, tone: Tone, link: String) -> String {
        let name = friendName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasFriendName = !(name?.isEmpty ?? true)
        switch tone {
        case .polite:
            let line1 = hasFriendName ? "\(name!)さん、お仕事をお探しと伺いました。" : "お仕事をお探しと伺いました。"
            let line2 = "\(supporterName)さんという、ご相談に乗ってくださる方がいます。"
            let skillLine = skill.isEmpty ? "" : "\(skill)を得意とされている方です。\n"
            return line1 + "\n" + line2 + "\n" + skillLine + "よろしければ一度お話ししてみてください。\n→ " + link
        case .casual:
            let line1 = hasFriendName ? "\(name!)、仕事探してるって言ってたよね。" : "仕事探してるって言ってたよね。"
            let line2 = "\(supporterName)さんって人が相談に乗ってくれるから、よかったら話してみて。"
            let skillLine = skill.isEmpty ? "" : "\(skill)が得意な人。\n"
            return line1 + "\n" + line2 + "\n" + skillLine + "知り合いだから安心して大丈夫。\n→ " + link
        }
    }

    /// 紹介できる人が0件のときの「誘い文をコピー」。
    static var invite: String {
        "◯◯さんって転職の相談乗ってるよね。\nつなぐってアプリで自分のカード作っといてくれない？\n仕事探してる子いたら回すわ\n→ \(publicBaseURLString)\n使い方: \(manualURLString)"
    }

    /// 支援する人の「紹介してくれる人に配る」文面。
    static func distribute(link: String) -> String {
        "転職の相談に乗ってます。\nもし仕事探してる人がいたら、つないでもらえたら嬉しいです。\nこのリンクから、僕のカードを保存できます。\n→ \(link)\n使い方: \(manualURLString)"
    }
}
