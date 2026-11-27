import SpriteKit
import UIKit

/// All the game's art, painted with code at launch. The look is painterly and natural: light comes from the
/// top left, every object has volume (highlight and core shadow), soft ground shadows and only a faint edge
/// instead of a cartoon outline. Textures are made once and cached.
@MainActor
enum Art {
    // MARK: Palette (earthy, slightly desaturated: closer to nature)

    enum Ink {
        static let edge = UIColor(red: 0.10, green: 0.08, blue: 0.05, alpha: 0.42)
        static let outline = edge
        static let grass = UIColor(hex: 0x6EA84A), grassDark = UIColor(hex: 0x4E8834), grassLight = UIColor(hex: 0x90C364), grassDry = UIColor(hex: 0xA9C26A)
        static let forest = UIColor(hex: 0x4D7E3A), forestDark = UIColor(hex: 0x345E28), forestLight = UIColor(hex: 0x6A9A4C), litter = UIColor(hex: 0x7A5A32)
        static let quarry = UIColor(hex: 0x8F8D7D), quarryDark = UIColor(hex: 0x76746A), quarryLight = UIColor(hex: 0xB4B2A3)
        static let dirt = UIColor(hex: 0xB28858), dirtDark = UIColor(hex: 0x8A6640), dirtLight = UIColor(hex: 0xCBA574)
        static let sand = UIColor(hex: 0xDFCB95), sandDark = UIColor(hex: 0xC4AB77), sandWet = UIColor(hex: 0xA48F63)
        static let water = UIColor(hex: 0x4C9DBE), waterDeep = UIColor(hex: 0x23608C), waterLight = UIColor(hex: 0x93D3DC)
        static let foam = UIColor(white: 1, alpha: 0.6)
        static let wood = UIColor(hex: 0x8A5A32), woodLight = UIColor(hex: 0xB37C4A), woodDark = UIColor(hex: 0x5A3A1E)
        static let bark = UIColor(hex: 0x6B4A2E), barkDark = UIColor(hex: 0x3F2A18), barkLight = UIColor(hex: 0x93704A)
        static let leaf = UIColor(hex: 0x5E9A3C), leafDark = UIColor(hex: 0x3B6D28), leafLight = UIColor(hex: 0x8CC259), leafDeep = UIColor(hex: 0x264A1C)
        static let pine = UIColor(hex: 0x3E7A40), pineDark = UIColor(hex: 0x285A30), pineLight = UIColor(hex: 0x62975A), pineDeep = UIColor(hex: 0x173A20)
        static let gold = UIColor(hex: 0xF2C14E), goldDark = UIColor(hex: 0xC98A1E), goldLight = UIColor(hex: 0xFFE59A)
        static let stone = UIColor(hex: 0x9D9B92), stoneDark = UIColor(hex: 0x6C6B65), stoneLight = UIColor(hex: 0xC9C7BE), moss = UIColor(hex: 0x6E8F3C)
        static let berry = UIColor(hex: 0x4A58B8), berryLight = UIColor(hex: 0x8A97E6)
        static let brote = UIColor(hex: 0x7ED957), broteDark = UIColor(hex: 0x4A9A35), broteBelly = UIColor(hex: 0xD3F3B5)
        static let mist = UIColor(hex: 0x8D84C7), mistDark = UIColor(hex: 0x5D5498)
        static let fire = UIColor(hex: 0xFF8A2E), fireCore = UIColor(hex: 0xFFE27A), fireDeep = UIColor(hex: 0xD9441F)
        static let roof = UIColor(hex: 0xA8503A), roofDark = UIColor(hex: 0x7A3424), roofLight = UIColor(hex: 0xC86A4C)
        static let cloth = UIColor(hex: 0xC9473B), clothLight = UIColor(hex: 0xF3E7CF)
        static let window = UIColor(hex: 0xFFD27A)
        static let shadowTint = UIColor(hex: 0x14200E)
    }

    private static var images: [String: UIImage] = [:]
    private static var cache: [String: SKTexture] = [:]

