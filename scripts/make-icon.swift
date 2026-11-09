// Draws the Run-Walk app icon (light, dark and tinted) into the asset catalog.
// Run from the repo root: swift scripts/make-icon.swift
//
// Motif: a rising path of rounded bars. Teal walk bars get shorter and coral run bars get longer
// as the path climbs, which is the plan in one picture. Colours match RunWalk/App/Theme.swift.

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let outDir = "RunWalk/Resources/Assets.xcassets/AppIcon.appiconset"

struct RGB {
    let r: CGFloat, g: CGFloat, b: CGFloat
    init(_ hex: UInt32) {
        r = CGFloat((hex >> 16) & 0xFF) / 255
        g = CGFloat((hex >> 8) & 0xFF) / 255
        b = CGFloat(hex & 0xFF) / 255
    }
    init(gray: CGFloat) { r = gray; g = gray; b = gray }
    var cg: CGColor { CGColor(srgbRed: r, green: g, blue: b, alpha: 1) }
}

struct Variant {
    let file: String
    let top: RGB
    let bottom: RGB
    let walk: RGB
    let run: RGB
}

let variants = [
    Variant(file: "icon-light.png", top: RGB(0xFFF7EF), bottom: RGB(0xFCE6D8), walk: RGB(0x2BB3A3), run: RGB(0xFF6B4A)),
    Variant(file: "icon-dark.png", top: RGB(0x1F2326), bottom: RGB(0x111315), walk: RGB(0x2BB3A3), run: RGB(0xFF6B4A)),
    // Tinted icons are grayscale on black; the system applies the tint.
    Variant(file: "icon-tinted.png", top: RGB(gray: 0), bottom: RGB(gray: 0), walk: RGB(gray: 0.55), run: RGB(gray: 1)),
]

/// Visible bar lengths along the path, bottom-left first: walk, run, walk, run.
let bars: [(isRun: Bool, length: CGFloat)] = [(false, 160), (true, 170), (false, 128), (true, 290)]
let thickness: CGFloat = 128
let gap: CGFloat = 38
let angle: CGFloat = 40 * .pi / 180

func draw(_ v: Variant) -> CGImage {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let s = CGFloat(size)

    // Background: soft vertical gradient (CoreGraphics y points up).
    let gradient = CGGradient(colorsSpace: space, colors: [v.bottom.cg, v.top.cg] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: s), options: [])

    // Centre the whole path on the canvas, nudged down a touch so it sits optically centred.
    let total = bars.reduce(0) { $0 + $1.length } + gap * CGFloat(bars.count - 1)
    let dir = CGPoint(x: cos(angle), y: sin(angle))
    var cursor = CGPoint(x: s / 2 - dir.x * total / 2, y: s / 2 - 12 - dir.y * total / 2)

    for bar in bars {
        ctx.saveGState()
        ctx.translateBy(x: cursor.x, y: cursor.y)
        ctx.rotate(by: angle)
        let rect = CGRect(x: 0, y: -thickness / 2, width: bar.length, height: thickness)
        ctx.addPath(CGPath(roundedRect: rect, cornerWidth: thickness / 2, cornerHeight: thickness / 2, transform: nil))
        ctx.setFillColor((bar.isRun ? v.run : v.walk).cg)
        ctx.fillPath()
        ctx.restoreGState()
        cursor.x += dir.x * (bar.length + gap)
        cursor.y += dir.y * (bar.length + gap)
    }
    return ctx.makeImage()!
}

for variant in variants {
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(variant.file)
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, draw(variant), nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("Could not write \(url.path)") }
    print("wrote \(url.path)")
}
