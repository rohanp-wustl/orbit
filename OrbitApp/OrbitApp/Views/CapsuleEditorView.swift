import SwiftUI

/// The canvas editor. Renders `layout.items` on a page; drag / pinch /
/// rotate gestures write the new x/y/w/rotation straight back into the
/// matching LayoutItem — same JSON shape whether the item came from Ground
/// Control or was hand-placed. Undo is a stack of whole-layout snapshots
/// (cheap: a layout is a few hundred bytes).
struct CapsuleEditorView: View {
    @Binding var layout: CapsuleLayout
    let senderId: UUID

    @State private var selectedId: String?
    @State private var undoStack: [CapsuleLayout] = []
    /// Word item open in ItemEditorSheet (new or existing).
    @State private var editingItemId: String?

    private var selectedItem: LayoutItem? {
        layout.items.first { $0.id == selectedId }
    }

    var body: some View {
        VStack(spacing: 12) {
            canvas
            if let selectedItem {
                selectionControls(for: selectedItem)
            } else {
                addControls
            }
        }
        .padding(.horizontal)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Undo", systemImage: "arrow.uturn.backward", action: undo)
                    .disabled(undoStack.isEmpty)
            }
        }
        .sheet(item: Binding(get: { editingItemId.map(EditingID.init) }, set: { editingItemId = $0?.value })) { editing in
            if let index = layout.items.firstIndex(where: { $0.id == editing.value }) {
                ItemEditorSheet(item: Binding(
                    get: { layout.items[index] },
                    set: { newValue in update(editing.value) { $0 = newValue } }
                ))
            }
        }
    }

    // MARK: - Canvas

    private var canvas: some View {
        GeometryReader { geo in
            ZStack {
                CapsuleBackground(name: layout.background)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedId = nil }
                ForEach(layout.items.sorted { $0.z < $1.z }) { item in
                    EditableItem(
                        item: item,
                        pageSize: geo.size,
                        senderId: senderId,
                        inkColor: CapsuleBackground.inkColor(for: layout.background),
                        isSelected: item.id == selectedId,
                        onSelect: { selectedId = item.id },
                        onCommit: { changed in update(item.id) { $0 = changed } }
                    )
                }
            }
        }
        .aspectRatio(capsulePageAspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
    }

    // MARK: - Controls

    private var addControls: some View {
        HStack {
            Menu {
                Button("Caption", systemImage: "textformat") { addWords(.text) }
                Button("Letter", systemImage: "envelope") { addWords(.letter) }
                Button("Question", systemImage: "questionmark.bubble") { addWords(.question) }
                Button("Song", systemImage: "music.note") { addWords(.song) }
                Button("Recipe card", systemImage: "fork.knife") { addWords(.recipe) }
            } label: {
                Label("Add", systemImage: "plus")
            }
            Menu {
                ForEach(OrbitAssets.stickers, id: \.name) { sticker in
                    Button("\(LayoutItemView.stickerEmoji[sticker.name] ?? "") \(sticker.name.replacingOccurrences(of: "_", with: " "))") {
                        addSticker(sticker.name)
                    }
                }
            } label: {
                Label("Sticker", systemImage: "face.smiling")
            }
            Menu {
                ForEach(OrbitAssets.backgrounds, id: \.name) { background in
                    Button(background.name.replacingOccurrences(of: "_", with: " ")) {
                        pushUndo()
                        layout.background = background.name
                    }
                }
            } label: {
                Label("Background", systemImage: "photo.on.rectangle")
            }
        }
        .buttonStyle(.bordered)
        .labelStyle(.titleAndIcon)
        .font(.subheadline)
    }

    private func selectionControls(for item: LayoutItem) -> some View {
        HStack {
            Button("Smaller", systemImage: "minus.magnifyingglass") {
                update(item.id) { $0.w = max(0.08, $0.w - 0.05) }
            }
            Button("Bigger", systemImage: "plus.magnifyingglass") {
                update(item.id) { $0.w = min(1, $0.w + 0.05) }
            }
            Button("Rotate", systemImage: "rotate.right") {
                update(item.id) { $0.rotation += 15 }
            }
            Button("Bring to front", systemImage: "square.3.layers.3d.top.filled") {
                let top = (layout.items.map(\.z).max() ?? 0) + 1
                update(item.id) { $0.z = top }
            }
            if item.type.isWords {
                Button("Edit", systemImage: "pencil") { editingItemId = item.id }
            }
            if item.type == .photo {
                Menu {
                    ForEach(OrbitAssets.frames, id: \.name) { frame in
                        Button(frame.name.capitalized) { update(item.id) { $0.frame = frame.name } }
                    }
                } label: {
                    Label("Frame", systemImage: "photo.artframe")
                }
            }
            if [.text, .letter, .question].contains(item.type) {
                Menu {
                    ForEach(OrbitAssets.fonts, id: \.name) { font in
                        Button(font.name.capitalized) { update(item.id) { $0.font = font.name } }
                    }
                } label: {
                    Label("Font", systemImage: "textformat.alt")
                }
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                pushUndo()
                layout.items.removeAll { $0.id == item.id }
                selectedId = nil
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.bordered)
    }

    // MARK: - Mutations (every one snapshots for undo first)

    private func pushUndo() {
        undoStack.append(layout)
        // Bounded so a long editing session can't grow memory forever.
        if undoStack.count > 50 { undoStack.removeFirst() }
    }

    private func undo() {
        guard let previous = undoStack.popLast() else { return }
        layout = previous
        if let selectedId, !layout.items.contains(where: { $0.id == selectedId }) {
            self.selectedId = nil
        }
    }

    private func update(_ id: String?, _ change: (inout LayoutItem) -> Void) {
        guard let index = layout.items.firstIndex(where: { $0.id == id }) else { return }
        var item = layout.items[index]
        change(&item)
        guard item != layout.items[index] else { return }
        pushUndo()
        layout.items[index] = item
    }

    private func nextZ() -> Int { (layout.items.map(\.z).max() ?? 0) + 1 }

    /// Adds a hand-made word item with starter text and opens its editor.
    private func addWords(_ type: LayoutItemType) {
        guard layout.items.filter({ $0.type == type }).count < type.limit else { return }
        pushUndo()
        let id = "\(type.rawValue)_\(UUID().uuidString.prefix(8))"
        let item: LayoutItem = switch type {
        case .letter:
            LayoutItem(id: id, type: .letter, text: "Write something only you would say…", font: "handwritten", x: 0.5, y: 0.5, w: 0.7, z: nextZ())
        case .question:
            LayoutItem(id: id, type: .question, text: "What should we do when I visit?", font: "marker", x: 0.5, y: 0.5, w: 0.7, z: nextZ())
        case .song:
            LayoutItem(id: id, type: .song, title: "Song title", artist: "Artist", x: 0.5, y: 0.5, w: 0.66, z: nextZ())
        case .recipe:
            LayoutItem(id: id, type: .recipe, title: "Recipe name", lines: ["Ingredient", "Step"], x: 0.5, y: 0.5, w: 0.5, z: nextZ())
        default:
            LayoutItem(id: id, type: .text, text: "Your caption", font: "handwritten", x: 0.5, y: 0.5, w: 0.7, z: nextZ())
        }
        layout.items.append(item)
        selectedId = item.id
        editingItemId = id
    }

    private func addSticker(_ name: String) {
        pushUndo()
        let item = LayoutItem(id: "sticker_\(UUID().uuidString.prefix(8))", type: .sticker, asset: name,
                              x: 0.5, y: 0.5, w: 0.2, rotation: Double.random(in: -12...12), z: nextZ())
        layout.items.append(item)
        selectedId = item.id
    }
}

