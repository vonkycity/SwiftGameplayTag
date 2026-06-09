import Foundation

/// 文件菜单 / 工具栏共用的打开、保存触发器。
@MainActor
@Observable
final class FileCommands {
    var openPicker = false
    var saveAsSheet = false

    /// 若有未保存修改则先确认,再弹出文件选择器。
    func open(using store: TagStore) {
        guard store.confirmDiscardChangesIfNeeded() else { return }
        openPicker = true
    }

    func saveAs() {
        saveAsSheet = true
    }

    func save(using store: TagStore) {
        if store.currentURL == nil {
            saveAsSheet = true
            return
        }
        do {
            try store.save()
        } catch {
            NotificationCenter.default.post(
                name: .gameplayTagError,
                object: error.localizedDescription
            )
        }
    }
}
