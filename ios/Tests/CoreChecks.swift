import Foundation

@main
struct CoreChecks {
    @MainActor
    static func main() async throws {
        // Node.js Buffer.from(JSON.stringify(...)).toString("base64url")で作ったWeb側の固定fixture。
        let webFixture = "eyJuYW1lIjoi55Sw5LitIiwic2tpbGwiOiJJVCIsImFyZWEiOiLlhajlm70iLCJjb21tZW50Ijoi44G-44Ga55u46KuHIiwibGluZVVybCI6Imh0dHBzOi8vbGluLmVlL2FiYyJ9"
        let webCard = try decodeSupporterParam(webFixture)
        precondition(webCard == SupporterPayload(name: "田中", skill: "IT", area: "全国", comment: "まず相談", lineUrl: "https://lin.ee/abc"))
        let payload = SupporterPayload(name: "今井 涼晴", skill: "転職・IT", area: "東京／全国", comment: "一緒に話そう😊", lineUrl: "https://lin.ee/example")
        let encoded = try encodeSupporterParam(payload)
        precondition(!encoded.contains("=") && !encoded.contains("+") && !encoded.contains("/"))
        let decoded = try decodeSupporterParam(encoded)
        precondition(decoded == payload)
        let name = try decodeTextParam(encodeTextParam("りょうせい & 友達"))
        precondition(name == "りょうせい & 友達")
        precondition((try? decodeSupporterParam("broken!")) == nil)
        precondition((try? decodeSupporterParam(encodeTextParam("null"))) == nil)
        let refID = UUID()
        let incoming = IncomingLink(url: longReferralURL(payload: payload, refID: refID)!)
        precondition(incoming.s == encoded && incoming.ref == refID.uuidString)
        precondition(IncomingLink(url: URL(string: "tsunagu://open?s&add=other")!).s == "")
        precondition(IncomingLink(url: longDistributeURL(payload: payload)!).add == encoded)
        let text = "日本語 + & ? # 改行\n次の行"
        let line = URLComponents(url: lineShareURL(text: text)!, resolvingAgainstBaseURL: false)!
        precondition(line.host == "line.me" && line.path == "/R/share")
        precondition(line.queryItems?.first?.value == text)
        precondition(lineShareURL(text: text)!.absoluteString.contains("%2B"))
        precondition(validLineURL("https://lin.ee/abc") != nil)
        precondition(validLineURL("https://line.me.evil.example/abc") == nil)
        precondition(validLineURL("javascript:alert(1)") == nil)
        for tone in Tone.allCases {
            let preview = ShareText.referral(supporterName: "今井", skill: "IT", friendName: nil, tone: tone, link: "https://example.com")
            precondition(!preview.hasPrefix("、") && !preview.hasPrefix("さん"))
            precondition(preview.hasSuffix("→ https://example.com"))
        }
        precondition(ShareText.referral(supporterName: "今井", skill: "", friendName: " 太郎 ", tone: .casual, link: "URL") == "太郎、仕事探してるって言ってたよね。\n今井さんって人が相談に乗ってくれるから、よかったら話してみて。\n知り合いだから安心して大丈夫。\n→ URL")
        print("PASS: Japanese base64url, malformed links, LINE encoding, Web text templates")

        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "tsunagu.json")
        let suite = "tsunagu.core-checks.\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let supporterID = UUID()
        let statuses = ["送信済", "相談中", "決まった！", "別で決めた", "見送り"]
        let records = statuses.map { ["id": UUID().uuidString, "supporterID": supporterID.uuidString, "createdAt": 123456.0, "status": $0] as [String: Any] }
        let legacy: [String: Any] = ["supporters": [["id": supporterID.uuidString, "name": "旧カード", "specialty": "IT", "region": "全国", "message": "こんにちは", "lineURL": ""]], "referrals": records]
        try JSONSerialization.data(withJSONObject: legacy).write(to: file)
        let store = AppStore(fileURL: file, defaults: defaults)
        precondition(store.role == nil && store.myCard == nil && store.storageError == nil)
        precondition(store.supporters.count == 1 && store.referrals.count == 5)
        precondition(store.referrals.map(\.status) == ReferralStatus.allCases)
        precondition(store.counts(for: supporterID).referred == 4 && store.counts(for: supporterID).decided == 1)
        for record in store.referrals { store.setStatus(record.id, record.status) }
        let reread = AppStore(fileURL: file, defaults: defaults)
        precondition(reread.referrals.count == 5 && reread.counts(for: supporterID).referred == 4)
        precondition(reread.counts(for: supporterID).decided == 1)
        let id = store.createReferral(for: supporterID, friendName: " 太郎 ", tone: .polite)
        store.setStatus(id, .consulting)
        store.setStatus(id, .hired)
        store.setStatus(id, .sent)
        store.setStatus(id, .hired)
        precondition(store.counts(for: supporterID).referred == 5 && store.counts(for: supporterID).decided == 2)
        store.importSupporterIfNeeded(payload)
        store.importSupporterIfNeeded(payload)
        precondition(store.supporters.count == 2)
        store.saveMyCard(Supporter(payload: payload))
        store.cacheDistributeLink(addParam: encoded, shortURL: "https://example.com/card")
        var edited = store.myCard!
        edited.name = "編集後"
        store.saveMyCard(edited)
        precondition(store.myCard?.distributeShortURL == nil)
        store.role = .support
        precondition(AppStore(fileURL: file, defaults: defaults).role == .support)
        // 読めないデータは上書きしない。
        let broken = Data("unreadable legacy data".utf8)
        try broken.write(to: file)
        let blocked = AppStore(fileURL: file, defaults: defaults)
        blocked.addSampleSupporter()
        precondition(blocked.storageError != nil)
        let preserved = try Data(contentsOf: file)
        precondition(preserved == broken)
        print("PASS: v1 migration, persistence, all statuses, idempotent counts, duplicate import, card cache, corrupt data preservation")
    }
}
