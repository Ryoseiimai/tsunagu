import SwiftUI

/// 配布シート（DESIGN-v3 §5-9: 紹介シートと同じ型）。SPEC-v2 §3の配布文面・短縮リンク取得ロジック。
/// Web版 btn-distribute と同じくコピー・LINE送信のみ（他のアプリでは送らない）。
struct DistributeSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toastCenter
    let store: AppStore
    let supporter: Supporter

    @State private var isBusy = true
    @State private var link = publicBaseURLString
    @State private var sheetWidth: CGFloat = 0

    private var text: String { ShareText.distribute(link: link) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("相手にはこう届きます").font(.footnote).foregroundStyle(Color.secondary)
                        Text(text)
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background {
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 18, bottomLeadingRadius: 6,
                                    bottomTrailingRadius: 18, topTrailingRadius: 18, style: .continuous
                                )
                                .fill(Color(.systemFill))
                            }
                    }

                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    Button {
                        sendViaLINE()
                    } label: {
                        Label(isBusy ? "準備中…" : "LINEで送る", systemImage: Symbol.line)
                    }
                    .buttonStyle(.tsunaguLine)
                    .disabled(isBusy)

                    Button {
                        UIPasteboard.general.string = text
                        toastCenter.show("コピーしました")
                    } label: {
                        Label("コピー", systemImage: Symbol.copy)
                    }
                    .buttonStyle(.tsunaguSecondary)
                    .disabled(isBusy)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .navigationTitle("紹介してくれる人に配る")
            .navigationBarTitleDisplayMode(.inline)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { sheetWidth = $0 }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SheetNavigationTitle(title: "紹介してくれる人に配る", sheetWidth: sheetWidth)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                        .font(.subheadline)
                }
            }
        }
        .toastOverlay()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task { await prepareLink() }
    }

    private func prepareLink() async {
        guard let payload = try? encodeSupporterParam(SupporterPayload(supporter)) else {
            isBusy = false
            return
        }
        // カード内容が変わっていなければ、前に取った短縮リンクを使い回す（Web版と同じキャッシュ規則）。
        if supporter.distributeAddParam == payload, let cached = supporter.distributeShortURL {
            link = cached
            isBusy = false
            return
        }
        isBusy = true
        let short = await ShortenClient.shorten(add: payload)
        isBusy = false
        if let short {
            link = short
            store.cacheDistributeLink(addParam: payload, shortURL: short)
        } else {
            link = longDistributeURL(payload: SupporterPayload(supporter))?.absoluteString ?? publicBaseURLString
        }
    }

    private func sendViaLINE() {
        if let url = lineShareURL(text: text) {
            UIApplication.shared.open(url)
        }
    }
}
