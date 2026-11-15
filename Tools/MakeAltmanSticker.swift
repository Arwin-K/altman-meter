import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

// MakeAltmanSticker: cuts a head out of a photo as a die-cut sticker PNG for Altman Meter.
// Everything runs on-device with Apple's Vision framework (subject lifting + face landmarks).
//
// Usage:
//   swiftc -O Tools/MakeAltmanSticker.swift -o /tmp/make-altman-sticker
//   /tmp/make-altman-sticker in.jpg Shared/Photos/altman-annoyed.png [sideMargin padTop chinPad outSize red]
//
//   sideMargin  px of hair/ears kept past the jaw on each side (default 70)
//   padTop      px of hair to extend upward by mirroring, if the photo cuts off the head (default 0)
//   chinPad     px kept below the jawline (default 14)
//   outSize     output width/height in px (default 400; keep it small, widgets reject big images)
//   red         1 = give the face a furious red flush (default 0)
let a = CommandLine.arguments
let src = NSImage(contentsOfFile: a[1])!
var r0 = CGRect(origin: .zero, size: src.size)
let cg = src.cgImage(forProposedRect: &r0, context: nil, hints: nil)!
let W = CGFloat(cg.width), H = CGFloat(cg.height)
func arg(_ i: Int, _ d: Double) -> Double { a.count > i ? Double(a[i]) ?? d : d }
let sideMargin = CGFloat(arg(3, 70)), padTop = CGFloat(arg(4, 0)), chinPad = CGFloat(arg(5, 14)), outSize = Int(arg(6, 400)), red = arg(7, 0) == 1
let ctxCI = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

// 1. Subject mask (on-device "lift subject from background").
let handler = VNImageRequestHandler(cgImage: cg)
let fgReq = VNGenerateForegroundInstanceMaskRequest()
let lmReq = VNDetectFaceLandmarksRequest()
try! handler.perform([fgReq, lmReq])
let obs = fgReq.results!.first!
let fgPB = try! obs.generateScaledMaskForImage(forInstances: obs.allInstances, from: handler)
var fg = CIImage(cvPixelBuffer: fgPB)
let face = lmReq.results!.first!
let fb = face.boundingBox
let faceRect = CGRect(x: fb.minX * W, y: fb.minY * H, width: fb.width * W, height: fb.height * H) // bottom-left origin
var jaw = face.landmarks!.faceContour!.pointsInImage(imageSize: CGSize(width: W, height: H))
let center = CGPoint(x: faceRect.midX, y: faceRect.midY)
// Push the jawline outward a little so the chin isn't clipped.
jaw = jaw.map { p in
    let dx = p.x - center.x, dy = p.y - center.y
    let len = max(1, (dx*dx + dy*dy).squareRoot())
    return CGPoint(x: p.x + dx / len * chinPad, y: p.y + dy / len * chinPad)
}
if jaw.first!.x > jaw.last!.x { jaw.reverse() }

// 2. Extend the cut-off top of the hair by mirroring the top rows upward.
let HH = H + padTop
var img = CIImage(cgImage: cg)
if red {
    let m = CIFilter.colorMatrix(); m.inputImage = img
    m.rVector = CIVector(x: 1.05, y: 0, z: 0, w: 0); m.gVector = CIVector(x: 0, y: 0.74, z: 0, w: 0); m.bVector = CIVector(x: 0, y: 0, z: 0.68, w: 0)
    img = m.outputImage!.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.15])
}
func mirrorTop(_ im: CIImage) -> CIImage {
    guard padTop > 0 else { return im }
    // Skip the top few rows (often a border/compression line), then mirror upward.
    let k: CGFloat = 5
    let base = im.cropped(to: CGRect(x: 0, y: 0, width: W, height: H - k))
    let strip = im.cropped(to: CGRect(x: 0, y: H - k - padTop - k, width: W, height: padTop + k))
    let flipped = strip.transformed(by: CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: 2 * (H - k)))
    return base.composited(over: flipped).cropped(to: CGRect(x: 0, y: 0, width: W, height: HH))
}
let imgX = mirrorTop(img)
fg = mirrorTop(fg)

