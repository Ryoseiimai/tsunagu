import Foundation
import Observation

private struct SavedData: Codable {
    var supporters: [Supporter]
    var referrals: [Referral]
    var myCard: Supporter?

    init(supporters: [Supporter], referrals: [Referral], myCard: Supporter?) {
        self.supporters = supporters
        self.referrals = referrals
        self.myCard = myCard
    }

    // v1データにはmyCardキーが無いため、無ければnilで補う。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        supporters = try c.decodeIfPresent([Supporter].self, forKey: .supporters) ?? []
        referrals = try c.decodeIfPresent([Referral].self, forKey: .referrals) ?? []
        myCard = try c.decodeIfPresent(Supporter.self, forKey: .myCard)
    }
}

/// 固定のサンプル支援者（「見本で試す」）。Web版 btn-try-sample と同じ内容。
let sampleSupporter = Supporter(
    name: "サンプル支援者",
    specialty: "20代の転職・未経験IT",
    region: "全国・オンライン",
    message: "まず話を聞くところから",
    lineURL: "https://line.me/ti/p/xxxx"
)

@MainActor @Observable
final class AppStore {
    private(set) var supporters: [Supporter] = []
    private(set) var referrals: [Referral] = []
    private(set) var myCard: Supporter?
    var storageError: String?
    var role: Role? {
        didSet { defaults.set(role?.rawValue, forKey: Self.roleKey) }
    }

    private var canSave = true
    private let fileURL: URL
    private let defaults: UserDefaults
    private static let roleKey = "tsunagu.role"

    init(fileURL: URL = URL.documentsDirectory.appending(path: "tsunagu.json"), defaults: UserDefaults = .standard) {
        self.fileURL = fileURL
        self.defaults = defaults
        role = defaults.string(forKey: Self.roleKey).flatMap(Role.init(rawValue:))
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try JSONDecoder().decode(SavedData.self, from: Data(contentsOf: fileURL))
                supporters = data.supporters
                referrals = data.referrals
                myCard = data.myCard
                // v1には累計・加算済みフラグがない。既存実績を一度だけ復元する。
                for index in referrals.indices {
                    guard let supporterIndex = supporters.firstIndex(where: { $0.id == referrals[index].supporterID }) else { continue }
                    if referrals[index].status.countsAsReferred, !referrals[index].countedReferred {
                        supporters[supporterIndex].referredCount += 1
                        referrals[index].countedReferred = true
                    }
                    if referrals[index].status == .hired, !referrals[index].countedDecided {
                        supporters[supporterIndex].decidedCount += 1
                        referrals[index].countedDecided = true
                    }
                }
            } catch {
                canSave = false
                storageError = "保存データを読み込めませんでした。再起動するか、データ全消去で初期化してください。"
            }
        }
    }

    // ---------- 参照 ----------
    // Web版 findSupporter と同じ: supporters配列だけを探す（myCardは対象外）。
    func supporter(_ id: UUID) -> Supporter? { supporters.first { $0.id == id } }
    func referral(_ id: UUID) -> Referral? { referrals.first { $0.id == id } }

    /// 「紹介n件・決まったm件」。myCardなど配列外のIDは0/0を返す（Web版と同じ挙動）。
    func counts(for id: UUID) -> (referred: Int, decided: Int) {
        let s = supporter(id)
        return (s?.referredCount ?? 0, s?.decidedCount ?? 0)
    }

    /// support-role側の「紹介されてきた人」一覧。myCard.idに紐づく紹介記録のみ。
    var receivedReferrals: [Referral] {
        guard let myCard else { return [] }
        return referrals.filter { $0.supporterID == myCard.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var sortedReferrals: [Referral] { referrals.sorted { $0.createdAt > $1.createdAt } }

    // ---------- 紹介する人：支援者リスト ----------
    func addSampleSupporter() {
        supporters.append(sampleSupporter)
        save()
    }

    /// ?add= / ?s= から届いたカードを、name+specialtyが一致するものが無ければ追加する。
    /// Web版と同じく、既にある場合は「新規に生成したidを持つ表示用の値」を返すだけで配列には追加しない
    /// （その値のid/referredCount/decidedCountは表示にしか使わない）。
    @discardableResult
    func importSupporterIfNeeded(_ payload: SupporterPayload) -> Supporter {
        let fresh = Supporter(name: payload.name, specialty: payload.skill, region: payload.area,
                               message: payload.comment, lineURL: payload.lineUrl)
        let already = supporters.contains { $0.name == payload.name && $0.specialty == payload.skill }
        if !already {
            supporters.append(fresh)
            save()
        }
        return fresh
    }

    // ---------- 紹介1画面 ----------
    // idを呼び出し側から渡せるようにしてあるのは、紹介シートが短縮リンクの`ref=`に使うUUIDと
    // 保存する紹介記録のidを同じ値にそろえるため（Web版 currentRefId と同じ役割）。
    @discardableResult
    func createReferral(id: UUID = UUID(), for supporterID: UUID, friendName: String?, tone: Tone) -> UUID {
        let trimmed = friendName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let referral = Referral(id: id, supporterID: supporterID, friendName: (trimmed?.isEmpty ?? true) ? nil : trimmed, tone: tone)
        referrals.insert(referral, at: 0)
        save()
        return referral.id
    }

    /// Web版 updateReferralStatus と同じ「一度だけ加算」ロジック。
    /// supportersの外(myCard)にあるsupporterIDは対象外＝そのままWeb版の仕様を踏襲。
    func setStatus(_ id: UUID, _ newStatus: ReferralStatus) {
        guard let index = referrals.firstIndex(where: { $0.id == id }) else { return }
        referrals[index].status = newStatus
        if let sIndex = supporters.firstIndex(where: { $0.id == referrals[index].supporterID }) {
            if newStatus.countsAsReferred, !referrals[index].countedReferred {
                supporters[sIndex].referredCount += 1
                referrals[index].countedReferred = true
            }
            if newStatus == .hired, !referrals[index].countedDecided {
                supporters[sIndex].decidedCount += 1
                referrals[index].countedDecided = true
            }
        }
        save()
    }

    // ---------- 支援する人：自分のカード ----------
    func saveMyCard(_ supporter: Supporter) {
        var updated = supporter
        // カード内容が変わったら配布リンクのキャッシュは無効化する（Web版のコメントと同じ意図）。
        if myCard?.distributeAddParam != nil, myCard?.name != supporter.name || myCard?.specialty != supporter.specialty
            || myCard?.region != supporter.region || myCard?.message != supporter.message || myCard?.lineURL != supporter.lineURL {
            updated.distributeAddParam = nil
            updated.distributeShortURL = nil
        }
        myCard = updated
        save()
    }

    func cacheDistributeLink(addParam: String, shortURL: String) {
        myCard?.distributeAddParam = addParam
        myCard?.distributeShortURL = shortURL
        save()
    }

    // ---------- 全消去 ----------
    func erase() {
        supporters = []; referrals = []; myCard = nil; canSave = true
        role = nil
        save()
    }

    private func save() {
        guard canSave else { return }
        do {
            let data = try JSONEncoder().encode(SavedData(supporters: supporters, referrals: referrals, myCard: myCard))
            try data.write(to: fileURL, options: .atomic)
            storageError = nil
        } catch {
            storageError = "データを保存できませんでした。端末の空き容量などを確認してください。"
        }
    }
}
