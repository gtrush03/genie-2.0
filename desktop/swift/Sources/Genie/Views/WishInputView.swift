import SwiftUI

struct WishInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var wishText = ""
    @State private var isDispatching = false
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(.purple)
                Text("Make a Wish")
                    .font(.headline)
                Spacer()
                Text("Cmd+Shift+G")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(4)
            }

            TextEditor(text: $wishText)
                .font(.body)
                .frame(minHeight: 60, maxHeight: 120)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .focused($isFocused)

            HStack {
                Text("Type what you want. Genie will execute it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                Button(isDispatching ? "Dispatching..." : "Grant Wish") {
                    Task { await dispatchWish() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(wishText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isDispatching)
                .keyboardShortcut(.return)
            }
        }
        .padding(16)
        .frame(width: 440)
        .onAppear { isFocused = true }
    }

    private func dispatchWish() async {
        isDispatching = true
        let text = wishText.trimmingCharacters(in: .whitespacesAndNewlines)
        let repoDir = GenieState.shared.repoDir

        // Use the trigger script if available, otherwise spawn claurst directly
        let triggerScript = repoDir + "/src/core/trigger.mjs"
        let nodePath = "/opt/homebrew/bin/node"

        guard FileManager.default.fileExists(atPath: nodePath) else {
            isDispatching = false
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: nodePath)
        process.arguments = [triggerScript, text]
        process.currentDirectoryURL = URL(fileURLWithPath: repoDir)
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            // Don't wait -- the wish runs asynchronously
            dismiss()
        } catch {
            isDispatching = false
        }
    }
}
