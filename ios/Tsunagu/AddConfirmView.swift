import SwiftUI

/// 追加確認画面（`?add=` / `tsunagu://add`）。SPEC-v2 §1・DESIGN-v3 §5-12。
/// 復号に失敗した場合はこの画面自体を出さない（RootView側でトーストのみ出して通常ルーティングに戻す。Web版と同じ挙動）。
struct AddConfirmView: View {
    enum Result { case added, dismissed }

    let store: AppStore
    let payload: SupporterPayload
    var onResult: (Result) -> Void

    @Environment(ToastCenter.self) private var toastCenter

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("紹介リストに追加しますか？")
                    .font(.title3.weight(.semibold))
                    .padding(.top, 24)

                SupporterBigCard(supporter: Supporter(payload: payload))

                VStack(spacing: 10) {
                    Button("追加する") { addTapped() }
                        .buttonStyle(.tsunaguPrimary)
                    Button("今は追加しない") { onResult(.dismissed) }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.secondary)
                        .frame(minHeight: 44)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func addTapped() {
        store.importSupporterIfNeeded(payload)
        // Web版 btn-add-confirm-yes と同じ: 役割が未設定なら「紹介する人」にする。
        if store.role == nil { store.role = .refer }
        toastCenter.show("紹介リストに追加しました")
        onResult(.added)
    }
}
