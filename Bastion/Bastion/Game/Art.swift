import SpriteKit
import UIKit

/// All the game's art, painted with code at launch: soft gradients, a dark outline and a ground shadow
/// give every piece the same friendly storybook look. Textures are made once and cached.
@MainActor
enum Art {
    // MARK: Palette

    enum Ink {
        static let outline = UIColor(red: 0.16, green: 0.13, blue: 0.12, alpha: 0.85)
        static let shadow = UIColor(white: 0, alpha: 0.22)
        static let grass = UIColor(hex: 0x6FC25C), grassDark = UIColor(hex: 0x5DAE4C), grassLight = UIColor(hex: 0x86D46E)
        static let forest = UIColor(hex: 0x4E9A4B), forestDark = UIColor(hex: 0x3F8540), forestLight = UIColor(hex: 0x5FAE57)
        static let quarry = UIColor(hex: 0x9C9A86), quarryDark = UIColor(hex: 0x8A8875)
        static let dirt = UIColor(hex: 0xD9B27C), dirtDark = UIColor(hex: 0xC69A63)
        static let sand = UIColor(hex: 0xEBD9A3)
        static let water = UIColor(hex: 0x3FA7E0), waterDeep = UIColor(hex: 0x2E86C8), foam = UIColor(white: 1, alpha: 0.55)
        static let wood = UIColor(hex: 0x9A6232), woodLight = UIColor(hex: 0xC48A4F), woodDark = UIColor(hex: 0x6E4322)
        static let leaf = UIColor(hex: 0x3FA34D), leafDark = UIColor(hex: 0x2C7F3B), leafLight = UIColor(hex: 0x66C460)
        static let pine = UIColor(hex: 0x2F7A48), pineDark = UIColor(hex: 0x225E37)
        static let gold = UIColor(hex: 0xF7C948), goldDark = UIColor(hex: 0xD99A1E)
        static let stone = UIColor(hex: 0xA3ACB6), stoneDark = UIColor(hex: 0x7D8792), stoneLight = UIColor(hex: 0xCBD2D9)
        static let berry = UIColor(hex: 0x5468E0)
        static let brote = UIColor(hex: 0x7ED957), broteDark = UIColor(hex: 0x4FA83A), broteBelly = UIColor(hex: 0xC9F2A9)
        static let mist = UIColor(hex: 0x8D84C7), mistDark = UIColor(hex: 0x5D5498)
        static let wolf = UIColor(hex: 0x6A7896), wolfDark = UIColor(hex: 0x46516B)
        static let fire = UIColor(hex: 0xFF9A3C), fireCore = UIColor(hex: 0xFFE27A)
        static let roof = UIColor(hex: 0xD9573F), roofDark = UIColor(hex: 0xA73B2B)
    }

    private static var cache: [String: SKTexture] = [:]

