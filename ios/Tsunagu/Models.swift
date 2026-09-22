import Foundation
import Observation

struct Supporter: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var specialty: String
    var region: String
    var message: String
    var lineURL: String
}

enum ReferralStatus: String, Codable, CaseIterable, Identifiable {
    case sent = "送信済", consulting = "相談中", hired = "決まった！"
    case elsewhere = "別で決めた", declined = "見送り"
    var id: String { rawValue }
}

struct Referral: Identifiable, Codable {
    var id = UUID()
    var supporterID: UUID
    var createdAt = Date()
    var status: ReferralStatus = .sent
}

private struct SavedData: Codable {
    var supporters: [Supporter]
    var referrals: [Referral]
}

@MainActor @Observable
final class AppStore {
    private(set) var supporters: [Supporter] = []
    private(set) var referrals: [Referral] = []
    var storageError: String?
    private var canSave = true
    private let fileURL: URL

    init() {
        fileURL = URL.documentsDirectory.appending(path: "tsunagu.json")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try JSONDecoder().decode(SavedData.self, from: Data(contentsOf: fileURL))
                supporters = data.supporters
                referrals = data.referrals
            } catch {
                canSave = false
                storageError = "保存データを読み込めませんでした。再起動するか、データ全消去で初期化してください。"
            }
        } else {
            supporters = [Supporter(name: "サンプル支援者", specialty: "20代の転職・未経験IT", region: "全国・オンライン", message: "まず話を聞くところから", lineURL: "")]
            save()
        }
    }

    func supporter(_ id: UUID) -> Supporter? { supporters.first { $0.id == id } }
    func referral(_ id: UUID) -> Referral? { referrals.first { $0.id == id } }
    func counts(for id: UUID) -> (introduced: Int, hired: Int) {
        let records = referrals.filter { $0.supporterID == id }
        return (records.filter { $0.status != .sent }.count, records.filter { $0.status == .hired }.count)
    }
    func add(_ supporter: Supporter) { supporters.append(supporter); save() }
    @discardableResult func createReferral(for supporterID: UUID) -> UUID {
        let referral = Referral(supporterID: supporterID)
        referrals.insert(referral, at: 0)
        save()
        return referral.id
    }
    func setStatus(_ id: UUID, _ status: ReferralStatus) {
        guard let index = referrals.firstIndex(where: { $0.id == id }) else { return }
        referrals[index].status = status
        save()
    }
    func erase() {
        supporters = []; referrals = []; canSave = true
        save()
    }
    private func save() {
        guard canSave else { return }
        do {
            let data = try JSONEncoder().encode(SavedData(supporters: supporters, referrals: referrals))
            try data.write(to: fileURL, options: .atomic)
            storageError = nil
        } catch {
            storageError = "データを保存できませんでした。端末の空き容量などを確認してください。"
        }
    }
}

func validLineURL(_ text: String) -> URL? {
    guard let url = URL(string: text), url.scheme?.lowercased() == "https",
          let host = url.host?.lowercased(),
          host == "line.me" || host.hasSuffix(".line.me") || host == "lin.ee" else { return nil }
    return url
}
