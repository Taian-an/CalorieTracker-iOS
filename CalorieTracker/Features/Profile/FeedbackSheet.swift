import SwiftUI

struct FeedbackSheet: View {
    @Environment(SessionStore.self) private var session
    @Environment(LocalizationStore.self) private var localization
    @Environment(\.dismiss) private var dismiss

    @State private var message = ""
    @State private var isSubmitting = false
    @State private var isSent = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if isSent {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.success)
                    Text(localization.t("profile.feedbackSent")).font(.headline)
                    Spacer()
                } else {
                    TextField(localization.t("profile.feedbackPlaceholder"), text: $message, axis: .vertical)
                        .lineLimit(6...10)
                        .textFieldStyle(.roundedBorder)

                    if let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(Theme.danger)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text(localization.t("common.confirm")).frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)

                    Spacer()
                }
            }
            .padding(24)
            .navigationTitle(localization.t("profile.sendFeedback"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localization.t("common.cancel")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await FeedbackAPI.submit(message: message, email: session.authEmail)
            isSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
