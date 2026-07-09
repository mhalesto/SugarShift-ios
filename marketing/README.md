# Marketing assets

App Store-ready promotional screenshots for SugarShift, sized for the
iPhone 17 Pro Max display (**1320 × 2868**).

## Final marketing images

| File | Eyebrow | Headline | Game state shown |
|---|---|---|---|
| `marketing-01-splash.png`        | WELCOME             | Sweet Match Magic        | Splash screen |
| `marketing-02-tap-and-match.png` | TAP & MATCH         | Match 3 or More          | Level 1 |
| `marketing-03-frost-and-locks.png` | OBSTACLES         | Crack the Frost          | Level 5 (ice tiles) |
| `marketing-04-shapes.png`        | EVERY LEVEL UNIQUE  | 200 Levels. Fresh Boards. | Level 7 (donut shape) |
| `marketing-05-combos.png`        | BIG COMBOS          | Stack Combos for Mega Score | Level 13 (cross 9×9) |
| `marketing-06-finale.png`        | THE SUGAR CROWN     | Reach Level 200          | Level 200 finale board |

Each image has:
- Diagonal pastel gradient background tuned per-screen (pink/teal/blue/orange/pink/indigo)
- Soft white bubble accents in the corners
- Outlined "tag" pill at the top
- Bold heavy headline (110 pt, 2 lines)
- Medium-weight subtitle (40 pt)
- Centered phone screenshot mockup with rounded corners + drop shadow

## Raw inputs

`raw/` holds the unedited iOS Simulator screenshots that feed the composite:

```
raw/
├── 01-splash.png            (3,426 KB)
├── 02-game-level1.png       (2,228 KB)
├── 03-game-level5-ice.png   (2,217 KB)
├── 04-game-level7-donut.png (2,219 KB)
├── 05-game-level13-cross.png (2,220 KB)
└── 06-game-level200-finale.png (recapture after the 200-level expansion)
```

These were captured on a booted **iPhone 17 Pro Max (iOS 26.3)** simulator using
`xcrun simctl io booted screenshot`. UserDefaults were pre-set per launch via
`xcrun simctl spawn booted defaults write` so each screenshot lands on the
target level + economy state.

## How to regenerate

### 1. Capture fresh raw screenshots from the simulator

```bash
APP="$PWD/build/Build/Products/Debug-iphonesimulator/SugarShift.app"
BUNDLE_ID="com.currenttech.SugarShift"
xcodebuild -project SugarShift.xcodeproj -scheme SugarShift \
    -configuration Debug -sdk iphonesimulator \
    -destination "platform=iOS Simulator,name=iPhone 17 Pro Max" \
    -derivedDataPath build/ build

xcrun simctl boot "iPhone 17 Pro Max" 2>/dev/null
open -a Simulator
xcrun simctl install booted "$APP"

shoot() {
    local out=$1 level=$2 cash=$3 total=$4
    xcrun simctl terminate booted "$BUNDLE_ID" || true
    xcrun simctl spawn booted defaults write "$BUNDLE_ID" ss.currentLevel -int $level
    xcrun simctl spawn booted defaults write "$BUNDLE_ID" ss.cash -int $cash
    xcrun simctl spawn booted defaults write "$BUNDLE_ID" ss.totalScore -int $total
    xcrun simctl launch booted "$BUNDLE_ID"
    sleep 5.5
    xcrun simctl io booted screenshot "marketing/raw/$out"
}
shoot "03-game-level5-ice.png"     5  4820  8450
shoot "04-game-level7-donut.png"   7  5640  14820
shoot "05-game-level13-cross.png"  13 7340  38200
shoot "06-game-level200-finale.png" 200 12540 521300
```

### 2. Composite the marketing images

```bash
swift marketing/render_marketing.swift
```

Edit `specs[]` inside `marketing/render_marketing.swift` to change
tags/headlines/colors. Until `raw/06-game-level200-finale.png` is captured,
the renderer falls back to the old level 100 finale screenshot.

### 3. App Store fullbleed sets (the ones we actually submit)

The submitted screenshots come from `marketing/new/scripts/render_appstore_fullbleed.swift`
(no device mockups — 2.3.10). The fish-hero and daily-board raws are staged
showcase scenes (DEBUG builds only), captured with the marketing-scene launch flag:

```bash
BUNDLE_ID="com.currenttech.SugarShift"

# Pre-set BEFORE the first launch, or the notification permission alert sits
# over the board (it's a SpringBoard alert — it survives app relaunches; only
# answering it or rebooting the simulator clears it).
xcrun simctl spawn booted defaults write "$BUNDLE_ID" ss.pushAuthRequested -bool true

showcase() {  # showcase <output-path> <scene-kind>
    xcrun simctl terminate booted "$BUNDLE_ID" || true
    xcrun simctl launch booted "$BUNDLE_ID" --sugarshift-marketing-scene "$2"
    sleep 4
    xcrun simctl io booted screenshot "$1"
}

# iPhone 17 Pro Max simulator booted:
showcase marketing/new/raw-real-iphone/14-fish-hero.png   fish-hero
showcase marketing/new/raw-real-iphone/15-daily-board.png daily-board

# iPad Pro 13-inch (M4) simulator booted:
showcase marketing/new/raw-ipad/09-fish-hero.png   fish-hero
showcase marketing/new/raw-ipad/10-daily-board.png daily-board

swift marketing/new/scripts/render_appstore_fullbleed.swift
```

## Notes on visuals

The simulator's iOS 26.3 emoji font isn't usable from `SKLabelNode`, so the game
draws each tile as a **glossy candy gem** (radial gradient sphere + white
specular highlight + thin rim) keyed off the original 6-color palette. This
gives every device a consistent look, screenshot-friendly with no font fallback
risk.
