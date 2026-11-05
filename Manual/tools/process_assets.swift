import AppKit

// Turns the raw captures into the images the manual uses.
//   swift Manual/tools/process_assets.swift <raw captures folder> <assets folder>
// m-*.png / v-*.png  converted pictures   -> px/*.png|jpg   960×720 (4:3, nearest neighbour)
// w-sys-*, w-browser, w-theme-*  windows   -> shots/*.jpg    title bar cut off, 2000 px wide
// other w-*.png                  windows   -> shots/*.png    title bar cut off

let args = CommandLine.arguments
let raw = URL(fileURLWithPath: args[1]), out = URL(fileURLWithPath: args[2])
let fm = FileManager.default
for sub in ["px", "shots"] { try? fm.createDirectory(at: out.appendingPathComponent(sub), withIntermediateDirectories: true) }

func load(_ url: URL) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}

func resize(_ cg: CGImage, _ w: Int, _ h: Int, smooth: Bool) -> CGImage {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = smooth ? .high : .none
    ctx.setShouldAntialias(smooth)
    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    return ctx.makeImage()!
}

func data(_ cg: CGImage, jpeg: Bool, quality: Double = 0.9) -> Data {
    let rep = NSBitmapImageRep(cgImage: cg)
    return jpeg ? rep.representation(using: .jpeg, properties: [.compressionFactor: quality])! : rep.representation(using: .png, properties: [:])!
}

var total = 0
let names = try! fm.contentsOfDirectory(atPath: raw.path).filter { $0.hasSuffix(".png") }.sorted()
for name in names {
    guard let cg = load(raw.appendingPathComponent(name)) else { continue }
    let base = String(name.dropLast(4))
    if base.hasPrefix("m-") || base.hasPrefix("v-") {
        // Machines show their picture on a 4:3 screen
        let image = resize(cg, 960, 720, smooth: false)
        let png = data(image, jpeg: false)
        if png.count <= 300_000 {
            try! png.write(to: out.appendingPathComponent("px/\(base).png")); total += png.count
        } else {
            let jpg = data(image, jpeg: true, quality: 0.93)
            try! jpg.write(to: out.appendingPathComponent("px/\(base).jpg")); total += jpg.count
        }
    } else if base.hasPrefix("w-") {
        let name = String(base.dropFirst(2))
        let content = cg.cropping(to: CGRect(x: 0, y: 64, width: cg.width, height: cg.height - 64))!
        let photographic = name.hasPrefix("sys-") || name == "browser" || name.hasPrefix("theme-")
        if photographic {
            let w = 2000, h = Int((Double(content.height) * Double(w) / Double(content.width)).rounded())
            let d = data(resize(content, w, h, smooth: true), jpeg: true, quality: 0.9)
            try! d.write(to: out.appendingPathComponent("shots/\(name).jpg")); total += d.count
        } else {
            var image = content
            if name == "help" { image = content.cropping(to: CGRect(x: Int(Double(content.width) * 0.235), y: 0, width: Int(Double(content.width) * 0.765), height: content.height))! }
            let d = data(image, jpeg: false)
            try! d.write(to: out.appendingPathComponent("shots/\(name).png")); total += d.count
        }
    }
}
print("wrote", String(format: "%.1f MB", Double(total) / 1e6))
