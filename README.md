# SwiftGameplayTag

一个用 SwiftUI 实现的、可视化编辑 Unreal Engine 5 `GameplayTag` 的 macOS 工具。

## 功能

- 左侧 **树形面板**：层级化展示所有标签，支持新增 / 重命名 / 删除 / 拖拽重定父子
- 右侧 **CSV 预览**：当前选中节点的子标签以表格 + 原始 CSV 文本两种形式预览
- **导入 / 导出**：
  - CSV（含 `Tag, DevComment` 两列）
  - UE5 的 `DefaultGameplayTags.ini`（`+GameplayTagList=(Tag="...",DevComment="...")` 格式）
- **撤销 / 重做**：所有修改操作支持 ⌘Z / ⇧⌘Z
- **搜索过滤**：工具栏关键字过滤，命中节点及其祖先会自动展开
- **快捷键**：
  - ⌘N 新增子标签
  - ⌘R 重命名
  - ⌘D / Delete 删除
  - ⌘O 打开 CSV
  - ⌘S 保存 CSV
  - ⌘E 导出 UE 配置文件

## 运行

```bash
swift run
```

要求 macOS 14+、Swift 5.9+。

## 目录结构

```
Sources/SwiftGameplayTag/
├── SwiftGameplayTagApp.swift   // App 入口 + 全局快捷键
├── Models/
│   ├── GameplayTag.swift       // 标签数据模型
│   ├── TagNode.swift           // 树节点（ObservableObject）
│   ├── TagTreeBuilder.swift    // 扁平 → 树形
│   ├── CSVExporter.swift       // CSV 序列化/解析
│   └── UEConfigExporter.swift  // UE5 DefaultGameplayTags.ini 序列化/解析
├── ViewModels/
│   └── TagStore.swift          // 全局状态、撤销重做、搜索过滤
├── Documents/
│   ├── TagsDocument.swift      // CSV FileDocument
│   ├── UEConfigDocument.swift  // INI FileDocument
│   └── TagImporter.swift       // 按文件类型分派解析
└── Views/
    ├── ContentView.swift       // NavigationSplitView 双栏
    ├── TagTreeView.swift       // 左侧树 + 工具栏 + 拖拽
    ├── TagRow.swift            // 单行渲染
    ├── TagDetailView.swift     // 右侧：表格 + CSV 预览
    └── TagEditSheet.swift      // 新增 / 重命名 / 重父确认
```

## 验证

工程已经过 `swift build` 验证：

```
$ swift build
...
[20/21] Applying SwiftGameplayTag
Build complete! (3.39s)
```

## 数据模型

参见 `Sources/SwiftGameplayTag/Models/GameplayTag.swift`。