    static func texture(_ key: String, size: CGSize, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let cached = cache[key] { return cached }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            // Flip so that y grows upwards, like SpriteKit.
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: 1, y: -1)
            draw(cg, size)
        }
        let texture = SKTexture(image: image)
        cache[key] = texture
        return texture
    }

    // MARK: Drawing helpers

    static func fill(_ cg: CGContext, _ path: CGPath, _ colors: [UIColor], outline: CGFloat = 2.2, vertical: Bool = true) {
        cg.saveGState()
        cg.addPath(path)
        cg.clip()
        let box = path.boundingBox
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors.map(\.cgColor) as CFArray, locations: nil)!
        let start = vertical ? CGPoint(x: box.midX, y: box.maxY) : CGPoint(x: box.minX, y: box.maxY)
        let end = vertical ? CGPoint(x: box.midX, y: box.minY) : CGPoint(x: box.maxX, y: box.minY)
        cg.drawLinearGradient(gradient, start: start, end: end, options: [])
        cg.restoreGState()
        if outline > 0 {
            cg.addPath(path)
            cg.setStrokeColor(Ink.outline.cgColor)
            cg.setLineWidth(outline)
            cg.setLineJoin(.round)
            cg.strokePath()
        }
    }

    static func ellipse(_ rect: CGRect) -> CGPath { CGPath(ellipseIn: rect, transform: nil) }

    static func rounded(_ rect: CGRect, _ r: CGFloat) -> CGPath { CGPath(roundedRect: rect, cornerWidth: r, cornerHeight: r, transform: nil) }

    static func shadow(_ cg: CGContext, center: CGPoint, width: CGFloat, height: CGFloat = 10) {
        cg.setFillColor(Ink.shadow.cgColor)
        cg.fillEllipse(in: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height))
    }

    static func dot(_ cg: CGContext, _ p: CGPoint, _ r: CGFloat, _ color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
    }

    static func blob(_ center: CGPoint, radius: CGFloat, lumps: Int, wobble: CGFloat, seed: Int) -> CGPath {
        let path = CGMutablePath()
        let steps = lumps * 8
        for i in 0...steps {
            let a = Double(i) / Double(steps) * 2 * .pi
            let r = radius * (1 + wobble * CGFloat(sin(a * Double(lumps) + Double(seed))))
            let p = CGPoint(x: center.x + CGFloat(cos(a)) * r, y: center.y + CGFloat(sin(a)) * r * 0.92)
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        return path
    }

    // MARK: Ground tiles

    static func groundTile(_ zone: Zone, variant: Int) -> SKTexture {
        let t = WorldMap.tileSize
        return texture("ground-\(zone)-\(variant)", size: CGSize(width: t, height: t)) { cg, size in
            let (base, dark, light): (UIColor, UIColor, UIColor) = switch zone {
            case .clearing: (Ink.grass, Ink.grassDark, Ink.grassLight)
            case .oldForest: (Ink.forest, Ink.forestDark, Ink.forestLight)
            case .quarry: (Ink.quarry, Ink.quarryDark, Ink.stoneLight)
            }
            cg.setFillColor(base.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            var rng = SplitMix(seed: UInt64(variant * 97 + zone.rawValue * 13 + 5))
            // Soft patches and tufts so the field never looks like a checkerboard.
            for _ in 0..<3 {
                let p = CGPoint(x: rng.unit() * size.width, y: rng.unit() * size.height)
                cg.setFillColor((rng.unit() > 0.5 ? dark : light).withAlphaComponent(0.35).cgColor)
                cg.fillEllipse(in: CGRect(x: p.x - 9, y: p.y - 6, width: 18 + rng.unit() * 10, height: 12))
            }
            for _ in 0..<4 {
                let p = CGPoint(x: 4 + rng.unit() * (size.width - 8), y: 4 + rng.unit() * (size.height - 8))
                cg.setStrokeColor(dark.cgColor)
                cg.setLineWidth(1.6)
                cg.setLineCap(.round)
                cg.move(to: p); cg.addLine(to: CGPoint(x: p.x - 2, y: p.y + 5))
                cg.move(to: p); cg.addLine(to: CGPoint(x: p.x + 2, y: p.y + 6))
                cg.strokePath()
            }
            if zone == .clearing && variant % 3 == 0 {
                let p = CGPoint(x: 10 + rng.unit() * (size.width - 20), y: 10 + rng.unit() * (size.height - 20))
                let petal = [UIColor(hex: 0xFFF3A6), UIColor(hex: 0xFFB3C8), .white][variant % 3]
                for k in 0..<5 {
                    let a = Double(k) / 5 * 2 * .pi
                    dot(cg, CGPoint(x: p.x + CGFloat(cos(a)) * 2.6, y: p.y + CGFloat(sin(a)) * 2.6), 2, petal)
                }
                dot(cg, p, 1.6, Ink.gold)
            }
        }
    }

    static func dirtTile(variant: Int) -> SKTexture {
        let t = WorldMap.tileSize
        return texture("dirt-\(variant)", size: CGSize(width: t, height: t)) { cg, size in
            cg.setFillColor(Ink.dirt.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            var rng = SplitMix(seed: UInt64(variant + 300))
            for _ in 0..<5 {
                let p = CGPoint(x: rng.unit() * size.width, y: rng.unit() * size.height)
                dot(cg, p, 1.5 + rng.unit() * 2, Ink.dirtDark)
            }
        }
    }

    static func waterTile(variant: Int) -> SKTexture {
        let t = WorldMap.tileSize
        return texture("water-\(variant)", size: CGSize(width: t, height: t)) { cg, size in
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [Ink.water.cgColor, Ink.waterDeep.cgColor] as CFArray, locations: nil)!
            cg.drawLinearGradient(gradient, start: CGPoint(x: 0, y: size.height), end: CGPoint(x: size.width, y: 0), options: [])
            var rng = SplitMix(seed: UInt64(variant + 500))
            cg.setStrokeColor(Ink.foam.cgColor)
            cg.setLineWidth(2)
            cg.setLineCap(.round)
            for _ in 0..<2 {
                let y = 8 + rng.unit() * (size.height - 16)
                let x = rng.unit() * (size.width - 24)
                cg.move(to: CGPoint(x: x, y: y))
                cg.addCurve(to: CGPoint(x: x + 22, y: y), control1: CGPoint(x: x + 6, y: y + 4), control2: CGPoint(x: x + 14, y: y - 4))
                cg.strokePath()
            }
        }
    }

    static func bankTile() -> SKTexture {
        let t = WorldMap.tileSize
        return texture("bank", size: CGSize(width: t, height: t)) { cg, size in
            cg.setFillColor(Ink.sand.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            var rng = SplitMix(seed: 77)
            for _ in 0..<6 {
                dot(cg, CGPoint(x: rng.unit() * size.width, y: rng.unit() * size.height), 1.4, Ink.dirtDark.withAlphaComponent(0.6))
            }
        }
    }

    // MARK: Nature

    static func tree(dark: Bool = false) -> SKTexture {
        texture("tree-\(dark)", size: CGSize(width: 76, height: 96)) { cg, size in
            shadow(cg, center: CGPoint(x: 38, y: 9), width: 50, height: 12)
            fill(cg, rounded(CGRect(x: 31, y: 8, width: 14, height: 34), 5), [Ink.woodLight, Ink.wood])
            if dark {
                // Old Forest pines: three stacked layers.
                for (i, w) in [CGFloat(64), 50, 34].enumerated() {
                    let y = 30 + CGFloat(i) * 20
                    let path = CGMutablePath()
                    path.move(to: CGPoint(x: 38 - w / 2, y: y))
                    path.addQuadCurve(to: CGPoint(x: 38 + w / 2, y: y), control: CGPoint(x: 38, y: y - 8))
                    path.addLine(to: CGPoint(x: 38, y: y + 34))
                    path.closeSubpath()
                    fill(cg, path, [Ink.leaf, Ink.pine, Ink.pineDark])
                }
            } else {
                let canopy = blob(CGPoint(x: 38, y: 58), radius: 30, lumps: 5, wobble: 0.09, seed: 2)
                fill(cg, canopy, [Ink.leafLight, Ink.leaf, Ink.leafDark])
                dot(cg, CGPoint(x: 28, y: 70), 7, Ink.leafLight.withAlphaComponent(0.7))
                dot(cg, CGPoint(x: 46, y: 66), 4, Ink.leafLight.withAlphaComponent(0.55))
            }
        }
    }

    static func goldenTree() -> SKTexture {
        texture("goldenTree", size: CGSize(width: 80, height: 100)) { cg, _ in
            shadow(cg, center: CGPoint(x: 40, y: 9), width: 52, height: 12)
            fill(cg, rounded(CGRect(x: 33, y: 8, width: 14, height: 34), 5), [Ink.woodLight, Ink.wood])
            let canopy = blob(CGPoint(x: 40, y: 60), radius: 31, lumps: 6, wobble: 0.1, seed: 4)
            fill(cg, canopy, [UIColor(hex: 0xFFE680), Ink.gold, Ink.goldDark])
            for p in [CGPoint(x: 26, y: 72), CGPoint(x: 52, y: 64), CGPoint(x: 38, y: 82), CGPoint(x: 30, y: 50)] {
                star(cg, p, 4.5, .white)
            }
        }
    }

    static func star(_ cg: CGContext, _ c: CGPoint, _ r: CGFloat, _ color: UIColor) {
        let path = CGMutablePath()
        for i in 0..<8 {
            let a = Double(i) / 8 * 2 * .pi + .pi / 2
            let rr = i.isMultiple(of: 2) ? r : r * 0.35
            let p = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        cg.addPath(path)
        cg.setFillColor(color.cgColor)
        cg.fillPath()
    }

    static func stump() -> SKTexture {
        texture("stump", size: CGSize(width: 40, height: 30)) { cg, _ in
            shadow(cg, center: CGPoint(x: 20, y: 7), width: 30, height: 9)
            fill(cg, rounded(CGRect(x: 11, y: 6, width: 18, height: 14), 4), [Ink.woodLight, Ink.wood])
            fill(cg, ellipse(CGRect(x: 11, y: 15, width: 18, height: 8)), [UIColor(hex: 0xE8C08A), Ink.woodLight], outline: 1.6)
        }
    }

    static func bush(berries: Bool) -> SKTexture {
        texture("bush-\(berries)", size: CGSize(width: 56, height: 46)) { cg, _ in
            shadow(cg, center: CGPoint(x: 28, y: 8), width: 44, height: 10)
            fill(cg, blob(CGPoint(x: 28, y: 24), radius: 20, lumps: 4, wobble: 0.12, seed: 1), [Ink.leafLight, Ink.leaf, Ink.leafDark])
            if berries {
                for p in [CGPoint(x: 18, y: 26), CGPoint(x: 30, y: 33), CGPoint(x: 38, y: 22), CGPoint(x: 25, y: 16), CGPoint(x: 36, y: 13)] {
                    fill(cg, ellipse(CGRect(x: p.x - 4, y: p.y - 4, width: 8, height: 8)), [UIColor(hex: 0x8A9BFF), Ink.berry], outline: 1.2)
                    dot(cg, CGPoint(x: p.x - 1.3, y: p.y + 1.3), 1.2, .white)
                }
            }
        }
    }

    static func rock(small: Bool = false) -> SKTexture {
        texture("rock-\(small)", size: CGSize(width: 60, height: 48)) { cg, _ in
            let s: CGFloat = small ? 0.6 : 1
            shadow(cg, center: CGPoint(x: 30, y: 9), width: 46 * s, height: 10)
            let path = CGMutablePath()
            let pts = [(8, 8), (14, 28), (26, 38), (42, 34), (52, 20), (50, 8)].map { CGPoint(x: 30 + (CGFloat($0.0) - 30) * s, y: 8 + (CGFloat($0.1) - 8) * s) }
            path.addLines(between: pts)
            path.closeSubpath()
            fill(cg, path, [Ink.stoneLight, Ink.stone, Ink.stoneDark])
            if !small {
                cg.setStrokeColor(Ink.stoneDark.cgColor)
                cg.setLineWidth(1.6)
                cg.move(to: CGPoint(x: 26, y: 30)); cg.addLine(to: CGPoint(x: 32, y: 20)); cg.addLine(to: CGPoint(x: 40, y: 18))
                cg.strokePath()
            }
        }
    }

    static func mushroom() -> SKTexture {
        texture("mushroom", size: CGSize(width: 48, height: 44)) { cg, _ in
            shadow(cg, center: CGPoint(x: 24, y: 7), width: 34, height: 9)
            for (dx, s) in [(CGFloat(-9), CGFloat(0.75)), (6, 1.0)] {
                let cx = 24 + dx
                fill(cg, rounded(CGRect(x: cx - 4 * s, y: 6, width: 8 * s, height: 16 * s), 3), [UIColor(hex: 0xFFF6E3), UIColor(hex: 0xE8D9BA)], outline: 1.4)
                let cap = CGMutablePath()
                cap.addArc(center: CGPoint(x: cx, y: 6 + 16 * s), radius: 13 * s, startAngle: 0, endAngle: .pi, clockwise: false)
                cap.closeSubpath()
                fill(cg, cap, [UIColor(hex: 0xFF7A5C), UIColor(hex: 0xD9442D)], outline: 1.6)
                dot(cg, CGPoint(x: cx - 4 * s, y: 6 + 22 * s), 2.2 * s, .white)
                dot(cg, CGPoint(x: cx + 5 * s, y: 6 + 20 * s), 1.8 * s, .white)
            }
        }
    }

    // MARK: Characters

    /// The Brote: a round sprout with a leaf on its head. `frame` 0/1 squashes for the walk.
    static func brote(frame: Int) -> SKTexture {
        texture("brote-\(frame)", size: CGSize(width: 56, height: 64)) { cg, _ in
            let squash: CGFloat = frame == 1 ? 1.5 : 0
            shadow(cg, center: CGPoint(x: 28, y: 7), width: 34, height: 9)
            // Feet.
            fill(cg, ellipse(CGRect(x: 15, y: 4 + squash, width: 11, height: 7)), [Ink.broteDark, Ink.broteDark], outline: 1.6)
            fill(cg, ellipse(CGRect(x: 30, y: 4 - squash * 0.5, width: 11, height: 7)), [Ink.broteDark, Ink.broteDark], outline: 1.6)
            // Body.
            let body = ellipse(CGRect(x: 10, y: 8 - squash * 0.5, width: 36, height: 36 + squash))
            fill(cg, body, [UIColor(hex: 0x9BE875), Ink.brote, Ink.broteDark])
            fill(cg, ellipse(CGRect(x: 18, y: 10, width: 20, height: 16)), [Ink.broteBelly, Ink.broteBelly.withAlphaComponent(0.6)], outline: 0)
            // Eyes, looking right.
            for x in [CGFloat(24), 35] {
                dot(cg, CGPoint(x: x, y: 32), 5, .white)
                dot(cg, CGPoint(x: x + 1.5, y: 31.5), 2.8, Ink.outline)
                dot(cg, CGPoint(x: x + 2.4, y: 33), 1, .white)
            }
            dot(cg, CGPoint(x: 19, y: 25), 3, UIColor(hex: 0xFF8FA3).withAlphaComponent(0.7))
            dot(cg, CGPoint(x: 41, y: 25), 3, UIColor(hex: 0xFF8FA3).withAlphaComponent(0.7))
            // Sprout.
            cg.setStrokeColor(Ink.broteDark.cgColor)
            cg.setLineWidth(2.4)
            cg.move(to: CGPoint(x: 28, y: 43)); cg.addLine(to: CGPoint(x: 28, y: 50))
            cg.strokePath()
            for (dx, tilt) in [(CGFloat(-8), CGFloat(-0.5)), (8, 0.5)] {
                let leaf = CGMutablePath()
                leaf.move(to: CGPoint(x: 28, y: 50))
                leaf.addQuadCurve(to: CGPoint(x: 28 + dx * 1.5, y: 55 + tilt * 4), control: CGPoint(x: 28 + dx * 0.6, y: 62))
                leaf.addQuadCurve(to: CGPoint(x: 28, y: 50), control: CGPoint(x: 28 + dx, y: 48))
                fill(cg, leaf, [Ink.leafLight, Ink.leaf], outline: 1.6)
            }
        }
    }

    static func slime(frame: Int) -> SKTexture {
        texture("slime-\(frame)", size: CGSize(width: 48, height: 40)) { cg, _ in
            let h: CGFloat = frame == 1 ? 22 : 26
            shadow(cg, center: CGPoint(x: 24, y: 6), width: 34, height: 8)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 6, y: 6))
            path.addQuadCurve(to: CGPoint(x: 24, y: 6 + h), control: CGPoint(x: 4, y: 6 + h))
            path.addQuadCurve(to: CGPoint(x: 42, y: 6), control: CGPoint(x: 44, y: 6 + h))
            path.closeSubpath()
            fill(cg, path, [UIColor(hex: 0xB4ABEA), Ink.mist, Ink.mistDark])
            dot(cg, CGPoint(x: 18, y: 6 + h * 0.5), 3.4, .white)
            dot(cg, CGPoint(x: 29, y: 6 + h * 0.5), 3.4, .white)
            dot(cg, CGPoint(x: 18.8, y: 6 + h * 0.48), 1.8, Ink.outline)
            dot(cg, CGPoint(x: 29.8, y: 6 + h * 0.48), 1.8, Ink.outline)
            dot(cg, CGPoint(x: 15, y: 6 + h * 0.78), 2.5, .white.withAlphaComponent(0.6))
        }
    }

    static func wolf(boss: Bool, frame: Int) -> SKTexture {
        let s: CGFloat = boss ? 1.7 : 1
        return texture("wolf-\(boss)-\(frame)", size: CGSize(width: 72 * s, height: 54 * s)) { cg, _ in
            cg.scaleBy(x: s, y: s)
            let body = boss ? UIColor(hex: 0x3F4868) : Ink.wolf
            let dark = boss ? UIColor(hex: 0x262C45) : Ink.wolfDark
            let leg: CGFloat = frame == 1 ? 3 : 0
            shadow(cg, center: CGPoint(x: 36, y: 7), width: 52, height: 10)
            for x in [CGFloat(20), 30, 42, 52] {
                fill(cg, rounded(CGRect(x: x - 3, y: 5 + (x > 35 ? leg : 0), width: 7, height: 16), 3), [dark, dark], outline: 1.4)
            }
            // Smoky tail.
            fill(cg, blob(CGPoint(x: 12, y: 30), radius: 9, lumps: 3, wobble: 0.2, seed: 3), [body, dark], outline: 1.6)
            fill(cg, ellipse(CGRect(x: 14, y: 14, width: 44, height: 24)), [body.lighter(0.15), body, dark])
            // Head with ears.
            for x in [CGFloat(50), 60] {
                let ear = CGMutablePath()
                ear.move(to: CGPoint(x: x - 4, y: 38)); ear.addLine(to: CGPoint(x: x, y: 50)); ear.addLine(to: CGPoint(x: x + 4, y: 38))
                ear.closeSubpath()
                fill(cg, ear, [body, dark], outline: 1.4)
            }
            fill(cg, ellipse(CGRect(x: 44, y: 22, width: 24, height: 20)), [body.lighter(0.15), body])
            fill(cg, ellipse(CGRect(x: 60, y: 24, width: 10, height: 8)), [dark, dark], outline: 1.2)
            let eye = boss ? UIColor(hex: 0xFF4D5E) : UIColor(hex: 0xFFE066)
            dot(cg, CGPoint(x: 56, y: 33), 3.4, eye.withAlphaComponent(0.45))
            dot(cg, CGPoint(x: 56, y: 33), 2.2, eye)
        }
    }

    // MARK: Base

    static func campfire(frame: Int) -> SKTexture {
        texture("campfire-\(frame)", size: CGSize(width: 64, height: 64)) { cg, _ in
            shadow(cg, center: CGPoint(x: 32, y: 12), width: 52, height: 12)
            for i in 0..<8 {
                let a = Double(i) / 8 * 2 * .pi
                let p = CGPoint(x: 32 + CGFloat(cos(a)) * 20, y: 14 + CGFloat(sin(a)) * 8)
                fill(cg, ellipse(CGRect(x: p.x - 5, y: p.y - 4, width: 10, height: 8)), [Ink.stoneLight, Ink.stoneDark], outline: 1.2)
            }
            fill(cg, rounded(CGRect(x: 18, y: 12, width: 28, height: 7), 3), [Ink.woodLight, Ink.wood], outline: 1.4)
            let h: CGFloat = frame == 0 ? 34 : 29
            let flame = CGMutablePath()
            flame.move(to: CGPoint(x: 21, y: 18))
            flame.addQuadCurve(to: CGPoint(x: 32, y: 18 + h), control: CGPoint(x: 18, y: 18 + h * 0.6))
            flame.addQuadCurve(to: CGPoint(x: 43, y: 18), control: CGPoint(x: 46, y: 18 + h * 0.5))
            flame.closeSubpath()
            fill(cg, flame, [Ink.fireCore, Ink.fire, UIColor(hex: 0xE5532D)], outline: 1.4)
            fill(cg, ellipse(CGRect(x: 27, y: 19, width: 10, height: h * 0.45)), [.white, Ink.fireCore], outline: 0)
        }
    }

    static func glow(color: UIColor, radius: CGFloat) -> SKTexture {
        texture("glow-\(color.hashValue)-\(radius)", size: CGSize(width: radius * 2, height: radius * 2)) { cg, size in
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [color.withAlphaComponent(0.55).cgColor, color.withAlphaComponent(0).cgColor] as CFArray,
                                      locations: [0, 1])!
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            cg.drawRadialGradient(gradient, startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [])
        }
    }

    static func house() -> SKTexture {
        texture("house", size: CGSize(width: 110, height: 104)) { cg, _ in
            shadow(cg, center: CGPoint(x: 55, y: 10), width: 96, height: 14)
            fill(cg, rounded(CGRect(x: 18, y: 8, width: 74, height: 50), 6), [Ink.woodLight, Ink.wood])
            for y in stride(from: CGFloat(18), to: 56, by: 10) {
                cg.setStrokeColor(Ink.woodDark.withAlphaComponent(0.5).cgColor); cg.setLineWidth(1.2)
                cg.move(to: CGPoint(x: 20, y: y)); cg.addLine(to: CGPoint(x: 90, y: y)); cg.strokePath()
            }
            let roof = CGMutablePath()
            roof.move(to: CGPoint(x: 8, y: 54)); roof.addLine(to: CGPoint(x: 55, y: 96)); roof.addLine(to: CGPoint(x: 102, y: 54))
            roof.closeSubpath()
            fill(cg, roof, [Ink.roof, Ink.roofDark])
            fill(cg, rounded(CGRect(x: 46, y: 8, width: 18, height: 28), 8), [Ink.woodDark, Ink.woodDark], outline: 1.6)
            fill(cg, rounded(CGRect(x: 26, y: 30, width: 14, height: 14), 3), [Ink.fireCore, Ink.fire], outline: 1.6)
        }
    }

    static func stall() -> SKTexture {
        texture("stall", size: CGSize(width: 96, height: 90)) { cg, _ in
            shadow(cg, center: CGPoint(x: 48, y: 9), width: 84, height: 12)
            for x in [CGFloat(16), 76] { fill(cg, rounded(CGRect(x: x, y: 8, width: 6, height: 56), 2), [Ink.woodLight, Ink.wood], outline: 1.4) }
            fill(cg, rounded(CGRect(x: 10, y: 10, width: 76, height: 22), 4), [Ink.woodLight, Ink.wood])
            // Goods on the counter.
            for (i, c) in [Ink.berry, Ink.fire, Ink.gold, Ink.leaf].enumerated() {
                fill(cg, ellipse(CGRect(x: 18 + CGFloat(i) * 16, y: 30, width: 12, height: 10)), [c.lighter(0.2), c], outline: 1.2)
            }
            // Striped awning.
            for i in 0..<6 {
                let stripe = CGMutablePath()
                let x = 8 + CGFloat(i) * 13.3
                stripe.move(to: CGPoint(x: x, y: 62)); stripe.addLine(to: CGPoint(x: x + 13.3, y: 62))
                stripe.addLine(to: CGPoint(x: x + 13.3, y: 80)); stripe.addLine(to: CGPoint(x: x, y: 80))
                stripe.closeSubpath()
                fill(cg, stripe, i.isMultiple(of: 2) ? [Ink.roof, Ink.roofDark] : [.white, UIColor(white: 0.9, alpha: 1)], outline: 1.2)
            }
            for i in 0..<6 { dot(cg, CGPoint(x: 14.6 + CGFloat(i) * 13.3, y: 61), 6.6, i.isMultiple(of: 2) ? Ink.roof : .white) }
        }
    }

    static func board() -> SKTexture {
        texture("board", size: CGSize(width: 64, height: 70)) { cg, _ in
            shadow(cg, center: CGPoint(x: 32, y: 7), width: 48, height: 10)
            for x in [CGFloat(14), 46] { fill(cg, rounded(CGRect(x: x, y: 6, width: 5, height: 40), 2), [Ink.woodLight, Ink.wood], outline: 1.2) }
            fill(cg, rounded(CGRect(x: 6, y: 26, width: 52, height: 36), 4), [Ink.woodLight, Ink.wood])
            for (i, p) in [CGPoint(x: 12, y: 34), CGPoint(x: 30, y: 40), CGPoint(x: 44, y: 32)].enumerated() {
                fill(cg, rounded(CGRect(x: p.x, y: p.y, width: 13, height: 16), 1.5), [.white, UIColor(hex: 0xF3EBD7)], outline: 1)
                dot(cg, CGPoint(x: p.x + 6.5, y: p.y + 14), 1.6, [Ink.roof, Ink.berry, Ink.gold][i])
            }
        }
    }

    static func workshop() -> SKTexture {
        texture("workshop", size: CGSize(width: 104, height: 92)) { cg, _ in
            shadow(cg, center: CGPoint(x: 52, y: 9), width: 92, height: 12)
            fill(cg, rounded(CGRect(x: 12, y: 8, width: 80, height: 42), 5), [Ink.stoneLight, Ink.stone])
            let roof = CGMutablePath()
            roof.move(to: CGPoint(x: 4, y: 46)); roof.addLine(to: CGPoint(x: 24, y: 76)); roof.addLine(to: CGPoint(x: 80, y: 76)); roof.addLine(to: CGPoint(x: 100, y: 46))
            roof.closeSubpath()
            fill(cg, roof, [Ink.woodLight, Ink.wood])
            fill(cg, rounded(CGRect(x: 68, y: 70, width: 12, height: 20), 2), [Ink.stoneLight, Ink.stoneDark], outline: 1.4)
            // Saw blade.
            fill(cg, ellipse(CGRect(x: 22, y: 16, width: 26, height: 26)), [UIColor(white: 0.92, alpha: 1), Ink.stoneDark], outline: 1.6)
            dot(cg, CGPoint(x: 35, y: 29), 3, Ink.outline)
            fill(cg, rounded(CGRect(x: 58, y: 8, width: 22, height: 26), 9), [Ink.woodDark, Ink.woodDark], outline: 1.4)
        }
    }

    static func garden(stage: Int) -> SKTexture {
        texture("garden-\(stage)", size: CGSize(width: 100, height: 64)) { cg, _ in
            fill(cg, rounded(CGRect(x: 6, y: 6, width: 88, height: 50), 8), [Ink.dirtDark, UIColor(hex: 0xA97C4C)])
            for row in 0..<3 {
                for col in 0..<5 {
                    let p = CGPoint(x: 18 + CGFloat(col) * 16, y: 16 + CGFloat(row) * 15)
                    fill(cg, blob(p, radius: 5.5 + CGFloat(stage), lumps: 3, wobble: 0.15, seed: row + col), [Ink.leafLight, Ink.leaf], outline: 1.2)
                    if stage >= 2 { dot(cg, CGPoint(x: p.x + 2, y: p.y + 1), 2.2, Ink.berry) }
                }
            }
        }
    }

    static func tower() -> SKTexture {
        texture("tower", size: CGSize(width: 60, height: 110)) { cg, _ in
            shadow(cg, center: CGPoint(x: 30, y: 8), width: 46, height: 11)
            for x in [CGFloat(12), 42] { fill(cg, rounded(CGRect(x: x, y: 6, width: 6, height: 62), 2), [Ink.woodLight, Ink.wood], outline: 1.4) }
            cg.setStrokeColor(Ink.woodDark.cgColor); cg.setLineWidth(2.4)
            cg.move(to: CGPoint(x: 15, y: 12)); cg.addLine(to: CGPoint(x: 45, y: 50)); cg.move(to: CGPoint(x: 45, y: 12)); cg.addLine(to: CGPoint(x: 15, y: 50)); cg.strokePath()
            fill(cg, rounded(CGRect(x: 6, y: 62, width: 48, height: 18), 3), [Ink.woodLight, Ink.wood])
            let roof = CGMutablePath()
            roof.move(to: CGPoint(x: 2, y: 78)); roof.addLine(to: CGPoint(x: 30, y: 106)); roof.addLine(to: CGPoint(x: 58, y: 78)); roof.closeSubpath()
            fill(cg, roof, [Ink.roof, Ink.roofDark])
        }
    }

    static func stake() -> SKTexture {
        texture("stake", size: CGSize(width: 14, height: 40)) { cg, _ in
            let path = CGMutablePath()
            path.addLines(between: [CGPoint(x: 2, y: 2), CGPoint(x: 2, y: 30), CGPoint(x: 7, y: 38), CGPoint(x: 12, y: 30), CGPoint(x: 12, y: 2)])
            path.closeSubpath()
            fill(cg, path, [Ink.woodLight, Ink.wood], outline: 1.4)
        }
    }

    static func bridge(width: CGFloat, height: CGFloat) -> SKTexture {
        texture("bridge-\(Int(width))x\(Int(height))", size: CGSize(width: width + 20, height: height)) { cg, size in
            let planks = Int(width / 14)
            for i in 0...planks {
                let x = 10 + CGFloat(i) * width / CGFloat(planks + 1)
                fill(cg, rounded(CGRect(x: x, y: 6, width: width / CGFloat(planks + 1) - 2, height: size.height - 12), 2),
                     [Ink.woodLight, Ink.wood], outline: 1.4)
            }
            for y in [CGFloat(4), size.height - 8] {
                fill(cg, rounded(CGRect(x: 2, y: y, width: size.width - 4, height: 5), 2), [Ink.woodDark, Ink.woodDark], outline: 1)
            }
        }
    }

    static func sign() -> SKTexture {
        texture("sign", size: CGSize(width: 50, height: 60)) { cg, _ in
            shadow(cg, center: CGPoint(x: 25, y: 6), width: 30, height: 8)
            fill(cg, rounded(CGRect(x: 22, y: 4, width: 6, height: 36), 2), [Ink.woodLight, Ink.wood], outline: 1.2)
            fill(cg, rounded(CGRect(x: 6, y: 30, width: 38, height: 24), 4), [UIColor(hex: 0xFFE7A8), Ink.gold])
            cg.setStrokeColor(Ink.woodDark.cgColor); cg.setLineWidth(3); cg.setLineCap(.round)
            cg.move(to: CGPoint(x: 16, y: 36)); cg.addLine(to: CGPoint(x: 30, y: 48)); cg.strokePath()
            fill(cg, rounded(CGRect(x: 26, y: 44, width: 12, height: 6), 1.5), [Ink.stoneLight, Ink.stoneDark], outline: 1)
        }
    }

    static func arrow() -> SKTexture {
        texture("arrow", size: CGSize(width: 26, height: 6)) { cg, _ in
            cg.setFillColor(Ink.woodDark.cgColor); cg.fill(CGRect(x: 2, y: 2, width: 18, height: 2))
            let tip = CGMutablePath(); tip.addLines(between: [CGPoint(x: 18, y: 0), CGPoint(x: 26, y: 3), CGPoint(x: 18, y: 6)]); tip.closeSubpath()
            cg.addPath(tip); cg.setFillColor(Ink.stoneDark.cgColor); cg.fillPath()
        }
    }

    static func particle(_ color: UIColor, key: String) -> SKTexture {
        texture("p-\(key)", size: CGSize(width: 12, height: 12)) { cg, _ in
            dot(cg, CGPoint(x: 6, y: 6), 5, color)
        }
    }

    static func leafParticle() -> SKTexture {
        texture("leafp", size: CGSize(width: 14, height: 10)) { cg, _ in
            let leaf = CGMutablePath()
            leaf.move(to: CGPoint(x: 1, y: 5)); leaf.addQuadCurve(to: CGPoint(x: 13, y: 5), control: CGPoint(x: 7, y: 11))
            leaf.addQuadCurve(to: CGPoint(x: 1, y: 5), control: CGPoint(x: 7, y: -1))
            cg.addPath(leaf); cg.setFillColor(Ink.leafLight.cgColor); cg.fillPath()
        }
    }

    static func slash() -> SKTexture {
        texture("slash", size: CGSize(width: 70, height: 70)) { cg, _ in
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            cg.setLineWidth(6); cg.setLineCap(.round)
            cg.addArc(center: CGPoint(x: 35, y: 35), radius: 26, startAngle: -.pi * 0.35, endAngle: .pi * 0.35, clockwise: false)
            cg.strokePath()
        }
    }

    static func mist() -> SKTexture {
        texture("mist", size: CGSize(width: 220, height: 150)) { cg, size in
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                      colors: [UIColor(hex: 0xE6E1FF).withAlphaComponent(0.75).cgColor, UIColor(hex: 0xB9B0E6).withAlphaComponent(0).cgColor] as CFArray,
                                      locations: [0, 1])!
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            cg.scaleBy(x: 1, y: size.height / size.width)
            cg.drawRadialGradient(gradient, startCenter: CGPoint(x: c.x, y: c.x), startRadius: 0, endCenter: CGPoint(x: c.x, y: c.x), endRadius: size.width / 2, options: [])
        }
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    func lighter(_ amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: r + (1 - r) * amount, green: g + (1 - g) * amount, blue: b + (1 - b) * amount, alpha: a)
    }
}
