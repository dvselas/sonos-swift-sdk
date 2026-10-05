//
//  DemoArtwork.swift
//  SonosDemo
//
//  Covers for the demo music, drawn on the device: a soft gradient with one
//  big emoji. No network and no real artwork, and friendly for children.
//  They come as `data:` URLs, which `URLSession` (and so `AsyncImage`) loads
//  like any other image URL.
//

import CoreGraphics
import CoreText
import Foundation
import ImageIO

enum DemoArtwork {

    static let size = 240

    /// A PNG cover as a `data:` URL; nil if drawing fails.
    static func url(_ emoji: String, top: UInt32, bottom: UInt32) -> String? {
        guard let png = png(emoji, top: top, bottom: bottom) else { return nil }
        return "data:image/png;base64," + png.base64EncodedString()
    }

    static func png(_ emoji: String, top: UInt32, bottom: UInt32) -> Data? {
        let side = CGFloat(size)
        guard let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }

        // Core Graphics draws bottom-up: start at the bottom color.
        let colors = [color(bottom), color(top)] as CFArray
        if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: side * 0.3, y: side),
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }

        let font = CTFontCreateWithName("AppleColorEmoji" as CFString, side * 0.5, nil)
        let text = NSAttributedString(string: emoji, attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])
        let line = CTLineCreateWithAttributedString(text)
        let bounds = CTLineGetImageBounds(line, context)
        context.textPosition = CGPoint(x: (side - bounds.width) / 2 - bounds.minX,
                                       y: (side - bounds.height) / 2 - bounds.minY)
        CTLineDraw(line, context)

        guard let image = context.makeImage() else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func color(_ rgb: UInt32) -> CGColor {
        CGColor(srgbRed: CGFloat((rgb >> 16) & 0xFF) / 255, green: CGFloat((rgb >> 8) & 0xFF) / 255,
                blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
    }
}
