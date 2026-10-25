import SwiftUI

/// Shows its content only after a short delay, so indicators for quick
/// operations don't flicker on and off.
struct DelayedAppearance<Content: View>: View {
    var delay: Duration = .milliseconds(250)
    @ViewBuilder let content: () -> Content
    @State private var isVisible = false

    var body: some View {
        ZStack {
            if isVisible { content() }
        }
        .task {
            try? await Task.sleep(for: delay)
            isVisible = true
        }
    }
}
