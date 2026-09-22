#if DEBUG
import Foundation

// スクショ検証専用。起動引数 `-uiState <name>` で、普段は作りにくい状態
// （履歴の全状態・お祝い・配布シートなど）を注入する。Releaseビルドには含まれない
// （ファイル全体が#if DEBUGで、Release構成のビルドには一切コンパイルされない）。
enum DebugUIState: String {
    case role
    case historySent, historyConsulting, historyHired, historyElsewhere, historyDeclined, celebration
    case consultBy, consult, addConfirm, brokenLink
    case referEmpty
    case referList
    case referSheet
    case supportEmpty
    case supportCard
    case cardEdit
    case distributeSheet
}

enum DebugSeed {
    static var requestedState: DebugUIState? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-uiState"), index + 1 < args.count else { return nil }
        return DebugUIState(rawValue: args[index + 1])
    }

    static var incomingLink: IncomingLink? {
        guard let state = requestedState else { return nil }
        let payload = SupporterPayload(name: "今井 涼晴", skill: "20代の未経験転職・エンジニア職", area: "全国・オンライン", comment: "まず話を聞くところから始めましょう。", lineUrl: "https://line.me/ti/p/xxxx")
        let encoded = try! encodeSupporterParam(payload)
        var parts = URLComponents(string: "tsunagu://open")!
        switch state {
        case .consult, .consultBy:
            parts.queryItems = [URLQueryItem(name: "s", value: encoded)]
            if state == .consultBy { parts.queryItems?.append(URLQueryItem(name: "by", value: encodeTextParam("りょうせい"))) }
        case .addConfirm: parts.queryItems = [URLQueryItem(name: "add", value: encoded)]
        case .brokenLink: parts.queryItems = [URLQueryItem(name: "s", value: "broken!")]
        default: return nil
        }
        return IncomingLink(url: parts.url!)
    }

    @MainActor
    static func apply(_ state: DebugUIState, to store: AppStore) {
        switch state {
        case .role, .consultBy, .consult, .addConfirm, .brokenLink:
            break
        case .historySent, .historyConsulting, .historyHired, .historyElsewhere, .historyDeclined, .celebration:
            store.role = .refer
            store.addSampleSupporter()
            let states: [DebugUIState: ReferralStatus] = [.historySent: .sent, .historyConsulting: .consulting, .historyHired: .hired, .historyElsewhere: .elsewhere, .historyDeclined: .declined, .celebration: .consulting]
            let id = store.createReferral(for: store.supporters[0].id, friendName: "たかし", tone: .casual)
            store.setStatus(id, states[state]!)
            if state == .celebration {
                Task {
                    try? await Task.sleep(for: .seconds(1))
                    store.setStatus(id, .hired)
                }
            }
        case .referEmpty:
            store.role = .refer
        case .referList, .referSheet:
            store.role = .refer
            seedReferList(store)
        case .supportEmpty:
            store.role = .support
        case .supportCard, .cardEdit, .distributeSheet:
            store.role = .support
            seedSupportCard(store)
        }
    }

    @MainActor
    private static func seedReferList(_ store: AppStore) {
        guard store.supporters.isEmpty else { return }
        store.addSampleSupporter()
        guard let supporter = store.supporters.first else { return }

        // 5つの状態＋「お祝い」表示を1画面で確認できるように全状態を作る。
        let seeds: [(ReferralStatus, String?)] = [
            (.sent, "たかし"),
            (.consulting, "ゆうた"),
            (.hired, "まさと"),
            (.elsewhere, nil),
            (.declined, "けんじ"),
        ]
        for (status, friend) in seeds {
            let id = store.createReferral(for: supporter.id, friendName: friend, tone: .casual)
            store.setStatus(id, status)
        }
    }

    @MainActor
    private static func seedSupportCard(_ store: AppStore) {
        guard store.myCard == nil else { return }
        let card = Supporter(name: "今井 涼晴", specialty: "20代の未経験転職・エンジニア職", region: "全国・オンライン",
                              message: "まず話を聞くところから始めましょう。", lineURL: "https://line.me/ti/p/xxxx")
        store.saveMyCard(card)
        // 「紹介されてきた人」は普段は同端末では埋まらない項目なので、確認用に1件だけ注入する。
        guard let myCard = store.myCard else { return }
        let id = store.createReferral(for: myCard.id, friendName: "さやか", tone: .polite)
        store.setStatus(id, .consulting)
    }
}
#endif
