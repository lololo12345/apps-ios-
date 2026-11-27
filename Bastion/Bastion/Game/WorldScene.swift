import SpriteKit
import SwiftUI
import UIKit

/// A creature of the Mist walking the map.
@MainActor
final class Enemy {
    let kind: EnemyKind
    let sprite: SKSpriteNode
    let bar: SKSpriteNode
    var health: Double
    var position: CGPoint
    let home: CGPoint
    let raid: Bool
    var attackTimer = 0.0
    var wanderTarget: CGPoint
    var wanderTimer = 0.0
    var frameTimer = 0.0
    var frame = 0
    // Boss charge: telegraph, then a fast dash.
    var dashTimer = 3.5
    var telegraph = 0.0
    var dashLeft = 0.0
    var dashDirection = CGVector.zero
    var summoned = false
    var hitThisDash = false

    init(kind: EnemyKind, at point: CGPoint, raid: Bool) {
        self.kind = kind
        self.raid = raid
        position = point
        home = point
        wanderTarget = point
        health = Double(kind.health)
        sprite = SKSpriteNode(texture: kind == .slime ? Art.slime(frame: 0) : Art.wolf(boss: kind == .boss, frame: 0))
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.12)
        bar = SKSpriteNode(color: UIColor(hex: 0xFF5A6E), size: CGSize(width: kind == .boss ? 80 : 34, height: 5))
        bar.anchorPoint = CGPoint(x: 0, y: 0.5)
        bar.position = CGPoint(x: -(kind == .boss ? 40 : 17), y: sprite.size.height * 0.95)
        bar.alpha = 0
        sprite.addChild(bar)
    }
}

/// Live state of one gatherable thing.
@MainActor
struct NodeLive {
    let node: ResourceNode
    let sprite: SKSpriteNode
    var hitsLeft: Int
    var respawnAt: Double?
}

/// The whole world: map, Brote, nature, creatures, base, raids and the boss.
@MainActor
final class WorldScene: SKScene {
    private let model: GameModel
    private let world = SKNode()
    private let cam = SKCameraNode()
    private let player = SKSpriteNode(texture: Art.brote(frame: 0))
    private let playerGlow = SKSpriteNode(texture: Art.glow(color: UIColor(hex: 0xFFE7A8), radius: 110))
    private let darkness = SKSpriteNode(color: UIColor(hex: 0x0B1230), size: CGSize(width: 4000, height: 4000))
    private let hurtFlash = SKSpriteNode(color: UIColor(hex: 0xFF3B4E), size: CGSize(width: 4000, height: 4000))
    private let campfire = SKSpriteNode(texture: Art.campfire(frame: 0))
    private let campGlow = SKSpriteNode(texture: Art.glow(color: Art.Ink.fire, radius: 230))
    private var playerPos: CGPoint
    private var facing: CGFloat = 1
    private var nodes: [NodeLive] = []
    private var enemies: [Enemy] = []
    private var towerSprites: [SKSpriteNode] = []
    private var stakes: [SKSpriteNode] = []
    private var gardenSprite: SKSpriteNode?
    private var bridgeSprites: [Int: SKNode] = [:]
    private var signs: [Int: SKSpriteNode] = [:]
    private var mist: [SKSpriteNode] = []

    private var lastTime: TimeInterval = 0
    private var time = 0.0
    private var clock: Double
    private var gatherTimer = 0.0
    private var attackTimer = 0.0
    private var heavyTimer = 0.0
    private var walkTimer = 0.0
    private var walkFrame = 0
    private var combo = 0
    private var lastGather = -10.0
    private var fullWarned = -100.0
    private var inBase = true
    private var raidPlan: RaidPlan?
    private var raidSpawned = 0
    private var raidSpawnTimer = 0.0
    private var campfireHealth = 0
    private var forestSpawnTimer = 0.0
    private var slowTimer = 0.0
    private var reportedSeconds = -1
    private var invulnerable = 0.0
    private var rng = SplitMix(seed: UInt64(Date().timeIntervalSince1970))

    private static let t = WorldMap.tileSize
    private var mapSize: CGSize { CGSize(width: Double(WorldMap.columns) * Self.t, height: Double(WorldMap.rows) * Self.t) }

