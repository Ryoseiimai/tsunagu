import Foundation

// 意図的に省いた点（SPEC-v2 §6 / index.htmlの冒頭コメントと同じ内容をiOS側にも残す）:
// - 本物のプッシュ通知: 「決まった！」を押しても実際には誰にも通知が飛ばない。画面内トーストのみ。
//   本格対応はサーバー側でAPNs/LINE Notify等を叩く入口を作る。
// - サーバー保存・端末間同期: 全データは端末内（UserDefaults / Documents/tsunagu.json）のみ。
//   紹介した人・支援者・求職者の3者間で状態が自動同期しない（相手の操作で状態が変わるのは同じ端末で試したときだけ）。
//   本格対応はAPIサーバー+DBに置き換える。
// - 認証: 誰でも「自分のカードを作る」ができ、本人確認なし。本格対応はLINEログイン等のOAuth。
// - 紹介者名(&by=)の発行: 紹介する人自身の名前を入力する導線が無いため、リンク生成時に&by=を載せる処理は未実装
//   （受け取り側のデコードのみ実装済み）。本格対応は紹介する人のプロフィール入力欄を追加する。
// - 「紹介されてきた人」一覧・紹介実績カウント(referredCount/decidedCount)は、紹介する人の端末内にある
//   supporters配列に対してのみ加算される（Web版と同じ仕様）。myCardはこの配列に含まれないため、
//   支援する人が自分の端末で自分のカードの実績を見ることは今はできない。本格対応はサーバー側で
//   支援者IDに紐付けて配信する。

/// 役割（紹介する人 / 支援する人）。未設定は「役割を聞かれる前」を表す。
enum Role: String, Codable {
    case refer
    case support
}

/// 紹介文のトーン。rawValueはPicker(.segmented)にそのまま出す表示文言。
enum Tone: String, Codable, CaseIterable, Identifiable {
    case casual = "カジュアル"
    case polite = "ていねい"
    var id: String { rawValue }
}

/// 紹介の状態。rawValueはSPEC-v2 / Web版(index.html)の文言とそろえてある。
enum ReferralStatus: String, Codable, CaseIterable, Identifiable {
    case sent = "送った"
    case consulting = "相談してるみたい"
    case hired = "決まった！"
    case elsewhere = "別のところで決まった"
    case declined = "見送り"
    var id: String { rawValue }

    /// 「紹介n件」に数える状態か（Web版 STATUS_COUNTED_AS_REFERRED と同じ）。
    var countsAsReferred: Bool { self != .sent }

    /// v1(旧rawValue)からの移行用。旧データが読み込めても文言が変わっていて一致しない問題を防ぐ。
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        if let matched = ReferralStatus(rawValue: raw) {
            self = matched
            return
        }
        switch raw {
        case "送信済": self = .sent
        case "相談中": self = .consulting
        case "別で決めた": self = .elsewhere
        default: self = .sent
        }
    }
}

/// 支援者カード。「紹介できる人」リストの1件にも、支援する人自身のカード(myCard)にも使う。
/// プロパティ名はv1(Models.swift)から変えていない＝旧保存データをそのまま読み込める。
struct Supporter: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var specialty: String
    var region: String
    var message: String
    var lineURL: String
    var referredCount: Int = 0
    var decidedCount: Int = 0
    // 配布リンクの使い回しキャッシュ。カード内容(addパラメータ)が変わったら取り直す。
    var distributeAddParam: String?
    var distributeShortURL: String?

    init(id: UUID = UUID(), name: String, specialty: String, region: String, message: String, lineURL: String,
         referredCount: Int = 0, decidedCount: Int = 0, distributeAddParam: String? = nil, distributeShortURL: String? = nil) {
        self.id = id
        self.name = name
        self.specialty = specialty
        self.region = region
        self.message = message
        self.lineURL = lineURL
        self.referredCount = referredCount
        self.decidedCount = decidedCount
        self.distributeAddParam = distributeAddParam
        self.distributeShortURL = distributeShortURL
    }

    // v1データにはreferredCount等のキーが無いため、無ければ既定値で補う（decodeIfPresent）。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        specialty = try c.decode(String.self, forKey: .specialty)
        region = try c.decode(String.self, forKey: .region)
        message = try c.decode(String.self, forKey: .message)
        lineURL = try c.decode(String.self, forKey: .lineURL)
        referredCount = try c.decodeIfPresent(Int.self, forKey: .referredCount) ?? 0
        decidedCount = try c.decodeIfPresent(Int.self, forKey: .decidedCount) ?? 0
        distributeAddParam = try c.decodeIfPresent(String.self, forKey: .distributeAddParam)
        distributeShortURL = try c.decodeIfPresent(String.self, forKey: .distributeShortURL)
    }
}

struct Referral: Identifiable, Codable {
    var id = UUID()
    var supporterID: UUID
    var friendName: String?
    var tone: Tone = .casual
    var createdAt = Date()
    var status: ReferralStatus = .sent
    // 一度だけ加算するためのフラグ（Web版 countedReferred/countedDecided と同じ）。
    var countedReferred = false
    var countedDecided = false

    init(id: UUID = UUID(), supporterID: UUID, friendName: String? = nil, tone: Tone = .casual,
         createdAt: Date = Date(), status: ReferralStatus = .sent, countedReferred: Bool = false, countedDecided: Bool = false) {
        self.id = id
        self.supporterID = supporterID
        self.friendName = friendName
        self.tone = tone
        self.createdAt = createdAt
        self.status = status
        self.countedReferred = countedReferred
        self.countedDecided = countedDecided
    }

    // v1データにはfriendName/tone/countedReferred/countedDecidedのキーが無いため既定値で補う。
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        supporterID = try c.decode(UUID.self, forKey: .supporterID)
        friendName = try c.decodeIfPresent(String.self, forKey: .friendName)
        tone = try c.decodeIfPresent(Tone.self, forKey: .tone) ?? .casual
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        status = try c.decodeIfPresent(ReferralStatus.self, forKey: .status) ?? .sent
        countedReferred = try c.decodeIfPresent(Bool.self, forKey: .countedReferred) ?? false
        countedDecided = try c.decodeIfPresent(Bool.self, forKey: .countedDecided) ?? false
    }
}

/// LINE URLの簡易バリデーション（line.me / lin.ee のhttpsのみ許可）。v1から変更なし。
func validLineURL(_ text: String) -> URL? {
    guard let url = URL(string: text), url.scheme?.lowercased() == "https",
          let host = url.host?.lowercased(),
          host == "line.me" || host.hasSuffix(".line.me") || host == "lin.ee" else { return nil }
    return url
}
