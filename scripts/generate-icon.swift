import AppKit

print("Generating ShibaStack programmatic vector icon...")

let baseSize = NSSize(width: 512, height: 512)
let image = NSImage(size: baseSize)

image.lockFocus()

// 1. Draw rounded rectangle background (Charcoal Black: #1C1C1E)
let bgColor = NSColor(red: 28/255, green: 28/255, blue: 30/255, alpha: 1.0)
bgColor.setFill()
let rect = NSRect(origin: .zero, size: baseSize)
NSBezierPath(roundedRect: rect, xRadius: 100, yRadius: 100).fill()

// 2. Draw Ears (Shiba Orange: #E06D3A)
let earColor = NSColor(red: 224/255, green: 109/255, blue: 58/255, alpha: 1.0)
earColor.setFill()

let leftEar = NSBezierPath()
leftEar.move(to: NSPoint(x: 120, y: 320))
leftEar.line(to: NSPoint(x: 160, y: 440))
leftEar.line(to: NSPoint(x: 240, y: 360))
leftEar.close()
leftEar.fill()

let rightEar = NSBezierPath()
rightEar.move(to: NSPoint(x: 392, y: 320))
rightEar.line(to: NSPoint(x: 352, y: 440))
rightEar.line(to: NSPoint(x: 272, y: 360))
rightEar.close()
rightEar.fill()

// 3. Draw Ear inner linings (Shiba Cream: #F7EAD3)
let creamColor = NSColor(red: 247/255, green: 234/255, blue: 211/255, alpha: 1.0)
creamColor.setFill()

let leftEarInner = NSBezierPath()
leftEarInner.move(to: NSPoint(x: 145, y: 335))
leftEarInner.line(to: NSPoint(x: 175, y: 415))
leftEarInner.line(to: NSPoint(x: 225, y: 365))
leftEarInner.close()
leftEarInner.fill()

let rightEarInner = NSBezierPath()
rightEarInner.move(to: NSPoint(x: 367, y: 335))
rightEarInner.line(to: NSPoint(x: 337, y: 415))
rightEarInner.line(to: NSPoint(x: 287, y: 365))
rightEarInner.close()
rightEarInner.fill()

// 4. Draw Face circle (Shiba Orange: #E06D3A)
earColor.setFill()
let faceBase = NSBezierPath(ovalIn: NSRect(x: 120, y: 120, width: 272, height: 240))
faceBase.fill()

// 5. Draw Cream highlights on cheeks & muzzle (Shiba Cream: #F7EAD3)
creamColor.setFill()

// Left cheek highlight
let leftCheek = NSBezierPath(ovalIn: NSRect(x: 130, y: 130, width: 120, height: 120))
leftCheek.fill()

// Right cheek highlight
let rightCheek = NSBezierPath(ovalIn: NSRect(x: 262, y: 130, width: 120, height: 120))
rightCheek.fill()

// Central Muzzle
let muzzle = NSBezierPath(ovalIn: NSRect(x: 206, y: 150, width: 100, height: 80))
muzzle.fill()

// 6. Draw Eyes (Charcoal Black)
let eyeColor = NSColor(red: 40/255, green: 40/255, blue: 40/255, alpha: 1.0)
eyeColor.setFill()
let leftEye = NSBezierPath(ovalIn: NSRect(x: 190, y: 240, width: 16, height: 16))
leftEye.fill()
let rightEye = NSBezierPath(ovalIn: NSRect(x: 306, y: 240, width: 16, height: 16))
rightEye.fill()

// 7. Draw Nose (Charcoal Black)
let nose = NSBezierPath()
nose.move(to: NSPoint(x: 240, y: 195))
nose.line(to: NSPoint(x: 272, y: 195))
nose.line(to: NSPoint(x: 256, y: 180))
nose.close()
nose.fill()

image.unlockFocus()

// Setup temporary Iconset directory
let fm = FileManager.default
let iconsetPath = "ShibaStack.iconset"
try? fm.removeItem(atPath: iconsetPath)
try? fm.createDirectory(atPath: iconsetPath, withIntermediateDirectories: true, attributes: nil)

// Resolutions to export
let resolutions = [
    (16, "icon_16x16.png"),
    (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"),
    (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"),
    (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"),
    (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"),
    (1024, "icon_512x512@2x.png")
]

for (res, filename) in resolutions {
    let targetSize = NSSize(width: res, height: res)
    let scaledImage = NSImage(size: targetSize)
    
    scaledImage.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: targetSize), from: NSRect(origin: .zero, size: baseSize), operation: .copy, fraction: 1.0)
    scaledImage.unlockFocus()
    
    if let tiff = scaledImage.tiffRepresentation,
       let bitmap = NSBitmapImageRep(data: tiff),
       let pngData = bitmap.representation(using: .png, properties: [:]) {
        let fileURL = URL(fileURLWithPath: "\(iconsetPath)/\(filename)")
        try? pngData.write(to: fileURL)
    }
}

// Convert using macOS iconutil
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetPath]

do {
    try process.run()
    process.waitUntilExit()
    print("✓ Success: ShibaStack.icns has been compiled successfully.")
    
    // Clean up temporary iconset
    try? fm.removeItem(atPath: iconsetPath)
} catch {
    print("Failed to run iconutil: \(error.localizedDescription)")
}
