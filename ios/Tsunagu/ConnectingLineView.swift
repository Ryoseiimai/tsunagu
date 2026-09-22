import SwiftUI

/// 紹介シートと求職者画面だけに置く、二人が近づいてつながる線。
struct ConnectingLineView: View {
    let leftName: String
    let rightName: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var connected = false
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 0) {
            endpoint(name: leftName)
            connection
            Image(systemName: "link")
                .font(.headline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)
                .scaleEffect(connected || reduceMotion ? 1 : 0.6)
                .opacity(connected || reduceMotion ? 1 : 0)
            connection
            endpoint(name: rightName)
        }
        .frame(height: 44)
        .accessibilityHidden(true)
        .onAppear {
            guard !appeared else { return }
            appeared = true
            if reduceMotion { connected = true }
            else { withAnimation(.spring(duration: 0.4)) { connected = true } }
        }
    }

    private var connection: some View {
        Rectangle()
            .fill(Color.secondary.opacity(0.35))
            .frame(width: connected || reduceMotion ? 24 : 42, height: 1)
    }

    private func endpoint(name: String) -> some View {
        Group {
            if let initial = name.trimmingCharacters(in: .whitespacesAndNewlines).first {
                Text(String(initial))
            } else {
                Image(systemName: "person.fill")
            }
        }
            .font(.headline)
            .foregroundStyle(Color.secondary)
            .frame(width: 44, height: 44)
            .background(Color(.systemFill), in: Circle())
    }
}
