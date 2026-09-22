import Foundation

// 公開URL・短縮リンクAPIの入出力形はWeb版(index.html)と完全に同じにする。
// これにより、iOSで作ったリンクをWeb版で開いても(逆も)正しく解ける。
let publicBaseURLString = "https://ryoseiimai.github.io/tsunagu/"
let manualURLString = publicBaseURLString + "manual.html"
private let shortenAPIEndpoint = URL(string: "https://tsunagu.densalon.com/api/shorten")!
private let shortenTimeout: TimeInterval = 4

enum LinkError: Error { case decodeFailed }

/// URLの `s=` / `add=` に載せる支援者カードの中身。SPEC-v2 §5の {name, skill, area, comment, lineUrl} と同じキー。
struct SupporterPayload: Codable, Equatable {
    var name: String
    var skill: String
    var area: String
    var comment: String
    var lineUrl: String
}

extension SupporterPayload {
    init(_ supporter: Supporter) {
        self.init(name: supporter.name, skill: supporter.specialty, area: supporter.region,
                   comment: supporter.message, lineUrl: supporter.lineURL)
    }
}

extension Supporter {
    /// URLから届いたカードを画面表示用に持つ。idは表示にしか使わないため使い捨てでよい（Web版と同じ扱い）。
    init(payload: SupporterPayload) {
        self.init(name: payload.name, specialty: payload.skill, region: payload.area,
                   message: payload.comment, lineURL: payload.lineUrl)
    }
}

// ---------- base64url（日本語対応） ----------
// Web版 encodeTextParam/decodeTextParam/encodeSupporterParam/decodeSupporterParam と同じ変換。

func base64URLEncode(_ data: Data) -> String {
    data.base64EncodedString()
        .replacingOccurrences(of: "+", with: "-")
        .replacingOccurrences(of: "/", with: "_")
        .replacingOccurrences(of: "=", with: "")
}

func base64URLDecode(_ string: String) -> Data? {
    var padded = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
    while padded.count % 4 != 0 { padded += "=" }
    return Data(base64Encoded: padded)
}

func encodeTextParam(_ text: String) -> String { base64URLEncode(Data(text.utf8)) }

func decodeTextParam(_ string: String) throws -> String {
    guard let data = base64URLDecode(string), let text = String(data: data, encoding: .utf8) else {
        throw LinkError.decodeFailed
    }
    return text
}

func encodeSupporterParam(_ payload: SupporterPayload) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
    return base64URLEncode(try encoder.encode(payload))
}

func decodeSupporterParam(_ string: String) throws -> SupporterPayload {
    guard let data = base64URLDecode(string) else { throw LinkError.decodeFailed }
    return try JSONDecoder().decode(SupporterPayload.self, from: data)
}

// ---------- URL組み立て ----------

/// 紹介1画面のフォールバック用ロングリンク（短縮APIが失敗した時に使う）。Web版 regeneratePreview と同じ形。
func longReferralURL(payload: SupporterPayload, refID: UUID) -> URL? {
    guard let encoded = try? encodeSupporterParam(payload) else { return nil }
    var components = URLComponents(string: publicBaseURLString)!
    components.queryItems = [
        URLQueryItem(name: "s", value: encoded),
        URLQueryItem(name: "ref", value: refID.uuidString),
    ]
    return components.url
}

/// 配布リンクのフォールバック用ロングリンク。Web版 btnDistribute ハンドラと同じ形。
func longDistributeURL(payload: SupporterPayload) -> URL? {
    guard let encoded = try? encodeSupporterParam(payload) else { return nil }
    var components = URLComponents(string: publicBaseURLString)!
    components.queryItems = [URLQueryItem(name: "add", value: encoded)]
    return components.url
}

/// LINEのシェア画面を開くURL（Web版 `https://line.me/R/share?text=...` と同じ）。
func lineShareURL(text: String) -> URL? {
    // encodeURIComponentと同じ。URLComponentsでは「+」が残り、LINE側で空白になる。
    let allowed = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.!~*'()")
    guard let encoded = text.addingPercentEncoding(withAllowedCharacters: allowed) else { return nil }
    return URL(string: "https://line.me/R/share?text=" + encoded)
}

// ---------- 短縮リンクAPI ----------

enum ShortenClient {
    /// 失敗・タイムアウト時はnilを返す（呼び出し側が長いURLにフォールバックする）。Web版 shortenLink と同じ契約。
    /// 罠: /api/shorten は `s` が無いbody（addのみ等）を400で拒否する（Worker側の既知の未対応。HANDOFF.md参照）。
    /// その場合もここでnilにフォールバックするだけで、呼び出し側は長いURLを使う。
    static func shorten(s: String? = nil, ref: String? = nil, by: String? = nil, add: String? = nil) async -> String? {
        var body: [String: String] = [:]
        if let s { body["s"] = s }
        if let ref { body["ref"] = ref }
        if let by { body["by"] = by }
        if let add { body["add"] = add }
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return nil }

        var request = URLRequest(url: shortenAPIEndpoint, timeoutInterval: shortenTimeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
            return try JSONDecoder().decode(ShortenResponse.self, from: data).url
        } catch {
            return nil
        }
    }

    private struct ShortenResponse: Decodable { let url: String? }
}

// ---------- 受信したURL(?s= / ?add= / tsunagu://)の読み取り ----------

/// tsunagu:// カスタムスキーム、または公開URLのクエリと同じ形の値をまとめて読む。
/// ホスト/パスは見ない（Web版のURLSearchParamsと同じく、クエリの名前だけで判定する）。
struct IncomingLink: Hashable {
    var s: String?
    var ref: String?
    var by: String?
    var add: String?

    init(url: URL) {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first(where: { $0.name == name })?.value ?? (items.contains(where: { $0.name == name }) ? "" : nil) }
        s = value("s")
        ref = value("ref")
        by = value("by")
        add = value("add")
    }
}
