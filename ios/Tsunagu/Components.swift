import SwiftUI

// ---------- トースト（DESIGN-v3 §5-7）----------
// alert/confirm/promptは使わない（SPEC-v2 §6）。確認は全部これかMenuの2度押しで行う。

@MainActor @Observable
final class ToastCenter {
    private(set) var message: String?
    private var dismissTask: Task<Void, Never>?

    func show(_ message: String) {
        self.message = message
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            if Task.isCancelled { return }
            self?.message = nil
        }
    }
}

private struct ToastOverlayModifier: ViewModifier {
    @Environment(ToastCenter.self) private var toastCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message = toastCenter.message {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text(message)
                }
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
                .foregroundStyle(Color(uiColor: .systemBackground))
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Color.primary, in: Capsule())
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: toastCenter.message)
    }
}

extension View {
    func toastOverlay() -> some View { modifier(ToastOverlayModifier()) }
}

// ---------- 紙吹雪（DESIGN-v3 §5-6「決まった！」）----------

struct ConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animate = false
    private let particles: [ConfettiParticle] = (0..<22).map { _ in .random() }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(particles) { particle in
                    Capsule()
                        .fill(particle.color)
                        .frame(width: particle.size.width, height: particle.size.height)
                        .position(
                            x: proxy.size.width * particle.startX,
                            y: animate ? proxy.size.height * particle.endY : -16
                        )
                        .opacity(animate ? 0 : 1)
                        .rotationEffect(.degrees(animate ? particle.rotation : 0))
                }
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeIn(duration: 1.2)) { animate = true }
        }
    }
}

private struct ConfettiParticle: Identifiable {
    let id = UUID()
    let startX: CGFloat
    let endY: CGFloat
    let size: CGSize
    let color: Color
    let rotation: Double

    static func random() -> ConfettiParticle {
        ConfettiParticle(
            startX: .random(in: 0.05...0.95),
            endY: .random(in: 0.6...1.05),
            size: CGSize(width: .random(in: 4...7), height: .random(in: 8...14)),
            color: [Color.accentColor, Color.primary, Color.secondary].randomElement()!,
            rotation: .random(in: 0...360)
        )
    }
}

// ---------- 支援者セル（DESIGN-v3 §5-3）----------

struct SupporterRow: View {
    let supporter: Supporter
    let counts: (referred: Int, decided: Int)
    var onIntroduce: () -> Void

    var body: some View {
        Button(action: onIntroduce) {
            HStack(alignment: .top, spacing: 12) {
                AvatarView(name: supporter.name)
                VStack(alignment: .leading, spacing: 4) {
                    Text(supporter.name).font(.headline).foregroundStyle(Color.primary)
                    if !supporter.specialty.isEmpty {
                        Text(supporter.specialty).font(.subheadline).foregroundStyle(Color.secondary)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: Symbol.area)
                        Text(supporter.region)

                    }
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
                    Text("紹介 \(counts.referred) ・決まった \(counts.decided)")
                        .font(.footnote).foregroundStyle(Color.secondary)
                    if !supporter.message.isEmpty {
                        Text(supporter.message)
                            .font(.subheadline)
                            .foregroundStyle(Color.primary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 8)
                SupporterInviteChip()
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// ---------- 履歴セル（DESIGN-v3 §5-6）----------

struct HistoryRow: View {
    let referral: Referral
    let supporterName: String
    var onChangeStatus: (ReferralStatus) -> Void

    // 紙吹雪は「今まさにhiredへ変わった瞬間」だけ出す。既にhiredな行が再描画・再出現しても出さない。
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showConfetti = false
    @State private var celebrateTrigger = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: Symbol.forStatus(referral.status))
                    .font(.footnote)
                    .foregroundStyle(referral.status == .hired ? Color.accentColor : Color.secondary)
                    .frame(width: 28, height: 28)
                    .background(Color(.systemFill), in: Circle())
                Text(title).font(.headline)
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    dateLabel
                    Spacer(minLength: 8)
                    statusMenu.fixedSize()
                }
                VStack(alignment: .leading, spacing: 4) {
                    dateLabel
                    statusMenu
                }
            }
            if referral.status == .hired {
                Text("よかったね！").font(.headline).foregroundStyle(Color.accentColor)
            }
        }
        .padding(.vertical, 4)
        .overlay {
            if showConfetti { ConfettiView() }
        }
        .sensoryFeedback(.success, trigger: celebrateTrigger)
        .onChange(of: referral.status) { oldValue, newValue in
            guard newValue == .hired, oldValue != .hired else { return }
            celebrateTrigger.toggle()
            showConfetti = !reduceMotion
            Task {
                try? await Task.sleep(for: .seconds(1.3))
                showConfetti = false
            }
        }
    }

    private var dateLabel: some View {
        Text(referral.createdAt.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP"))))
            .font(.footnote).foregroundStyle(Color.secondary)
            .fixedSize()
    }

    private var statusMenu: some View {
        Menu {
            ForEach(ReferralStatus.allCases) { status in
                Button { onChangeStatus(status) } label: {
                    Label(status.rawValue, systemImage: Symbol.forStatus(status))
                }
            }
        } label: {
            StatusCapsule(status: referral.status)
        }
    }

    // Web版(index.html) renderReferralRecords の nameLine と同じ組み立て方
    // （支援者名には「さん」を付けず、友達の名前がある時だけ「 → {友達}さん」を続ける）。
    private var title: String {
        if let friend = referral.friendName, !friend.isEmpty {
            return "\(supporterName) → \(friend)さん"
        }
        return supporterName
    }
}

// ---------- 大きいカード（DESIGN-v3 §5-11）。支援ホームのプレビューと求職者画面で共有する ----------

struct SupporterBigCard: View {
    let supporter: Supporter

    var body: some View {
        VStack(spacing: 14) {
            AvatarView(name: supporter.name, size: 72)
            Text(supporter.name).font(.title.bold()).multilineTextAlignment(.center)
            if !supporter.specialty.isEmpty {
                Text(supporter.specialty).font(.body).foregroundStyle(Color.secondary)
            }
            if !supporter.region.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: Symbol.area)
                    Text(supporter.region)
                }
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemFill), in: Capsule())
            }
            if !supporter.message.isEmpty {
                Text(supporter.message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .foregroundStyle(Color.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// ---------- 「紹介されてきた人」行（DESIGN-v3 §5-9）。読み取り専用（状態を変えられるのは紹介した人の端末だけ）----------

struct ReceivedRow: View {
    let referral: Referral

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(referral.friendName?.isEmpty == false ? "\(referral.friendName!)さん" : "（名前未設定）")
                    .font(.headline)
                Text(referral.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.footnote)
                    .foregroundStyle(Color.secondary)
            }
            Spacer()
            Label(referral.status.rawValue, systemImage: Symbol.forStatus(referral.status))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(referral.status == .hired ? Color.accentColor : Color.secondary)
                .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 4)
    }
}
