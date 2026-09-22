import SwiftUI

/// 紹介シートと求職者画面だけに置く、二人が近づいてつながる線。
struct ConnectingLineView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var connected = false
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 0) {
            endpoint.offset(x: connected || reduceMotion ? 0 : -18)
            Capsule().fill(Color.secondary.opacity(0.35)).frame(width: 56, height: 2)
            endpoint.offset(x: connected || reduceMotion ? 0 : 18)
        }
        .frame(height: 32)
        .accessibilityHidden(true)
        .onAppear {
            guard !appeared else { return }
            appeared = true
            if reduceMotion { connected = true }
            else { withAnimation(.spring(duration: 0.4)) { connected = true } }
        }
    }

    private var endpoint: some View {
        Image(systemName: "person.fill")
            .font(.footnote)
            .foregroundStyle(Color.secondary)
            .frame(width: 32, height: 32)
            .background(Color(.systemFill), in: Circle())
    }
}
