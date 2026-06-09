import XCTest
@testable import SwiftGameplayTag

final class CSVParserTests: XCTestCase {
    func testBasicParse() {
        let csv = "a,b,c\n1,2,3\n4,5,6\n"
        let rows = CSVParser.parse(csv)
        XCTAssertEqual(rows, [["a","b","c"], ["1","2","3"], ["4","5","6"]])
    }

    func testQuotedFields() {
        let csv = "a,b\n\"hello, world\",\"x\"\"y\"\n"
        let rows = CSVParser.parse(csv)
        XCTAssertEqual(rows, [["a","b"], ["hello, world", "x\"y"]])
    }

    func testCRLF() {
        let csv = "a,b\r\n1,2\r\n"
        let rows = CSVParser.parse(csv)
        XCTAssertEqual(rows, [["a","b"], ["1","2"]])
    }

    func testEscape() {
        XCTAssertEqual(CSVParser.escape("plain"), "plain")
        XCTAssertEqual(CSVParser.escape("a,b"), "\"a,b\"")
        XCTAssertEqual(CSVParser.escape("she said \"hi\""), "\"she said \"\"hi\"\"\"")
    }
}

final class CSVBridgeTests: XCTestCase {
    func testDataTableCSV_export() {
        let tags = [GameplayTag(name: "Combat.Fire", devComment: "火")]
        let csv = CSVBridge.export(TagTreeBuilder.build(from: tags), format: .dataTableCSV)
        let lines = csv.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines[0], "Name,Tag,DevComment")
        XCTAssertEqual(lines[1], "0,Combat,")
        XCTAssertEqual(lines[2], "1,Combat.Fire,火")
    }

    func testDataTableCSV_parse() {
        let csv = """
        Name,Tag,DevComment
        0,Damage.Burning,燃烧
        1,Damage.Poison,中毒
        """
        let parsed = CSVBridge.parse(csv)
        XCTAssertEqual(parsed.format, .dataTableCSV)
        XCTAssertEqual(parsed.tags.map(\.name), ["Damage.Burning", "Damage.Poison"])
        XCTAssertEqual(parsed.tags[0].devComment, "燃烧")
    }

    func testDataTableCSV_parseLegacyHeader() {
        let csv = """
        ,Tag,DevComment
        0,Damage.Burning,燃烧
        """
        let parsed = CSVBridge.parse(csv)
        XCTAssertEqual(parsed.format, .dataTableCSV)
        XCTAssertEqual(parsed.tags.map(\.name), ["Damage.Burning"])
    }

    func testLegacyOpenSaveUpgradesNameColumn() {
        let legacy = ",Tag,DevComment\n0,Combat.Fire,火\n"
        let parsed = CSVBridge.parse(legacy)
        XCTAssertEqual(parsed.format, .dataTableCSV)
        let exported = CSVBridge.export(TagTreeBuilder.build(from: parsed.tags), format: .dataTableCSV)
        XCTAssertTrue(exported.hasPrefix("Name,Tag,DevComment\n"))
        XCTAssertTrue(exported.contains("0,Combat,"))
        XCTAssertTrue(exported.contains("1,Combat.Fire,火"))
    }

    func testLegacyCategoryColumnIsIgnored() {
        let csv = """
        Name,Tag,DevComment,CategoryText
        0,Combat.Fire,火,Combat
        """
        let parsed = CSVBridge.parse(csv)
        XCTAssertEqual(parsed.tags.map(\.name), ["Combat.Fire"])
        XCTAssertEqual(parsed.tags[0].devComment, "火")
    }

    func testEmptyFirstColumnHeaderIsDataTable() {
        let csv = ",Tag,DevComment\n0,Combat.Fire,火\n"
        XCTAssertEqual(CSVBridge.parse(csv).format, .dataTableCSV)
    }

    func testINI_export() {
        let tags = [GameplayTag(name: "Combat.Fire", devComment: "火")]
        let ini = CSVBridge.export(TagTreeBuilder.build(from: tags), format: .ini)
        let lines = ini.split(separator: "\n").map(String.init)
        XCTAssertEqual(lines[0], "[/Script/GameplayTags.GameplayTagsList]")
        XCTAssertTrue(lines.contains(where: { $0.contains("Tag=\"Combat\"") }))
        XCTAssertTrue(lines.contains(where: { $0.contains("Tag=\"Combat.Fire\"") && $0.contains("DevComment=\"火\"") }))
    }

    func testINI_parse() {
        let ini = """
        [/Script/GameplayTags.GameplayTagsList]
        GameplayTagList=(Tag="Vehicle.Air.Helicopter",DevComment="Helicopter tag")
        GameplayTagList=(Tag="Movement.Flying",DevComment="")
        """
        let parsed = CSVBridge.parse(ini)
        XCTAssertEqual(parsed.format, .ini)
        XCTAssertEqual(parsed.tags.map(\.name), ["Vehicle.Air.Helicopter", "Movement.Flying"])
        XCTAssertEqual(parsed.tags[0].devComment, "Helicopter tag")
    }

    func testINI_parsePlusPrefix() {
        let ini = """
        [/Script/GameplayTags.GameplayTagsSettings]
        +GameplayTagList=(Tag="Combat.Fire",DevComment="火")
        """
        let parsed = CSVBridge.parse(ini)
        XCTAssertEqual(parsed.format, .ini)
        XCTAssertEqual(parsed.tags.map(\.name), ["Combat.Fire"])
        XCTAssertEqual(parsed.tags[0].devComment, "火")
    }

    func testINI_escapedQuotes() {
        let ini = #"""
        [/Script/GameplayTags.GameplayTagsList]
        GameplayTagList=(Tag="X.Y",DevComment="She said \"hi\"")
        """#
        let parsed = CSVBridge.parse(ini)
        XCTAssertEqual(parsed.tags.first?.devComment, #"She said "hi""#)
    }

    func testNameColumnCSV_parse() {
        let csv = """
        Name,DevComment
        Combat.Fire,火
        Status.Burning,燃烧
        """
        let parsed = CSVBridge.parse(csv)
        XCTAssertEqual(parsed.format, .dataTableCSV)
        XCTAssertEqual(parsed.tags.map(\.name), ["Combat.Fire", "Status.Burning"])
        XCTAssertEqual(parsed.tags[0].devComment, "火")
    }

    func testFormatAutoDetect() {
        XCTAssertEqual(CSVBridge.parse("Name,Tag,DevComment\n0,A,B").format, .dataTableCSV)
        XCTAssertEqual(CSVBridge.parse(",Tag,DevComment\n0,A,B").format, .dataTableCSV)
        XCTAssertEqual(CSVBridge.parse("Name,DevComment\nA,B").format, .dataTableCSV)
        XCTAssertEqual(CSVBridge.parse("[/Script/GameplayTags.GameplayTagsList]\nGameplayTagList=(Tag=\"A\")").format, .ini)
    }
}

final class TagStoreTests: XCTestCase {
    @MainActor
    func testUndoRedo() {
        let store = TagStore()
        store.addRoot(name: "Root1")
        XCTAssertEqual(store.flatTags.count, 1)
        store.undo()
        XCTAssertEqual(store.flatTags.count, 0)
        store.redo()
        XCTAssertEqual(store.flatTags.count, 1)
    }

    @MainActor
    func testValidationDuplicate() {
        let store = TagStore()
        store.addRoot(name: "Combat")
        store.addRoot(name: "Combat")
        XCTAssertEqual(store.duplicateIDs.count, 0)
        let r = store.roots[0]
        store.addChild(under: r.id, name: "A")
        store.addChild(under: r.id, name: "A")
        XCTAssertEqual(store.duplicateIDs.count, 0)
    }

    @MainActor
    func testExportTextMatchesFormat() {
        let store = TagStore()
        store.addRoot(name: "A.B")
        let ini = store.exportText(format: .ini)
        XCTAssertTrue(ini.contains("[/Script/GameplayTags.GameplayTagsList]"))
        let csv = store.exportText(format: .dataTableCSV)
        XCTAssertTrue(csv.hasPrefix("Name,Tag,DevComment"))
    }

    @MainActor
    func testLoadFilePreservesSourceTextForPreview() throws {
        let store = TagStore()
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("SwiftGameplayTagPreview-\(UUID().uuidString).ini")
        let source = """
        [/Script/GameplayTags.GameplayTagsList]
        GameplayTagList=(Tag="Combat.Fire",DevComment="火")
        """
        try source.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        try store.loadFile(from: url)
        XCTAssertEqual(store.currentFormat, .ini)
        XCTAssertTrue(store.rawPreviewShowsLoadedText)
        store.refreshCSVText()
        XCTAssertEqual(store.csvText, source)
    }

    @MainActor
    func testDirtyPreviewUsesExport() throws {
        let store = TagStore()
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent("SwiftGameplayTagPreview-\(UUID().uuidString).csv")
        let source = """
        Name,Tag,DevComment
        0,Combat.Fire,火
        """
        try source.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        try store.loadFile(from: url)
        guard let id = store.flatTags.first(where: { $0.name == "Combat.Fire" })?.id else {
            XCTFail("missing tag")
            return
        }
        store.updateMetadata(id: id, devComment: "新注释")
        store.refreshCSVText()
        XCTAssertFalse(store.rawPreviewShowsLoadedText)
        XCTAssertTrue(store.csvText.contains("新注释"))
        XCTAssertFalse(store.csvText == source)
    }

    @MainActor
    func testMoveToParent() {
        let store = TagStore()
        let r1 = store.addRoot(name: "Root1")
        let r2 = store.addRoot(name: "Root2")
        let child = store.addChild(under: r1, name: "Child")!
        XCTAssertTrue(store.findNode(id: child)?.tag.name == "Root1.Child")

        store.move(id: child, toParent: r2)
        XCTAssertTrue(store.findNode(id: child)?.tag.name == "Root2.Child")
        XCTAssertEqual(store.findNode(id: r2)?.children.first?.id, child)
        XCTAssertNil(store.findNode(id: r1)?.children.first)
    }

    @MainActor
    func testMoveUpdatesDescendantPaths() {
        let store = TagStore()
        let a = store.addRoot(name: "A")
        let b = store.addRoot(name: "B")
        let x = store.addChild(under: a, name: "X")!
        let y = store.addChild(under: x, name: "Y")!
        let z = store.addChild(under: y, name: "Z")!

        store.move(id: x, toParent: b)
        XCTAssertEqual(store.findNode(id: x)?.tag.name, "B.X")
        XCTAssertEqual(store.findNode(id: y)?.tag.name, "B.X.Y")
        XCTAssertEqual(store.findNode(id: z)?.tag.name, "B.X.Y.Z")
    }

    @MainActor
    func testMoveRefusesCircular() {
        let store = TagStore()
        let a = store.addRoot(name: "A")
        let b = store.addChild(under: a, name: "B")!
        let c = store.addChild(under: b, name: "C")!

        store.move(id: a, toParent: c)
        XCTAssertNil(store.findNode(id: a)?.parent)
        XCTAssertEqual(store.findNode(id: c)?.parent?.id, b)
    }

    @MainActor
    func testMoveRefusesSelf() {
        let store = TagStore()
        let a = store.addRoot(name: "A")
        store.move(id: a, toParent: a)
        XCTAssertNil(store.findNode(id: a)?.parent)
    }

    @MainActor
    func testMoveToRoot() {
        let store = TagStore()
        let a = store.addRoot(name: "A")
        let b = store.addChild(under: a, name: "B")!
        store.move(id: b, toParent: nil)
        XCTAssertNil(store.findNode(id: b)?.parent)
        XCTAssertEqual(store.findNode(id: b)?.tag.name, "B")
    }

    @MainActor
    func testMoveAvoidsNameConflict() {
        let store = TagStore()
        let a = store.addRoot(name: "Root")
        let b = store.addRoot(name: "Other")
        let aX = store.addChild(under: a, name: "X")!
        let bX = store.addChild(under: b, name: "X")!
        store.move(id: bX, toParent: a)
        XCTAssertEqual(store.findNode(id: aX)?.tag.name, "Root.X")
        XCTAssertEqual(store.findNode(id: bX)?.tag.name, "Root.X_2")
    }

    @MainActor
    func testUpdateMetadata() {
        let store = TagStore()
        let id = store.addRoot(name: "Foo")
        store.updateMetadata(id: id, devComment: "测试")
        let n = store.findNode(id: id)!
        XCTAssertEqual(n.tag.devComment, "测试")
    }

    @MainActor
    func testUpdateMetadataSkipsNoOp() {
        let store = TagStore()
        let id = store.addRoot(name: "Foo")
        store.updateMetadata(id: id, devComment: "测试")
        store.updateMetadata(id: id, devComment: "测试")

        var undoSteps = 0
        while store.canUndo {
            store.undo()
            undoSteps += 1
        }
        XCTAssertEqual(undoSteps, 2)
        XCTAssertNil(store.findNode(id: id))
    }

    @MainActor
    func testMetadataUndoIsGranular() {
        let store = TagStore()
        store.loadSample()
        guard let first = store.flatTags.first else {
            XCTFail("sample empty")
            return
        }
        let originalComment = first.devComment
        store.updateMetadata(id: first.id, devComment: "新注释")
        store.undo()
        XCTAssertEqual(store.findNode(id: first.id)?.tag.devComment, originalComment)
        XCTAssertFalse(store.roots.isEmpty)
    }

    @MainActor
    func testReorderAmongRoots() {
        let store = TagStore()
        let a = store.addRoot(name: "A")
        let b = store.addRoot(name: "B")
        let c = store.addRoot(name: "C")
        XCTAssertEqual(store.roots.map(\.id), [a, b, c])

        store.reorder(id: c, before: a)
        XCTAssertEqual(store.roots.map(\.id), [c, a, b])
    }

    @MainActor
    func testReorderAfterSibling() {
        let store = TagStore()
        let parent = store.addRoot(name: "Parent")
        let x = store.addChild(under: parent, name: "X")!
        let y = store.addChild(under: parent, name: "Y")!
        let z = store.addChild(under: parent, name: "Z")!
        XCTAssertEqual(store.findNode(id: parent)?.children.map(\.id), [x, y, z])

        store.reorder(id: x, after: y)
        XCTAssertEqual(store.findNode(id: parent)?.children.map(\.id), [y, x, z])
    }

    @MainActor
    func testMoveWithInsertBefore() {
        let store = TagStore()
        let r1 = store.addRoot(name: "R1")
        let r2 = store.addRoot(name: "R2")
        let child = store.addChild(under: r1, name: "Child")!

        store.move(id: child, toParent: r2, insertBefore: nil)
        XCTAssertEqual(store.findNode(id: r2)?.children.map(\.id), [child])
        XCTAssertTrue(store.findNode(id: child)?.tag.name == "R2.Child")
    }

    @MainActor
    func testValidationAllowsChildPaths() {
        let store = TagStore()
        let root = store.addRoot(name: "Combat")
        store.addChild(under: root, name: "Damage")
        let child = store.roots[0].children[0]
        XCTAssertEqual(child.tag.name, "Combat.Damage")
        XCTAssertNil(store.validationIssues[child.id])
        XCTAssertTrue(store.validationIssues.isEmpty)
    }

    func testNodeIDMatchesTagIDAfterTreeBuild() {
        let tags = [
            GameplayTag(name: "Character.Stats.Health", devComment: "生命值")
        ]
        let roots = TagTreeBuilder.build(from: tags)
        GameplayTagNode.forEach(in: roots) { node in
            XCTAssertEqual(node.id, node.tag.id, "节点 \(node.tag.name) 的 id 与 tag.id 不一致")
        }
    }

    @MainActor
    func testSampleHealthTagIsSelectableInFlatTags() {
        let store = TagStore()
        store.loadSample()
        guard let health = store.flatTags.first(where: { $0.name == "Character.Stats.Health" }),
              let node = store.findNode(id: health.id) else {
            XCTFail("找不到 Character.Stats.Health")
            return
        }
        XCTAssertEqual(node.id, health.id)
        store.selectNode(health.id)
        XCTAssertTrue(store.selectedNodeIDs.contains(health.id))
    }
}
