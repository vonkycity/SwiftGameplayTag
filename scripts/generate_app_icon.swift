#!/usr/bin/swift
import AppKit
import CoreGraphics

let size = 1024
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no context") }

// UE 编辑器深色面板底色
NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.10, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()

let cx = CGFloat(size) / 2
let line: CGFloat = 36

func strokePath(_ path: NSBezierPath, width: CGFloat = line, color: NSColor = .white) {
    color.setStroke()
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    path.stroke()
}

func fillPath(_ path: NSBezierPath, color: NSColor) {
    color.setFill()
    path.fill()
}

// ── 主节点：UE Blueprint 风格 ──
let nodeW: CGFloat = 380
let nodeH: CGFloat = 240
let nodeX = cx - nodeW / 2
let nodeY: CGFloat = 470

let nodeBody = NSBezierPath(roundedRect: NSRect(x: nodeX, y: nodeY, width: nodeW, height: nodeH), xRadius: 28, yRadius: 28)
strokePath(nodeBody, width: line, color: NSColor(white: 0.92, alpha: 1))

// 标题栏分隔线
let headerLine = NSBezierPath()
headerLine.move(to: NSPoint(x: nodeX + 20, y: nodeY + nodeH - 72))
headerLine.line(to: NSPoint(x: nodeX + nodeW - 20, y: nodeY + nodeH - 72))
strokePath(headerLine, width: 6, color: NSColor(white: 0.35, alpha: 1))

// UE Event 节点顶部色条
let accentBar = NSBezierPath(roundedRect: NSRect(x: nodeX + 4, y: nodeY + nodeH - 28, width: nodeW - 8, height: 18), xRadius: 8, yRadius: 8)
fillPath(accentBar, color: NSColor(calibratedRed: 0.98, green: 0.55, blue: 0.09, alpha: 1))

// 节点内：简化「GameplayTag」符号 — 小标签 + 层级线
let tagGlyph = NSBezierPath()
tagGlyph.move(to: NSPoint(x: cx - 90, y: nodeY + 110))
tagGlyph.line(to: NSPoint(x: cx - 90, y: nodeY + 40))
tagGlyph.line(to: NSPoint(x: cx - 20, y: nodeY + 18))
tagGlyph.line(to: NSPoint(x: cx + 10, y: nodeY + 18))
tagGlyph.line(to: NSPoint(x: cx + 10, y: nodeY + 110))
tagGlyph.close()
strokePath(tagGlyph, width: line * 0.85)

let tagHole = NSBezierPath(ovalIn: NSRect(x: cx - 38, y: nodeY + 62, width: 24, height: 24))
strokePath(tagHole, width: line * 0.55)

// 右侧：游戏手柄 D-pad（游戏开发联想）
let padCX = cx + 105
let padCY = nodeY + 72
let dpad = NSBezierPath()
dpad.move(to: NSPoint(x: padCX, y: padCY + 46))
dpad.line(to: NSPoint(x: padCX, y: padCY - 46))
dpad.move(to: NSPoint(x: padCX - 46, y: padCY))
dpad.line(to: NSPoint(x: padCX + 46, y: padCY))
strokePath(dpad, width: line * 0.75, color: NSColor(white: 0.75, alpha: 1))

let btnA = NSBezierPath(ovalIn: NSRect(x: padCX + 52, y: padCY + 18, width: 28, height: 28))
let btnB = NSBezierPath(ovalIn: NSRect(x: padCX + 82, y: padCY - 12, width: 28, height: 28))
strokePath(btnA, width: line * 0.55, color: NSColor(white: 0.75, alpha: 1))
strokePath(btnB, width: line * 0.55, color: NSColor(white: 0.75, alpha: 1))

// ── 连接引脚 ──
func drawPin(at point: NSPoint) {
    let pin = NSBezierPath(ovalIn: NSRect(x: point.x - 16, y: point.y - 16, width: 32, height: 32))
    strokePath(pin, width: line * 0.65)
}

let pinLeft1 = NSPoint(x: nodeX - 2, y: nodeY + nodeH - 110)
let pinLeft2 = NSPoint(x: nodeX - 2, y: nodeY + 90)
let pinRight = NSPoint(x: nodeX + nodeW + 2, y: nodeY + nodeH / 2)
let pinBottom = NSPoint(x: cx, y: nodeY - 2)

drawPin(at: pinLeft1)
drawPin(at: pinLeft2)
drawPin(at: pinRight)
drawPin(at: pinBottom)

// ── 连线 → 下方两个子 Tag 节点 ──
func drawConnector(from: NSPoint, to: NSPoint) {
    let path = NSBezierPath()
    path.move(to: from)
    let midY = (from.y + to.y) / 2
    path.curve(
        to: to,
        controlPoint1: NSPoint(x: from.x, y: midY),
        controlPoint2: NSPoint(x: to.x, y: midY)
    )
    strokePath(path, width: line * 0.7, color: NSColor(white: 0.55, alpha: 1))
}

let childY: CGFloat = 220
let childLeft = NSPoint(x: cx - 130, y: childY + 80)
let childRight = NSPoint(x: cx + 130, y: childY + 80)

drawConnector(from: pinBottom, to: NSPoint(x: childLeft.x, y: childLeft.y + 40))
drawConnector(from: pinBottom, to: NSPoint(x: childRight.x, y: childRight.y + 40))

func drawChildNode(center: NSPoint, label: String) {
    let w: CGFloat = 160
    let h: CGFloat = 88
    let rect = NSRect(x: center.x - w / 2, y: center.y, width: w, height: h)
    strokePath(NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16), width: line * 0.75)

    let pin = NSBezierPath(ovalIn: NSRect(x: center.x - 12, y: center.y + h - 2, width: 24, height: 24))
    strokePath(pin, width: line * 0.5)

    // 小 Tag 符号
    let t = NSBezierPath()
    t.move(to: NSPoint(x: center.x - 28, y: center.y + 28))
    t.line(to: NSPoint(x: center.x - 28, y: center.y + 14))
    t.line(to: NSPoint(x: center.x - 8, y: center.y + 6))
    t.line(to: NSPoint(x: center.x + 8, y: center.y + 6))
    t.line(to: NSPoint(x: center.x + 8, y: center.y + 28))
    t.close()
    strokePath(t, width: line * 0.45, color: NSColor(white: 0.7, alpha: 1))
}

drawChildNode(center: childLeft, label: "Combat")
drawChildNode(center: childRight, label: "Ability")

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else { fatalError("png export failed") }

try png.write(to: outputURL)
print("Wrote \(outputURL.path) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