private struct EditingID: Identifiable {
    let value: String
    var id: String { value }
}

/// One item on the canvas with its own in-flight gesture state, so moving
/// one item never jitters another. The layout is only written on gesture
/// end (one undo step per gesture, not one per frame).
private struct EditableItem: View {
    let item: LayoutItem
    let pageSize: CGSize
    let senderId: UUID
    let inkColor: Color
    let isSelected: Bool
    var onSelect: () -> Void
    var onCommit: (LayoutItem) -> Void

    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1
    @GestureState private var twist: Angle = .zero

    /// The item as it looks right now, including any gesture in progress.
    private var live: LayoutItem {
        var copy = item
        copy.w = Self.clampedWidth(item.w * pinchScale)
        copy.rotation = item.rotation + twist.degrees
        return copy
    }

    var body: some View {
        LayoutItemView(item: live, pageWidth: pageSize.width, senderId: senderId, inkColor: inkColor)
            .padding(6)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.accentBlue, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                }
            }
            .contentShape(Rectangle())
            .rotationEffect(.degrees(live.rotation))
            // Gestures before .position so only the item itself is grabbable,
            // not the whole canvas-sized frame .position creates.
            .onTapGesture(perform: onSelect)
            .gesture(drag.simultaneously(with: pinch.simultaneously(with: rotate)))
            .position(x: item.x * pageSize.width + dragOffset.width,
                      y: item.y * pageSize.height + dragOffset.height)
    }

    private var drag: some Gesture {
        // Global space so a rotated item still moves in the finger's direction.
        DragGesture(coordinateSpace: .global)
            .updating($dragOffset) { value, state, _ in state = value.translation }
            .onEnded { value in
                var moved = item
                moved.x = min(1, max(0, item.x + value.translation.width / pageSize.width))
                moved.y = min(1, max(0, item.y + value.translation.height / pageSize.height))
                onSelect()
                onCommit(moved)
            }
    }

    private var pinch: some Gesture {
        MagnifyGesture()
            .updating($pinchScale) { value, state, _ in state = value.magnification }
            .onEnded { value in
                var resized = item
                resized.w = Self.clampedWidth(item.w * value.magnification)
                onSelect()
                onCommit(resized)
            }
    }

    private var rotate: some Gesture {
        RotateGesture()
            .updating($twist) { value, state, _ in state = value.rotation }
            .onEnded { value in
                var turned = item
                turned.rotation = item.rotation + value.rotation.degrees
                onSelect()
                onCommit(turned)
            }
    }

    private static func clampedWidth(_ w: Double) -> Double { min(1, max(0.08, w)) }
}

#Preview {
    @Previewable @State var layout = CapsuleLayout(background: "mint_grid", template: "scrapbook_collage", items: [
        LayoutItem(id: "t1", type: .text, text: "drag me", font: "marker", x: 0.5, y: 0.4, w: 0.6, z: 1),
        LayoutItem(id: "s1", type: .sticker, asset: "planet", x: 0.3, y: 0.7, w: 0.25, z: 2),
    ])
    NavigationStack {
        CapsuleEditorView(layout: $layout, senderId: UUID())
    }
}
