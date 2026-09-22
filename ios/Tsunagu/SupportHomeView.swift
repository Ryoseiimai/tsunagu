import SwiftUI

/// 支援する人モードのホーム（SPEC-v2 §3 / DESIGN-v3 §5-9）。
struct SupportHomeView: View {
    let store: AppStore
    var onChangeRole: () -> Void
    /// 役割変更・全消去のあとRootViewにルーティングをやり直してもらうための合図。
    var onNeedsReroute: () -> Void = {}
    /// スクショ検証用。起動直後にカード編集/配布シートを自動で開く（DEBUGのみRootViewから渡る）。
    var autoPresentEdit = false
    var autoPresentDistribute = false

    @Environment(ToastCenter.self) private var toastCenter
    @State private var showEdit = false
    @State private var showDistribute = false
    @State private var showEraseConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if let myCard = store.myCard {
                        SupporterBigCard(supporter: myCard)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)

                        Button {
                            showDistribute = true
                        } label: {
                            Text("紹介してくれる人に配る")
                        }
                        .buttonStyle(.tsunaguPrimary)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                    } else {
                        emptyState
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                Section("紹介されてきた人") {
                    if store.receivedReferrals.isEmpty {
                        Text("まだいません")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    } else {
                        ForEach(store.receivedReferrals) { referral in
                            ReceivedRow(referral: referral)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("あなたのカード")
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("編集") { showEdit = true }
                        .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showEdit) {
                CardEditView(store: store)
            }
            .sheet(isPresented: $showDistribute) {
                if let myCard = store.myCard {
                    DistributeSheetView(store: store, supporter: myCard)
                }
            }

        }
        .onAppear {
            if autoPresentEdit { showEdit = true }
            if autoPresentDistribute, store.myCard != nil { showDistribute = true }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("カードをまだ作っていません", systemImage: Symbol.support)
        } description: {
            Text("名前と得意分野を入れれば、すぐに配れるカードができます。")
        } actions: {
            Button("カードを作る") { showEdit = true }
                .buttonStyle(.tsunaguPrimary)
        }
    }
}
