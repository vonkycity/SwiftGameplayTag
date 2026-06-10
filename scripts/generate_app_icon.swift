#!/usr/bin/swift
import AppKit
import CoreGraphics

let size = 1024
let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

// UE 编辑器深色面板底色
NSColor(calibratedRed: 0.09, green: 0.09, blue: 0.10, alpha: 1).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()

let cx = CGFloat(size) / 2

// 居中大字 U
let uFont = NSFont.systemFont(ofSize: 800, weight: .black)
let uAttrs: [NSAttributedString.Key: Any] = [
    .font: uFont,
    .foregroundColor: NSColor(white: 0.94, alpha: 1)
]
let uString = NSAttributedString(string: "U", attributes: uAttrs)
let uSize = uString.size()
let uOrigin = NSPoint(x: cx - uSize.width / 2, y: cx - uSize.height / 2 - 20)
uString.draw(at: uOrigin)

// Tag 徽章：略大，空心红框，压在 U 右下
let badgeRed = NSColor(calibratedRed: 0.90, green: 0.20, blue: 0.16, alpha: 1)
let badgeFont = NSFont.systemFont(ofSize: 112, weight: .black)
let badgeAttrs: [NSAttributedString.Key: Any] = [
    .font: badgeFont,
    .foregroundColor: badgeRed
]
let badgeText = NSAttributedString(string: "Tag", attributes: badgeAttrs)
let badgeTextSize = badgeText.size()
let padH: CGFloat = 44
let padV: CGFloat = 28
let badgeW = badgeTextSize.width + padH * 2
let badgeH = badgeTextSize.height + padV * 2

let uRight = uOrigin.x + uSize.width
let uBottom = uOrigin.y
let badgeX = uRight - badgeW * 0.62 - 8
let badgeY = uBottom + uSize.height * 0.10 + 8
let textX = badgeX + padH
let textY = badgeY + padV - 5

// 边框单独下移，文字位置不变
let borderDrop: CGFloat = 20
let badgeRect = NSRect(x: badgeX, y: badgeY - borderDrop, width: badgeW, height: badgeH)
let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 24, yRadius: 24)
badgePath.lineWidth = 18
badgeRed.setStroke()
badgePath.stroke()
badgeText.draw(at: NSPoint(x: textX, y: textY))

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else { fatalError("png export failed") }

try png.write(to: outputURL)
print("Wrote \(outputURL.path) (\(rep.pixelsWide)x\(rep.pixelsHigh))")
