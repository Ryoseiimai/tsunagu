import SwiftUI
import UIKit

private let publicBase = "https://ryoseiimai.github.io/tsunagu/"

private struct SupporterShareData: Codable {
    let name: String
    let skill: String
    let area: String
    let word: String
    let lineUrl: String
}

private func base64URLEncode(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

private func publicReferralURL(supporter: Supporter, referralID: UUID) -> URL? {
    let payload = SupporterShareData(
        name: supporter.name, skill: supporter.specialty, area: supporter.region,
        word: supporter.message, lineUrl: supporter.lineURL
    )
    guard let json = try? JSONEncoder().encode(payload) else { return nil }
    var components = URLComponents(string: publicBase)!
    components.queryItems = [
        URLQueryItem(name: "s", value: base64URLEncode(json)),
        URLQueryItem(name: "ref", value: referralID.uuidString)
    ]
    return components.url
}

struct ReferralsView: View {
    let store: AppStore
    @State private var supporterID: UUID?
    @State private var draftID: UUID?
    @State private var notice: String?

    private var draft: Referral? { draftID.flatMap { store.referral($0) } }
    private var shareText: String? {
        guard let draft, let supporter = store.supporter(draft.supporterID),
              let url = publicReferralURL(supporter: supporter, referralID: draft.id) else { return nil }
        return "仕事探してるって言ってたよね。\(supporter.name)さんが転職の相談乗ってくれるから、よかったら話してみて → \(url.absoluteString)"
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("友達と支援者をつなぐ").font(.title2.bold())
                Picker("支援者を選ぶ", selection: $supporterID) {
                    Text("選択してください").tag(nil as UUID?)
                    ForEach(store.supporters) { Text($0.name).tag(Optional($0.id)) }
                }.frame(minHeight: 44)
                .onChange(of: supporterID) { _, id in
                    notice = nil
                    draftID = id.map { store.createReferral(for: $0) }
                }
                if let shareText {
                    Text(shareText).textSelection(.enabled).padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                    ActionButton(title: "コピー", symbol: "doc.on.doc") {
                        UIPasteboard.general.string = shareText
                        notice = "紹介文をコピーしました"
                    }
                    ActionButton(title: "LINEで送る", symbol: "paperplane.fill") {
                        var components = URLComponents(string: "https://line.me/R/share")!
                        components.queryItems = [URLQueryItem(name: "text", value: shareText)]
                        guard let url = components.url else { return }
                        UIApplication.shared.open(url) { success in
                            notice = success ? "LINEの共有画面を開きました" : "LINEを開けませんでした。コピーして送ってください。"
                        }
                    }
                    Button("同じ支援者で新しい紹介を作る") {
                        if let supporterID { draftID = store.createReferral(for: supporterID); notice = nil }
                    }.frame(minHeight: 44)
                }
                if let notice { Text(notice).font(.subheadline).accessibilityAddTraits(.updatesFrequently) }
                Text("紹介記録").font(.title2.bold())
                Text("文面の作成時に「送信済」で記録します。紹介数は相談中以降の記録、決定数は「決まった！」の記録を集計します。")
                    .font(.caption).foregroundStyle(.secondary)
                if store.referrals.isEmpty { Text("紹介はまだありません。").foregroundStyle(.secondary) }
                ForEach(store.referrals) { referral in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.supporter(referral.supporterID)?.name ?? "支援者なし").font(.headline)
                        Text(referral.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                        Picker("状態", selection: Binding(get: { store.referral(referral.id)?.status ?? .sent }, set: { store.setStatus(referral.id, $0) })) {
                            ForEach(ReferralStatus.allCases) { Text($0.rawValue).tag($0) }
                        }.frame(minHeight: 44)
                    }.padding().frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }.padding()
        }
    }
}

struct ConsultView: View {
    let store: AppStore
    @Binding var activeReferral: UUID?
    @Binding var selectedSupporter: UUID?
    @Binding var linkError: String?
    @State private var toast: String?
    @State private var toastToken = UUID()

    private var supporter: Supporter? { selectedSupporter.flatMap { store.supporter($0) } }
    private func referralID(for supporter: Supporter) -> UUID {
        if let activeReferral, store.referral(activeReferral)?.supporterID == supporter.id { return activeReferral }
        let id = store.createReferral(for: supporter.id)
        activeReferral = id
        return id
    }
    private func showToast(_ message: String) {
        toast = message
        let token = UUID()
        toastToken = token
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            if toastToken == token { toast = nil }
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("気軽に相談してみよう").font(.title2.bold())
                if let linkError { Text(linkError).font(.subheadline).foregroundStyle(.secondary) }
                if activeReferral == nil {
                    Picker("相談する支援者", selection: $selectedSupporter) {
                        Text("一覧から選ぶ").tag(nil as UUID?)
                        ForEach(store.supporters) { Text($0.name).tag(Optional($0.id)) }
                    }.frame(minHeight: 44)
                }
                if let supporter {
                    SupporterCard(supporter: supporter, counts: store.counts(for: supporter.id), large: true)
                    if let id = activeReferral, let record = store.referral(id) {
                        Text("現在の状態：\(record.status.rawValue)").font(.subheadline)
                    }
                    ActionButton(title: "LINEで相談する", symbol: "bubble.left.and.bubble.right.fill") {
                        guard let url = validLineURL(supporter.lineURL) else {
                            showToast("この支援者にはLINE URLが登録されていません。")
                            return
                        }
                        let id = referralID(for: supporter)
                        UIApplication.shared.open(url) { success in
                            if success {
                                if let record = store.referral(id), record.status == .sent {
                                    store.setStatus(id, .consulting)
                                }
                            } else { showToast("LINEを開けませんでした。") }
                        }
                    }
                    if supporter.lineURL.isEmpty {
                        Text("サンプルのためLINEには接続しません。自分のカードにLINE URLを登録すると相談できます。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    ActionButton(title: "決まった！を送る", symbol: "checkmark.seal.fill") {
                        store.setStatus(referralID(for: supporter), .hired)
                        showToast("紹介者に通知しました（試作）")
                    }
                    Button("ほかの支援者を選ぶ") {
                        activeReferral = nil; selectedSupporter = nil; linkError = nil; toast = nil
                    }.frame(minHeight: 44)
                } else {
                    Text(store.supporters.isEmpty ? "支援者タブからカードを作成してください。" : "友達から届いた紹介リンクを開くか、支援者を選んでください。")
                        .foregroundStyle(.secondary)
                }
                Text("この試作の記録は端末内に保存されます。紹介リンクの他端末との共有・実際の通知には未対応です。")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding()
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast).font(.subheadline.bold()).padding()
                    .frame(maxWidth: .infinity).background(.black, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white).padding().allowsHitTesting(false)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
    }
}