    static func image(_ key: String, size: CGSize, scale: CGFloat = 2, draw: (CGContext, CGSize) -> Void) -> UIImage {
        if let cached = images[key] { return cached }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            // Flip so that y grows upwards, like SpriteKit.
            cg.translateBy(x: 0, y: size.height)
            cg.scaleBy(x: 1, y: -1)
            cg.setLineCap(.round)
            cg.setLineJoin(.round)
            draw(cg, size)
        }
        images[key] = image
        return image
    }

    static func texture(_ key: String, size: CGSize, scale: CGFloat = 2, draw: (CGContext, CGSize) -> Void) -> SKTexture {
        if let cached = cache[key] { return cached }
        let texture = SKTexture(image: image(key, size: size, scale: scale, draw: draw))
        texture.filteringMode = .linear
        cache[key] = texture
        return texture
    }

    // MARK: Drawing helpers

    static func grad(_ colors: [UIColor], _ locations: [CGFloat] = []) -> CGGradient {
        let cgColors = colors.map(\.cgColor) as CFArray
        let space = CGColorSpaceCreateDeviceRGB()
        if locations.count == colors.count {
            return CGGradient(colorsSpace: space, colors: cgColors, locations: locations)!
        }
        return CGGradient(colorsSpace: space, colors: cgColors, locations: nil)!
    }

    /// Light from the top left and a core shadow at the bottom right. Call with the shape's clip set.
    static func volume(_ cg: CGContext, _ box: CGRect, strength: CGFloat = 1) {
        let r = max(box.width, box.height)
        let light = CGPoint(x: box.minX + box.width * 0.3, y: box.maxY - box.height * 0.25)
        cg.drawRadialGradient(grad([UIColor(white: 1, alpha: 0.32 * strength), UIColor(white: 1, alpha: 0)]),
                              startCenter: light, startRadius: 0, endCenter: light, endRadius: r * 0.6, options: [])
        let core = CGPoint(x: box.minX + box.width * 0.38, y: box.maxY - box.height * 0.38)
        cg.drawRadialGradient(grad([UIColor(hex: 0x1A1430, alpha: 0), UIColor(hex: 0x1A1430, alpha: 0.34 * strength)], [0.42, 1]),
                              startCenter: core, startRadius: 0, endCenter: core, endRadius: r * 0.82, options: [.drawsAfterEndLocation])
    }

    static func fill(_ cg: CGContext, _ path: CGPath, _ colors: [UIColor], outline: CGFloat = 1.1, shade: CGFloat = 1, vertical: Bool = true) {
        let box = path.boundingBox
        cg.saveGState()
        cg.addPath(path)
        cg.clip()
        let stops = colors.count == 1 ? [colors[0], colors[0]] : colors
        let start = vertical ? CGPoint(x: box.midX, y: box.maxY) : CGPoint(x: box.minX, y: box.midY)
        let end = vertical ? CGPoint(x: box.midX, y: box.minY) : CGPoint(x: box.maxX, y: box.midY)
        cg.drawLinearGradient(grad(stops), start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        if shade > 0 { volume(cg, box, strength: shade) }
        cg.restoreGState()
        if outline > 0 {
            cg.addPath(path)
            cg.setStrokeColor(Ink.edge.cgColor)
            cg.setLineWidth(outline)
            cg.strokePath()
        }
    }

    static func ellipse(_ rect: CGRect) -> CGPath { CGPath(ellipseIn: rect, transform: nil) }

    static func circle(_ c: CGPoint, _ r: CGFloat) -> CGPath { ellipse(CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) }

    static func rounded(_ rect: CGRect, _ r: CGFloat) -> CGPath {
        CGPath(roundedRect: rect, cornerWidth: min(r, rect.width / 2), cornerHeight: min(r, rect.height / 2), transform: nil)
    }

    /// Soft contact shadow, stretched a little to the bottom right (the sun is top left).
    static func shadow(_ cg: CGContext, center: CGPoint, width: CGFloat, height: CGFloat = 10, alpha: CGFloat = 0.36) {
        cg.saveGState()
        cg.translateBy(x: center.x + width * 0.07, y: center.y - height * 0.1)
        cg.scaleBy(x: 1, y: max(height, 1) / max(width, 1))
        cg.drawRadialGradient(grad([Ink.shadowTint.withAlphaComponent(alpha), Ink.shadowTint.withAlphaComponent(alpha * 0.55), Ink.shadowTint.withAlphaComponent(0)], [0, 0.55, 1]),
                              startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: width / 2, options: [])
        cg.restoreGState()
    }

    static func dot(_ cg: CGContext, _ p: CGPoint, _ r: CGFloat, _ color: UIColor) {
        cg.setFillColor(color.cgColor)
        cg.fillEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
    }

    /// A dot that fades out to its edge.
    static func softDot(_ cg: CGContext, _ p: CGPoint, _ r: CGFloat, _ color: UIColor) {
        cg.drawRadialGradient(grad([color, color.withAlphaComponent(0)]), startCenter: p, startRadius: 0, endCenter: p, endRadius: r, options: [])
    }

    static func blob(_ center: CGPoint, radius: CGFloat, lumps: Int, wobble: CGFloat, seed: Int, squash: CGFloat = 0.92) -> CGPath {
        let path = CGMutablePath()
        let steps = max(lumps, 3) * 8
        for i in 0...steps {
            let a = Double(i) / Double(steps) * 2 * .pi
            let r = radius * (1 + wobble * CGFloat(sin(a * Double(lumps) + Double(seed))) + wobble * 0.4 * CGFloat(sin(a * Double(lumps * 2 + 1) + Double(seed) * 1.7)))
            let p = CGPoint(x: center.x + CGFloat(cos(a)) * r, y: center.y + CGFloat(sin(a)) * r * squash)
            i == 0 ? path.move(to: p) : path.addLine(to: p)
        }
        path.closeSubpath()
        return path
    }

    /// Draws `body` at `p` and at its wrapped copies, so a pattern tiles without seams.
    static func wrapped(_ size: CGSize, _ p: CGPoint, margin: CGFloat, _ body: (CGPoint) -> Void) {
        for dx in [-size.width, 0, size.width] {
            for dy in [-size.height, 0, size.height] {
                let q = CGPoint(x: p.x + dx, y: p.y + dy)
                if q.x > -margin, q.x < size.width + margin, q.y > -margin, q.y < size.height + margin { body(q) }
            }
        }
    }

    static func line(_ cg: CGContext, _ a: CGPoint, _ b: CGPoint, _ color: UIColor, _ width: CGFloat) {
        cg.setStrokeColor(color.cgColor)
        cg.setLineWidth(width)
        cg.move(to: a)
        cg.addLine(to: b)
        cg.strokePath()
    }

    /// A round, leafy clump lit from the top left: the building block of every crown and bush.
    static func leafBall(_ cg: CGContext, _ c: CGPoint, _ r: CGFloat, light: UIColor, mid: UIColor, dark: UIColor, seed: Int) {
        let path = blob(c, radius: r, lumps: 7, wobble: 0.07, seed: seed, squash: 0.94)
        cg.saveGState()
        cg.addPath(path)
        cg.clip()
        let lc = CGPoint(x: c.x - r * 0.38, y: c.y + r * 0.42)
        cg.drawRadialGradient(grad([light, mid, dark], [0, 0.5, 1]), startCenter: lc, startRadius: 0, endCenter: lc, endRadius: r * 1.55,
                              options: [.drawsAfterEndLocation])
        cg.restoreGState()
    }

    /// Small leaves catching the light (top left) or sitting in shade (bottom right) over a crown.
    static func foliageTexture(_ cg: CGContext, center: CGPoint, radius: CGFloat, light: UIColor, dark: UIColor, rng: inout SplitMix, count: Int) {
        for _ in 0..<count {
            let a = rng.r(0, 2 * .pi)
            let d = rng.r(0, radius)
            let p = CGPoint(x: center.x + cos(a) * d, y: center.y + sin(a) * d * 0.9)
            let lit = (p.x - center.x) - (p.y - center.y) < rng.r(-radius * 0.3, radius * 0.3)
            let color = lit ? light.withAlphaComponent(rng.r(0.35, 0.7)) : dark.withAlphaComponent(rng.r(0.25, 0.5))
            cg.saveGState()
            cg.translateBy(x: p.x, y: p.y)
            cg.rotate(by: rng.r(-0.8, 0.8))
            cg.setFillColor(color.cgColor)
            cg.fillEllipse(in: CGRect(x: -rng.r(1.6, 2.6), y: -1.2, width: rng.r(3.2, 5.2), height: rng.r(2.2, 3)))
            cg.restoreGState()
        }
    }

    // MARK: Ground

    private static func groundPalette(_ zone: Zone) -> (base: UIColor, dark: UIColor, light: UIColor, accent: UIColor) {
        switch zone {
        case .clearing: (Ink.grass, Ink.grassDark, Ink.grassLight, Ink.grassDry)
        case .oldForest: (Ink.forest, Ink.forestDark, Ink.forestLight, Ink.litter)
        case .quarry: (Ink.quarry, Ink.quarryDark, Ink.quarryLight, Ink.stoneDark)
        }
    }

    /// Grass (or gravel) tile. Details stay inside the tile, so neighbouring variants never show a seam.
    static func groundTile(_ zone: Zone, variant: Int) -> SKTexture {
        let t = WorldMap.tileSize
        return texture("ground-\(zone)-\(variant)", size: CGSize(width: t, height: t)) { cg, size in
            let p = groundPalette(zone)
            cg.setFillColor(p.base.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            var rng = SplitMix(seed: UInt64(variant * 131 + zone.rawValue * 17 + 3))
            for _ in 0..<5 {
                let r = rng.r(9, 16)
                let c = CGPoint(x: rng.r(r, size.width - r), y: rng.r(r, size.height - r))
                softDot(cg, c, r, (rng.chance(0.5) ? p.dark : p.light).withAlphaComponent(rng.r(0.12, 0.22)))
            }
            for _ in 0..<50 {
                let c = CGPoint(x: rng.r(1, size.width - 1), y: rng.r(1, size.height - 1))
                dot(cg, c, rng.r(0.4, 0.9), (rng.chance(0.5) ? p.dark : p.light).withAlphaComponent(0.45))
            }
            let blades = zone == .quarry ? 8 : 30
            for _ in 0..<blades {
                let base = CGPoint(x: rng.r(3, size.width - 3), y: rng.r(2, size.height - 9))
                let h = rng.r(3, 6.5)
                let lean = rng.r(-2.2, 2.2)
                let color: UIColor = rng.chance(0.15) ? p.accent.withAlphaComponent(0.7)
                    : rng.chance(0.55) ? p.dark.withAlphaComponent(0.75) : p.light.withAlphaComponent(0.85)
                cg.setStrokeColor(color.cgColor)
                cg.setLineWidth(rng.r(0.8, 1.3))
                cg.move(to: base)
                cg.addQuadCurve(to: CGPoint(x: base.x + lean, y: base.y + h), control: CGPoint(x: base.x + lean * 0.15, y: base.y + h * 0.6))
                cg.strokePath()
            }
            switch zone {
            case .oldForest:
                for _ in 0..<9 {
                    let a = CGPoint(x: rng.r(3, size.width - 6), y: rng.r(3, size.height - 6))
                    line(cg, a, CGPoint(x: a.x + rng.r(-3, 3), y: a.y + rng.r(-2, 2)), Ink.litter.withAlphaComponent(0.55), 0.9)
                }
            case .quarry:
                for _ in 0..<16 {
                    let c = CGPoint(x: rng.r(3, size.width - 3), y: rng.r(3, size.height - 3))
                    let r = rng.r(1, 2.4)
                    fill(cg, ellipse(CGRect(x: c.x - r, y: c.y - r * 0.75, width: r * 2, height: r * 1.5)), [Ink.stoneLight, Ink.stoneDark], outline: 0, shade: 0.4)
                }
            case .clearing:
                break
            }
        }
    }

    /// Seamless earth: grains, pebbles and faint cracks. Tiled inside the base and the paths.
    static func dirtPattern() -> UIImage {
        image("pattern-dirt", size: CGSize(width: 128, height: 128)) { cg, size in
            cg.setFillColor(Ink.dirt.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            var rng = SplitMix(seed: 404)
            for _ in 0..<26 {
                let r = rng.r(10, 26)
                let c = CGPoint(x: rng.r(0, size.width), y: rng.r(0, size.height))
                let color = (rng.chance(0.5) ? Ink.dirtDark : Ink.dirtLight).withAlphaComponent(rng.r(0.12, 0.24))
                wrapped(size, c, margin: r) { softDot(cg, $0, r, color) }
            }
            for _ in 0..<260 {
                let c = CGPoint(x: rng.r(0, size.width), y: rng.r(0, size.height))
                let r = rng.r(0.4, 1.1)
                let color = (rng.chance(0.6) ? Ink.dirtDark : Ink.dirtLight).withAlphaComponent(rng.r(0.4, 0.8))
                wrapped(size, c, margin: 2) { dot(cg, $0, r, color) }
            }
            for _ in 0..<6 {
                var a = CGPoint(x: rng.r(0, size.width), y: rng.r(0, size.height))
                for _ in 0..<3 {
                    let b = CGPoint(x: a.x + rng.r(-7, 7), y: a.y + rng.r(-7, 7))
                    let from = a
                    wrapped(size, from, margin: 10) { q in
                        line(cg, q, CGPoint(x: q.x + b.x - from.x, y: q.y + b.y - from.y), Ink.dirtDark.withAlphaComponent(0.3), 0.8)
                    }
                    a = b
                }
            }
            for _ in 0..<16 {
                let c = CGPoint(x: rng.r(0, size.width), y: rng.r(0, size.height))
                let r = rng.r(1.4, 3.4)
                wrapped(size, c, margin: 5) { q in
                    shadow(cg, center: CGPoint(x: q.x, y: q.y - r * 0.5), width: r * 2.6, height: r, alpha: 0.35)
                    fill(cg, ellipse(CGRect(x: q.x - r, y: q.y - r * 0.75, width: r * 2, height: r * 1.5)),
                         [Ink.stoneLight, Ink.stone, Ink.stoneDark], outline: 0.5, shade: 0.8)
                }
            }
        }
    }

    static func sandPattern() -> UIImage {
        image("pattern-sand", size: CGSize(width: 128, height: 128)) { cg, size in
            cg.setFillColor(Ink.sand.cgColor)
            cg.fill(CGRect(origin: .zero, size: size))
            var rng = SplitMix(seed: 505)
            for _ in 0..<20 {
                let r = rng.r(10, 24)
                let c = CGPoint(x: rng.r(0, size.width), y: rng.r(0, size.height))
                let color = (rng.chance(0.5) ? Ink.sandDark : UIColor.white).withAlphaComponent(rng.r(0.08, 0.18))
                wrapped(size, c, margin: r) { softDot(cg, $0, r, color) }
            }
            for _ in 0..<420 {
                let c = CGPoint(x: rng.r(0, size.width), y: rng.r(0, size.height))
                let r = rng.r(0.3, 0.8)
                let color = (rng.chance(0.6) ? Ink.sandDark : UIColor.white).withAlphaComponent(rng.r(0.3, 0.7))
                wrapped(size, c, margin: 1) { dot(cg, $0, r, color) }
            }
        }
    }

    // MARK: Terrain layer (base, paths, banks and rivers with soft natural edges)

    /// Worn footpaths, in tile coordinates: base → first bridge, and through the Old Forest to the lair.
    static let footpaths: [[CGPoint]] = [
        [CGPoint(x: 12.4, y: 15.2), CGPoint(x: 14.4, y: 15.6), CGPoint(x: 16.6, y: 15.1), CGPoint(x: 18.6, y: 14.6), CGPoint(x: 20.4, y: 14.5)],
        [CGPoint(x: 23.6, y: 14.5), CGPoint(x: 25.8, y: 14.3), CGPoint(x: 28.6, y: 13.2), CGPoint(x: 31.6, y: 12.6),
         CGPoint(x: 34.6, y: 11.2), CGPoint(x: 37.6, y: 10.3), CGPoint(x: 40.2, y: 9.5)],
    ]

    /// Points every `step` tiles along every footpath (tile coordinates).
    static let footpathSamples: [CGPoint] = {
        var points: [CGPoint] = []
        for path in footpaths {
            for (a, b) in zip(path, path.dropFirst()) {
                let n = max(1, Int(hypot(b.x - a.x, b.y - a.y) / 0.3))
                for i in 0..<n {
                    let f = CGFloat(i) / CGFloat(n)
                    points.append(CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f))
                }
            }
            if let last = path.last { points.append(last) }
        }
        return points
    }()

    static func onFootpath(col: Double, row: Double, margin: Double = 0.75) -> Bool {
        footpathSamples.contains { hypot(Double($0.x) - col, Double($0.y) - row) < margin }
            || hypot(col - Double(WorldMap.bossLair.col), row - Double(WorldMap.bossLair.row)) < 2.6
    }

    private struct TerrainShapes {
        let dirt: CGPath
        let sand: CGPath
        let wet: CGPath
        let water: CGPath
        let deep: CGPath
    }

    private static var shapesCache: TerrainShapes?

    /// Merges many circles into one clean outline (balanced, so it stays fast).
    private static func merge(_ shapes: [CGPath]) -> CGPath {
        var layer = shapes
        guard !layer.isEmpty else { return CGMutablePath() }
        while layer.count > 1 {
            var next: [CGPath] = []
            next.reserveCapacity(layer.count / 2 + 1)
            var i = 0
            while i < layer.count {
                next.append(i + 1 < layer.count ? layer[i].union(layer[i + 1]) : layer[i])
                i += 2
            }
            layer = next
        }
        return layer[0]
    }

    private static func isWater(_ tile: Tile) -> Bool {
        switch WorldMap.terrain(tile) {
        case .water, .bridge: true
        default: false
        }
    }

    /// Every terrain outline in world points, built once.
    private static func terrainShapes() -> TerrainShapes {
        if let shapesCache { return shapesCache }
        let t = CGFloat(WorldMap.tileSize)
        func center(_ c: CGFloat, _ r: CGFloat) -> CGPoint { CGPoint(x: (c + 0.5) * t, y: (r + 0.5) * t) }
        func jitter(_ col: Int, _ row: Int, _ salt: Int) -> CGFloat {
            var g = SplitMix(seed: UInt64(col * 7919 + row * 104_729 + salt * 31 + 11))
            return CGFloat(g.unit())
        }
        var dirt: [CGPath] = [], sand: [CGPath] = [], wet: [CGPath] = [], water: [CGPath] = [], deep: [CGPath] = []
        for col in 0..<WorldMap.columns {
            for row in 0..<WorldMap.rows {
                let p = center(CGFloat(col), CGFloat(row))
                switch WorldMap.terrain(Tile(col: col, row: row)) {
                case .base:
                    dirt.append(circle(p, t * (0.8 + 0.14 * jitter(col, row, 1))))
                case .bank:
                    sand.append(circle(p, t * (0.72 + 0.12 * jitter(col, row, 2))))
                case .water, .bridge:
                    sand.append(circle(p, t * 0.8))
                    // Rivers leave the map: extend the water past the top and bottom edges.
                    let extra: CGFloat = row == 0 || row == WorldMap.rows - 1 ? t * 0.6 : 0
                    let ry = row == 0 ? p.y - extra : p.y + extra
                    water.append(circle(CGPoint(x: p.x, y: (p.y + ry) / 2), t * 0.64 + extra / 2))
                    wet.append(circle(CGPoint(x: p.x, y: (p.y + ry) / 2), t * 0.64 + 8 + extra / 2))
                    if isWater(Tile(col: col - 1, row: row)) {
                        deep.append(circle(CGPoint(x: p.x - t * 0.5, y: p.y), t * (0.34 + 0.08 * jitter(col, row, 3))))
                    }
                case .grass:
                    break
                }
            }
        }
        for s in footpathSamples {
            let j = jitter(Int(s.x * 10), Int(s.y * 10), 4)
            dirt.append(circle(center(s.x, s.y), t * (0.44 + 0.12 * j)))
        }
        // The lair: a trampled clearing.
        let lair = center(CGFloat(WorldMap.bossLair.col), CGFloat(WorldMap.bossLair.row))
        dirt.append(Art.blob(lair, radius: t * 2.3, lumps: 6, wobble: 0.1, seed: 9))
        let shapes = TerrainShapes(dirt: merge(dirt), sand: merge(sand), wet: merge(wet), water: merge(water), deep: merge(deep))
        shapesCache = shapes
        return shapes
    }

    private static func tile(_ cg: CGContext, _ pattern: UIImage, origin: CGPoint) {
        guard let image = pattern.cgImage else { return }
        let w = pattern.size.width, h = pattern.size.height
        let rect = CGRect(x: -origin.x.truncatingRemainder(dividingBy: w), y: -origin.y.truncatingRemainder(dividingBy: h), width: w, height: h)
        cg.draw(image, in: rect, byTiling: true)
    }

    /// Paints one rectangle of the world (in tiles) with earth, sand and water. Neighbouring rectangles use the
    /// same world-space shapes, so they meet without a seam.
    static func terrainLayer(cols: ClosedRange<Int>, rows: ClosedRange<Int>, scale: CGFloat) -> SKTexture {
        let t = CGFloat(WorldMap.tileSize)
        let origin = CGPoint(x: CGFloat(cols.lowerBound) * t, y: CGFloat(rows.lowerBound) * t)
        let size = CGSize(width: CGFloat(cols.count) * t, height: CGFloat(rows.count) * t)
        let shapes = terrainShapes()
        let dirtImage = dirtPattern(), sandImage = sandPattern()
        return texture("terrain-\(cols.lowerBound)-\(cols.upperBound)-\(rows.lowerBound)-\(rows.upperBound)", size: size, scale: scale) { cg, size in
            cg.translateBy(x: -origin.x, y: -origin.y)
            let area = CGRect(origin: origin, size: size)
            // Earth: a worn, darker rim where grass gives way, then the textured ground.
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 14, color: Ink.dirtDark.withAlphaComponent(0.6).cgColor)
            cg.addPath(shapes.dirt)
            cg.setFillColor(Ink.dirt.cgColor)
            cg.fillPath()
            cg.restoreGState()
            cg.saveGState()
            cg.addPath(shapes.dirt)
            cg.clip()
            tile(cg, dirtImage, origin: .zero)
            cg.addPath(shapes.dirt)
            cg.setShadow(offset: .zero, blur: 10, color: UIColor(hex: 0x3A2612, alpha: 0.45).cgColor)
            cg.setStrokeColor(UIColor(hex: 0x3A2612, alpha: 0.18).cgColor)
            cg.setLineWidth(8)
            cg.strokePath()
            cg.restoreGState()

            // Banks of sand.
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 10, color: Ink.sandDark.withAlphaComponent(0.7).cgColor)
            cg.addPath(shapes.sand)
            cg.setFillColor(Ink.sand.cgColor)
            cg.fillPath()
            cg.restoreGState()
            cg.saveGState()
            cg.addPath(shapes.sand)
            cg.clip()
            tile(cg, sandImage, origin: .zero)
            cg.restoreGState()

            // Wet sand at the waterline.
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 9, color: Ink.sandWet.withAlphaComponent(0.8).cgColor)
            cg.addPath(shapes.wet)
            cg.setFillColor(Ink.sandWet.withAlphaComponent(0.75).cgColor)
            cg.fillPath()
            cg.restoreGState()

            // Water: clear shallows, a deep channel, light ripples.
            cg.saveGState()
            cg.addPath(shapes.water)
            cg.clip()
            cg.setFillColor(Ink.water.cgColor)
            cg.fill(area)
            cg.saveGState()
            cg.setShadow(offset: .zero, blur: 24, color: Ink.waterDeep.cgColor)
            cg.addPath(shapes.deep)
            cg.setFillColor(Ink.waterDeep.cgColor)
            cg.fillPath()
            cg.restoreGState()
            var rng = SplitMix(seed: UInt64(cols.lowerBound * 97 + rows.lowerBound + 1))
            let ripples = Int(size.width * size.height / 900)
            for _ in 0..<ripples {
                let p = CGPoint(x: area.minX + rng.r(0, size.width), y: area.minY + rng.r(0, size.height))
                guard shapes.water.contains(p) else { continue }
                let len = rng.r(8, 20)
                cg.setStrokeColor(UIColor(white: 1, alpha: rng.r(0.08, 0.22)).cgColor)
                cg.setLineWidth(rng.r(0.8, 1.6))
                cg.move(to: CGPoint(x: p.x - len / 2, y: p.y))
                cg.addCurve(to: CGPoint(x: p.x + len / 2, y: p.y + rng.r(-2, 2)),
                            control1: CGPoint(x: p.x - len / 6, y: p.y + 2.5), control2: CGPoint(x: p.x + len / 6, y: p.y - 2.5))
                cg.strokePath()
            }
            // Lighter shallows along the shore.
            cg.addPath(shapes.water)
            cg.setShadow(offset: .zero, blur: 12, color: Ink.waterLight.withAlphaComponent(0.8).cgColor)
            cg.setStrokeColor(Ink.waterLight.withAlphaComponent(0.4).cgColor)
            cg.setLineWidth(9)
            cg.strokePath()
            cg.restoreGState()

            // Foam where water meets sand.
            cg.saveGState()
            cg.addPath(shapes.water)
            cg.setStrokeColor(Ink.foam.cgColor)
            cg.setLineWidth(2)
            cg.setLineDash(phase: 0, lengths: [14, 5, 6, 7, 20, 4])
            cg.strokePath()
            cg.restoreGState()
        }
    }

    // MARK: Decoration (no gameplay: makes the land feel lived in)

    static func tuft(_ v: Int, forest: Bool = false) -> SKTexture {
        texture("tuft-\(v)-\(forest)", size: CGSize(width: 28, height: 22)) { cg, _ in
            var rng = SplitMix(seed: UInt64(v * 7 + (forest ? 50 : 0) + 1))
            shadow(cg, center: CGPoint(x: 14, y: 4), width: 20, height: 5, alpha: 0.25)
            let dark = forest ? Ink.forestDark : Ink.grassDark
            let light = forest ? Ink.forestLight : Ink.grassLight
            for i in 0..<9 {
                let x = 14 + rng.r(-6, 6)
                let h = rng.r(9, 17)
                let lean = rng.r(-6, 6)
                let blade = CGMutablePath()
                blade.move(to: CGPoint(x: x - 1.4, y: 3))
                blade.addQuadCurve(to: CGPoint(x: x + lean, y: 3 + h), control: CGPoint(x: x - 1 + lean * 0.2, y: 3 + h * 0.6))
                blade.addQuadCurve(to: CGPoint(x: x + 1.4, y: 3), control: CGPoint(x: x + 1 + lean * 0.3, y: 3 + h * 0.5))
                blade.closeSubpath()
                fill(cg, blade, i.isMultiple(of: 3) ? [light, dark] : [light.lighter(0.1), Ink.grass, dark], outline: 0, shade: 0)
            }
        }
    }

    static func flower(_ v: Int) -> SKTexture {
        texture("flower-\(v)", size: CGSize(width: 24, height: 24)) { cg, _ in
            var rng = SplitMix(seed: UInt64(v * 13 + 5))
            let (petal, heart): (UIColor, UIColor) = switch v % 4 {
            case 0: (UIColor(hex: 0xFBF8EE), Ink.gold)
            case 1: (UIColor(hex: 0xF7D44C), UIColor(hex: 0xD99A1E))
            case 2: (UIColor(hex: 0x7C86D9), UIColor(hex: 0xF3E7CF))
            default: (UIColor(hex: 0xD9473B), UIColor(hex: 0x2A1A14))
            }
            shadow(cg, center: CGPoint(x: 12, y: 3), width: 16, height: 4, alpha: 0.22)
            for _ in 0..<3 {
                let base = CGPoint(x: 12 + rng.r(-5, 5), y: 3)
                let head = CGPoint(x: base.x + rng.r(-2, 2), y: rng.r(10, 19))
                line(cg, base, head, Ink.grassDark, 1)
                let r: CGFloat = v % 4 == 3 ? 3.2 : 2.6
                for k in 0..<5 {
                    let a = CGFloat(k) / 5 * 2 * .pi + rng.r(0, 0.5)
                    let c = CGPoint(x: head.x + cos(a) * r * 0.75, y: head.y + sin(a) * r * 0.65)
                    fill(cg, ellipse(CGRect(x: c.x - r * 0.6, y: c.y - r * 0.5, width: r * 1.2, height: r)), [petal, petal.withAlphaComponent(0.85)], outline: 0.4, shade: 0.5)
                }
                dot(cg, head, r * 0.42, heart)
            }
        }
    }

    static func pebbles(_ v: Int) -> SKTexture {
        texture("pebbles-\(v)", size: CGSize(width: 22, height: 14)) { cg, _ in
            var rng = SplitMix(seed: UInt64(v * 3 + 77))
            for _ in 0..<3 {
                let c = CGPoint(x: rng.r(5, 17), y: rng.r(4, 8))
                let r = rng.r(1.8, 3.6)
                shadow(cg, center: CGPoint(x: c.x, y: c.y - r * 0.5), width: r * 2.8, height: r, alpha: 0.3)
                fill(cg, ellipse(CGRect(x: c.x - r, y: c.y - r * 0.7, width: r * 2, height: r * 1.4)), [Ink.stoneLight, Ink.stone, Ink.stoneDark], outline: 0.5)
            }
        }
    }

    static func fern(_ v: Int) -> SKTexture {
        texture("fern-\(v)", size: CGSize(width: 40, height: 30)) { cg, _ in
            var rng = SplitMix(seed: UInt64(v * 19 + 3))
            shadow(cg, center: CGPoint(x: 20, y: 5), width: 30, height: 7, alpha: 0.3)
            for i in 0..<6 {
                let angle = CGFloat.pi * (0.15 + 0.7 * CGFloat(i) / 5) + rng.r(-0.1, 0.1)
                let len = rng.r(13, 19)
                let base = CGPoint(x: 20, y: 4)
                let tip = CGPoint(x: base.x + cos(angle) * len, y: base.y + sin(angle) * len * 0.9)
                let color = i.isMultiple(of: 2) ? Ink.forestLight : Ink.leaf
                line(cg, base, tip, Ink.forestDark, 1)
                for k in 1...6 {
                    let f = CGFloat(k) / 7
                    let p = CGPoint(x: base.x + (tip.x - base.x) * f, y: base.y + (tip.y - base.y) * f)
                    let s = (1 - f) * 4 + 1.2
                    let n = CGPoint(x: -(tip.y - base.y) / len, y: (tip.x - base.x) / len)
                    for side in [CGFloat(-1), 1] {
                        line(cg, p, CGPoint(x: p.x + n.x * s * side + (tip.x - base.x) / len * 1.5, y: p.y + n.y * s * side + (tip.y - base.y) / len * 1.5), color, 1.6)
                    }
                }
            }
        }
    }

    static func litter(_ v: Int) -> SKTexture {
        texture("litter-\(v)", size: CGSize(width: 26, height: 16)) { cg, _ in
            var rng = SplitMix(seed: UInt64(v * 23 + 9))
            let colors = [UIColor(hex: 0xC9782E), UIColor(hex: 0xA65A26), UIColor(hex: 0xD9A441), UIColor(hex: 0x8A6A3A)]
            for _ in 0..<5 {
                let c = CGPoint(x: rng.r(5, 21), y: rng.r(4, 12))
                cg.saveGState()
                cg.translateBy(x: c.x, y: c.y)
                cg.rotate(by: rng.r(0, .pi))
                fill(cg, ellipse(CGRect(x: -3.2, y: -1.6, width: 6.4, height: 3.2)), [colors[Int(rng.next() % 4)]], outline: 0.4, shade: 0.4)
                cg.restoreGState()
            }
            line(cg, CGPoint(x: 4, y: 5), CGPoint(x: 18, y: 9), Ink.barkDark.withAlphaComponent(0.8), 1.2)
        }
    }

    static func reeds(_ v: Int) -> SKTexture {
        texture("reeds-\(v)", size: CGSize(width: 26, height: 44)) { cg, _ in
            var rng = SplitMix(seed: UInt64(v * 29 + 1))
            shadow(cg, center: CGPoint(x: 13, y: 4), width: 20, height: 5, alpha: 0.28)
            for i in 0..<5 {
                let x = 13 + rng.r(-7, 7)
                let h = rng.r(22, 38)
                let lean = rng.r(-4, 4)
                cg.setStrokeColor((i.isMultiple(of: 2) ? Ink.leafDark : Ink.leaf).cgColor)
                cg.setLineWidth(1.4)
                cg.move(to: CGPoint(x: x, y: 3))
                cg.addQuadCurve(to: CGPoint(x: x + lean, y: 3 + h), control: CGPoint(x: x, y: 3 + h * 0.6))
                cg.strokePath()
                if i < 3 {
                    let top = CGPoint(x: x + lean * 0.85, y: 3 + h * 0.82)
                    fill(cg, rounded(CGRect(x: top.x - 1.8, y: top.y - 4, width: 3.6, height: 8), 1.8), [UIColor(hex: 0x8A5A32), UIColor(hex: 0x5A3A1E)], outline: 0.5)
                }
            }
        }
    }

    static func lilyPad(_ v: Int) -> SKTexture {
        texture("lily-\(v)", size: CGSize(width: 26, height: 18)) { cg, _ in
            let pad = CGMutablePath()
            pad.addArc(center: CGPoint(x: 13, y: 9), radius: 9, startAngle: 0.35, endAngle: 2 * .pi - 0.05, clockwise: false)
            pad.addLine(to: CGPoint(x: 13, y: 9))
            pad.closeSubpath()
            cg.saveGState()
            cg.translateBy(x: 13, y: 9)
            cg.scaleBy(x: 1, y: 0.7)
            cg.translateBy(x: -13, y: -9)
            cg.setShadow(offset: CGSize(width: 1.5, height: -1.5), blur: 2, color: UIColor(hex: 0x0E3550, alpha: 0.5).cgColor)
            fill(cg, pad, [Ink.leafLight, Ink.leaf, Ink.leafDark], outline: 0.6, shade: 0.6)
            cg.restoreGState()
            if v.isMultiple(of: 2) {
                for k in 0..<6 {
                    let a = CGFloat(k) / 6 * 2 * .pi
                    fill(cg, ellipse(CGRect(x: 15 + cos(a) * 2.2 - 1.8, y: 11 + sin(a) * 1.6 - 1.2, width: 3.6, height: 2.6)), [UIColor(hex: 0xFFE0EC), UIColor(hex: 0xF29BB8)], outline: 0, shade: 0)
                }
                dot(cg, CGPoint(x: 15, y: 11), 1.1, Ink.gold)
            }
        }
    }

    static func fallenLog() -> SKTexture {
        texture("fallenLog", size: CGSize(width: 70, height: 28)) { cg, _ in
            shadow(cg, center: CGPoint(x: 35, y: 6), width: 62, height: 9)
            let body = rounded(CGRect(x: 6, y: 6, width: 56, height: 15), 7.5)
            fill(cg, body, [Ink.barkLight, Ink.bark, Ink.barkDark])
            var rng = SplitMix(seed: 31)
            for _ in 0..<9 {
                let x = rng.r(10, 54)
                line(cg, CGPoint(x: x, y: 8), CGPoint(x: x + rng.r(-3, 6), y: 19), Ink.barkDark.withAlphaComponent(0.45), 0.9)
            }
            fill(cg, ellipse(CGRect(x: 56, y: 6, width: 10, height: 15)), [UIColor(hex: 0xE2C08E), UIColor(hex: 0xB98E5C)], outline: 0.8, shade: 0.3)
            for r in [CGFloat(2), 4] {
                cg.setStrokeColor(UIColor(hex: 0x8A6640, alpha: 0.6).cgColor)
                cg.setLineWidth(0.6)
                cg.strokeEllipse(in: CGRect(x: 61 - r * 0.5, y: 13.5 - r, width: r, height: r * 2))
            }
            for _ in 0..<14 { softDot(cg, CGPoint(x: rng.r(10, 50), y: rng.r(15, 21)), rng.r(2, 4), Ink.moss.withAlphaComponent(0.7)) }
        }
    }

    /// Huge soft blotch laid on the meadow so the grass is never uniform.
    static func meadowPatch(light: Bool) -> SKTexture {
        texture("meadow-\(light)", size: CGSize(width: 240, height: 160), scale: 0.5) { cg, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            cg.translateBy(x: c.x, y: c.y)
            cg.scaleBy(x: 1, y: size.height / size.width)
            let color = light ? UIColor(hex: 0xC8E07A, alpha: 0.5) : UIColor(hex: 0x2E5A22, alpha: 0.5)
            cg.drawRadialGradient(grad([color, color.withAlphaComponent(0)]), startCenter: .zero, startRadius: 0, endCenter: .zero, endRadius: size.width / 2, options: [])
        }
    }

    // MARK: Nature

    /// Broad-leaved tree of the Clearing (three shapes).
    static func tree(variant v: Int) -> SKTexture {
        texture("oak-\(v % 3)", size: CGSize(width: 100, height: 124)) { cg, _ in
            var rng = SplitMix(seed: UInt64(v % 3 * 101 + 7))
            let tint: [UIColor] = switch v % 3 {
            case 0: [Ink.leafLight, Ink.leaf, Ink.leafDark, Ink.leafDeep]
            case 1: [UIColor(hex: 0x9CC75E), UIColor(hex: 0x6E9E3E), UIColor(hex: 0x46732A), UIColor(hex: 0x2C4E1C)]
            default: [UIColor(hex: 0x84BD5C), UIColor(hex: 0x56913E), UIColor(hex: 0x356428), UIColor(hex: 0x214419)]
            }
            shadow(cg, center: CGPoint(x: 56, y: 10), width: 78, height: 18, alpha: 0.42)
            trunk(cg, x: 50, width: 13, height: 52, rng: &rng)
            let cx: CGFloat = 50, cy: CGFloat = 78 + CGFloat(v % 3) * 2
            let clusters: [(CGPoint, CGFloat)] = (0..<14).map { _ in
                let a = rng.r(0, 2 * .pi), d = rng.r(0, 22)
                return (CGPoint(x: cx + cos(a) * d * 1.15, y: cy + sin(a) * d * 0.8), rng.r(13, 19))
            }
            for (p, r) in clusters { dot(cg, CGPoint(x: p.x + 3, y: p.y - 4), r, tint[3]) }
            for (i, item) in clusters.sorted(by: { $0.0.y > $1.0.y }).enumerated() {
                leafBall(cg, item.0, item.1, light: tint[0], mid: tint[1], dark: tint[2], seed: i)
            }
            foliageTexture(cg, center: CGPoint(x: cx, y: cy), radius: 34, light: tint[0].lighter(0.15), dark: tint[3], rng: &rng, count: 90)
        }
    }

    private static func trunk(_ cg: CGContext, x: CGFloat, width w: CGFloat, height h: CGFloat, rng: inout SplitMix) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x - w * 0.9, y: 6))
        path.addQuadCurve(to: CGPoint(x: x - w * 0.4, y: 14), control: CGPoint(x: x - w * 0.45, y: 7))
        path.addLine(to: CGPoint(x: x - w * 0.32, y: h))
        path.addLine(to: CGPoint(x: x + w * 0.32, y: h))
        path.addLine(to: CGPoint(x: x + w * 0.4, y: 14))
        path.addQuadCurve(to: CGPoint(x: x + w * 0.95, y: 6), control: CGPoint(x: x + w * 0.45, y: 7))
        path.closeSubpath()
        fill(cg, path, [Ink.barkLight, Ink.bark, Ink.barkDark], vertical: false)
        cg.saveGState()
        cg.addPath(path)
        cg.clip()
        for _ in 0..<7 {
            let bx = x + rng.r(-w * 0.3, w * 0.3)
            let by = rng.r(10, h - 6)
            line(cg, CGPoint(x: bx, y: by), CGPoint(x: bx + rng.r(-1, 1), y: by + rng.r(5, 10)), Ink.barkDark.withAlphaComponent(0.55), 0.9)
        }
        cg.restoreGState()
    }

    /// Conifer of the Old Forest (three shapes).
    static func pine(variant v: Int) -> SKTexture {
        texture("pine-\(v % 3)", size: CGSize(width: 88, height: 132)) { cg, _ in
            var rng = SplitMix(seed: UInt64(v % 3 * 37 + 5))
            shadow(cg, center: CGPoint(x: 50, y: 10), width: 70, height: 17, alpha: 0.45)
            trunk(cg, x: 44, width: 10, height: 34, rng: &rng)
            let tiers = 5
            let tall = 104 + CGFloat(v % 3) * 6
            for i in 0..<tiers {
                let f = CGFloat(i) / CGFloat(tiers)
                let w = 74 * (1 - f * 0.72) + rng.r(-3, 3)
                let y = 22 + f * (tall - 40)
                let h = 30 - f * 6
                let path = CGMutablePath()
                path.move(to: CGPoint(x: 44 - w / 2, y: y + 2))
                let teeth = 6
                for k in 0...teeth {
                    let tx = 44 - w / 2 + w * CGFloat(k) / CGFloat(teeth)
                    path.addLine(to: CGPoint(x: tx, y: y + (k.isMultiple(of: 2) ? 0 : 5) + rng.r(-1, 1)))
                }
                path.addLine(to: CGPoint(x: 44 + w / 2, y: y + 2))
                path.addQuadCurve(to: CGPoint(x: 44 + rng.r(-1.5, 1.5), y: y + h + 10), control: CGPoint(x: 44 + w * 0.22, y: y + h * 0.55))
                path.addQuadCurve(to: CGPoint(x: 44 - w / 2, y: y + 2), control: CGPoint(x: 44 - w * 0.22, y: y + h * 0.55))
                path.closeSubpath()
                cg.saveGState()
                cg.setShadow(offset: CGSize(width: 2, height: -3), blur: 4, color: Ink.pineDeep.withAlphaComponent(0.6).cgColor)
                fill(cg, path, [Ink.pineLight, Ink.pine, Ink.pineDark], outline: 0.8, vertical: false)
                cg.restoreGState()
                cg.saveGState()
                cg.addPath(path)
                cg.clip()
                for _ in 0..<14 {
                    let p = CGPoint(x: 44 + rng.r(-w / 2, w / 2), y: y + rng.r(2, h))
                    let lit = p.x < 44
                    line(cg, p, CGPoint(x: p.x + (lit ? -3 : 3), y: p.y - 2.5), (lit ? Ink.pineLight.lighter(0.2) : Ink.pineDeep).withAlphaComponent(0.55), 1)
                }
                cg.restoreGState()
            }
        }
    }

    static func goldenTree() -> SKTexture {
        texture("goldenTree", size: CGSize(width: 104, height: 128)) { cg, _ in
            var rng = SplitMix(seed: 99)
            shadow(cg, center: CGPoint(x: 56, y: 10), width: 80, height: 18, alpha: 0.4)
            trunk(cg, x: 52, width: 13, height: 52, rng: &rng)
            let clusters: [(CGPoint, CGFloat)] = (0..<14).map { _ in
                let a = rng.r(0, 2 * .pi), d = rng.r(0, 22)
                return (CGPoint(x: 52 + cos(a) * d * 1.15, y: 80 + sin(a) * d * 0.8), rng.r(13, 19))
            }
            for (p, r) in clusters { dot(cg, CGPoint(x: p.x + 3, y: p.y - 4), r, UIColor(hex: 0x8A5A12)) }
            for (i, item) in clusters.sorted(by: { $0.0.y > $1.0.y }).enumerated() {
                leafBall(cg, item.0, item.1, light: Ink.goldLight, mid: Ink.gold, dark: Ink.goldDark, seed: i)
            }
            foliageTexture(cg, center: CGPoint(x: 52, y: 80), radius: 34, light: .white, dark: UIColor(hex: 0x9A6410), rng: &rng, count: 80)
            for p in [CGPoint(x: 36, y: 92), CGPoint(x: 62, y: 84), CGPoint(x: 48, y: 104), CGPoint(x: 40, y: 70), CGPoint(x: 68, y: 98)] {
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
        texture("stump", size: CGSize(width: 44, height: 34)) { cg, _ in
            shadow(cg, center: CGPoint(x: 23, y: 7), width: 36, height: 10)
            let side = CGMutablePath()
            side.move(to: CGPoint(x: 8, y: 6))
            side.addQuadCurve(to: CGPoint(x: 13, y: 9), control: CGPoint(x: 12, y: 6))
            side.addLine(to: CGPoint(x: 13, y: 20))
            side.addLine(to: CGPoint(x: 31, y: 20))
            side.addLine(to: CGPoint(x: 31, y: 9))
            side.addQuadCurve(to: CGPoint(x: 37, y: 6), control: CGPoint(x: 32, y: 6))
            side.closeSubpath()
            fill(cg, side, [Ink.barkLight, Ink.bark, Ink.barkDark], vertical: false)
            fill(cg, ellipse(CGRect(x: 12, y: 16, width: 20, height: 9)), [UIColor(hex: 0xE8C796), UIColor(hex: 0xC49A64)], outline: 1, shade: 0.4)
            for r in [CGFloat(2.5), 5, 7.5] {
                cg.setStrokeColor(UIColor(hex: 0x9A7246, alpha: 0.55).cgColor)
                cg.setLineWidth(0.6)
                cg.strokeEllipse(in: CGRect(x: 22 - r, y: 20.5 - r * 0.45, width: r * 2, height: r * 0.9))
            }
        }
    }

    static func bush(berries: Bool, variant v: Int = 0) -> SKTexture {
        texture("bush-\(berries)-\(v % 2)", size: CGSize(width: 62, height: 50)) { cg, _ in
            var rng = SplitMix(seed: UInt64(v % 2 * 11 + 3))
            shadow(cg, center: CGPoint(x: 33, y: 8), width: 52, height: 13, alpha: 0.4)
            let balls: [(CGPoint, CGFloat)] = (0..<7).map { _ in (CGPoint(x: 31 + rng.r(-12, 12), y: 22 + rng.r(-5, 9)), rng.r(9, 13)) }
            for (p, r) in balls { dot(cg, CGPoint(x: p.x + 2, y: p.y - 3), r, Ink.leafDeep) }
            for (i, item) in balls.sorted(by: { $0.0.y > $1.0.y }).enumerated() {
                leafBall(cg, item.0, item.1, light: Ink.leafLight, mid: Ink.leaf, dark: Ink.leafDark, seed: i + 3)
            }
            foliageTexture(cg, center: CGPoint(x: 31, y: 25), radius: 20, light: Ink.leafLight.lighter(0.2), dark: Ink.leafDeep, rng: &rng, count: 40)
            guard berries else { return }
            for _ in 0..<5 {
                let c = CGPoint(x: 31 + rng.r(-15, 15), y: 22 + rng.r(-8, 12))
                for k in 0..<3 {
                    let p = CGPoint(x: c.x + CGFloat(k % 2) * 3.4 - 1.7, y: c.y + CGFloat(k / 2) * 3 - 1)
                    fill(cg, circle(p, 2.4), [Ink.berryLight, Ink.berry, UIColor(hex: 0x262E6A)], outline: 0.6, shade: 0.3)
                    dot(cg, CGPoint(x: p.x - 0.8, y: p.y + 0.9), 0.7, UIColor(white: 1, alpha: 0.85))
                }
            }
        }
    }

    static func rock(small: Bool = false, variant v: Int = 0, mossy: Bool = false) -> SKTexture {
        texture("rock-\(small)-\(v % 2)-\(mossy)", size: CGSize(width: 64, height: 52)) { cg, _ in
            var rng = SplitMix(seed: UInt64(v % 2 * 17 + 23))
            let s: CGFloat = small ? 0.6 : 1
            shadow(cg, center: CGPoint(x: 34, y: 9), width: 54 * s, height: 13 * s, alpha: 0.45)
            let c = CGPoint(x: 32, y: 8 + 15 * s)
            var points: [CGPoint] = []
            for i in 0..<9 {
                let a = CGFloat(i) / 9 * 2 * .pi
                let r = (21 + rng.r(-3, 3)) * s
                points.append(CGPoint(x: c.x + cos(a) * r * 1.1, y: max(6, c.y + sin(a) * r * 0.78)))
            }
            let path = CGMutablePath()
            path.addLines(between: points)
            path.closeSubpath()
            fill(cg, path, [Ink.stoneLight, Ink.stone, Ink.stoneDark])
            // Lit top facet and a shaded right face.
            let top = CGMutablePath()
            top.addLines(between: [points[2], points[3], points[4], CGPoint(x: c.x - 4 * s, y: c.y + 3 * s), points[1]])
            top.closeSubpath()
            cg.addPath(top)
            cg.setFillColor(UIColor(white: 1, alpha: 0.16).cgColor)
            cg.fillPath()
            let side = CGMutablePath()
            side.addLines(between: [points[0], points[1], CGPoint(x: c.x + 6 * s, y: c.y - 2 * s), points[7], points[8]])
            side.closeSubpath()
            cg.addPath(side)
            cg.setFillColor(UIColor(hex: 0x1A1430, alpha: 0.16).cgColor)
            cg.fillPath()
            if !small {
                cg.setStrokeColor(Ink.stoneDark.withAlphaComponent(0.8).cgColor)
                cg.setLineWidth(1)
                cg.move(to: CGPoint(x: c.x - 6, y: c.y + 10))
                cg.addLine(to: CGPoint(x: c.x - 1, y: c.y + 2))
                cg.addLine(to: CGPoint(x: c.x + 7, y: c.y))
                cg.strokePath()
            }
            for _ in 0..<12 { dot(cg, CGPoint(x: c.x + rng.r(-16, 16) * s, y: c.y + rng.r(-8, 10) * s), rng.r(0.4, 0.9), Ink.stoneDark.withAlphaComponent(0.5)) }
            if mossy {
                cg.saveGState()
                cg.addPath(path)
                cg.clip()
                for _ in 0..<10 { softDot(cg, CGPoint(x: c.x + rng.r(-14, 6) * s, y: c.y + rng.r(4, 14) * s), rng.r(3, 6) * s, Ink.moss.withAlphaComponent(0.75)) }
                cg.restoreGState()
            }
        }
    }

    static func mushroom() -> SKTexture {
        texture("mushroom", size: CGSize(width: 50, height: 46)) { cg, _ in
            shadow(cg, center: CGPoint(x: 26, y: 7), width: 40, height: 10)
            for (dx, s) in [(CGFloat(-9), CGFloat(0.72)), (7, 1.0), (-1, 0.5)] {
                let cx = 25 + dx
                fill(cg, rounded(CGRect(x: cx - 3.6 * s, y: 5, width: 7.2 * s, height: 17 * s), 3), [UIColor(hex: 0xFBF3E2), UIColor(hex: 0xDCCBA8)], outline: 0.8)
                let cap = CGMutablePath()
                let base = 5 + 15 * s
                cap.move(to: CGPoint(x: cx - 13 * s, y: base))
                cap.addQuadCurve(to: CGPoint(x: cx + 13 * s, y: base), control: CGPoint(x: cx, y: base + 22 * s))
                cap.addQuadCurve(to: CGPoint(x: cx - 13 * s, y: base), control: CGPoint(x: cx, y: base - 3 * s))
                cap.closeSubpath()
                fill(cg, cap, [UIColor(hex: 0xF0614A), UIColor(hex: 0xC93A27), UIColor(hex: 0x8E2418)], outline: 0.9)
                for (px, py, r) in [(-5.0, 6.0, 1.9), (3.0, 8.0, 1.5), (7.0, 4.0, 1.3), (-1.0, 3.0, 1.1)] {
                    dot(cg, CGPoint(x: cx + CGFloat(px) * s, y: base + CGFloat(py) * s), CGFloat(r) * s, UIColor(white: 1, alpha: 0.92))
                }
            }
        }
    }

    // MARK: Characters

    /// The Brote: a round sprout with a leaf on its head. Four walk frames (0 is also the idle pose).
    static func brote(frame: Int) -> SKTexture {
        let f = frame % 4
        return texture("brote-\(f)", size: CGSize(width: 58, height: 68)) { cg, _ in
            let bob: CGFloat = [0, 1.6, 0, 1.6][f]
            let left: CGFloat = [0, 2.2, 0, -1][f]
            let right: CGFloat = [0, -1, 0, 2.2][f]
            shadow(cg, center: CGPoint(x: 29, y: 6), width: 36, height: 9, alpha: 0.42)
            fill(cg, ellipse(CGRect(x: 16, y: 3 + left, width: 11, height: 7)), [Ink.broteDark, UIColor(hex: 0x2F6E22)], outline: 0.9, shade: 0.5)
            fill(cg, ellipse(CGRect(x: 31, y: 3 + right, width: 11, height: 7)), [Ink.broteDark, UIColor(hex: 0x2F6E22)], outline: 0.9, shade: 0.5)
            let body = ellipse(CGRect(x: 11, y: 7 + bob, width: 36, height: 37))
            fill(cg, body, [UIColor(hex: 0xA6EE80), Ink.brote, Ink.broteDark], outline: 1.1)
            // Belly and a soft rim light on the shaded side.
            cg.saveGState()
            cg.addPath(body)
            cg.clip()
            softDot(cg, CGPoint(x: 29, y: 17 + bob), 12, Ink.broteBelly.withAlphaComponent(0.75))
            cg.setStrokeColor(UIColor(hex: 0xE9FFD0, alpha: 0.5).cgColor)
            cg.setLineWidth(1.6)
            cg.addArc(center: CGPoint(x: 29, y: 25.5 + bob), radius: 17, startAngle: -0.9, endAngle: 0.2, clockwise: false)
            cg.strokePath()
            cg.restoreGState()
            // Eyes, looking right.
            for x in [CGFloat(25), 36] {
                fill(cg, circle(CGPoint(x: x, y: 31 + bob), 4.8), [.white, UIColor(hex: 0xE4EEF2)], outline: 0.7, shade: 0)
                dot(cg, CGPoint(x: x + 1.4, y: 30.5 + bob), 2.8, UIColor(hex: 0x231A14))
                dot(cg, CGPoint(x: x + 2.3, y: 32 + bob), 1, .white)
            }
            softDot(cg, CGPoint(x: 20, y: 24 + bob), 3.6, UIColor(hex: 0xFF8FA3).withAlphaComponent(0.6))
            softDot(cg, CGPoint(x: 41, y: 24 + bob), 3.6, UIColor(hex: 0xFF8FA3).withAlphaComponent(0.6))
            // Sprout, swaying with the steps.
            let sway: CGFloat = [0, -1.5, 0, 1.5][f]
            line(cg, CGPoint(x: 29, y: 43 + bob), CGPoint(x: 29 + sway * 0.5, y: 51 + bob), Ink.broteDark, 2.2)
            for (dx, tilt) in [(CGFloat(-8), CGFloat(-0.5)), (8, 0.5)] {
                let o = CGPoint(x: 29 + sway * 0.5, y: 51 + bob)
                let leaf = CGMutablePath()
                leaf.move(to: o)
                leaf.addQuadCurve(to: CGPoint(x: o.x + dx * 1.5 + sway, y: o.y + 5 + tilt * 4), control: CGPoint(x: o.x + dx * 0.6, y: o.y + 12))
                leaf.addQuadCurve(to: o, control: CGPoint(x: o.x + dx, y: o.y - 2))
                fill(cg, leaf, [Ink.leafLight, Ink.leaf], outline: 0.9, shade: 0.6)
            }
        }
    }

    static func slime(frame: Int) -> SKTexture {
        texture("slime-\(frame % 2)", size: CGSize(width: 50, height: 42)) { cg, _ in
            let h: CGFloat = frame % 2 == 1 ? 22 : 27
            let w: CGFloat = frame % 2 == 1 ? 40 : 36
            shadow(cg, center: CGPoint(x: 25, y: 6), width: 38, height: 9, alpha: 0.42)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 25 - w / 2, y: 6))
            path.addQuadCurve(to: CGPoint(x: 25, y: 6 + h), control: CGPoint(x: 25 - w / 2 - 2, y: 6 + h))
            path.addQuadCurve(to: CGPoint(x: 25 + w / 2, y: 6), control: CGPoint(x: 25 + w / 2 + 2, y: 6 + h))
            path.closeSubpath()
            fill(cg, path, [UIColor(hex: 0xC6BEF2, alpha: 0.95), Ink.mist.withAlphaComponent(0.92), Ink.mistDark], outline: 1)
            cg.saveGState()
            cg.addPath(path)
            cg.clip()
            softDot(cg, CGPoint(x: 27, y: 12), 12, UIColor(hex: 0xEDE8FF, alpha: 0.45))
            cg.restoreGState()
            for x in [CGFloat(19), 30] {
                dot(cg, CGPoint(x: x, y: 6 + h * 0.5), 3.4, .white)
                dot(cg, CGPoint(x: x + 0.8, y: 6 + h * 0.48), 1.9, UIColor(hex: 0x231A2E))
            }
            fill(cg, ellipse(CGRect(x: 14, y: 6 + h * 0.68, width: 7, height: 4)), [UIColor(white: 1, alpha: 0.8)], outline: 0, shade: 0)
        }
    }

    static func wolf(boss: Bool, frame: Int) -> SKTexture {
        let s: CGFloat = boss ? 1.7 : 1
        let f = frame % 2
        return texture("wolf-\(boss)-\(f)", size: CGSize(width: 84 * s, height: 62 * s)) { cg, _ in
            cg.scaleBy(x: s, y: s)
            let fur = boss ? UIColor(hex: 0x3E4258) : UIColor(hex: 0x6E717C)
            let back = boss ? UIColor(hex: 0x23263A) : UIColor(hex: 0x464953)
            let belly = boss ? UIColor(hex: 0x5D627C) : UIColor(hex: 0xA6A9B2)
            let step: CGFloat = f == 1 ? 3 : 0
            shadow(cg, center: CGPoint(x: 42, y: 6), width: 62, height: 12, alpha: 0.45)
            // Far legs (darker), then the near ones after the body.
            for (x, lift) in [(CGFloat(28), step), (56, -step * 0.6)] {
                fill(cg, rounded(CGRect(x: x - 3, y: 5 + max(0, lift), width: 6, height: 19), 3), [back, back], outline: 0.8, shade: 0.3)
            }
            let tail = CGMutablePath()
            tail.move(to: CGPoint(x: 20, y: 34))
            tail.addQuadCurve(to: CGPoint(x: 4, y: 44 + step * 0.5), control: CGPoint(x: 6, y: 34))
            tail.addQuadCurve(to: CGPoint(x: 22, y: 40), control: CGPoint(x: 10, y: 48))
            tail.closeSubpath()
            fill(cg, tail, [fur, back], outline: 0.9)
            let body = CGMutablePath()
            body.move(to: CGPoint(x: 19, y: 26))
            body.addQuadCurve(to: CGPoint(x: 22, y: 40), control: CGPoint(x: 14, y: 36))
            body.addQuadCurve(to: CGPoint(x: 48, y: 42), control: CGPoint(x: 34, y: 47))
            body.addQuadCurve(to: CGPoint(x: 58, y: 36), control: CGPoint(x: 55, y: 44))
            body.addLine(to: CGPoint(x: 60, y: 24))
            body.addQuadCurve(to: CGPoint(x: 47, y: 20), control: CGPoint(x: 56, y: 18))
            body.addQuadCurve(to: CGPoint(x: 25, y: 22), control: CGPoint(x: 36, y: 17))
            body.addQuadCurve(to: CGPoint(x: 19, y: 26), control: CGPoint(x: 20, y: 22))
            body.closeSubpath()
            fill(cg, body, [fur.lighter(0.12), fur, back], outline: 1)
            cg.saveGState()
            cg.addPath(body)
            cg.clip()
            softDot(cg, CGPoint(x: 40, y: 19), 13, belly.withAlphaComponent(0.7))
            for i in 0..<9 {
                let x = 24 + CGFloat(i) * 3.6
                line(cg, CGPoint(x: x, y: 42), CGPoint(x: x + 3, y: 36), back.withAlphaComponent(0.6), 1)
            }
            cg.restoreGState()
            for (x, lift) in [(CGFloat(24), -step * 0.6), (52, step)] {
                fill(cg, rounded(CGRect(x: x - 3.5, y: 5 + max(0, lift), width: 7, height: 19), 3.5), [fur, back], outline: 0.9, shade: 0.4)
            }
            for x in [CGFloat(58), 63] {
                let ear = CGMutablePath()
                ear.move(to: CGPoint(x: x - 3.5, y: 44))
                ear.addLine(to: CGPoint(x: x, y: 55))
                ear.addLine(to: CGPoint(x: x + 3.5, y: 44))
                ear.closeSubpath()
                fill(cg, ear, [fur, back], outline: 0.8)
            }
            let head = CGMutablePath()
            head.move(to: CGPoint(x: 52, y: 37))
            head.addQuadCurve(to: CGPoint(x: 61, y: 48), control: CGPoint(x: 53, y: 46))
            head.addQuadCurve(to: CGPoint(x: 71, y: 42), control: CGPoint(x: 67, y: 48))
            head.addLine(to: CGPoint(x: 80, y: 37))
            head.addQuadCurve(to: CGPoint(x: 74, y: 32), control: CGPoint(x: 81, y: 32))
            head.addQuadCurve(to: CGPoint(x: 57, y: 30), control: CGPoint(x: 65, y: 28))
            head.closeSubpath()
            fill(cg, head, [fur.lighter(0.15), fur, back], outline: 1)
            dot(cg, CGPoint(x: 79, y: 36.5), 1.8, UIColor(hex: 0x15131A))
            line(cg, CGPoint(x: 72, y: 32.5), CGPoint(x: 78, y: 33.5), back, 0.8)
            let eye = boss ? UIColor(hex: 0xFF4D5E) : UIColor(hex: 0xFFE066)
            softDot(cg, CGPoint(x: 67, y: 40), 4.5, eye.withAlphaComponent(0.55))
            dot(cg, CGPoint(x: 67, y: 40), 1.7, eye)
            if boss {
                // Smoke curling off its back.
                for (x, y, r) in [(26.0, 46.0, 4.0), (34.0, 50.0, 5.0), (44.0, 49.0, 3.5), (16.0, 48.0, 3.0)] {
                    softDot(cg, CGPoint(x: x, y: y), CGFloat(r) * 1.6, UIColor(hex: 0x8D84C7, alpha: 0.45))
                }
            }
        }
    }

    // MARK: Base

    static func campfire(frame: Int) -> SKTexture {
        let f = frame % 3
        return texture("campfire-\(f)", size: CGSize(width: 68, height: 70)) { cg, _ in
            shadow(cg, center: CGPoint(x: 34, y: 12), width: 58, height: 14, alpha: 0.4)
            var rng = SplitMix(seed: 12)
            for i in 0..<9 {
                let a = CGFloat(i) / 9 * 2 * .pi
                let p = CGPoint(x: 34 + cos(a) * 21, y: 14 + sin(a) * 8)
                let r = rng.r(4.5, 6)
                fill(cg, ellipse(CGRect(x: p.x - r, y: p.y - r * 0.75, width: r * 2, height: r * 1.5)), [Ink.stoneLight, Ink.stone, Ink.stoneDark], outline: 0.8)
            }
            softDot(cg, CGPoint(x: 34, y: 15), 15, UIColor(hex: 0x2A1A10, alpha: 0.7))
            for (a, b) in [(CGPoint(x: 20, y: 11), CGPoint(x: 46, y: 19)), (CGPoint(x: 20, y: 19), CGPoint(x: 47, y: 12))] {
                cg.setStrokeColor(Ink.barkDark.cgColor)
                cg.setLineWidth(6.5)
                cg.move(to: a); cg.addLine(to: b); cg.strokePath()
                cg.setStrokeColor(Ink.barkLight.withAlphaComponent(0.6).cgColor)
                cg.setLineWidth(2)
                cg.move(to: CGPoint(x: a.x, y: a.y + 1.5)); cg.addLine(to: CGPoint(x: b.x, y: b.y + 1.5)); cg.strokePath()
            }
            softDot(cg, CGPoint(x: 34, y: 16), 9, UIColor(hex: 0xFF6A1E, alpha: 0.9))
            let heights: [CGFloat] = [36, 31, 39]
            let leans: [CGFloat] = [0, -3, 2.5]
            for (k, (scale, colors)) in [(CGFloat(1), [Ink.fire, Ink.fireDeep]), (0.68, [Ink.fireCore, Ink.fire]), (0.36, [UIColor.white, Ink.fireCore])].enumerated() {
                let h = heights[f] * scale
                let w = 24 * scale
                let flame = CGMutablePath()
                flame.move(to: CGPoint(x: 34 - w / 2, y: 17))
                flame.addQuadCurve(to: CGPoint(x: 34 + leans[f] * scale, y: 17 + h), control: CGPoint(x: 34 - w / 2 - 3, y: 17 + h * 0.55))
                flame.addQuadCurve(to: CGPoint(x: 34 + w / 2, y: 17), control: CGPoint(x: 34 + w / 2 + 3, y: 17 + h * 0.45))
                flame.closeSubpath()
                fill(cg, flame, colors, outline: 0, shade: k == 0 ? 0.2 : 0)
            }
        }
    }

    static func glow(_ name: String, color: UIColor, radius: CGFloat) -> SKTexture {
        texture("glow-\(name)-\(Int(radius))", size: CGSize(width: radius * 2, height: radius * 2), scale: radius > 60 ? 1 : 2) { cg, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            cg.drawRadialGradient(grad([color.withAlphaComponent(0.6), color.withAlphaComponent(0.22), color.withAlphaComponent(0)], [0, 0.45, 1]),
                                  startCenter: c, startRadius: 0, endCenter: c, endRadius: radius, options: [])
        }
    }

    /// Log cabin. `windows` and `chimney` give the points (from the sprite's anchor) where lights and smoke go.
    static let houseSize = CGSize(width: 124, height: 120)
    static let houseWindows = [CGPoint(x: 34, y: 38), CGPoint(x: 90, y: 38)]
    static let houseChimney = CGPoint(x: 94, y: 108)

    static func house() -> SKTexture {
        texture("house", size: houseSize) { cg, _ in
            shadow(cg, center: CGPoint(x: 64, y: 12), width: 116, height: 20, alpha: 0.42)
            // Stone footing.
            for i in 0..<9 {
                let x = 16 + CGFloat(i) * 10.4
                fill(cg, rounded(CGRect(x: x, y: 6, width: 10, height: 7), 2.5), [Ink.stoneLight, Ink.stone, Ink.stoneDark], outline: 0.6)
            }
            // Log walls.
            let wall = CGRect(x: 18, y: 12, width: 88, height: 48)
            for i in 0..<6 {
                let y = wall.minY + CGFloat(i) * 8
                fill(cg, rounded(CGRect(x: wall.minX - 3, y: y, width: wall.width + 6, height: 8.5), 4.2), [Ink.woodLight, Ink.wood, Ink.woodDark], outline: 0.7, shade: 0.4)
                for end in [wall.minX - 3, wall.maxX - 5] {
                    fill(cg, ellipse(CGRect(x: end, y: y + 0.5, width: 8, height: 7.5)), [UIColor(hex: 0xD9B07A), UIColor(hex: 0xA77A48)], outline: 0.6, shade: 0.3)
                }
            }
            // Door with frame.
            fill(cg, rounded(CGRect(x: 52, y: 12, width: 22, height: 34), 10), [Ink.woodDark.lighter(0.1), UIColor(hex: 0x3E2614)], outline: 1)
            for x in [CGFloat(58), 63, 68] { line(cg, CGPoint(x: x, y: 14), CGPoint(x: x, y: 42), UIColor(hex: 0x2A190C, alpha: 0.6), 0.8) }
            dot(cg, CGPoint(x: 69, y: 28), 1.5, Ink.gold)
            // Windows: warm glass behind a cross frame.
            for w in houseWindows {
                let rect = CGRect(x: w.x - 9, y: w.y - 8, width: 18, height: 16)
                fill(cg, rounded(rect.insetBy(dx: -2.5, dy: -2.5), 2), [Ink.woodLight, Ink.woodDark], outline: 0.8, shade: 0.3)
                fill(cg, rect, [UIColor(hex: 0xFFE7A8), Ink.window, UIColor(hex: 0xE59A3A)], outline: 0.6, shade: 0)
                line(cg, CGPoint(x: rect.midX, y: rect.minY), CGPoint(x: rect.midX, y: rect.maxY), Ink.woodDark, 1.6)
                line(cg, CGPoint(x: rect.minX, y: rect.midY), CGPoint(x: rect.maxX, y: rect.midY), Ink.woodDark, 1.6)
            }
            // Chimney behind the roof.
            fill(cg, rounded(CGRect(x: 86, y: 70, width: 16, height: 38), 2), [Ink.stoneLight, Ink.stone, Ink.stoneDark], outline: 0.9)
            for y in stride(from: CGFloat(74), to: 106, by: 7) { line(cg, CGPoint(x: 86, y: y), CGPoint(x: 102, y: y), Ink.stoneDark.withAlphaComponent(0.6), 0.7) }
            fill(cg, rounded(CGRect(x: 84, y: 104, width: 20, height: 5), 1.5), [Ink.stoneLight, Ink.stoneDark], outline: 0.8)
            // Shingled roof.
            let roof = CGMutablePath()
            roof.move(to: CGPoint(x: 6, y: 56)); roof.addLine(to: CGPoint(x: 62, y: 104)); roof.addLine(to: CGPoint(x: 118, y: 56)); roof.closeSubpath()
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: -4), blur: 6, color: UIColor(white: 0, alpha: 0.4).cgColor)
            fill(cg, roof, [Ink.roofLight, Ink.roof, Ink.roofDark], outline: 1)
            cg.restoreGState()
            cg.saveGState()
            cg.addPath(roof)
            cg.clip()
            for row in 0..<7 {
                let y = 58 + CGFloat(row) * 7
                cg.setStrokeColor(Ink.roofDark.withAlphaComponent(0.7).cgColor)
                cg.setLineWidth(1)
                for k in 0..<16 {
                    let x = CGFloat(k) * 8 + (row.isMultiple(of: 2) ? 0 : 4)
                    cg.move(to: CGPoint(x: x, y: y + 6))
                    cg.addQuadCurve(to: CGPoint(x: x + 8, y: y + 6), control: CGPoint(x: x + 4, y: y))
                }
                cg.strokePath()
            }
            cg.restoreGState()
            line(cg, CGPoint(x: 6, y: 56), CGPoint(x: 62, y: 104), Ink.roofDark, 3)
            line(cg, CGPoint(x: 62, y: 104), CGPoint(x: 118, y: 56), Ink.roofDark, 3)
        }
    }

    static func stall() -> SKTexture {
        texture("stall", size: CGSize(width: 104, height: 96)) { cg, _ in
            shadow(cg, center: CGPoint(x: 54, y: 9), width: 96, height: 15, alpha: 0.4)
            for x in [CGFloat(14), 84] { fill(cg, rounded(CGRect(x: x, y: 8, width: 6, height: 60), 2), [Ink.woodLight, Ink.wood, Ink.woodDark], outline: 0.8, vertical: false) }
            fill(cg, rounded(CGRect(x: 8, y: 9, width: 88, height: 24), 3), [Ink.woodLight, Ink.wood, Ink.woodDark], outline: 1)
            for y in [CGFloat(17), 25] { line(cg, CGPoint(x: 10, y: y), CGPoint(x: 94, y: y), Ink.woodDark.withAlphaComponent(0.5), 0.8) }
            // Crates of produce.
            let goods: [(UIColor, UIColor)] = [(UIColor(hex: 0xD9473B), UIColor(hex: 0x8E2418)), (UIColor(hex: 0xF08A2E), UIColor(hex: 0xB0561A)),
                                               (Ink.berryLight, Ink.berry), (Ink.leafLight, Ink.leafDark)]
            var rng = SplitMix(seed: 4)
            for (i, colors) in goods.enumerated() {
                let x = 14 + CGFloat(i) * 20
                fill(cg, rounded(CGRect(x: x, y: 30, width: 18, height: 9), 1.5), [Ink.woodLight, Ink.wood], outline: 0.7, shade: 0.3)
                for _ in 0..<5 {
                    let p = CGPoint(x: x + rng.r(3.5, 14.5), y: 39 + rng.r(0, 4))
                    fill(cg, circle(p, 2.8), [colors.0.lighter(0.25), colors.0, colors.1], outline: 0.5, shade: 0.3)
                }
            }
            // Cloth awning with a scalloped edge.
            let awning = CGMutablePath()
            awning.move(to: CGPoint(x: 4, y: 62)); awning.addLine(to: CGPoint(x: 16, y: 84)); awning.addLine(to: CGPoint(x: 88, y: 84)); awning.addLine(to: CGPoint(x: 100, y: 62))
            for k in 0..<8 {
                let x0 = 100 - CGFloat(k) * 12
                awning.addQuadCurve(to: CGPoint(x: x0 - 12, y: 62), control: CGPoint(x: x0 - 6, y: 55))
            }
            awning.closeSubpath()
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: -4), blur: 6, color: UIColor(white: 0, alpha: 0.35).cgColor)
            fill(cg, awning, [Ink.clothLight, UIColor(hex: 0xDCCFB4)], outline: 1)
            cg.restoreGState()
            cg.saveGState()
            cg.addPath(awning)
            cg.clip()
            for k in 0..<4 {
                let x = 10 + CGFloat(k) * 24
                let stripe = CGMutablePath()
                stripe.addLines(between: [CGPoint(x: x - 4, y: 50), CGPoint(x: x + 8, y: 50), CGPoint(x: x + 10, y: 90), CGPoint(x: x + 2, y: 90)])
                stripe.closeSubpath()
                cg.addPath(stripe)
                cg.setFillColor(Ink.cloth.cgColor)
                cg.fillPath()
            }
            volume(cg, awning.boundingBox, strength: 0.8)
            cg.restoreGState()
        }
    }

    static func board() -> SKTexture {
        texture("board", size: CGSize(width: 68, height: 78)) { cg, _ in
            shadow(cg, center: CGPoint(x: 36, y: 7), width: 56, height: 11, alpha: 0.4)
            for x in [CGFloat(14), 48] { fill(cg, rounded(CGRect(x: x, y: 5, width: 6, height: 44), 2), [Ink.woodLight, Ink.wood, Ink.woodDark], outline: 0.8, vertical: false) }
            fill(cg, rounded(CGRect(x: 6, y: 26, width: 56, height: 38), 3), [Ink.woodLight, Ink.wood, Ink.woodDark], outline: 1)
            for y in [CGFloat(38), 50] { line(cg, CGPoint(x: 8, y: y), CGPoint(x: 60, y: y), Ink.woodDark.withAlphaComponent(0.5), 0.7) }
            let roof = CGMutablePath()
            roof.addLines(between: [CGPoint(x: 2, y: 62), CGPoint(x: 34, y: 76), CGPoint(x: 66, y: 62)])
            roof.closeSubpath()
            fill(cg, roof, [Ink.roofLight, Ink.roof, Ink.roofDark], outline: 0.9)
            for (i, p) in [CGPoint(x: 11, y: 33), CGPoint(x: 28, y: 39), CGPoint(x: 45, y: 31)].enumerated() {
                cg.saveGState()
                cg.translateBy(x: p.x + 7, y: p.y + 9)
                cg.rotate(by: [CGFloat(-0.08), 0.06, -0.03][i])
                cg.setShadow(offset: CGSize(width: 1, height: -1.5), blur: 2, color: UIColor(white: 0, alpha: 0.35).cgColor)
                fill(cg, CGPath(rect: CGRect(x: -7, y: -9, width: 14, height: 18), transform: nil), [.white, UIColor(hex: 0xEFE4CC)], outline: 0.5, shade: 0)
                cg.restoreGState()
                for k in 0..<3 { line(cg, CGPoint(x: p.x + 3, y: p.y + 4 + CGFloat(k) * 3.5), CGPoint(x: p.x + 11, y: p.y + 4 + CGFloat(k) * 3.5), UIColor(hex: 0x8A7A62, alpha: 0.6), 0.6) }
                dot(cg, CGPoint(x: p.x + 7, y: p.y + 16), 1.4, [Ink.cloth, Ink.berry, Ink.gold][i])
            }
        }
    }

    static func workshop() -> SKTexture {
        texture("workshop", size: CGSize(width: 116, height: 100)) { cg, _ in
            shadow(cg, center: CGPoint(x: 60, y: 10), width: 108, height: 17, alpha: 0.42)
            // Stone walls in courses.
            let wall = CGRect(x: 12, y: 8, width: 84, height: 44)
            fill(cg, CGPath(rect: wall, transform: nil), [Ink.stoneLight, Ink.stone, Ink.stoneDark], outline: 1)
            cg.saveGState()
            cg.addPath(CGPath(rect: wall, transform: nil))
            cg.clip()
            var rng = SplitMix(seed: 21)
            for row in 0..<6 {
                let y = wall.minY + CGFloat(row) * 7.5
                line(cg, CGPoint(x: wall.minX, y: y), CGPoint(x: wall.maxX, y: y), Ink.stoneDark.withAlphaComponent(0.7), 0.8)
                var x = wall.minX + (row.isMultiple(of: 2) ? 0 : 6)
                while x < wall.maxX {
                    line(cg, CGPoint(x: x, y: y), CGPoint(x: x, y: y + 7.5), Ink.stoneDark.withAlphaComponent(0.6), 0.8)
                    fill(cg, CGPath(rect: CGRect(x: x + 1, y: y + 1, width: 10, height: 5.5), transform: nil), [UIColor(white: 1, alpha: rng.r(0.0, 0.15))], outline: 0, shade: 0)
                    x += rng.r(10, 14)
                }
            }
            cg.restoreGState()
            // Wide doorway with the saw inside.
            fill(cg, rounded(CGRect(x: 54, y: 8, width: 28, height: 30), 4), [UIColor(hex: 0x3A2818), UIColor(hex: 0x1E140C)], outline: 1, shade: 0)
            fill(cg, circle(CGPoint(x: 68, y: 22), 9), [UIColor(white: 0.92, alpha: 1), Ink.stone, Ink.stoneDark], outline: 0.8)
            for k in 0..<12 {
                let a = CGFloat(k) / 12 * 2 * .pi
                dot(cg, CGPoint(x: 68 + cos(a) * 9, y: 22 + sin(a) * 9), 1.1, Ink.stoneDark)
            }
            dot(cg, CGPoint(x: 68, y: 22), 2, Ink.barkDark)
            // Timber roof.
            let roof = CGMutablePath()
            roof.addLines(between: [CGPoint(x: 4, y: 48), CGPoint(x: 24, y: 80), CGPoint(x: 86, y: 80), CGPoint(x: 104, y: 48)])
            roof.closeSubpath()
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: -4), blur: 6, color: UIColor(white: 0, alpha: 0.4).cgColor)
            fill(cg, roof, [Ink.woodLight, Ink.wood, Ink.woodDark], outline: 1)
            cg.restoreGState()
            cg.saveGState()
            cg.addPath(roof)
            cg.clip()
            for k in 0..<14 { line(cg, CGPoint(x: 4 + CGFloat(k) * 7.5, y: 48), CGPoint(x: 18 + CGFloat(k) * 6, y: 80), Ink.woodDark.withAlphaComponent(0.55), 0.9) }
            cg.restoreGState()
            fill(cg, rounded(CGRect(x: 72, y: 72, width: 12, height: 22), 2), [Ink.stoneLight, Ink.stone, Ink.stoneDark], outline: 0.9)
            // Log pile by the wall.
            for (i, p) in [CGPoint(x: 100, y: 10), CGPoint(x: 108, y: 10), CGPoint(x: 104, y: 17)].enumerated() {
                fill(cg, circle(p, 4.4), [UIColor(hex: 0xE2C08E), UIColor(hex: 0xB98E5C)], outline: 0.7, shade: 0.4)
                dot(cg, p, 1.2 + CGFloat(i % 2) * 0.3, UIColor(hex: 0x9A7246, alpha: 0.7))
            }
        }
    }

    static func garden(stage: Int) -> SKTexture {
        texture("garden-\(stage)", size: CGSize(width: 108, height: 70)) { cg, _ in
            shadow(cg, center: CGPoint(x: 56, y: 10), width: 100, height: 14, alpha: 0.3)
            fill(cg, rounded(CGRect(x: 6, y: 6, width: 96, height: 54), 6), [UIColor(hex: 0x8A6440), UIColor(hex: 0x6A4A2C)], outline: 1, shade: 0.4)
            var rng = SplitMix(seed: UInt64(stage + 40))
            for row in 0..<3 {
                let y = 15 + CGFloat(row) * 15
                fill(cg, rounded(CGRect(x: 11, y: y - 4, width: 86, height: 8), 4), [UIColor(hex: 0x9A7148), UIColor(hex: 0x5E3F22)], outline: 0, shade: 0.5)
                for col in 0..<6 {
                    let p = CGPoint(x: 18 + CGFloat(col) * 14.5, y: y + 2)
                    if stage == 1 {
                        for side in [CGFloat(-1), 1] {
                            let leaf = ellipse(CGRect(x: p.x + side * 2.5 - 2.2, y: p.y, width: 4.4, height: 2.6))
                            fill(cg, leaf, [Ink.leafLight, Ink.leaf], outline: 0.4, shade: 0)
                        }
                    } else {
                        leafBall(cg, p, 4.5 + CGFloat(stage), light: Ink.leafLight, mid: Ink.leaf, dark: Ink.leafDark, seed: row * 6 + col)
                        if stage >= 3 {
                            for _ in 0..<2 { fill(cg, circle(CGPoint(x: p.x + rng.r(-3, 3), y: p.y + rng.r(-2, 3)), 1.8), [Ink.berryLight, Ink.berry], outline: 0.4, shade: 0) }
                        }
                    }
                }
            }
            // Little fence posts at the corners.
            for p in [CGPoint(x: 8, y: 8), CGPoint(x: 100, y: 8), CGPoint(x: 8, y: 56), CGPoint(x: 100, y: 56)] {
                fill(cg, rounded(CGRect(x: p.x - 2.5, y: p.y - 2, width: 5, height: 10), 1.5), [Ink.woodLight, Ink.woodDark], outline: 0.6)
            }
        }
    }

    static let towerTorch = CGPoint(x: 31, y: 96)

    static func tower() -> SKTexture {
        texture("tower", size: CGSize(width: 64, height: 118)) { cg, _ in
            shadow(cg, center: CGPoint(x: 34, y: 8), width: 54, height: 14, alpha: 0.42)
            for x in [CGFloat(12), 46] { fill(cg, rounded(CGRect(x: x, y: 5, width: 6.5, height: 66), 2), [Ink.woodLight, Ink.wood, Ink.woodDark], outline: 0.8, vertical: false) }
            cg.setStrokeColor(Ink.woodDark.cgColor)
            cg.setLineWidth(2.6)
            cg.move(to: CGPoint(x: 16, y: 12)); cg.addLine(to: CGPoint(x: 48, y: 54))
            cg.move(to: CGPoint(x: 48, y: 12)); cg.addLine(to: CGPoint(x: 16, y: 54))
            cg.strokePath()
            // Ladder.
            for x in [CGFloat(27), 37] { line(cg, CGPoint(x: x, y: 5), CGPoint(x: x, y: 66), Ink.woodLight, 1.6) }
            for y in stride(from: CGFloat(10), to: 64, by: 7) { line(cg, CGPoint(x: 27, y: y), CGPoint(x: 37, y: y), Ink.woodLight, 1.4) }
            fill(cg, rounded(CGRect(x: 5, y: 64, width: 54, height: 18), 2.5), [Ink.woodLight, Ink.wood, Ink.woodDark], outline: 1)
            for x in stride(from: CGFloat(9), to: 58, by: 7) { line(cg, CGPoint(x: x, y: 65), CGPoint(x: x, y: 81), Ink.woodDark.withAlphaComponent(0.5), 0.8) }
            let roof = CGMutablePath()
            roof.move(to: CGPoint(x: 0, y: 84)); roof.addLine(to: CGPoint(x: 32, y: 116)); roof.addLine(to: CGPoint(x: 64, y: 84)); roof.closeSubpath()
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 0, height: -3), blur: 5, color: UIColor(white: 0, alpha: 0.4).cgColor)
            fill(cg, roof, [Ink.roofLight, Ink.roof, Ink.roofDark], outline: 1)
            cg.restoreGState()
            for x in [CGFloat(8), 54] { fill(cg, rounded(CGRect(x: x, y: 80, width: 4, height: 8), 1), [Ink.woodDark], outline: 0.5, shade: 0) }
            fill(cg, rounded(CGRect(x: towerTorch.x - 1.5, y: 78, width: 3, height: 14), 1), [Ink.barkLight, Ink.barkDark], outline: 0.5)
        }
    }

    static func torch(frame: Int) -> SKTexture {
        let f = frame % 3
        return texture("torch-\(f)", size: CGSize(width: 16, height: 24)) { cg, _ in
            let h: [CGFloat] = [17, 14, 19]
            let lean: [CGFloat] = [0, -1.5, 1.2]
            for (scale, colors) in [(CGFloat(1), [Ink.fire, Ink.fireDeep]), (0.6, [Ink.fireCore, Ink.fire])] {
                let flame = CGMutablePath()
                let w = 10 * scale
                flame.move(to: CGPoint(x: 8 - w / 2, y: 3))
                flame.addQuadCurve(to: CGPoint(x: 8 + lean[f] * scale, y: 3 + h[f] * scale), control: CGPoint(x: 8 - w / 2 - 1, y: 3 + h[f] * 0.5))
                flame.addQuadCurve(to: CGPoint(x: 8 + w / 2, y: 3), control: CGPoint(x: 8 + w / 2 + 1, y: 3 + h[f] * 0.45))
                flame.closeSubpath()
                fill(cg, flame, colors, outline: 0, shade: 0)
            }
        }
    }

    static func stake() -> SKTexture {
        texture("stake", size: CGSize(width: 16, height: 44)) { cg, _ in
            shadow(cg, center: CGPoint(x: 9, y: 4), width: 14, height: 4, alpha: 0.35)
            let path = CGMutablePath()
            path.addLines(between: [CGPoint(x: 2.5, y: 3), CGPoint(x: 2.5, y: 32), CGPoint(x: 8, y: 42), CGPoint(x: 13.5, y: 32), CGPoint(x: 13.5, y: 3)])
            path.closeSubpath()
            fill(cg, path, [Ink.barkLight, Ink.bark, Ink.barkDark], outline: 0.8, vertical: false)
            let tip = CGMutablePath()
            tip.addLines(between: [CGPoint(x: 2.5, y: 32), CGPoint(x: 8, y: 42), CGPoint(x: 13.5, y: 32)])
            tip.closeSubpath()
            fill(cg, tip, [UIColor(hex: 0xE2C08E), UIColor(hex: 0xB98E5C)], outline: 0.6, shade: 0.4)
            line(cg, CGPoint(x: 2.5, y: 20), CGPoint(x: 13.5, y: 22), UIColor(hex: 0xC9B48A), 2)
        }
    }

    static func bridge(width: CGFloat, height: CGFloat) -> SKTexture {
        texture("bridge-\(Int(width))x\(Int(height))", size: CGSize(width: width + 20, height: height + 14)) { cg, size in
            let deck = CGRect(x: 10, y: 14, width: width, height: height - 8)
            // Shadow cast on the water.
            cg.saveGState()
            cg.setShadow(offset: CGSize(width: 4, height: -8), blur: 8, color: UIColor(hex: 0x0E3550, alpha: 0.55).cgColor)
            cg.setFillColor(Ink.woodDark.cgColor)
            cg.fill(deck)
            cg.restoreGState()
            var rng = SplitMix(seed: UInt64(width))
            let planks = Int(width / 12)
            let pw = width / CGFloat(planks)
            for i in 0..<planks {
                let x = deck.minX + CGFloat(i) * pw
                let tone = rng.r(-0.06, 0.08)
                fill(cg, rounded(CGRect(x: x + 0.6, y: deck.minY + rng.r(-1, 1), width: pw - 1.2, height: deck.height), 1.5),
                     [Ink.woodLight.lighter(max(0, tone)), Ink.wood, Ink.woodDark], outline: 0.7, shade: 0.4, vertical: false)
                for _ in 0..<2 {
                    let gx = x + rng.r(2, pw - 2)
                    line(cg, CGPoint(x: gx, y: deck.minY + 3), CGPoint(x: gx + rng.r(-1, 1), y: deck.maxY - 3), Ink.woodDark.withAlphaComponent(0.35), 0.6)
                }
                dot(cg, CGPoint(x: x + pw / 2, y: deck.minY + 4), 0.9, Ink.barkDark)
                dot(cg, CGPoint(x: x + pw / 2, y: deck.maxY - 4), 0.9, Ink.barkDark)
            }
            // Log rails and corner posts.
            for y in [deck.minY - 2, deck.maxY - 4] {
                fill(cg, rounded(CGRect(x: 4, y: y, width: size.width - 8, height: 6), 3), [Ink.barkLight, Ink.bark, Ink.barkDark], outline: 0.8)
            }
            for x in [CGFloat(4), size.width - 12] {
                for y in [deck.minY - 6, deck.maxY - 8] {
                    fill(cg, rounded(CGRect(x: x, y: y, width: 8, height: 14), 3), [Ink.barkLight, Ink.barkDark], outline: 0.8)
                    fill(cg, ellipse(CGRect(x: x, y: y + 10, width: 8, height: 5)), [UIColor(hex: 0xE2C08E), UIColor(hex: 0xB98E5C)], outline: 0.6, shade: 0)
                }
            }
        }
    }

    static func sign() -> SKTexture {
        texture("sign", size: CGSize(width: 52, height: 62)) { cg, _ in
            shadow(cg, center: CGPoint(x: 27, y: 5), width: 34, height: 9, alpha: 0.4)
            fill(cg, rounded(CGRect(x: 23, y: 3, width: 6, height: 38), 2), [Ink.barkLight, Ink.bark, Ink.barkDark], outline: 0.8, vertical: false)
            fill(cg, rounded(CGRect(x: 6, y: 30, width: 40, height: 25), 3), [Ink.woodLight, Ink.wood, Ink.woodDark], outline: 1)
            for y in [CGFloat(38), 46] { line(cg, CGPoint(x: 8, y: y), CGPoint(x: 44, y: y), Ink.woodDark.withAlphaComponent(0.5), 0.7) }
            // Carved, gilded hammer.
            line(cg, CGPoint(x: 18, y: 36), CGPoint(x: 31, y: 48), UIColor(hex: 0x3A2612), 3.2)
            line(cg, CGPoint(x: 18, y: 36), CGPoint(x: 31, y: 48), Ink.goldLight, 1.6)
            fill(cg, rounded(CGRect(x: 26, y: 45, width: 12, height: 6), 1.5), [Ink.goldLight, Ink.gold, Ink.goldDark], outline: 0.8)
        }
    }

    static func arrow() -> SKTexture {
        texture("arrow", size: CGSize(width: 28, height: 8)) { cg, _ in
            line(cg, CGPoint(x: 4, y: 4), CGPoint(x: 21, y: 4), Ink.woodLight, 1.6)
            for dy in [CGFloat(-2), 2] { line(cg, CGPoint(x: 2, y: 4 + dy), CGPoint(x: 7, y: 4), UIColor(hex: 0xEDE6D6), 1.2) }
            let tip = CGMutablePath()
            tip.addLines(between: [CGPoint(x: 20, y: 1), CGPoint(x: 28, y: 4), CGPoint(x: 20, y: 7)])
            tip.closeSubpath()
            fill(cg, tip, [Ink.stoneLight, Ink.stoneDark], outline: 0.5, shade: 0)
        }
    }

    // MARK: Effects

    static func particle(_ color: UIColor, key: String) -> SKTexture {
        texture("p-\(key)", size: CGSize(width: 12, height: 12)) { cg, _ in
            softDot(cg, CGPoint(x: 6, y: 6), 6, color)
            dot(cg, CGPoint(x: 6, y: 6), 2.6, color)
        }
    }

    static func leafParticle(_ v: Int = 0) -> SKTexture {
        let colors = [Ink.leafLight, UIColor(hex: 0xD9A441), UIColor(hex: 0xC9782E)]
        return texture("leafp-\(v % 3)", size: CGSize(width: 14, height: 10)) { cg, _ in
            let leaf = CGMutablePath()
            leaf.move(to: CGPoint(x: 1, y: 5)); leaf.addQuadCurve(to: CGPoint(x: 13, y: 5), control: CGPoint(x: 7, y: 11))
            leaf.addQuadCurve(to: CGPoint(x: 1, y: 5), control: CGPoint(x: 7, y: -1))
            fill(cg, leaf, [colors[v % 3].lighter(0.15), colors[v % 3].withAlphaComponent(0.95)], outline: 0.4, shade: 0.4)
            line(cg, CGPoint(x: 2, y: 5), CGPoint(x: 12, y: 5), UIColor(white: 0, alpha: 0.2), 0.5)
        }
    }

    static func slash() -> SKTexture {
        texture("slash", size: CGSize(width: 72, height: 72)) { cg, _ in
            for (width, alpha) in [(CGFloat(9), CGFloat(0.25)), (5, 0.6), (2.2, 1.0)] {
                cg.setStrokeColor(UIColor(white: 1, alpha: alpha).cgColor)
                cg.setLineWidth(width)
                cg.addArc(center: CGPoint(x: 36, y: 36), radius: 26, startAngle: -.pi * 0.35, endAngle: .pi * 0.35, clockwise: false)
                cg.strokePath()
            }
        }
    }

    static func ring() -> SKTexture {
        texture("ring", size: CGSize(width: 80, height: 80)) { cg, _ in
            for (width, alpha) in [(CGFloat(10), CGFloat(0.25)), (5, 0.8)] {
                cg.setStrokeColor(UIColor(white: 1, alpha: alpha).cgColor)
                cg.setLineWidth(width)
                cg.strokeEllipse(in: CGRect(x: 8, y: 8, width: 64, height: 64))
            }
        }
    }

    static func mist() -> SKTexture {
        texture("mist", size: CGSize(width: 220, height: 150), scale: 1) { cg, size in
            let c = CGPoint(x: size.width / 2, y: size.width / 2)
            cg.scaleBy(x: 1, y: size.height / size.width)
            cg.drawRadialGradient(grad([UIColor(hex: 0xE6E1FF).withAlphaComponent(0.75), UIColor(hex: 0xB9B0E6).withAlphaComponent(0)]),
                                  startCenter: c, startRadius: 0, endCenter: c, endRadius: size.width / 2, options: [])
        }
    }

    static func smoke() -> SKTexture {
        texture("smoke", size: CGSize(width: 32, height: 32)) { cg, _ in
            softDot(cg, CGPoint(x: 16, y: 16), 16, UIColor(hex: 0xD8D4CC, alpha: 0.75))
        }
    }

    static func dust() -> SKTexture {
        texture("dust", size: CGSize(width: 20, height: 14)) { cg, size in
            cg.translateBy(x: size.width / 2, y: size.height / 2)
            cg.scaleBy(x: 1, y: 0.7)
            softDot(cg, .zero, 10, UIColor(hex: 0xE9DCC0, alpha: 0.8))
        }
    }

    static func cloudShadow(_ v: Int) -> SKTexture {
        texture("cloud-\(v % 2)", size: CGSize(width: 360, height: 220), scale: 0.4) { cg, size in
            var rng = SplitMix(seed: UInt64(v % 2 + 70))
            for _ in 0..<7 {
                let c = CGPoint(x: rng.r(90, size.width - 90), y: rng.r(70, size.height - 70))
                softDot(cg, c, rng.r(60, 95), UIColor(hex: 0x0E1A10, alpha: 0.55))
            }
        }
    }

    static func butterfly(frame: Int, variant v: Int) -> SKTexture {
        let colors = [UIColor(hex: 0xF7D44C), UIColor(hex: 0xFBF8EE), UIColor(hex: 0x7CA7E8), UIColor(hex: 0xF29B5C)]
        return texture("butterfly-\(frame % 2)-\(v % 4)", size: CGSize(width: 16, height: 12)) { cg, _ in
            let open: CGFloat = frame % 2 == 0 ? 1 : 0.35
            let c = colors[v % 4]
            for side in [CGFloat(-1), 1] {
                fill(cg, ellipse(CGRect(x: 8 + side * 4 * open - 3.5 * open, y: 5, width: 7 * open, height: 6)), [c.lighter(0.2), c], outline: 0.4, shade: 0.3)
                fill(cg, ellipse(CGRect(x: 8 + side * 3 * open - 2.5 * open, y: 1.5, width: 5 * open, height: 4.5)), [c, c.withAlphaComponent(0.8)], outline: 0.4, shade: 0.3)
            }
            line(cg, CGPoint(x: 8, y: 2), CGPoint(x: 8, y: 10), UIColor(hex: 0x2A1A14), 1.2)
        }
    }
}

// MARK: - Small helpers

extension SplitMix {
    mutating func r(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * CGFloat(unit()) }
    mutating func chance(_ p: Double) -> Bool { unit() < p }
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
