import SwiftUI

// DESIGN-v3 §1: 独自の色はAccentColor(#00873C / dark #30D158)とLineGreen(#06C755)の2つだけ。
// それ以外は全部システムカラー（.primary / .secondary / Color(.systemFill) など）でダークモードに自動対応させる。
// DESIGN-v3 §4: SF Symbolsの名前一覧（Symbols.swift相当。ここに集約し、実在確認スクリプトが1箇所を見れば済むようにする）。
enum Symbol {
    static let referFriend = "person.2.fill"
    static let support = "briefcase.fill"
    static let help = "questionmark.circle"
    static let menu = "ellipsis.circle"
    static let area = "mappin"
    static let sent = "paperplane.fill"
    static let consulting = "bubble.left.and.bubble.right.fill"
    static let hired = "checkmark.seal.fill"
    static let elsewhere = "arrow.uturn.right"
    static let declined = "minus.circle"
    static let copy = "doc.on.doc"
    static let shareOther = "square.and.arrow.up"
    static let line = "message.fill"
    static let chevronRight = "chevron.right"
    static let chevronDown = "chevron.down"
    static let brokenLink = "link"
    static let pencil = "pencil"
    static let personAdd = "person.crop.circle.badge.plus"

    static func forStatus(_ status: ReferralStatus) -> String {
        switch status {
        case .sent: return sent
        case .consulting: return consulting
        case .hired: return hired
        case .elsewhere: return elsewhere
        case .declined: return declined
        }
    }
}

/// 主ボタン（LINE以外）。黒の塗り・ダークは白の塗り・52pt・カプセル。DESIGN-v3 §1, §3。
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 52
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 20)
            .foregroundStyle(Color(uiColor: .systemBackground))
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Color.primary, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// LINE操作専用の緑ボタン。DESIGN-v3 §1「塗り: LINEで送る/LINEで相談するボタンだけ」。
struct LineButtonStyle: ButtonStyle {
    var height: CGFloat = 52
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 20)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Color("LineGreen"), in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// 副ボタン。`--fill`地・`--label`文字・44pt・カプセル。
struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 44
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .padding(.horizontal, 20)
            .foregroundStyle(Color.primary)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(Color(.systemFill), in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var tsunaguPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
extension ButtonStyle where Self == LineButtonStyle {
    static var tsunaguLine: LineButtonStyle { LineButtonStyle() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var tsunaguSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

/// セル内の小さい「紹介する」チップ。`--fill`地・`--accent-text`文字・32pt見た目／44ptタップ域。
/// App Storeの「入手」ボタンと同じ作法（小カプセル・軽い塗り）。DESIGN-v3 §5-3。
struct SupporterInviteChip: View {
    var body: some View {
        Text("紹介する")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 14)
            .frame(height: 32)
            .background(Color(.systemFill), in: Capsule())
            .frame(minHeight: 44)
    }
}

/// 履歴セルの状態カプセル（Menuのラベル用）。`--fill`地・Subheadline・下向きシェブロン付き。DESIGN-v3 §5-6。
struct StatusCapsule: View {
    let status: ReferralStatus
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: Symbol.forStatus(status))
                .foregroundStyle(status == .hired ? Color.accentColor : Color.secondary)
            Text(status.rawValue)
            Image(systemName: Symbol.chevronDown).font(.footnote)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(status == .hired ? Color.accentColor : Color.primary)
        .padding(.horizontal, 10)
        .frame(height: 32)
        .background(Color(.systemFill), in: Capsule())
        .frame(minHeight: 44)
    }
}

/// 丸アバター。`--fill`地に名前の1文字目。DESIGN-v3 §5-3。
struct AvatarView: View {
    let name: String
    var size: CGFloat = 44
    var body: some View {
        Circle()
            .fill(Color(.systemFill))
            .frame(width: size, height: size)
            .overlay {
                Text(name.first.map(String.init) ?? "?")
                    .font(size > 44 ? .title.weight(.semibold) : .headline)
                    .foregroundStyle(Color.secondary)
            }
    }
}
