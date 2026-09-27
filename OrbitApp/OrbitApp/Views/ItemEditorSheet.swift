import SwiftUI

/// Edit the words of one item — caption, letter, question, song, recipe —
/// without touching anything else in the capsule. Saving clears the
/// "Ground Control draft" flag: it's the sender's words now.
struct ItemEditorSheet: View {
    @Binding var item: LayoutItem
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var title = ""
    @State private var artist = ""
    @State private var linesText = ""

    var body: some View {
        NavigationStack {
            Form {
                switch item.type {
                case .song:
                    Section {
                        TextField("Song title", text: $title)
                        TextField("Artist", text: $artist)
                    } footer: {
                        Text("Links out to Apple Music. The song itself is never uploaded.")
                    }
                case .recipe:
                    Section("Recipe name") { TextField("Grandma's lemon bars", text: $title) }
                    Section {
                        TextEditor(text: $linesText).frame(minHeight: 160)
                    } header: {
                        Text("Ingredients & steps")
                    } footer: {
                        Text("One per line.")
                    }
                default:
                    Section {
                        TextEditor(text: $text).frame(minHeight: item.type == .letter ? 200 : 90)
                    } header: {
                        Text(item.type.displayName)
                    } footer: {
                        Text(footer)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.panelNavy.ignoresSafeArea())
            .navigationTitle("Edit \(item.type.displayName.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save", action: save) }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
        .onAppear {
            text = item.text ?? ""
            title = item.title ?? ""
            artist = item.artist ?? ""
            linesText = (item.lines ?? []).joined(separator: "\n")
        }
    }

    private var footer: String {
        switch item.type {
        case .text: "Short is best — 14 words or fewer."
        case .letter: "Keep it short and specific — about 70 words."
        case .question: "Something they'd love to answer with a capsule back."
        default: ""
        }
    }

    private func save() {
        switch item.type {
        case .song:
            item.title = title
            item.artist = artist
        case .recipe:
            item.title = title
            item.lines = linesText.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        default:
            item.text = text
        }
        item.aiDrafted = false
        dismiss()
    }
}
