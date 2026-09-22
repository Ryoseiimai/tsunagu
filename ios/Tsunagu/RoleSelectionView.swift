import SwiftUI

/// 役割選択画面。SPEC-v2 §1 / DESIGN-v3 §5-8。
struct RoleSelectionView: View {
    var onSelect: (Role) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 10) {
                    Image("Logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    Text("つなぐ").font(.largeTitle.bold())
                    Text("仕事探しを、友達の紹介で。")
                        .font(.body)
                        .foregroundStyle(Color.secondary)
                }
                .padding(.top, 24)

                VStack(alignment: .leading, spacing: 14) {
                    Text("どちらで使いますか？").font(.title3.weight(.semibold))

                    RoleCell(
                        symbol: Symbol.referFriend,
                        title: "友達を紹介したい",
                        description: "仕事を探してる友達を、相談できる人に繋ぐ",
                        action: { onSelect(.refer) }
                    )
                    RoleCell(
                        symbol: Symbol.support,
                        title: "仕事探しを手伝っている",
                        description: "自分のカードを作って、紹介してもらう",
                        action: { onSelect(.support) }
                    )
                }

                Link(destination: URL(string: manualURLString)!) {
                    Text("使い方を見る")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .frame(minHeight: 44)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct RoleCell: View {
    let symbol: String
    let title: String
    let description: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Circle()
                    .fill(Color(.systemFill))
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: symbol).foregroundStyle(Color.accentColor)
                    }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline).foregroundStyle(Color.primary)
                    Text(description).font(.subheadline).foregroundStyle(Color.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: Symbol.chevronRight)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
            }
            .padding(16)
            .frame(minHeight: 120)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RoleSelectionView(onSelect: { _ in })
}
