import SwiftUI
import OrbCore

/// Shown in place of a reading when the orb declines a question.
///
/// Deliberately not styled as an error or a warning. Someone who just typed a
/// hard question doesn't need red text and an exclamation mark — they need a
/// calm sentence and somewhere real to go.
@MainActor
struct SafetyNoticeView: View {
    let screening: Screening
    var onDismiss: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(screening.headline, systemImage: "heart.circle.fill")
                .font(.headline)
                .foregroundStyle(Theme.accent)

            Text(screening.message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)

            if !screening.resources.isEmpty {
                VStack(spacing: 10) {
                    ForEach(screening.resources) { resource in
                        resourceRow(resource)
                    }
                }
            }

            Button("Ask something else", action: onDismiss)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.09)))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(screening.headline). \(screening.message)")
    }

    @ViewBuilder
    private func resourceRow(_ resource: SupportResource) -> some View {
        let content = HStack(spacing: 12) {
            Image(systemName: resource.url == nil ? "phone.fill" : "arrow.up.right.square.fill")
                .foregroundStyle(Theme.accent)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(resource.name)
                    .font(.subheadline.weight(.semibold))
                Text(resource.detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.07)))

        if let url = resource.url {
            Button { openURL(url) } label: { content }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
        } else {
            // Emergency numbers are an instruction, not a link — dialling on the
            // user's behalf is not ours to do.
            content.foregroundStyle(.white)
        }
    }
}

/// The lighter banner shown *alongside* a reading for legal and money topics,
/// where the orb still answers but the answer must not be mistaken for advice.
@MainActor
struct CautionBanner: View {
    let screening: Screening

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.tint(for: .noncommittal))
            VStack(alignment: .leading, spacing: 3) {
                Text(screening.headline)
                    .font(.subheadline.weight(.semibold))
                Text(screening.message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.tint(for: .noncommittal).opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(Theme.tint(for: .noncommittal).opacity(0.3), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
