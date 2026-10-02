import SwiftUI

struct CoachChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String
    let text: String
    var isError = false
}

struct CoachView: View {
    @Environment(LocalizationStore.self) private var localization

    @State private var messages: [CoachChatMessage] = []
    @State private var input = ""
    @State private var isSending = false
    @FocusState private var inputFocused: Bool

    private var canSend: Bool { !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(messages) { message in
                                bubble(message).id(message.id)
                            }
                            if isSending {
                                HStack(spacing: 8) {
                                    ProgressView()
                                    Text(localization.t("coach.thinking")).font(.footnote).foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("typing")
                            }
                        }
                        .padding(16)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: messages) { scrollToEnd(proxy) }
                    .onChange(of: isSending) { scrollToEnd(proxy) }
                }

                Divider()
                HStack(alignment: .bottom, spacing: 8) {
                    TextField(localization.t("coach.placeholder"), text: $input, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($inputFocused)
                        .padding(10)
                        .background(Theme.cardBackground, in: RoundedRectangle(cornerRadius: 18))
                    Button(action: send) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(canSend ? Theme.calorie : Color.gray.opacity(0.4))
                    }
                    .disabled(!canSend)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Theme.screenBackground)
            .navigationTitle(localization.t("coach.navTitle"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { resetChat() } label: { Image(systemName: "arrow.counterclockwise") }
                        .disabled(isSending)
                }
            }
            .onAppear { if messages.isEmpty { resetChat() } }
        }
    }

    private func bubble(_ message: CoachChatMessage) -> some View {
        let isUser = message.role == "user"
        return HStack {
            if isUser { Spacer(minLength: 48) }
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(isUser ? Color.white : (message.isError ? Theme.danger : Color.primary))
                .background(isUser ? Theme.calorie : Theme.cardBackground, in: RoundedRectangle(cornerRadius: 16))
            if !isUser { Spacer(minLength: 48) }
        }
    }

    private func scrollToEnd(_ proxy: ScrollViewProxy) {
        withAnimation {
            if isSending { proxy.scrollTo("typing", anchor: .bottom) }
            else if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
        }
    }

    private func resetChat() {
        messages = [CoachChatMessage(role: "model", text: localization.t("coach.greeting"))]
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        messages.append(CoachChatMessage(role: "user", text: text))
        input = ""
        isSending = true

        // Error bubbles and the local greeting aren't real conversation turns, so they're not sent.
        let history = messages.filter { !$0.isError }.map { CoachMessageDTO(role: $0.role, text: $0.text) }
        Task {
            defer { isSending = false }
            do {
                let reply = try await CoachAPI.send(messages: history, language: localization.apiLanguageCode)
                messages.append(CoachChatMessage(role: "model", text: reply))
            } catch {
                // Out of today's free coach messages → say so; anything else → the generic "unavailable" bubble.
                let isDailyLimit = (error as? APIError).map { if case .server(429, "daily_limit") = $0 { return true } else { return false } } ?? false
                messages.append(CoachChatMessage(role: "model", text: localization.t(isDailyLimit ? "error.dailyLimit" : "coach.error"), isError: true))
            }
        }
    }
}