// 3. Head-only region: below = the jawline, sides = margin past the jaw ends, top = a dome.
let cs = CGColorSpaceCreateDeviceGray()
let mctx = CGContext(data: nil, width: Int(W), height: Int(HH), bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: 0)!
let left = jaw.first!, right = jaw.last!
let leftX = left.x - sideMargin, rightX = right.x + sideMargin
let cy = max(left.y, right.y)
let path = CGMutablePath()
path.move(to: CGPoint(x: leftX, y: left.y - sideMargin * 0.3))
for p in jaw { path.addLine(to: p) }
path.addLine(to: CGPoint(x: rightX, y: right.y - sideMargin * 0.3))
path.addLine(to: CGPoint(x: rightX, y: cy))
let aR = (rightX - leftX) / 2, bR = HH - 1 - cy
for i in 0...60 {
    let t = Double(i) / 60 * .pi
    path.addLine(to: CGPoint(x: (leftX + rightX) / 2 + aR * cos(t), y: cy + bR * sin(t)))
}
path.closeSubpath()
mctx.setFillColor(gray: 1, alpha: 1); mctx.addPath(path); mctx.fillPath()
let head = CIImage(cgImage: mctx.makeImage()!).applyingGaussianBlur(sigma: 2).cropped(to: imgX.extent)

// alpha = subject ∩ head
let mult = CIFilter.multiplyCompositing(); mult.inputImage = fg; mult.backgroundImage = head
var alpha = mult.outputImage!.cropped(to: imgX.extent)
// Firm up the edge a bit.
alpha = alpha.applyingFilter("CIColorControls", parameters: ["inputContrast": 1.6]).cropped(to: imgX.extent)

// 4. Sticker: white border around the cutout.
let border = max(4, W * 0.018)
let dil = CIFilter.morphologyMaximum(); dil.inputImage = alpha; dil.radius = Float(border)
let outline = dil.outputImage!.applyingGaussianBlur(sigma: 1).cropped(to: imgX.extent)
let clear = CIImage(color: .clear).cropped(to: imgX.extent)
let white = CIImage(color: .white).cropped(to: imgX.extent)
let blend1 = CIFilter.blendWithMask(); blend1.inputImage = white; blend1.backgroundImage = clear; blend1.maskImage = outline
let blend2 = CIFilter.blendWithMask(); blend2.inputImage = imgX; blend2.backgroundImage = blend1.outputImage!; blend2.maskImage = alpha
let sticker = blend2.outputImage!.cropped(to: imgX.extent)

// 5. Trim to content, place on a square transparent canvas, resize.
let full = ctxCI.createCGImage(sticker, from: sticker.extent, format: .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!)!
let rep = NSBitmapImageRep(cgImage: full)
var minX = Int.max, minY = Int.max, maxX = 0, maxY = 0
for y in 0..<rep.pixelsHigh { for x in 0..<rep.pixelsWide {
    if rep.colorAt(x: x, y: y)!.alphaComponent > 0.05 { minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y) }
}}
let bw = maxX - minX + 1, bh = maxY - minY + 1
let side = max(bw, bh) + 8
let out = CGContext(data: nil, width: outSize, height: outSize, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
out.interpolationQuality = .high
let s = CGFloat(outSize) / CGFloat(side)
let cropped = full.cropping(to: CGRect(x: minX, y: minY, width: bw, height: bh))!   // top-left origin for CGImage
let dw = CGFloat(bw) * s, dh = CGFloat(bh) * s
out.draw(cropped, in: CGRect(x: (CGFloat(outSize) - dw) / 2, y: 4 * s, width: dw, height: dh)) // sit on the bottom
let final = out.makeImage()!
try! NSBitmapImageRep(cgImage: final).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[2]))

// 6. Landmarks on the final sticker (top-left normalized) for the cartoon overlays.
let g = CGContext(data: nil, width: outSize, height: outSize, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
g.setFillColor(CGColor(gray: 0.5, alpha: 1)); g.fill(CGRect(x: 0, y: 0, width: outSize, height: outSize)); g.draw(final, in: CGRect(x: 0, y: 0, width: outSize, height: outSize))
let r2 = VNDetectFaceLandmarksRequest()
try! VNImageRequestHandler(cgImage: g.makeImage()!).perform([r2])
if let f = r2.results?.first, let lm = f.landmarks {
    func n(_ r: VNFaceLandmarkRegion2D?) -> String {
        (r?.pointsInImage(imageSize: CGSize(width: 1, height: 1)) ?? []).map { String(format: "(%.3f,%.3f)", $0.x, 1 - $0.y) }.joined(separator: " ")
    }
    print("leftEyebrow", n(lm.leftEyebrow)); print("rightEyebrow", n(lm.rightEyebrow)); print("outerLips", n(lm.outerLips))
    print(String(format: "faceBox x=%.3f y=%.3f w=%.3f h=%.3f", f.boundingBox.minX, 1 - f.boundingBox.maxY, f.boundingBox.width, f.boundingBox.height))
}
