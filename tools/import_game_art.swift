// Native production import: preserve masters, extract atlas cells, validate alpha,
// trim neutral preview matte at the outside silhouette, and export without upscaling.
// swift tools/import_game_art.swift SOURCE DESTINATION ASSET_NAMES COLUMNS ROWS [background]
import AppKit
import ImageIO
import UniformTypeIdentifiers

let args = CommandLine.arguments
guard args.count >= 6 else { fatalError("source destination comma-separated-names columns rows [background]") }
let source = URL(fileURLWithPath: args[1])
let destination = URL(fileURLWithPath: args[2], isDirectory: true)
let names = args[3].split(separator: ",").map(String.init)
let columns = Int(args[4])!, rows = Int(args[5])!
guard let input = CGImageSourceCreateWithURL(source as CFURL, nil),
      let master = CGImageSourceCreateImageAtIndex(input, 0, nil) else { fatalError("Unreadable source") }
let environment = args.count > 6 && args[6] == "background"
let fm = FileManager.default
try fm.createDirectory(at: destination, withIntermediateDirectories: true)
var exportedImages: [(String, CGImage)] = []

func writeImage(_ image: CGImage, name: String) throws {
    let folder = destination.appendingPathComponent(name + ".imageset", isDirectory: true)
    try fm.createDirectory(at: folder, withIntermediateDirectories: true)
    let ext = environment ? "jpg" : "png"
    let path = folder.appendingPathComponent(name + "." + ext)
    let format = environment ? UTType.jpeg.identifier : UTType.png.identifier
    guard let output = CGImageDestinationCreateWithURL(path as CFURL, format as CFString, 1, nil) else { fatalError("Destination unavailable") }
    CGImageDestinationAddImage(output, image, environment
        ? [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary : nil)
    guard CGImageDestinationFinalize(output) else { fatalError("Image export failed") }
    let json: [String: Any] = ["images": [["filename": path.lastPathComponent, "idiom": "universal"]],
                               "info": ["author": "xcode", "version": 1]]
    try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("Contents.json"))
    exportedImages.append((name, image))
    print("\(name): \(image.width)x\(image.height), alpha=\(!environment), \(path.path)")
}

for (index, name) in names.enumerated() {
    let c = index % columns, r = index / columns
    guard r < rows else { fatalError("Atlas names exceed grid") }
    let x0 = master.width * c / columns, x1 = master.width * (c + 1) / columns
    // Hand-verified whitespace separators in this generated sheet are not
    // mathematically equal rows. Preserve the entire silhouette, not a cut cap.
    let cuts = source.lastPathComponent == "blocker_layers_atlas.png" ? [0, 430, 780, master.height]
        : source.lastPathComponent == "stone_cream_atlas.png" ? [0, 390, master.height] : []
    let y0 = cuts.isEmpty ? master.height * r / rows : cuts[r]
    let y1 = cuts.isEmpty ? master.height * (r + 1) / rows : cuts[r + 1]
    guard let cell = master.cropping(to: CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)) else { fatalError("Bad crop") }
    if environment { try writeImage(cell, name: name); continue }
    let width = cell.width, height = cell.height
    var pixels = [UInt8](repeating: 0, count: width * height * 4)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmap = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    pixels.withUnsafeMutableBytes { bytes in
        let context = CGContext(data: bytes.baseAddress, width: width, height: height,
                                bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: colorSpace, bitmapInfo: bitmap)!
        context.draw(cell, in: CGRect(x: 0, y: 0, width: width, height: height))
    }
    // Only remove connected, near-neutral light matte at the outside. Enclosed
    // white specular highlights remain untouched. This handles RGB preview grids
    // without degrading existing real alpha or recoloring the artwork.
    var visited = [Bool](repeating: false, count: width * height)
    var queue: [Int] = []
    func add(_ x: Int, _ y: Int) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let p = y * width + x, offset = p * 4
        guard !visited[p] else { return }
        visited[p] = true
        let red = Int(pixels[offset]), green = Int(pixels[offset + 1]), blue = Int(pixels[offset + 2])
        let lo = min(red, green, blue), hi = max(red, green, blue)
        let whiteMaster = source.lastPathComponent.contains("blocker_layers") || source.lastPathComponent.contains("stone_cream")
        let matteFloor = whiteMaster ? 244 : source.lastPathComponent == "core_ui_atlas.png" ? 95 : 165
        if pixels[offset + 3] == 0 || (lo > matteFloor && hi - lo < (whiteMaster ? 12 : 28)) {
            pixels[offset] = 0; pixels[offset + 1] = 0; pixels[offset + 2] = 0; pixels[offset + 3] = 0
            queue.append(p)
        }
    }
    for x in 0..<width { add(x, 0); add(x, height - 1) }
    for y in 0..<height { add(0, y); add(width - 1, y) }
    // The gear has one intentional through-hole, verified in the source atlas.
    if name == "ui_settings" { add(width / 2, height / 2) }
    var cursor = 0
    while cursor < queue.count {
        let p = queue[cursor]; cursor += 1
        let x = p % width, y = p / width
        add(x - 1, y); add(x + 1, y); add(x, y - 1); add(x, y + 1)
    }
    let transparent = stride(from: 3, to: pixels.count, by: 4).filter { pixels[$0] == 0 }.count
    guard transparent > width * height / 12 else { fatalError("\(name): insufficient transparent gutter; reject asset") }
    let provider = CGDataProvider(data: Data(pixels) as CFData)!
    let clean = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                        bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGBitmapInfo(rawValue: bitmap),
                        provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)!
    // Keep square atlas cell dimensions so every sprite has identical scale.
    // No upscaling. Sources remain available as full-resolution masters.
    try writeImage(clean, name: name)
}

// A navy contact sheet exposes leftover preview matte and inconsistent optical
// scale before the app uses an atlas. This is a review artifact, never bundled.
let reviewWidth = columns * 256, reviewHeight = rows * 282
let review = CGContext(data: nil, width: reviewWidth, height: reviewHeight,
                       bitsPerComponent: 8, bytesPerRow: reviewWidth * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
review.setFillColor(CGColor(red: 0.055, green: 0.095, blue: 0.16, alpha: 1))
review.fill(CGRect(x: 0, y: 0, width: reviewWidth, height: reviewHeight))
for (index, entry) in exportedImages.enumerated() {
    let x = (index % columns) * 256, y = reviewHeight - (index / columns + 1) * 282
    let ratio = min(238 / Double(entry.1.width), 238 / Double(entry.1.height))
    let width = Double(entry.1.width) * ratio, height = Double(entry.1.height) * ratio
    review.draw(entry.1, in: CGRect(x: Double(x) + (256 - width) / 2,
                                   y: Double(y) + 25 + (238 - height) / 2,
                                   width: width, height: height))
    let text = NSAttributedString(string: entry.0, attributes: [
        .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.white])
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: review, flipped: false)
    text.draw(at: CGPoint(x: x + 8, y: y + 4))
    NSGraphicsContext.restoreGraphicsState()
}
let contactPath = source.deletingPathExtension().appendingPathExtension("review.png")
let contact = CGImageDestinationCreateWithURL(contactPath as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(contact, review.makeImage()!, nil)
guard CGImageDestinationFinalize(contact) else { fatalError("Contact sheet export failed") }
print("Review sheet: \(contactPath.path)")