    static func point(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: (x + 0.5) * t, y: (y + 0.5) * t) }
    static func tile(_ p: CGPoint) -> (x: Double, y: Double) { (Double(p.x) / t - 0.5, Double(p.y) / t - 0.5) }

    init(model: GameModel, size: CGSize) {
        self.model = model
        clock = model.state.clock
        playerPos = model.spawn ?? Self.point(Double(WorldMap.campfire.col) + 1.4, Double(WorldMap.campfire.row) - 1.2)
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = UIColor(hex: 0x2E86C8)
        anchorPoint = .zero
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: Building the world

    override func didMove(to view: SKView) {
        guard world.parent == nil else { return }
        addChild(world)
        camera = cam
        addChild(cam)
        buildGround()
        buildRiverDetails()
        buildNodes()
        buildBase()
        buildBridges()
        buildMist()

        player.anchorPoint = CGPoint(x: 0.5, y: 0.1)
        player.position = playerPos
        world.addChild(player)
        playerGlow.blendMode = .add
        playerGlow.zPosition = 960
        playerGlow.alpha = 0
        world.addChild(playerGlow)

        darkness.zPosition = 950
        darkness.alpha = 0
        cam.addChild(darkness)
        hurtFlash.zPosition = 990
        hurtFlash.alpha = 0
        cam.addChild(hurtFlash)
        cam.position = playerPos
        spawnBossIfNeeded()
        updateDarkness()
    }

    private func buildGround() {
        var groups: [String: SKTileGroup] = [:]
        func group(_ key: String, _ texture: @autoclosure () -> SKTexture) -> SKTileGroup {
            if let g = groups[key] { return g }
            let g = SKTileGroup(tileDefinition: SKTileDefinition(texture: texture(), size: CGSize(width: Self.t, height: Self.t)))
            groups[key] = g
            return g
        }
        // Build all groups first: an SKTileSet is fixed once created.
        for zone in Zone.allCases { for v in 0..<4 { _ = group("\(zone)-\(v)", Art.groundTile(zone, variant: v)) } }
        for v in 0..<3 { _ = group("water-\(v)", Art.waterTile(variant: v)); _ = group("dirt-\(v)", Art.dirtTile(variant: v)) }
        _ = group("bank", Art.bankTile())
        let map = SKTileMapNode(tileSet: SKTileSet(tileGroups: Array(groups.values)), columns: WorldMap.columns, rows: WorldMap.rows,
                                tileSize: CGSize(width: Self.t, height: Self.t))
        map.anchorPoint = .zero
        map.zPosition = 0
        for col in 0..<WorldMap.columns {
            for row in 0..<WorldMap.rows {
                let tile = Tile(col: col, row: row)
                let v = (col * 7 + row * 13 + (col * row) % 5) % 4
                let key: String = switch WorldMap.terrain(tile) {
                case .water, .bridge: "water-\(v % 3)"
                case .bank: "bank"
                case .base: "dirt-\(v % 3)"
                case .grass: "\(WorldMap.zone(col: Double(col), row: Double(row)))-\(v)"
                }
                map.setTileGroup(groups[key], forColumn: col, row: row)
            }
        }
        world.addChild(map)
    }

    private func buildRiverDetails() {
        // Twinkles drifting on the water, so the river feels alive.
        for _ in 0..<70 {
            let row = Int(rng.next() % UInt64(WorldMap.rows))
            let river = Int(rng.next() % 2)
            let col = Double(WorldMap.riverCenter(river: river, row: row)) - 0.5 + rng.unit() - 0.5
            let sparkle = SKSpriteNode(texture: Art.particle(.white, key: "white"))
            sparkle.setScale(0.5)
            sparkle.alpha = 0
            sparkle.position = Self.point(col, Double(row) + rng.unit() - 0.5)
            sparkle.zPosition = 1
            world.addChild(sparkle)
            let wait = SKAction.wait(forDuration: rng.unit() * 3)
            let twinkle = SKAction.sequence([.fadeAlpha(to: 0.8, duration: 0.6), .fadeOut(withDuration: 0.9), .wait(forDuration: 1 + rng.unit() * 2)])
            sparkle.run(.sequence([wait, .repeatForever(.group([twinkle, .sequence([.moveBy(x: 0, y: -14, duration: 2.5), .moveBy(x: 0, y: 14, duration: 0)])]))]))
        }
    }

    private func texture(for kind: NodeKind, depleted: Bool, zone: Zone) -> SKTexture {
        switch kind {
        case .tree: depleted ? Art.stump() : Art.tree(dark: zone != .clearing)
        case .goldenTree: depleted ? Art.stump() : Art.goldenTree()
        case .bush: Art.bush(berries: !depleted)
        case .rock: Art.rock(small: depleted)
        case .mushroom: Art.mushroom()
        }
    }

    private func buildNodes() {
        for node in WorldMap.nodes {
            let sprite = SKSpriteNode(texture: texture(for: node.kind, depleted: false, zone: node.zone))
            sprite.anchorPoint = CGPoint(x: 0.5, y: 0.1)
            sprite.position = Self.point(node.x, node.y)
            sprite.zPosition = depth(sprite.position.y)
            if node.kind == .tree || node.kind == .goldenTree {
                // Trees sway gently, each at its own pace.
                let sway = 0.025 + rng.unit() * 0.02
                sprite.run(.repeatForever(.sequence([.rotate(toAngle: sway, duration: 1.6 + rng.unit()), .rotate(toAngle: -sway, duration: 1.6 + rng.unit())])))
            }
            if node.kind == .goldenTree {
                let glow = SKSpriteNode(texture: Art.glow(color: Art.Ink.gold, radius: 70))
                glow.position = CGPoint(x: 0, y: 50)
                glow.zPosition = -1
                glow.blendMode = .add
                glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 1), .fadeAlpha(to: 0.9, duration: 1)])))
                sprite.addChild(glow)
            }
            world.addChild(sprite)
            nodes.append(NodeLive(node: node, sprite: sprite, hitsLeft: node.kind.hits))
        }
    }

    private func depth(_ y: CGFloat) -> CGFloat { 100 + (mapSize.height - y) / 4 }

    private func place(_ texture: SKTexture, at x: Double, _ y: Double) -> SKSpriteNode {
        let sprite = SKSpriteNode(texture: texture)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0.1)
        sprite.position = Self.point(x, y)
        sprite.zPosition = depth(sprite.position.y)
        world.addChild(sprite)
        return sprite
    }

    private var campfirePoint: CGPoint { Self.point(Double(WorldMap.campfire.col), Double(WorldMap.campfire.row)) }

    private func buildBase() {
        let c = (x: Double(WorldMap.campfire.col), y: Double(WorldMap.campfire.row))
        campfire.anchorPoint = CGPoint(x: 0.5, y: 0.15)
        campfire.position = campfirePoint
        campfire.zPosition = depth(campfire.position.y)
        campfire.run(.repeatForever(.animate(with: [Art.campfire(frame: 0), Art.campfire(frame: 1)], timePerFrame: 0.18)))
        world.addChild(campfire)
        campGlow.position = CGPoint(x: campfirePoint.x, y: campfirePoint.y + 20)
        campGlow.blendMode = .add
        campGlow.zPosition = 960
        campGlow.alpha = 0.25
        campGlow.run(.repeatForever(.sequence([.scale(to: 1.06, duration: 0.5), .scale(to: 0.96, duration: 0.6)])))
        world.addChild(campGlow)
        _ = place(Art.house(), at: c.x, c.y + 2.6)
        _ = place(Art.stall(), at: c.x - 3, c.y + 1.2)
        _ = place(Art.board(), at: c.x + 3.1, c.y + 1.4)
        _ = place(Art.workshop(), at: c.x + 2.9, c.y - 2.3)
        refreshBuildings()
    }

    /// Garden, towers and palisade appear and grow with their level.
    private func refreshBuildings() {
        let c = (x: Double(WorldMap.campfire.col), y: Double(WorldMap.campfire.row))
        let garden = model.state.level(.garden)
        gardenSprite?.removeFromParent()
        gardenSprite = garden > 0 ? place(Art.garden(stage: min(garden, 3)), at: c.x - 2.9, c.y - 2.6) : place(Art.sign(), at: c.x - 2.9, c.y - 2.4)
        towerSprites.forEach { $0.removeFromParent() }
        let spots = [(c.x - 4.1, c.y - 0.4), (c.x + 4.3, c.y + 0.2), (c.x, c.y - 4.2), (c.x - 0.3, c.y + 4.4)]
        towerSprites = spots.prefix(model.state.level(.tower)).map { place(Art.tower(), at: $0.0, $0.1) }
        stakes.forEach { $0.removeFromParent() }
        stakes = []
        if model.state.level(.palisade) > 0 {
            for i in 0..<34 {
                let a = Double(i) / 34 * 2 * .pi
                // Gaps east (to the bridge) and west.
                if abs(cos(a)) > 0.93 { continue }
                let sprite = place(Art.stake(), at: c.x + cos(a) * 5.1, c.y + sin(a) * 4.7)
                stakes.append(sprite)
            }
        }
    }

    private func bridgeCenter(_ id: Int) -> CGPoint {
        let site = WorldMap.bridges[id]
        let x = (Double(site.cols.lowerBound) + Double(site.cols.upperBound)) / 2
        let y = (Double(site.rows.lowerBound) + Double(site.rows.upperBound)) / 2
        return Self.point(x, y)
    }

    private func buildBridges() {
        for site in WorldMap.bridges {
            if model.state.bridges.contains(site.id) {
                addBridgeSprite(site.id, animated: false)
            } else {
                let sign = place(Art.sign(), at: Double(site.cols.lowerBound) - 1.6, Double(site.rows.lowerBound) + 0.4)
                sign.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.8), .moveBy(x: 0, y: -4, duration: 0.8)])))
                signs[site.id] = sign
            }
        }
    }

    private func addBridgeSprite(_ id: Int, animated: Bool) {
        let site = WorldMap.bridges[id]
        let width = CGFloat(site.cols.count) * Self.t + 24
        let height = CGFloat(site.rows.count) * Self.t - 6
        let holder = SKNode()
        holder.position = bridgeCenter(id)
        holder.zPosition = 2
        let sprite = SKSpriteNode(texture: Art.bridge(width: width, height: height))
        holder.addChild(sprite)
        world.addChild(holder)
        bridgeSprites[id] = holder
        signs[id]?.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
        if animated {
            // Built plank by plank: a wipe from the near bank.
            let crop = SKCropNode()
            let mask = SKSpriteNode(color: .white, size: CGSize(width: 1, height: height + 20))
            mask.anchorPoint = CGPoint(x: 0, y: 0.5)
            mask.position = CGPoint(x: -sprite.size.width / 2, y: 0)
            crop.maskNode = mask
            sprite.removeFromParent()
            crop.addChild(sprite)
            holder.addChild(crop)
            mask.run(.resize(toWidth: sprite.size.width, duration: 1.6))
            for i in 0..<10 {
                let point = CGPoint(x: holder.position.x - sprite.size.width / 2 + CGFloat(i) * sprite.size.width / 10, y: holder.position.y)
                run(.sequence([.wait(forDuration: Double(i) * 0.16), .run { [weak self] in
                    MainActor.assumeIsolated {
                        self?.burst(at: point, color: Art.Ink.woodLight, count: 5)
                        self?.model.hapticsTick += 1
                    }
                }]))
            }
        }
    }

    private func buildMist() {
        // The Quarry stays in the Mist until the next update.
        for i in 0..<16 {
            let sprite = SKSpriteNode(texture: Art.mist())
            sprite.setScale(2.2 + rng.unit())
            let col = 49 + Double(i % 4) * 4.2 + rng.unit()
            let row = 2 + Double(i / 4) * 7.5 + rng.unit() * 2
            sprite.position = Self.point(col, row)
            sprite.zPosition = 940
            sprite.alpha = 0.85
            sprite.run(.repeatForever(.sequence([.moveBy(x: 40, y: 10, duration: 5 + rng.unit() * 3), .moveBy(x: -40, y: -10, duration: 5 + rng.unit() * 3)])))
            world.addChild(sprite)
            mist.append(sprite)
        }
        let label = SKLabelNode(text: "La Cantera · Próximamente")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 30
        label.fontColor = UIColor(hex: 0x4B4380)
        label.position = Self.point(55, 15)
        label.zPosition = 945
        world.addChild(label)
    }

    // MARK: Frame loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastTime == 0 ? 1.0 / 60 : min(currentTime - lastTime, 1.0 / 20)
        lastTime = currentTime
        time += dt
        handleCommands()
        movePlayer(dt)
        let fighting = updateCombat(dt)
        if !fighting { updateGathering(dt) }
        updateNodes()
        updateEnemies(dt)
        updateDayCycle(dt)
        updateCamera(dt)
        slowTimer += dt
        if slowTimer > 1 {
            slowTimer = 0
            everySecond()
        }
    }

    private func handleCommands() {
        guard !model.commands.isEmpty else { return }
        let commands = model.commands
        model.commands = []
        for command in commands {
            switch command {
            case .buildingsChanged: refreshBuildings()
            case .bridgeBuilt(let id): addBridgeSprite(id, animated: true)
            case .respawn: knockOut()
            }
        }
    }

    private func movePlayer(_ dt: Double) {
        let stick = model.stick
        let length = min(1, hypot(stick.dx, stick.dy))
        if length > 0.08 {
            let speed = Stats.speed(boots: model.state.level(.boots)) * length * (model.state.isFull ? 0.85 : 1)
            let dx = stick.dx / max(length, 0.0001) * speed * dt * length
            let dy = stick.dy / max(length, 0.0001) * speed * dt * length
            let built = model.state.bridges
            // Slide along obstacles: try each axis on its own.
            let nx = Self.tile(CGPoint(x: playerPos.x + dx, y: playerPos.y))
            if WorldMap.isWalkable(col: nx.x, row: nx.y, builtBridges: built) { playerPos.x += dx }
            let ny = Self.tile(CGPoint(x: playerPos.x, y: playerPos.y + dy))
            if WorldMap.isWalkable(col: ny.x, row: ny.y, builtBridges: built) { playerPos.y += dy }
            if abs(stick.dx) > 0.15 { facing = stick.dx > 0 ? 1 : -1 }
            walkTimer += dt
            if walkTimer > 0.16 {
                walkTimer = 0
                walkFrame ^= 1
                player.texture = Art.brote(frame: walkFrame)
            }
            player.position = CGPoint(x: playerPos.x, y: playerPos.y + (walkFrame == 1 ? 2 : 0))
        } else {
            player.position = playerPos
            // Idle: a soft breathing squash.
            player.yScale = 1 + 0.025 * sin(time * 3)
        }
        player.xScale = facing
        player.zPosition = depth(playerPos.y)
        playerGlow.position = CGPoint(x: playerPos.x, y: playerPos.y + 20)

        let tile = Self.tile(playerPos)
        let zone = WorldMap.zone(col: tile.x, row: tile.y)
        if model.zone != zone { model.zone = zone }
        let distBase = hypot(tile.x - Double(WorldMap.campfire.col), tile.y - Double(WorldMap.campfire.row))
        let nowInBase = distBase < WorldMap.baseRadius + 0.4
        if nowInBase && !inBase { enteredBase() }
        inBase = nowInBase
        var newPlace: Place? = nowInBase ? .base : nil
        for site in WorldMap.bridges where !model.state.bridges.contains(site.id) {
            if hypot(playerPos.x - bridgeCenter(site.id).x, playerPos.y - bridgeCenter(site.id).y) < Self.t * 2.6 { newPlace = .bridge(site.id) }
        }
        if model.place != newPlace { withAnimation(.snappy) { model.place = newPlace } }
    }

    private func enteredBase() {
        let moved = model.state.unload()
        guard !moved.isEmpty else { return }
        let text = moved.sorted { $0.key.basePrice < $1.key.basePrice }.map { "\($0.key.emoji)\($0.value)" }.joined(separator: " ")
        model.toast("Guardado en el almacén: \(text)", "shippingbox.fill")
        model.hapticsTick += 1
        model.progressChanged()
    }

    // MARK: Gathering

    private func updateGathering(_ dt: Double) {
        var best: Int?
        var bestDistance = Self.t * 1.15
        for (i, live) in nodes.enumerated() where live.respawnAt == nil {
            if live.node.zone != .clearing && !model.state.bridges.contains(0) { continue }
            let d = hypot(live.sprite.position.x - playerPos.x, live.sprite.position.y - playerPos.y)
            if d < bestDistance { bestDistance = d; best = i }
        }
        guard let index = best else { gatherTimer = 0; return }
        gatherTimer += dt
        guard gatherTimer >= Stats.gatherInterval(axe: model.state.level(.axe)) else { return }
        gatherTimer = 0
        hit(index, strength: 1)
    }

    private func hit(_ index: Int, strength: Int) {
        let kind = nodes[index].node.kind
        let item = kind.item
        if model.state.isFull && item != .goldenLog {
            if time - fullWarned > 6 {
                fullWarned = time
                model.toast("Mochila llena: vuelve a la base", "backpack.fill", tint: Palette.gold)
            }
            return
        }
        let sprite = nodes[index].sprite
        sprite.run(.sequence([.scaleX(to: 1.12, y: 0.92, duration: 0.06), .scale(to: 1, duration: 0.12)]))
        burst(at: CGPoint(x: sprite.position.x, y: sprite.position.y + 30),
              color: kind == .rock ? Art.Ink.stoneLight : kind == .bush ? Art.Ink.berry : kind == .goldenTree ? Art.Ink.gold : Art.Ink.leafLight,
              count: 6, leaf: kind == .tree)
        combo = time - lastGather < 1.8 ? combo + 1 : 1
        lastGather = time
        var amount = strength
        if combo > 0 && combo.isMultiple(of: 8) {
            amount += 1
            floating("¡Racha ×\(combo)!", at: CGPoint(x: playerPos.x, y: playerPos.y + 92), color: Art.Ink.gold, size: 20)
        }
        if combo > model.state.counters.bestCombo { model.state.counters.bestCombo = combo }
        let got = model.state.pick(item, amount)
        if got > 0 { floating("+\(got) \(item.emoji)", at: CGPoint(x: sprite.position.x, y: sprite.position.y + 70), color: .white) }
        model.hapticsTick += 1
        nodes[index].hitsLeft -= strength
        if nodes[index].hitsLeft <= 0 {
            if let bonus = kind.bonus {
                model.state.pick(bonus.item, bonus.count)
                model.state.counters.goldenTrees += 1
                floating("+\(bonus.count) \(bonus.item.emoji) ¡Tronco dorado!", at: CGPoint(x: sprite.position.x, y: sprite.position.y + 100), color: Art.Ink.gold, size: 20)
                burst(at: CGPoint(x: sprite.position.x, y: sprite.position.y + 50), color: Art.Ink.gold, count: 24)
            }
            nodes[index].respawnAt = time + kind.respawn
            sprite.removeAllActions()
            sprite.zRotation = 0
            if kind == .mushroom {
                sprite.run(.fadeOut(withDuration: 0.2))
            } else {
                sprite.texture = texture(for: kind, depleted: true, zone: nodes[index].node.zone)
                sprite.size = sprite.texture?.size() ?? sprite.size
                sprite.children.forEach { $0.isHidden = true }
            }
            model.progressChanged()
        }
    }

    private func updateNodes() {
        for i in nodes.indices {
            guard let at = nodes[i].respawnAt, time >= at else { continue }
            nodes[i].respawnAt = nil
            nodes[i].hitsLeft = nodes[i].node.kind.hits
            let sprite = nodes[i].sprite
            sprite.texture = texture(for: nodes[i].node.kind, depleted: false, zone: nodes[i].node.zone)
            sprite.size = sprite.texture?.size() ?? sprite.size
            sprite.children.forEach { $0.isHidden = false }
            sprite.setScale(0.2)
            sprite.alpha = 1
            sprite.run(.scale(to: 1, duration: 0.35))
        }
    }

    // MARK: Combat

    /// Returns true while the Brote is busy fighting (so it does not chop trees mid-fight).
    private func updateCombat(_ dt: Double) -> Bool {
        attackTimer += dt
        heavyTimer = max(0, heavyTimer - dt)
        invulnerable = max(0, invulnerable - dt)
        let ready = heavyTimer == 0
        if model.heavyReady != ready { model.heavyReady = ready }
        if model.heavyRequested {
            model.heavyRequested = false
            if ready { heavyStrike() }
        }
        let target = enemies.filter { $0.health > 0 }.min { dist($0.position, playerPos) < dist($1.position, playerPos) }
        guard let enemy = target, dist(enemy.position, playerPos) < Combat.attackRange else { return false }
        if attackTimer >= Combat.attackInterval {
            attackTimer = 0
            let hit = Combat.hit(sword: model.state.level(.sword), roll: rng.unit())
            facing = enemy.position.x >= playerPos.x ? 1 : -1
            slashEffect(towards: enemy.position)
            damage(enemy, Double(hit.damage), critical: hit.critical, knock: 16)
        }
        return true
    }

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private func heavyStrike() {
        heavyTimer = Combat.heavyCooldown
        let ring = SKShapeNode(circleOfRadius: 20)
        ring.strokeColor = UIColor.white.withAlphaComponent(0.9)
        ring.lineWidth = 5
        ring.position = CGPoint(x: playerPos.x, y: playerPos.y + 18)
        ring.zPosition = 900
        world.addChild(ring)
        ring.run(.sequence([.group([.scale(to: Combat.heavyRadius / 20, duration: 0.22), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        shake(6)
        model.hapticsTick += 1
        for enemy in enemies where enemy.health > 0 && dist(enemy.position, playerPos) < Combat.heavyRadius {
            damage(enemy, Double(Stats.damage(sword: model.state.level(.sword)) * Combat.heavyMultiplier), critical: true, knock: 60)
        }
        // A heavy blow also chops: two hits on whatever is closest.
        if let index = nodes.indices.filter({ nodes[$0].respawnAt == nil }).min(by: { dist(nodes[$0].sprite.position, playerPos) < dist(nodes[$1].sprite.position, playerPos) }),
           dist(nodes[index].sprite.position, playerPos) < Self.t * 1.3,
           nodes[index].node.zone == .clearing || model.state.bridges.contains(0) {
            hit(index, strength: min(2, nodes[index].hitsLeft))
        }
    }

    private func damage(_ enemy: Enemy, _ amount: Double, critical: Bool, knock: CGFloat) {
        enemy.health -= amount
        floating(critical ? "\(Int(amount))!" : "\(Int(amount))", at: CGPoint(x: enemy.position.x, y: enemy.position.y + enemy.sprite.size.height * 0.9),
                 color: critical ? Art.Ink.gold : .white, size: critical ? 22 : 17)
        enemy.sprite.run(.sequence([.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.03), .colorize(withColorBlendFactor: 0, duration: 0.12)]))
        let away = CGVector(dx: enemy.position.x - playerPos.x, dy: enemy.position.y - playerPos.y)
        let len = max(1, hypot(away.dx, away.dy))
        let pushed = CGPoint(x: enemy.position.x + away.dx / len * knock * (enemy.kind == .boss ? 0.2 : 1),
                             y: enemy.position.y + away.dy / len * knock * (enemy.kind == .boss ? 0.2 : 1))
        let t = Self.tile(pushed)
        if WorldMap.isWalkable(col: t.x, row: t.y, builtBridges: model.state.bridges) { enemy.position = pushed }
        enemy.bar.alpha = 1
        enemy.bar.xScale = max(0, CGFloat(enemy.health / Double(enemy.kind.health)))
        if enemy.kind == .boss { model.boss = (Int(max(0, enemy.health)), enemy.kind.health) }
        if enemy.health <= 0 { kill(enemy) }
    }

    private func kill(_ enemy: Enemy) {
        burst(at: CGPoint(x: enemy.position.x, y: enemy.position.y + 20), color: Art.Ink.mist, count: enemy.kind == .boss ? 40 : 14)
        floating("+\(enemy.kind.coins) 🪙", at: CGPoint(x: enemy.position.x, y: enemy.position.y + 60), color: Art.Ink.gold, size: 18)
        enemy.sprite.run(.sequence([.group([.fadeOut(withDuration: 0.3), .scale(to: 0.3, duration: 0.3)]), .removeFromParent()]))
        model.state.defeated(enemy.kind)
        model.hapticsTick += 1
        if enemy.kind == .boss {
            model.boss = nil
            shake(14)
            for m in mist { m.run(.fadeAlpha(to: 0.55, duration: 3)) }
            model.celebrate("¡Has vencido al Gran Lobo de Humo!", "La Niebla retrocede. La Cantera abrirá en la próxima actualización.", "crown.fill", tint: Palette.gold)
        }
        model.progressChanged()
    }

    private func spawnBossIfNeeded() {
        guard model.state.bridges.contains(0), !model.state.counters.bossesDefeated.contains(.boss),
              !enemies.contains(where: { $0.kind == .boss }) else { return }
        add(Enemy(kind: .boss, at: Self.point(Double(WorldMap.bossLair.col), Double(WorldMap.bossLair.row)), raid: false))
    }

    private func add(_ enemy: Enemy) {
        enemy.sprite.position = enemy.position
        enemy.sprite.setScale(0.2)
        enemy.sprite.run(.scale(to: 1, duration: 0.3))
        world.addChild(enemy.sprite)
        enemies.append(enemy)
    }

    private func updateEnemies(_ dt: Double) {
        let built = model.state.bridges
        for enemy in enemies where enemy.health > 0 {
            var target: CGPoint
            var speed = enemy.kind.speed
            let toPlayer = dist(enemy.position, playerPos)
            if enemy.raid {
                target = toPlayer < 150 ? playerPos : campfirePoint
            } else if toPlayer < enemy.kind.sight && !inBase && dist(enemy.home, playerPos) < Self.t * 10 {
                target = playerPos
            } else {
                enemy.wanderTimer -= dt
                if enemy.wanderTimer <= 0 || dist(enemy.position, enemy.wanderTarget) < 8 {
                    enemy.wanderTimer = 2 + rng.unit() * 3
                    enemy.wanderTarget = CGPoint(x: enemy.home.x + CGFloat(rng.unit() - 0.5) * Self.t * 4, y: enemy.home.y + CGFloat(rng.unit() - 0.5) * Self.t * 4)
                }
                target = enemy.wanderTarget
                speed *= 0.45
            }
            if enemy.kind == .boss { bossMoves(enemy, dt, target: &target, speed: &speed) }
            let reach = enemy.kind.reach
            let distance = dist(enemy.position, target)
            if distance > reach * 0.8 || enemy.dashLeft > 0 {
                var dir = CGVector(dx: target.x - enemy.position.x, dy: target.y - enemy.position.y)
                if enemy.dashLeft > 0 { dir = enemy.dashDirection }
                let len = max(1, hypot(dir.dx, dir.dy))
                let step = CGPoint(x: enemy.position.x + dir.dx / len * speed * dt, y: enemy.position.y + dir.dy / len * speed * dt)
                let t = Self.tile(step)
                if WorldMap.isWalkable(col: t.x, row: t.y, builtBridges: built) { enemy.position = step }
                if abs(dir.dx) > 1 { enemy.sprite.xScale = dir.dx > 0 ? 1 : -1 }
                enemy.frameTimer += dt
                if enemy.frameTimer > 0.2 {
                    enemy.frameTimer = 0
                    enemy.frame ^= 1
                    enemy.sprite.texture = enemy.kind == .slime ? Art.slime(frame: enemy.frame) : Art.wolf(boss: enemy.kind == .boss, frame: enemy.frame)
                }
            }
            enemy.sprite.position = enemy.position
            enemy.sprite.zPosition = depth(enemy.position.y)
            // Attacks.
            enemy.attackTimer -= dt
            if enemy.dashLeft > 0 && !enemy.hitThisDash && toPlayer < reach {
                enemy.hitThisDash = true
                hurt(enemy.kind.damage * 2)
            } else if enemy.attackTimer <= 0 {
                if toPlayer < reach {
                    enemy.attackTimer = enemy.kind.attackInterval
                    lunge(enemy, towards: playerPos)
                    hurt(enemy.kind.damage)
                } else if enemy.raid && dist(enemy.position, campfirePoint) < reach + 20 && campfireHealth > 0 {
                    enemy.attackTimer = enemy.kind.attackInterval
                    lunge(enemy, towards: campfirePoint)
                    campfireHealth = max(0, campfireHealth - enemy.kind.damage)
                    campfire.run(.sequence([.colorize(with: .red, colorBlendFactor: 0.5, duration: 0.05), .colorize(withColorBlendFactor: 0, duration: 0.15)]))
                    if campfireHealth == 0 { campfireOut() }
                }
            }
        }
        enemies.removeAll { $0.health <= 0 }
        // Old Forest keeps a few creatures roaming once it is open.
        if model.state.bridges.contains(0) {
            forestSpawnTimer -= dt
            if forestSpawnTimer <= 0 && enemies.filter({ !$0.raid && $0.kind != .boss }).count < 7 {
                forestSpawnTimer = 12
                let spots = [(27.0, 6.0), (30.0, 22.0), (35.0, 12.0), (38.0, 25.0), (41.0, 4.0), (33.0, 18.0), (26.0, 26.0)]
                let spot = spots[Int(rng.next() % UInt64(spots.count))]
                let point = Self.point(spot.0, spot.1)
                if dist(point, playerPos) > Self.t * 6 {
                    add(Enemy(kind: rng.unit() < 0.55 ? .wolf : .slime, at: point, raid: false))
                }
            }
        }
    }

    private func bossMoves(_ boss: Enemy, _ dt: Double, target: inout CGPoint, speed: inout Double) {
        let near = dist(boss.position, playerPos) < boss.kind.sight
        if near, model.boss == nil { model.boss = (Int(boss.health), boss.kind.health) }
        if !near, model.boss != nil, dist(boss.position, playerPos) > boss.kind.sight * 1.6 { model.boss = nil }
        if boss.dashLeft > 0 {
            boss.dashLeft -= dt
            speed = 430
            return
        }
        if boss.telegraph > 0 {
            boss.telegraph -= dt
            speed = 0
            target = boss.position
            if boss.telegraph <= 0 {
                boss.dashLeft = 0.45
                boss.hitThisDash = false
                boss.dashDirection = CGVector(dx: playerPos.x - boss.position.x, dy: playerPos.y - boss.position.y)
                boss.sprite.colorBlendFactor = 0
            }
            return
        }
        guard near else { return }
        boss.dashTimer -= dt
        if boss.dashTimer <= 0 {
            boss.dashTimer = 4.5
            boss.telegraph = 0.7
            boss.sprite.color = UIColor(hex: 0xFF3B4E)
            boss.sprite.colorBlendFactor = 0.45
            floating("!", at: CGPoint(x: boss.position.x, y: boss.position.y + 110), color: UIColor(hex: 0xFF5A6E), size: 34)
        }
        if !boss.summoned && boss.health < Double(boss.kind.health) / 2 {
            boss.summoned = true
            for dx in [-60.0, 60.0] { add(Enemy(kind: .wolf, at: CGPoint(x: boss.position.x + dx, y: boss.position.y + 40), raid: false)) }
            floating("¡Aúlla!", at: CGPoint(x: boss.position.x, y: boss.position.y + 120), color: .white, size: 24)
        }
    }

    private func lunge(_ enemy: Enemy, towards point: CGPoint) {
        let dx = (point.x - enemy.position.x) > 0 ? 8.0 : -8.0
        enemy.sprite.run(.sequence([.moveBy(x: dx, y: 0, duration: 0.06), .moveBy(x: -dx, y: 0, duration: 0.1)]))
    }

    private func hurt(_ amount: Int) {
        guard invulnerable == 0 else { return }
        invulnerable = 0.25
        model.health = max(0, model.health - amount)
        model.hurtTick += 1
        hurtFlash.removeAllActions()
        hurtFlash.run(.sequence([.fadeAlpha(to: 0.22, duration: 0.05), .fadeOut(withDuration: 0.3)]))
        player.run(.sequence([.colorize(with: .red, colorBlendFactor: 0.6, duration: 0.05), .colorize(withColorBlendFactor: 0, duration: 0.2)]))
        if model.health == 0 { knockOut() }
    }

    private func knockOut() {
        model.state.knockedOut()
        model.health = model.state.maxHealth
        playerPos = Self.point(Double(WorldMap.campfire.col) + 1.4, Double(WorldMap.campfire.row) - 1.2)
        player.position = playerPos
        player.alpha = 0
        player.run(.fadeIn(withDuration: 0.6))
        invulnerable = 2
        model.toast("Te has desmayado: pierdes la mitad de la mochila", "bandage.fill", tint: Palette.bad)
        model.save()
    }

    // MARK: Day, night and raids

    private func updateDayCycle(_ dt: Double) {
        clock += dt
        let night = DayCycle.isNight(clock: clock)
        if night != model.isNight {
            model.isNight = night
            night ? nightFalls() : dawn()
        }
        updateDarkness()
        if let plan = raidPlan, raidSpawned < plan.total {
            raidSpawnTimer -= dt
            if raidSpawnTimer <= 0 {
                raidSpawnTimer = 1.6
                let kind: EnemyKind = raidSpawned < plan.slimes ? .slime : .wolf
                let edges = [(1.5, 6.0), (1.5, 15.0), (1.5, 24.0), (8.0, 1.5), (8.0, 28.0), (15.0, 2.0), (15.0, 27.5)]
                let edge = edges[Int(rng.next() % UInt64(edges.count))]
                add(Enemy(kind: kind, at: Self.point(edge.0, edge.1), raid: true))
                raidSpawned += 1
            }
        }
        if raidPlan != nil {
            let alive = enemies.filter { $0.raid && $0.health > 0 }.count + (raidPlan!.total - raidSpawned)
            let fullHealth = Stats.campfireHealth(palisade: model.state.level(.palisade))
            if model.raid?.enemies != alive || model.raid?.campfire != campfireHealth { model.raid = (alive, campfireHealth, fullHealth) }
            if alive == 0 && raidSpawned == raidPlan!.total { endRaid(early: true) }
        }
        towersFire(dt)
    }

    private func updateDarkness() {
        let dark = DayCycle.darkness(clock: clock)
        darkness.alpha = CGFloat(dark)
        playerGlow.alpha = CGFloat(dark) * 0.9
        campGlow.alpha = 0.25 + CGFloat(dark) * 1.1
        let seconds = Int(DayCycle.secondsToChange(clock: clock))
        if seconds != reportedSeconds {
            reportedSeconds = seconds
            model.secondsToChange = seconds
        }
    }

    private func nightFalls() {
        guard model.state.tutorialDone else { return }
        let plan = RaidPlan(night: model.state.night + 1)
        raidPlan = plan
        raidSpawned = 0
        raidSpawnTimer = 2
        campfireHealth = Stats.campfireHealth(palisade: model.state.level(.palisade))
        campfire.alpha = 1
        model.toast("¡Anochece! \(plan.total) criaturas vienen a por la hoguera", "moon.stars.fill", tint: Palette.secondary)
        model.hapticsTick += 1
        // Fireflies around the base.
        for _ in 0..<24 {
            let fly = SKSpriteNode(texture: Art.glow(color: UIColor(hex: 0xEFFF8A), radius: 6))
            fly.blendMode = .add
            fly.zPosition = 970
            fly.position = CGPoint(x: campfirePoint.x + CGFloat(rng.unit() - 0.5) * 900, y: campfirePoint.y + CGFloat(rng.unit() - 0.5) * 600)
            world.addChild(fly)
            fly.run(.sequence([.repeat(.sequence([.moveBy(x: CGFloat(rng.unit() - 0.5) * 80, y: CGFloat(rng.unit() - 0.5) * 60, duration: 2),
                                                  .fadeAlpha(to: 0.3, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)]), count: 20),
                               .fadeOut(withDuration: 1), .removeFromParent()]))
        }
    }

    private func dawn() {
        if raidPlan != nil { endRaid(early: false) }
    }

    private func endRaid(early: Bool) {
        guard raidPlan != nil else { return }
        let standing = campfireHealth > 0
        for enemy in enemies where enemy.raid {
            enemy.health = 0
            burst(at: enemy.position, color: Art.Ink.mist, count: 8)
            enemy.sprite.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))
        }
        enemies.removeAll { $0.raid }
        raidPlan = nil
        model.raid = nil
        campfire.alpha = 1
        let reward = model.state.nightEnded(campfireStanding: standing)
        if standing {
            model.celebrate("¡La hoguera resiste!", "Noche \(model.state.night) superada · +\(reward) 🪙", "sun.max.fill", tint: Palette.gold)
        } else {
            model.celebrate("La Niebla se llevó parte del almacén", "Mejora la empalizada y construye torres para la próxima noche.", "flame", tint: Palette.bad)
        }
        if early, DayCycle.isNight(clock: clock) {
            // The raid is over: skip to dawn.
            clock += DayCycle.secondsToChange(clock: clock)
        }
        model.progressChanged()
    }

    private func campfireOut() {
        campfire.run(.fadeAlpha(to: 0.35, duration: 0.4))
        shake(8)
        model.toast("¡La hoguera se apaga!", "flame", tint: Palette.bad)
        endRaid(early: true)
    }

    private func towersFire(_ dt: Double) {
        guard !towerSprites.isEmpty, raidPlan != nil || enemies.contains(where: { dist($0.position, campfirePoint) < 300 }) else { return }
        let damage = Double(Stats.towerDamage(level: model.state.level(.tower)))
        for (i, tower) in towerSprites.enumerated() {
            let key = "towerCooldown\(i)"
            if tower.action(forKey: key) != nil { continue }
            let origin = CGPoint(x: tower.position.x, y: tower.position.y + 70)
            guard let enemy = enemies.filter({ $0.health > 0 && dist($0.position, tower.position) < 270 })
                .min(by: { dist($0.position, tower.position) < dist($1.position, tower.position) }) else { continue }
            tower.run(.wait(forDuration: 1.0), withKey: key)
            let arrow = SKSpriteNode(texture: Art.arrow())
            arrow.position = origin
            arrow.zPosition = 905
            let target = CGPoint(x: enemy.position.x, y: enemy.position.y + 16)
            arrow.zRotation = atan2(target.y - origin.y, target.x - origin.x)
            world.addChild(arrow)
            arrow.run(.sequence([.move(to: target, duration: 0.25), .run { [weak self, weak enemy] in
                MainActor.assumeIsolated {
                    guard let self, let enemy, enemy.health > 0 else { return }
                    self.damage(enemy, damage, critical: false, knock: 6)
                }
            }, .removeFromParent()]))
        }
    }

    // MARK: Once a second

    private func everySecond() {
        model.state.clock = clock
        let finished = model.state.collectJobs()
        for job in finished {
            model.toast("\(job.count) \(job.item.name.lowercased()) listas en el almacén", Recipe.making(job.item)?.station.symbol ?? "checkmark")
        }
        if !finished.isEmpty { model.progressChanged() }
        model.state.settleGarden()
        spawnBossIfNeeded()
    }

    // MARK: Camera and effects

    private func updateCamera(_ dt: Double) {
        guard let view else { return }
        let half = CGSize(width: view.bounds.width / 2, height: view.bounds.height / 2)
        let target = CGPoint(x: min(max(playerPos.x, half.width), mapSize.width - half.width),
                             y: min(max(playerPos.y + 20, half.height), mapSize.height - half.height))
        let k = CGFloat(min(1, dt * 7))
        cam.position = CGPoint(x: cam.position.x + (target.x - cam.position.x) * k, y: cam.position.y + (target.y - cam.position.y) * k)
    }

    private func shake(_ amount: CGFloat) {
        let moves = (0..<6).map { i -> SKAction in
            let a = amount * CGFloat(6 - i) / 6
            return .moveBy(x: i.isMultiple(of: 2) ? a : -a, y: i.isMultiple(of: 3) ? a / 2 : -a / 2, duration: 0.03)
        }
        world.run(.sequence(moves + [.move(to: .zero, duration: 0.02)]))
    }

    private func burst(at point: CGPoint, color: UIColor, count: Int, leaf: Bool = false) {
        for _ in 0..<count {
            let p = SKSpriteNode(texture: leaf && rng.unit() < 0.6 ? Art.leafParticle() : Art.particle(color, key: color.description))
            p.position = point
            p.zPosition = 910
            p.setScale(0.5 + CGFloat(rng.unit()) * 0.5)
            world.addChild(p)
            let angle = rng.unit() * 2 * .pi
            let distance = 20 + rng.unit() * 40
            p.run(.sequence([
                .group([.moveBy(x: CGFloat(cos(angle) * distance), y: CGFloat(sin(angle) * distance) + 12, duration: 0.45),
                        .rotate(byAngle: CGFloat(rng.unit() * 4 - 2), duration: 0.45),
                        .sequence([.wait(forDuration: 0.2), .fadeOut(withDuration: 0.25)])]),
                .removeFromParent(),
            ]))
        }
    }

    private func floating(_ text: String, at point: CGPoint, color: UIColor, size: CGFloat = 16) {
        let label = SKLabelNode(text: text)
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = size
        label.fontColor = color
        label.position = point
        label.zPosition = 920
        let shadow = SKLabelNode(text: text)
        shadow.fontName = label.fontName
        shadow.fontSize = size
        shadow.fontColor = UIColor(white: 0, alpha: 0.45)
        shadow.position = CGPoint(x: 1.5, y: -1.5)
        shadow.zPosition = -1
        label.addChild(shadow)
        world.addChild(label)
        label.setScale(0.6)
        label.run(.sequence([.group([.scale(to: 1, duration: 0.15), .moveBy(x: 0, y: 34, duration: 0.8),
                                     .sequence([.wait(forDuration: 0.5), .fadeOut(withDuration: 0.3)])]), .removeFromParent()]))
    }

    private func slashEffect(towards point: CGPoint) {
        let slash = SKSpriteNode(texture: Art.slash())
        slash.position = CGPoint(x: playerPos.x + (point.x > playerPos.x ? 26 : -26), y: playerPos.y + 26)
        slash.zRotation = atan2(point.y - playerPos.y, point.x - playerPos.x)
        slash.zPosition = 915
        slash.alpha = 0.9
        world.addChild(slash)
        slash.run(.sequence([.group([.rotate(byAngle: 0.6, duration: 0.14), .fadeOut(withDuration: 0.16)]), .removeFromParent()]))
    }
}
