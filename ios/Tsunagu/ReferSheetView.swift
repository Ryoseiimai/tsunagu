import SwiftUI

/// 紹介1画面（DESIGN-v3 §5-5）。画面遷移はホームからここへの1回だけ（SPEC-v2 §2）。
/// 通常の文字サイズでは1画面に収まり、キーボード表示中・Dynamic Typeでは入力部分だけスクロールできる。
struct ReferSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ToastCenter.self) private var toastCenter
    let store: AppStore
    let supporter: Supporter

    // Web版 currentRefId と同じ役割: 短縮リンクの`ref=`と、保存する紹介記録のidを同じ値にそろえる。
    @State private var refID = UUID()
    @State private var friendName = ""
    @State private var tone: Tone = .casual
    @State private var text = ""
    @State private var referralCreated = false
    @State private var shortLink: String?
    @State private var isBusy = false

    private var longLink: URL? { longReferralURL(payload: SupporterPayload(supporter), refID: refID) }
    private var currentLink: String { shortLink ?? longLink?.absoluteString ?? publicBaseURLString }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    ConnectingLineView()
                        .frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("送る相手").font(.footnote).foregroundStyle(Color.secondary)
                        TextField("友達の名前（なくてもOK）", text: $friendName)
                            .padding(12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    Picker("トーン", selection: $tone) {
                        ForEach(Tone.allCases) { tone in Text(tone.rawValue).tag(tone) }
                    }
                    .pickerStyle(.segmented)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("相手にはこう届きます").font(.footnote).foregroundStyle(Color.secondary)
                        TextEditor(text: $text)
                            .font(.subheadline)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .frame(minHeight: 150, maxHeight: 170)
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

                    HStack(spacing: 8) {
                        Button {
                            copyToClipboard()
                        } label: {
                            Label("コピー", systemImage: Symbol.copy)
                        }
                        .buttonStyle(.tsunaguSecondary)
                        .disabled(isBusy)

                        ShareLink(item: text) {
                            Label("ほかのアプリ", systemImage: Symbol.shareOther)
                        }
                        .buttonStyle(.tsunaguSecondary)
                        .disabled(isBusy)
                        .simultaneousGesture(TapGesture().onEnded { ensureReferralCreated() })
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.bar)
            }
            .navigationTitle("\(supporter.name)さんを紹介")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .toastOverlay()
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onAppear { regeneratePreview() }
        .onChange(of: friendName) { _, _ in regeneratePreview() }
        .onChange(of: tone) { _, _ in regeneratePreview() }
        .task(id: refID) { await fetchShortLink() }
    }

    // Web版 regeneratePreview と同じ: 名前・トーンを変えるたびに文面を作り直す
    // （編集した内容はその時点で上書きされる簡略仕様。index.htmlの同名コメントと同じ）。
    private func regeneratePreview() {
        text = ShareText.referral(supporterName: supporter.name, skill: supporter.specialty,
                                   friendName: friendName, tone: tone, link: currentLink)
    }

    private func fetchShortLink() async {
        guard let payload = try? encodeSupporterParam(SupporterPayload(supporter)) else { return }
        isBusy = true
        let result = await ShortenClient.shorten(s: payload, ref: refID.uuidString)
        isBusy = false
        if let result {
            let previousLink = currentLink
            shortLink = result
            text = text.replacingOccurrences(of: previousLink, with: result)
        }
    }

    private func ensureReferralCreated() {
        guard !referralCreated else { return }
        store.createReferral(id: refID, for: supporter.id, friendName: friendName, tone: tone)
        referralCreated = true
    }

    private func copyToClipboard() {
        ensureReferralCreated()
        UIPasteboard.general.string = text
        toastCenter.show("コピーしました")
    }

    private func sendViaLINE() {
        ensureReferralCreated()
        if let url = lineShareURL(text: text) {
            UIApplication.shared.open(url)
        }
        toastCenter.show("送りました。相手が相談したら、ここに出ます")
        dismiss()
    }
}
