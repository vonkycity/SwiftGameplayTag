import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(TagStore.self) private var store
    @Environment(FileCommands.self) private var fileCommands
    @Binding var showRaw: Bool
    @Binding var showAddRoot: Bool
    @State private var alertMessage: String?

    var body: some View {
        @Bindable var store = store
        @Bindable var fileCommands = fileCommands

        NavigationSplitView {
            TagTreeSidebar()
                .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 480)
        } detail: {
            CSVPane()
        }
        .navigationTitle(store.windowTitle)
        .searchable(text: $store.searchQuery,
                    placement: .sidebar,
                    prompt: "搜索 Tag 名称（例：Fire）")
        .toolbar { ToolbarItems(showRaw: $showRaw, showAddRoot: $showAddRoot) }
        .fileImporter(
            isPresented: $fileCommands.openPicker,
            allowedContentTypes: [
                .commaSeparatedText,
                .plainText,
                .init(filenameExtension: "ini") ?? .plainText
            ]
        ) { result in
            handleOpen(result)
        }
        .sheet(isPresented: $fileCommands.saveAsSheet) {
            SaveAsSheet()
                .environment(store)
                .frame(minWidth: 460, minHeight: 320)
        }
        .sheet(isPresented: $showAddRoot) {
            AddRootSheet()
                .environment(store)
                .frame(minWidth: 380, minHeight: 180)
        }
        .sheet(isPresented: $showRaw) {
            RawCSVWindow()
                .environment(store)
                .frame(minWidth: 520, minHeight: 480)
        }
        .alert("出错了", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } })
        ) {
            Button("好") { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
        .onReceive(NotificationCenter.default.publisher(for: .gameplayTagError)) { note in
            if let msg = note.object as? String { alertMessage = msg }
        }
    }

    private func handleOpen(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let needsScope = url.startAccessingSecurityScopedResource()
            defer { if needsScope { url.stopAccessingSecurityScopedResource() } }
            do {
                try store.loadFile(from: url)
            } catch {
                alertMessage = error.localizedDescription
            }
        case .failure(let err):
            let nsErr = err as NSError
            if nsErr.code != NSUserCancelledError {
                alertMessage = err.localizedDescription
            }
        }
    }
}

extension Notification.Name {
    static let gameplayTagError = Notification.Name("SwiftGameplayTag.Error")
}
