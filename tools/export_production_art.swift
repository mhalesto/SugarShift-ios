// swift tools/export_production_art.swift art/production-jobs.json
// Pure export: preserve generated alpha, downsample only, never paint or upscale.
import AppKit
import ImageIO
import UniformTypeIdentifiers

struct Job: Decodable { let id: String; let master: String; let type: String }
let manifest = CommandLine.arguments.dropFirst().first ?? "art/production-jobs.json"
let jobs = try JSONDecoder().decode([Job].self, from: Data(contentsOf: URL(fileURLWithPath: manifest)))
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
var inventory: [[String: Any]] = []
var previews: [(String, CGImage)] = []
for job in jobs {
    let masterURL = root.appendingPathComponent(job.master)
    guard let source = CGImageSourceCreateWithURL(masterURL as CFURL, nil),
          let master = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Unreadable \(job.master)") }
    let background = job.type == "background"
    let id = job.id.replacingOccurrences(of: "_v2", with: "")
    let category = background ? "Worlds" : id.hasPrefix("blocker_") ? "BlockersPremium" : id.hasPrefix("objective_") ? "ObjectivesPremium" : "WorldEffects"
    let folder = root.appendingPathComponent("SugarShift/Assets.xcassets/\(category)/\(id).imageset")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let limit = background ? 2800 : id.hasPrefix("combo_") ? 640 : 320
    let factor = min(1, Double(limit) / Double(max(master.width, master.height)))
    let w = max(1, Int(Double(master.width) * factor)), h = max(1, Int(Double(master.height) * factor))
    let bitmap = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: bitmap)!
    context.interpolationQuality = .high
    context.draw(master, in: CGRect(x: 0, y: 0, width: w, height: h))
    let image = context.makeImage()!
    let pixels = context.data!.assumingMemoryBound(to: UInt8.self)
    let transparent = (0..<(w * h)).filter { pixels[$0 * 4 + 3] < 8 }.count
    if !background, transparent < w * h / 20 { fatalError("Reject \(id): expected genuine alpha, found opaque backdrop") }
    let ext = background ? "jpg" : "png"
    let file = folder.appendingPathComponent("\(id).\(ext)")
    let output = CGImageDestinationCreateWithURL(file as CFURL, (background ? UTType.jpeg.identifier : UTType.png.identifier) as CFString, 1, nil)!
    CGImageDestinationAddImage(output, image, background ? [kCGImageDestinationLossyCompressionQuality: 0.91] as CFDictionary : nil)
    guard CGImageDestinationFinalize(output) else { fatalError("Export failed \(id)") }
    let contents: [String: Any] = ["images": [["filename": file.lastPathComponent, "idiom": "universal"]], "info": ["author": "xcode", "version": 1]]
    try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: folder.appendingPathComponent("Contents.json"))
    inventory.append(["id": id, "category": category, "master": job.master,
                      "masterDimensions": "\(master.width)×\(master.height)", "shippingDimensions": "\(w)×\(h)",
                      "alpha": !background, "transparentPixels": transparent,
                      "shipping": file.path.replacingOccurrences(of: root.path + "/", with: "")])
    previews.append((id, image))
    print("\(id): \(master.width)×\(master.height) → \(w)×\(h), alpha=\(!background)")
}
try JSONSerialization.data(withJSONObject: inventory, options: [.prettyPrinted, .sortedKeys]).write(to: root.appendingPathComponent("art/production-inventory.json"))

// Navy exposes stray matte and lets every asset be reviewed at gameplay scale.
for background in [false, true] {
    let group = previews.filter { $0.0.hasPrefix("world_") == background }
    guard !group.isEmpty else { continue }
    let cols = background ? 7 : 6, cellW = 190, cellH = background ? 425 : 213
    let rows = (group.count + cols - 1) / cols
    let context = CGContext(data: nil, width: cols * cellW, height: rows * cellH,
        bitsPerComponent: 8, bytesPerRow: cols * cellW * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.setFillColor(NSColor(calibratedRed: 0.045, green: 0.095, blue: 0.18, alpha: 1).cgColor)
    context.fill(CGRect(x: 0, y: 0, width: cols * cellW, height: rows * cellH))
    for (i, entry) in group.enumerated() {
        let x = i % cols * cellW, y = (rows - 1 - i / cols) * cellH
        let factor = min(Double(cellW - 12) / Double(entry.1.width), Double(cellH - 30) / Double(entry.1.height))
        let w = Double(entry.1.width) * factor, h = Double(entry.1.height) * factor
        context.draw(entry.1, in: CGRect(x: Double(x) + (Double(cellW) - w) / 2, y: Double(y + 23) + (Double(cellH - 30) - h) / 2, width: w, height: h))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        NSAttributedString(string: entry.0, attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.white]).draw(at: CGPoint(x: x + 5, y: y + 6))
        NSGraphicsContext.restoreGraphicsState()
    }
    let url = root.appendingPathComponent("art/\(background ? "worlds" : "sprites")-production-review.png")
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, context.makeImage()!, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("Review export failed") }
}
