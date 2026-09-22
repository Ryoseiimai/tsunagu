import SwiftUI

/// 仕事を探している人の画面（`?s=` / `tsunagu://consult`）。SPEC-v2 §4・DESIGN-v3 §5-11。
/// 役割選択もタブも出さない。この画面だけを見せる。
struct ConsultView: View {
    let store: AppStore
    let link: IncomingLink
    var onDone: () -> Void

    @Environment(ToastCenter.self) private var toastCenter
    @State private var payload: SupporterPayload?
    @State private var resolvedReferral: Referral?
    @State private var byName: String?
    @State private var decodeFailed = false

    var body: some View {
        Group {
            if let payload {
                content(for: payload)
            } else {
                ContentUnavailableView {
                    Label(decodeFailed ? "リンクが古いようです" : "紹介リンクから開いてください", systemImage: Symbol.brokenLink)
                } description: {
                    Text(decodeFailed
                        ? "リンクの一部が壊れているか、期限が切れている可能性があります。"
                        : "友達から届いたリンクをもう一度開いてみてください。")
                } actions: {
                    Button("ホームへ", action: onDone)
                        .buttonStyle(.tsunaguPrimary)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .onAppear(perform: resolve)
    }

    // Web版 renderConsultArea と同じ優先順位:
    // 1. ref に一致する紹介記録がこの端末にあれば、それが指す支援者を使う（同じ端末での動作確認用）
    // 2. なければ s を復号して使う。名前+得意分野が一致する支援者がなければ紹介リストに追加する
    // 3. どちらも無ければ壊れたリンク/案内表示
    private func resolve() {
        if let refRaw = link.ref, let refID = UUID(uuidString: refRaw),
           let referral = store.referral(refID), let supporter = store.supporter(referral.supporterID) {
            resolvedReferral = referral
            payload = SupporterPayload(supporter)
        } else if let sRaw = link.s {
            do {
                let decoded = try decodeSupporterParam(sRaw)
                store.importSupporterIfNeeded(decoded)
                payload = decoded
            } catch {
                decodeFailed = true
            }
        }
        if let byRaw = link.by {
            byName = try? decodeTextParam(byRaw)
        }
    }

    @ViewBuilder
    private func content(for payload: SupporterPayload) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 6) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    Text("つなぐ").font(.footnote.weight(.semibold))
                }
                .padding(.top, 12)

                ConnectingLineView()

                if let byName, !byName.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                        Text("\(byName)さんからの紹介です")
                    }
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(Color.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemFill), in: Capsule())
                }

                SupporterBigCard(supporter: Supporter(payload: payload))

                VStack(spacing: 6) {
                    Text("決まったら、紹介してくれた人に教えてあげてね")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                        .multilineTextAlignment(.center)
                    Button("決まった！を送る") { markHired(payload: payload) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(minHeight: 44)
                }

                Color.clear.frame(height: 8)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if validLineURL(payload.lineUrl) == nil {
                    Text("この支援者にはLINEの連絡先が登録されていません。")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }
                Button {
                    consult(payload: payload)
                } label: {
                    Label("LINEで相談する", systemImage: Symbol.line)
                }
                .buttonStyle(.tsunaguLine)
                .disabled(validLineURL(payload.lineUrl) == nil)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(.bar)
        }
    }

    private func consult(payload: SupporterPayload) {
        guard let url = validLineURL(payload.lineUrl) else { return }
        UIApplication.shared.open(url)
        if let resolvedReferral {
            store.setStatus(resolvedReferral.id, .consulting)
        }
    }

    private func markHired(payload: SupporterPayload) {
        if let resolvedReferral {
            store.setStatus(resolvedReferral.id, .hired)
        }
        toastCenter.show("紹介してくれた人に伝えました（試作なので画面内だけ）")
    }
}
