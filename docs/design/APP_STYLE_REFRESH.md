# Sugar Shift app style refresh — 6 September 2026

The user authorized an app-wide creative implementation and will perform runtime
testing. No simulator launch, screenshot capture, archive or upload is part of this
pass. The existing tree was checkpointed and pushed as `fdf0661` before this work.

## Design

The new glossy fruit and world artwork are the visual foundation. Carry the cream,
berry-pink, gold and midnight glass language into home, launch, journey, shop,
settings, results, missions, collection and Tower. Introduce Pip, an original
strawberry guide with short optional dialogue, encouragement and world greetings.
Keep titles and gameplay values as real localized text. No competitor art or copy.

Independent level-card and board transparency controls run from 0–100% transparency.
Default both to 0% to preserve the current appearance. Persist the values. Fade
only decorative backing and tile wells; fruit, blockers, counters, progress and
mechanical markers remain readable. At high transparency, use light text and a
subtle outline/shadow. High Contrast keeps a readable surface and preserves the
chosen setting for when the override is disabled.

Motion uses anticipation, a crisp impact and a short settle: fruit squash and
spring, juicy fragments, collectible trails, prominent original combo lettering,
and world-specific signature moments. Keep authoritative clear footprints,
resolution callbacks, random seeds and input gates intact. Respect Reduce Motion,
haptics and sound, bound particle counts and clean up temporary nodes.

The frequently used DEBUG level tester becomes a safe-area-aware full-height
native sheet with current-level statistics, search by world or level, artwork,
individual level selection, previous/next, and seed replay. Preserve jump semantics:
no life charge and no unlocking by browsing, normal completion still saves.

## Global constraints

- Preserve `buildFooterCard()`, its helpers/assets, and all booster/navigation
  geometry in `GameplayLayout.swift` byte for byte from the checkpoint.
- Continue this checkout; preserve gameplay, purchases, cloud, localization and saves.
- Do not run any simulator. Use source checks, focused native policy checks and one
  generic iOS compile. Device feel, visual acceptance and frame rate remain user QA.
- This refresh stays local for review; the requested pre-work checkpoint is pushed.

## Implementation sequence and ownership

- [x] Checkpoint the entire current snapshot, push, and verify tracking.
- [ ] Main: persisted transparency policy, accessible controls, decorative-only
  rendering updates and meaningful native checks.
- [ ] Animation task: `Effects.swift`, new motion helper, `GameScene+WorldCombo.swift`,
  `GameScene+SwapCascade.swift`, existing fall animation in `GameScene+Modals.swift`
  only after coordination; preserve engine and HUD/footer.
- [ ] Menu task: map and its presentations, ShopCard, EndLevelCard, Tower and missions.
  Use `MenuStyle` helpers; preserve callbacks and the map's existing bottom bar.
- [ ] Tester task: new UIKit explorer and DEBUG tester functions in
  `GameScene+Modals.swift` only. No edits to the settings, generic modal, or fall code.
- [ ] Main: MenuStyle, Pip artwork/dialogue, HomeScene, SplashScene, launch storyboard,
  settings design and remaining gameplay overlays.
- [ ] Review integration, parse source/assets/storyboard, run native policy checks,
  compile generic iOS without signing or running, and document the user QA handoff.

## Shared menu API

`MenuStyle.decorate(_ node: SKShapeNode, size: CGSize, tone: Tone = .cream)` adds
noninteractive themed backing to an existing hit-test shape. Tones: cream, glass,
berry, mint, gold. `MenuStyle.backdrop(in: SKScene, world: WorldThemeDefinition? = nil)`
adds the aspect-filled world backdrop. `MenuStyle.art(_ name: String, size: CGFloat)`
returns optically fitted art. `MenuStyle.enter(_ node: SKNode)` performs a bounded
entrance respecting Reduce Motion. `MenuStyle.ink` and `MenuStyle.muted` are UIColor.

`OrchardGuide.avatar(size: CGFloat)` returns Pip's node. `OrchardGuide.greeting(for:
WorldThemeDefinition)` returns a localized world greeting. `OrchardGuide.bubble(text:
String, width: CGFloat)` returns a 78-point-high speech card. These helpers are
new and are never invoked by the protected footer.
