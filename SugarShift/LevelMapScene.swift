import SpriteKit
import UIKit

/// Candy Crush–style scrollable level map.
/// - Vertical winding path of campaign level circles (Levels.count)
/// - Decorative "vista" scenes inserted between every 5 levels
/// - Animated water river segments with drifting waves and foam
/// - Wheel-style momentum scrolling (low friction, long roll, elastic bounds)
/// - Top HUD (lives, cash, settings) and bottom Map tab — both fixed
final class LevelMapScene: SKScene {

    // Callbacks owned by the host VC
    var onLevelSelected: ((Int, DailyChallenge?) -> Void)?
    var onSettings:      (() -> Void)?
    var onShop:          (() -> Void)?

    // MARK: - Layout constants

    let levelCount       = Levels.count
    let levelStep:   CGFloat = 200      // base vertical gap between levels
    let vistaHeight: CGFloat = 360      // extra space inserted between groups
    let levelsPerGroup     = 5          // a vista scene appears after each group
    let swingWidth:  CGFloat = 110      // path side-to-side wiggle
    let levelDotRadius: CGFloat = 28
    let lockedDotRadius: CGFloat = 22
    let hudCardHeight: CGFloat = 56
    let bottomBarHeight: CGFloat = 84

    var sceneSafeAreaInsets: UIEdgeInsets {
        if let windowInsets = view?.window?.safeAreaInsets, windowInsets != .zero {
            return windowInsets
        }
        return view?.safeAreaInsets ?? .zero
    }

    var hudTopMargin: CGFloat {
        max(18, sceneSafeAreaInsets.top + 8)
    }

    var bottomChromeMargin: CGFloat {
        max(10, sceneSafeAreaInsets.bottom + 8)
    }

    var hudCenterY: CGFloat {
        size.height / 2 - hudTopMargin - hudCardHeight / 2
    }

    var hudBottomY: CGFloat {
        hudCenterY - hudCardHeight / 2
    }

    var eventBannerCenterY: CGFloat {
        hudBottomY - 48
    }

    var bottomBarCenterY: CGFloat {
        -size.height / 2 + bottomChromeMargin + bottomBarHeight / 2
    }

    var dailyStreakCenterY: CGFloat {
        bottomBarCenterY + bottomBarHeight / 2 + 50
    }

    var missionsStripCenterY: CGFloat {
        dailyStreakCenterY + 46
    }

    // MARK: - Nodes

    var sky: SKShapeNode!
    var stripe: SKNode!         // diagonal pink stripes near the top
    var world: SKNode!          // scrollable container
    var bgFar: SKNode!          // parallax slow
    var bgMid: SKNode!          // parallax medium

    var hud: SKNode!
    var bottomBar: SKNode!
    var livesLabel: SKLabelNode!
    var cashLabel: SKLabelNode!
    var settingsCard: SettingsCard?
    var shopCard: ShopCard?
    var levelPreviewCard: SKNode?
    var collectionCard: SKNode?
    var debugCard: SKNode?
    var storeKitDeliveryObserver: NSObjectProtocol?
    var storeKitProductObserver: NSObjectProtocol?
    var eventBannerNode: SKNode?
    var dailyStreakNode: SKNode?
    var missionsStripNode: SKNode?
    var missionsCard: SKNode?
    var towerCard: SKNode?
    var previewLevel: Int?
    var previewDailyChallenge: DailyChallenge?
    var nextHUDRefreshAt: TimeInterval = 0

    var levelPositions: [Int: CGPoint] = [:]
    var levelNodes: [Int: SKNode] = [:]
    var avatarMarker: SKNode?

    var waterRivers: [(node: SKShapeNode, baseY: CGFloat)] = []
    var waveLayers: [(node: SKNode, speed: CGFloat, startX: CGFloat,
                              widthSpan: CGFloat)] = []

    // MARK: - Scroll state

    var worldYMin: CGFloat = 0     // most negative position (most scrolled to top of map)
    var worldYMax: CGFloat = 0     // most positive position (level 1 visible at bottom)

    var isDragging = false
    var dragLastY: CGFloat = 0
    var dragStartY: CGFloat = 0
    var dragStartedAt: TimeInterval = 0
    var dragLastTime: TimeInterval = 0
    var didDragSignificantly = false
    var velocity: CGFloat = 0           // pts/sec
    var lastFrameTime: TimeInterval = 0

    // Wheel-feel constants. Friction multiplier per second; lower = longer roll.
    let frictionPerSecond: CGFloat = 0.06   // ~6% of velocity left after 1 sec of free roll
    let elasticPullFactor: CGFloat = 0.45   // resistance when overshooting bounds
    let elasticReturnSpeed: CGFloat = 14    // points/sec settling back
    let velocityCutoff: CGFloat = 4         // stop tracking below this

    var hasSetup = false

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        if size.width > 100 { setupOnce() }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if size.width > 100, !hasSetup { setupOnce() }
    }

    func setupOnce() {
        hasSetup = true

        buildSky()

        world = SKNode()
        world.zPosition = 0
        addChild(world)

        bgFar = SKNode(); bgFar.zPosition = 1; world.addChild(bgFar)
        bgMid = SKNode(); bgMid.zPosition = 2; world.addChild(bgMid)

        computeLevelPositions()
        buildGrassBackdrop()
        buildPathCorridor()
        buildBackgroundDecorations()
        buildVistaScenes()
        buildCandyRibbon()
        buildPathDots()
        buildChapterBanners()
        buildLevelNodes()
        buildRewardChestsAndGates()
        buildEventPins()
        placeAvatarMarker()

        computeScrollBounds()
        scrollToLevel(Persistence.currentLevel, animated: false)

        buildHUD()
        buildEventBanners()
        buildBottomBar()
        buildDailyStreakStrip()
        buildMissionsStrip()
        refreshHUD()
        observeStoreKitDeliveries()
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        if let storeKitDeliveryObserver {
            NotificationCenter.default.removeObserver(storeKitDeliveryObserver)
            self.storeKitDeliveryObserver = nil
        }
        if let storeKitProductObserver {
            NotificationCenter.default.removeObserver(storeKitProductObserver)
            self.storeKitProductObserver = nil
        }
    }

}
