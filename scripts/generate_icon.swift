// Generate the project's independent geometric app icon; no third-party artwork.
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let target = root.appendingPathComponent("App/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
guard let context = CGContext(data: nil, width: 1024, height: 1024,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else {
    fatalError("Could not create icon context")
}
context.setFillColor(CGColor(red: 1, green: 212.0 / 255, blue: 64.0 / 255, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
context.setFillColor(CGColor(red: 1, green: 0.98, blue: 0.94, alpha: 1))
context.fill(CGRect(x: 168, y: 230, width: 688, height: 564))
context.setStrokeColor(CGColor(gray: 0.08, alpha: 1))
context.setLineWidth(44)
context.stroke(CGRect(x: 168, y: 230, width: 688, height: 564))
context.move(to: CGPoint(x: 168, y: 650))
context.addLine(to: CGPoint(x: 856, y: 650))
context.strokePath()
context.setLineWidth(52)
context.setLineCap(.square)
context.setLineJoin(.miter)
context.move(to: CGPoint(x: 414, y: 530))
context.addLine(to: CGPoint(x: 312, y: 436))
context.addLine(to: CGPoint(x: 414, y: 342))
context.move(to: CGPoint(x: 610, y: 530))
context.addLine(to: CGPoint(x: 712, y: 436))
context.addLine(to: CGPoint(x: 610, y: 342))
context.strokePath()
guard let output = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(target as CFURL,
                                                        UTType.png.identifier as CFString, 1, nil) else {
    fatalError("Could not create icon output")
}
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write icon") }
// Keep the distributable PNG free of EXIF or textual metadata.
let data = try Data(contentsOf: target)
var sanitized = Data(data.prefix(8))
var offset = 8
while offset + 12 <= data.count {
    let length = data[offset..<(offset + 4)].reduce(0) { ($0 << 8) | Int($1) }
    let end = offset + length + 12
    guard end <= data.count else { fatalError("Invalid PNG chunk") }
    let kind = String(decoding: data[(offset + 4)..<(offset + 8)], as: UTF8.self)
    if !["eXIf", "tEXt", "zTXt", "iTXt"].contains(kind) {
        sanitized.append(data[offset..<end])
    }
    offset = end
}
try sanitized.write(to: target, options: .atomic)
print("Generated opaque 1024px AppIcon")
