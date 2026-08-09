import SwiftUI
import OrbCore

/// The disclaimer, shown as a gate on first launch and on demand from Settings.
///
/// The first-run presentation has no way past it except the acknowledgement
/// button — no swipe-to-dismiss, no close affordance. A disclaimer a user can
/// flick away without reading is decoration, and decoration is worth nothing if
/// anyone ever asks whether it was shown.
@MainActor
struct DisclaimerScreen: View {
    enum Mode {
        /// First launch. Must be acknowledged.
        case gate
        /// Opened from Settings. Dismissible.
        case reference
    }

    let mode: Mode
    var onAcknowledge: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            CosmicBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(Disclaimer.points, id: \.heading) { point in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(point.heading)
                                    .font(.headline)
                                Text(point.body)
                                    .font(.subheadline)
                                    .foregroundStyle(.white.opacity(0.75))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle(padding: 20)

                    if mode == .gate {
                        Text(Disclaimer.acknowledgement)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    actionButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 28)
            }
        }
        .preferredColorScheme(.dark)
        .interactiveDismissDisabled(mode == .gate)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.accent)
            Text(Disclaimer.title)
                .font(.largeTitle.bold())
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, mode == .gate ? 24 : 0)
    }

    private var actionButton: some View {
        Button {
            if mode == .gate { onAcknowledge() } else { dismiss() }
        } label: {
            Text(mode == .gate ? "I understand" : "Done")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.accent))
        .foregroundStyle(.white)
    }
}

#Preview {
    DisclaimerScreen(mode: .gate)
}
