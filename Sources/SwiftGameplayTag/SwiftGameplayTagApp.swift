import SwiftUI

@main
struct SwiftGameplayTagApp: App {
    @State private var store = TagStore()
    @State private var fileCommands = FileCommands()
    @State private var showRaw = false
    @State private var showAddRoot = false

    var body: some Scene {
        WindowGroup {
            ContentView(showRaw: $showRaw, showAddRoot: $showAddRoot)
                .environment(store)
                .environment(fileCommands)
                .frame(minWidth: 900, minHeight: 560)
                .onAppear {
                    if store.roots.isEmpty { store.loadSample() }
                }
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("打开…") {
                    fileCommands.open(using: store)
                }
                .keyboardShortcut("o", modifiers: .command)

                Button("新建根 Tag…") {
                    showAddRoot = true
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .saveItem) {
                Button("保存") {
                    fileCommands.save(using: store)
                }
                .keyboardShortcut("s", modifiers: .command)

                Button("另存为…") {
                    fileCommands.saveAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .undoRedo) {
                Button("撤销") { store.undo() }
                    .keyboardShortcut("z", modifiers: .command)
                    .disabled(!store.canUndo)
                Button("重做") { store.redo() }
                    .keyboardShortcut("z", modifiers: [.command, .shift])
                    .disabled(!store.canRedo)
            }
        }
    }
}
