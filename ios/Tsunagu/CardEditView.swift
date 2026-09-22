import SwiftUI

/// 自分のカードを作る/編集する（DESIGN-v3 §5-10: iOSはForm）。
/// 保存条件はWeb版 btn-save-mycard と同じ: 名前・得意分野だけ必須。対応地域が空なら「応相談」で補う。
/// LINE URLの形式チェックは保存時ではなく求職者画面の「LINEで相談する」側で行う（SPEC-v2 §4）。
struct CardEditView: View {
    @Environment(\.dismiss) private var dismiss
    let store: AppStore

    @State private var name: String
    @State private var specialty: String
    @State private var region: String
    @State private var message: String
    @State private var lineURL: String

    init(store: AppStore) {
        self.store = store
        let card = store.myCard
        _name = State(initialValue: card?.name ?? "")
        _specialty = State(initialValue: card?.specialty ?? "")
        _region = State(initialValue: card?.region ?? "")
        _message = State(initialValue: card?.message ?? "")
        _lineURL = State(initialValue: card?.lineURL ?? "")
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedSpecialty: String { specialty.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSave: Bool { !trimmedName.isEmpty && !trimmedSpecialty.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("支援者プロフィール") {
                    TextField("名前", text: $name)
                    TextField("得意分野", text: $specialty)
                    TextField("対応地域", text: $region, prompt: Text("空なら「応相談」にします"))
                    TextField("一言", text: $message, axis: .vertical)
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("LINE URL", text: $lineURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Text("https://line.me/… または https://lin.ee/… の形で入力すると、相談ボタンから開けるようになります。")
                            .font(.footnote)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .navigationTitle(store.myCard == nil ? "カードを作る" : "カードを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        var updated = store.myCard ?? Supporter(name: "", specialty: "", region: "", message: "", lineURL: "")
        updated.name = trimmedName
        updated.specialty = trimmedSpecialty
        let trimmedRegion = region.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.region = trimmedRegion.isEmpty ? "応相談" : trimmedRegion
        updated.message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.lineURL = lineURL.trimmingCharacters(in: .whitespacesAndNewlines)
        store.saveMyCard(updated)
        dismiss()
    }
}
