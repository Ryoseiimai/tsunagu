import SwiftUI

/// 紹介する人モードのホーム（SPEC-v2 §2 / DESIGN-v3 §5-1〜§5-4, §5-6）。
struct ReferHomeView: View {
    let store: AppStore
    var onChangeRole: () -> Void
    /// 役割変更・全消去のあとRootViewにルーティングをやり直してもらうための合図。
    var onNeedsReroute: () -> Void = {}
    /// スクショ検証用。指定した支援者の紹介シートを起動直後に自動で開く（DEBUGのみRootViewから渡る）。
    var autoPresentSupporterID: UUID?

    @Environment(ToastCenter.self) private var toastCenter
    @State private var introducing: Supporter?
    @State private var showEraseConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.supporters.isEmpty {
                        emptyState
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    } else {
                        ForEach(store.supporters) { supporter in
                            SupporterRow(supporter: supporter, counts: store.counts(for: supporter.id)) {
                                introducing = supporter
                            }
                        }
                    }
                }

                Section("紹介したあと") {
                    if store.referrals.isEmpty {
                        Text("まだ紹介の記録がありません")
                            .font(.subheadline)
                            .foregroundStyle(Color.secondary)
                    } else {
                        ForEach(store.sortedReferrals) { referral in
                            HistoryRow(referral: referral, supporterName: name(for: referral)) { newStatus in
                                store.setStatus(referral.id, newStatus)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("紹介できる人")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: URL(string: manualURLString)!) {
                        Image(systemName: Symbol.help)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("役割を変える", action: onChangeRole)
                        Button(role: .destructive) {
                            if showEraseConfirm {
                                store.erase()
                                onNeedsReroute()
                            } else {
                                showEraseConfirm = true
                                toastCenter.show("消去するには、もう一度メニューで「消去する」を押してください")
                            }
                        } label: {
                            Label(showEraseConfirm ? "消去する（取り消せません）" : "データを全て消去", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: Symbol.menu)
                    }
                }
            }
            .sheet(item: $introducing) { supporter in
                ReferSheetView(store: store, supporter: supporter)
            }

        }
        .onAppear {
            if let autoPresentSupporterID, let supporter = store.supporter(autoPresentSupporterID) {
                introducing = supporter
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("まだ紹介できる人がいません", systemImage: Symbol.referFriend)
        } description: {
            Text("仕事探しを手伝っている知り合いに、\nカードを作ってもらってください。")
        } actions: {
            VStack(spacing: 10) {
                Button("誘い文をコピー") {
                    UIPasteboard.general.string = ShareText.invite
                    toastCenter.show("コピーしました")
                }
                .buttonStyle(.tsunaguPrimary)

                Button("見本で試す") {
                    store.addSampleSupporter()
                    toastCenter.show("見本を追加しました")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func name(for referral: Referral) -> String {
        store.supporter(referral.supporterID)?.name ?? "不明"
    }
}
