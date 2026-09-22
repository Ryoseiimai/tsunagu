import SwiftUI

@main
struct TsunaguApp: App {
    @State private var store: AppStore = {
        #if DEBUG
        if DebugSeed.requestedState != nil {
            let url = FileManager.default.temporaryDirectory.appending(path: "tsunagu-preview.json")
            try? FileManager.default.removeItem(at: url)
            let defaults = UserDefaults(suiteName: "tsunagu.debug-preview")!
            defaults.removePersistentDomain(forName: "tsunagu.debug-preview")
            return AppStore(fileURL: url, defaults: defaults)
        }
        #endif
        return AppStore()
    }()
    var body: some Scene {
        WindowGroup { RootView(store: store) }
    }
}

private enum Route {
    case roleSelection
    case referHome
    case supportHome
    case consult(IncomingLink)
    case addConfirm(SupporterPayload)
}

/// 起動時・URL受信時のルーティング（SPEC-v2 §1）。
/// 優先順位はWeb版 index.html の init() と同じ:
/// 1. `s`があるか、`ref`がこの端末の紹介記録と一致する → 相談する画面（役割を聞かない）
/// 2. `add`が復号できる → 追加確認画面
/// 3. 役割が未設定 → 役割選択
/// 4. それ以外 → 役割のホーム
struct RootView: View {
    let store: AppStore

    @State private var toastCenter = ToastCenter()
    @State private var route: Route = .roleSelection
    // onOpenURLとonAppearのどちらが先に来ても正しいルートに決まるようにするためのガード
    // （URL付き起動でonOpenURLが先に来た場合、onAppearの無条件な再計算が上書きしてしまうのを防ぐ）。
    @State private var hasComputedInitialRoute = false

    // スクショ検証用のDEBUG起動引数注入で使う自動プレゼン先。Releaseでは常にnil/falseのまま
    // （下のapplyDebugStateIfNeeded自体が#if DEBUGでReleaseに存在しないため、代入する箇所が無い）。
    @State private var autoPresentSupporterID: UUID?
    @State private var autoPresentEdit = false
    @State private var autoPresentDistribute = false

    var body: some View {
        Group {
            switch route {
            case .roleSelection:
                RoleSelectionView(onSelect: { role in
                    store.role = role
                    recomputeRoute()
                })
            case .referHome:
                ReferHomeView(
                    store: store,
                    onChangeRole: { store.role = nil; recomputeRoute() },
                    onNeedsReroute: { recomputeRoute() },
                    autoPresentSupporterID: autoPresentSupporterID
                )
            case .supportHome:
                SupportHomeView(
                    store: store,
                    onChangeRole: { store.role = nil; recomputeRoute() },
                    onNeedsReroute: { recomputeRoute() },
                    autoPresentEdit: autoPresentEdit,
                    autoPresentDistribute: autoPresentDistribute
                )
            case .consult(let link):
                ConsultView(store: store, link: link, onDone: { recomputeRoute() }).id(link)
            case .addConfirm(let payload):
                AddConfirmView(store: store, payload: payload, onResult: { result in
                    if result == .added { route = .referHome } else { recomputeRoute() }
                })
            }
        }
        .toastOverlay()
        .environment(toastCenter)
        .tint(Color.accentColor)
        .onAppear {
            guard !hasComputedInitialRoute else { return }
            hasComputedInitialRoute = true
            applyDebugStateIfNeeded()
            #if DEBUG
            recomputeRoute(link: DebugSeed.incomingLink)
            #else
            recomputeRoute()
            #endif
            if let error = store.storageError { toastCenter.show(error) }
        }
        .onChange(of: store.storageError) { _, error in
            if let error { toastCenter.show(error) }
        }
        .onOpenURL { url in
            hasComputedInitialRoute = true
            recomputeRoute(link: IncomingLink(url: url))
        }
    }

    #if DEBUG
    private func applyDebugStateIfNeeded() {
        guard let requested = DebugSeed.requestedState else { return }
        DebugSeed.apply(requested, to: store)
        if requested == .referSheet { autoPresentSupporterID = store.supporters.first?.id }
        if requested == .cardEdit { autoPresentEdit = true }
        if requested == .distributeSheet { autoPresentDistribute = true }
    }
    #else
    private func applyDebugStateIfNeeded() {}
    #endif

    private func recomputeRoute(link: IncomingLink? = nil) {
        if let link {
            let refFound = link.ref.flatMap(UUID.init(uuidString:)).flatMap(store.referral) != nil
            if link.s != nil || refFound {
                route = .consult(link)
                return
            }
            if let addRaw = link.add {
                if let decoded = try? decodeSupporterParam(addRaw) {
                    route = .addConfirm(decoded)
                    return
                }
                // Web版 addResult.error と同じ: 壊れたaddは画面を専有せず、トーストのみ出して通常ルーティングへ。
                toastCenter.show("リンクが壊れているようです")
            }
        }
        route = (store.role == nil) ? .roleSelection : (store.role == .refer ? .referHome : .supportHome)
    }
}
