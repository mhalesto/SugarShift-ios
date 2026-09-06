import SpriteKit
import Testing
@testable import SugarShift

@Suite(.serialized)
@MainActor
struct GameplaySafetyTests {
    @Test func headerKeepsWorldSignClearOfLogoAndCentersScore() {
        for size in [CGSize(width: 375, height: 667), CGSize(width: 428, height: 926)] {
            let scene = GameScene(size: size)
            scene.buildHeaderCard()
            let logo = scene.childNode(withName: "//brandLogo")!
            let sign = scene.childNode(withName: "//worldSign")!
            #expect(!logo.calculateAccumulatedFrame().intersects(sign.calculateAccumulatedFrame()))
            #expect(scene.totalLabel.horizontalAlignmentMode == .center)
            #expect(scene.totalLabel.position.x == 0)
            #expect(scene.headerCard?.childNode(withName: "objectiveStrip") != nil)
            #expect(scene.premiumStarNodes.count == 3)
        }
    }

    @Test func interruptedShakeRestoresOriginalBoardPosition() {
        let reduceMotion = Persistence.reduceMotion
        defer { Persistence.reduceMotion = reduceMotion }
        Persistence.reduceMotion = false
        let node = SKNode()
        node.position = CGPoint(x: 20, y: 30)
        Effects.shake(node)
        // Simulate the presentation position partway through the first impact.
        node.position = CGPoint(x: 24, y: 27)
        Effects.shake(node)
        Effects.cancelShake(node)
        #expect(node.position == CGPoint(x: 20, y: 30))
    }

    @Test func levelPickerCannotOpenDuringWorldComboOrFalling() {
        let scene = GameScene(size: CGSize(width: 428, height: 926))
        for phase in [GamePhase.worldCombo, .falling, .swapping, .shuffling] {
            scene.gamePhase = phase
            scene.showLevelTesterOverlay()
            #expect(scene.levelTesterOverlay == nil)
        }
    }

    @Test func openLevelPickerBlocksBoardAndBoosters() {
        let scene = GameScene(size: CGSize(width: 428, height: 926))
        scene.levelTesterOverlay = SKNode()
        #expect(!scene.canAcceptBoardInput)
    }

    @Test func debugHeaderExposesLevelPicker() {
        #if DEBUG
        let scene = GameScene(size: CGSize(width: 428, height: 926))
        scene.buildHeaderCard()
        #expect(scene.childNode(withName: "//levelTesterButton") != nil)
        #endif
    }

    @Test func premiumBoosterBadgeIsRetainedByItsNodeTree() {
        let scene = GameScene(size: CGSize(width: 393, height: 852))
        scene.buildFooterCard()
        #expect(scene.movesQuantityBadgeLabel != nil)
        #expect(scene.movesQuantityBadgeLabel?.parent === scene.movesQuantityBadge)
        #expect(scene.boosterCircles.count == 5)
        #expect(scene.gameplayLayout.board.minY > scene.gameplayLayout.boosters.maxY)
    }
    @Test func rectangularBoardIsCenteredInsideItsFrame() {
        let original = Persistence.shapedBoard
        defer { Persistence.shapedBoard = original }
        Persistence.shapedBoard = false
        let scene = GameScene(size: CGSize(width: 393, height: 852))
        let old = Levels.config(for: 2)
        scene.levelConfig = LevelConfig(number: 2, rows: 6, cols: 7, colors: 4,
            moves: old.moves, target: old.target, archetype: old.archetype,
            difficulty: old.difficulty, skin: old.skin, layout: .default,
            goal: old.goal, starThresholds: old.starThresholds,
            bombSpawnRunLength: nil, blurb: "")
        scene.worldNode = SKNode()
        scene.addChild(scene.worldNode)
        scene.layoutBoard()
        let topLeft = scene.point(forRow: 0, col: 0)
        let bottomRight = scene.point(forRow: 5, col: 6)
        let center = CGPoint(x: (topLeft.x + bottomRight.x) / 2,
                             y: (topLeft.y + bottomRight.y) / 2)
        let frame = scene.worldNode.childNode(withName: "boardBackdrop")!
        #expect(abs(center.x - frame.position.x) < 0.1)
        #expect(abs(center.y - frame.position.y) < 0.1)
        #expect(scene.tileSize > 30)
    }

    @Test func buyingLifeAtCapacityCannotSpendCoins() {
        let cash = Persistence.cash
        let lives = Persistence.lives
        defer { Persistence.cash = cash; Persistence.lives = lives }
        let scene = GameScene(size: CGSize(width: 393, height: 852))
        scene.cash = 1_000
        scene.lives = Economy.livesMax
        scene.tryUseLife()
        #expect(scene.cash == 1_000)
        #expect(scene.lives == Economy.livesMax)
    }

    @Test func boosterCannotMutateMovesDuringResolution() {
        let cash = Persistence.cash
        let quantity = Persistence.movesQuantity
        defer { Persistence.cash = cash; Persistence.movesQuantity = quantity }
        let scene = GameScene(size: CGSize(width: 393, height: 852))
        scene.cash = 1_000
        scene.movesLeft = 8
        scene.isResolving = true
        scene.handleBoosterTap("+Moves")
        #expect(scene.movesLeft == 8)
        #expect(scene.cash == 1_000)
        #expect(scene.boosterMode == .none)
    }
}
