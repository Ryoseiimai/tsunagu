import SwiftUI
import UIKit

@main
struct TsunaguApp: App {
    @State private var store = AppStore()
    var body: some Scene {
        WindowGroup { RootView(store: store) }
    }
}

private let accent = Color(red: 6 / 255, green: 199 / 255, blue: 85 / 255)

struct RootView: View {
    @Bindable var store: AppStore
    @State private var tab = 0
    @State private var activeReferral: UUID?
    @State private var selectedSupporter: UUID?
    @State private var linkError: String?
    @State private var resetArmed = false
    @State private var resetVersion = UUID()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("つなぐ").font(.largeTitle.bold())
                    Text("仕事探しを、友達の紹介で。").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "person.2.fill").font(.title).foregroundStyle(accent)
            }.padding()
            if let error = store.storageError {
                Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal)
            }
            TabView(selection: $tab) {
                SupportersView(store: store).tabItem { Label("支援者", systemImage: "person.2.fill") }.tag(0)
                ReferralsView(store: store).tabItem { Label("紹介する", systemImage: "link") }.tag(1)
                ConsultView(store: store, activeReferral: $activeReferral, selectedSupporter: $selectedSupporter, linkError: $linkError)
                    .tabItem { Label("相談する", systemImage: "bubble.left.and.bubble.right.fill") }.tag(2)
            }.id(resetVersion)
            HStack {
                Button(resetArmed ? "もう一度押して全消去" : "データ全消去") {
                    if resetArmed {
                        store.erase()
                        activeReferral = nil; selectedSupporter = nil; linkError = nil
                        resetVersion = UUID()
                        resetArmed = false
                    } else { resetArmed = true }
                }.foregroundStyle(resetArmed ? .red : .secondary)
                if resetArmed { Button("キャンセル") { resetArmed = false } }
            }.font(.caption).frame(minHeight: 44)
        }
        .tint(accent)
        .preferredColorScheme(.light)
        .onOpenURL { url in
            guard url.scheme?.lowercased() == "tsunagu", url.host == "ref" else { return }
            tab = 2
            activeReferral = nil; selectedSupporter = nil
            guard url.pathComponents.count == 2,
                  let id = UUID(uuidString: url.lastPathComponent),
                  let referral = store.referral(id), store.supporter(referral.supporterID) != nil else {
                linkError = "この紹介はこの端末にありません。試作では同じ端末に保存された紹介のみ開けます。"
                return
            }
            linkError = nil
            activeReferral = id; selectedSupporter = referral.supporterID
        }
    }
}

struct SupporterCard: View {
    let supporter: Supporter
    let counts: (introduced: Int, hired: Int)
    var large = false
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(supporter.name, systemImage: "checkmark.seal.fill")
                .font(large ? .title.bold() : .title3.bold())
            Text(supporter.specialty).font(.headline)
            Label(supporter.region, systemImage: "mappin.and.ellipse").font(.subheadline).foregroundStyle(.secondary)
            Text(supporter.message).font(large ? .title3 : .body)
            HStack {
                Text("紹介 \(counts.introduced)件")
                Text("決定 \(counts.hired)件")
            }.font(.subheadline.bold()).foregroundStyle(.black)
                .padding(10).background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        }.frame(maxWidth: .infinity, alignment: .leading).padding(20)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.black.opacity(0.1)))
    }
}

struct ActionButton: View {
    let title: String
    let symbol: String
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(.headline)
                .frame(maxWidth: .infinity, minHeight: 48)
                .foregroundStyle(.black).background(accent, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }
}

struct SupportersView: View {
    let store: AppStore
    @State private var showForm = false
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ActionButton(title: "自分のカードを作る", symbol: "plus") { showForm = true }
                if store.supporters.isEmpty { Text("あなたの支援者カードを作ってみましょう。").foregroundStyle(.secondary) }
                ForEach(store.supporters) { supporter in
                    SupporterCard(supporter: supporter, counts: store.counts(for: supporter.id))
                }
            }.padding()
        }.sheet(isPresented: $showForm) { SupporterForm(store: store) }
    }
}

struct SupporterForm: View {
    let store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var specialty = ""
    @State private var region = ""
    @State private var message = ""
    @State private var lineURL = ""
    private func clean(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var valid: Bool {
        [name, specialty, region, message].allSatisfy { !clean($0).isEmpty } && validLineURL(clean(lineURL)) != nil
    }
    var body: some View {
        NavigationStack {
            Form {
                Section("支援者プロフィール") {
                    TextField("名前", text: $name)
                    TextField("得意分野", text: $specialty)
                    TextField("対応地域", text: $region)
                    TextField("一言", text: $message, axis: .vertical)
                    TextField("LINE URL", text: $lineURL).keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                }
                Section {
                    Text("すべて入力してください。LINE URLは https://line.me/… または https://lin.ee/… を使えます。").font(.caption).foregroundStyle(.secondary)
                    ActionButton(title: "カードを保存", symbol: "checkmark") {
                        store.add(Supporter(name: clean(name), specialty: clean(specialty), region: clean(region), message: clean(message), lineURL: clean(lineURL)))
                        dismiss()
                    }.disabled(!valid).opacity(valid ? 1 : 0.4)
                }
            }.navigationTitle("自分のカードを作る")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() }.frame(minHeight: 44) } }
        }
    }
}
