# Display settings and Explorer sizing — 8 September 2026

Version **1.1.0**, build **12**, across app, widget and test target configurations.

## Implemented

- Explorer world backgrounds no longer contribute their original image dimensions to Auto Layout. Browse cards prefer 110 pt and the selected-world header prefers 170 pt; either can expand for larger accessible text. Art fills and crops within the card. Search placeholder contrast is explicit on its cream field.
- Settings now has independent **Board transparency** and **Level card transparency** sliders, 0–100% in 5% steps. Horizontal drags adjust the slider; vertical gestures scroll Settings. The left scrollbar does not capture the slider's starting knob. VoiceOver can increment/decrement each value.
- Values use separate local preference keys, `ss.boardTransparency` and `ss.levelCardTransparency`. Both default to 0% transparency, retaining the existing appearance. They survive relaunches and progress resets without changing campaign or economy saves.
- Board controls affect the backdrop, tile surfaces and corner fillers. The navy backdrop is filled once so multiple outline passes cannot defeat transparency. Fruit, blockers, effects and board interaction remain independent.
- Level-card controls affect its background, decoration, objective inset and Moves background. Text, objective items, progress and score stay fully opaque. The new background groups have explicit drawing order.
- Live updates change background alpha only. New boards and rebuilt cards also load their saved values. The booster/navigation footer and `GameplayLayout.swift` remain unchanged.

## Files

Changed: `LevelExplorerViewController.swift`, `SettingsCard.swift`, `Persistence.swift`, `BoardRenderer.swift`, `GameScene.swift`, `GameScene+PremiumHUD.swift`, `GameScene+Modals.swift`, `HomeScene.swift`, `LevelMapScene+Modals.swift`, project version settings and the implementation plan.

Created: `SettingsTransparencySlider.swift`, `GameScene+Appearance.swift`, this note.

## Verification and handoff

Source parsing, project plist lint and diff whitespace checks were used. No build, simulator, screenshot capture, UI automation or compiled tests were run. Source checks do not establish runtime appearance or full compilation correctness.

On device:

1. Browse all worlds, search a world, open its level list and return. Cards should stay compact, with their labels visible; repeat with larger text.
2. In gameplay Settings, set Board transparency to 60% and Level card transparency to 20%. Check that they change independently and fruit/numbers remain visible. Drag from both slider endpoints and scroll vertically across the controls.
3. Close Settings, complete a match, change levels and relaunch. Both values should persist. Try 0% and 100%, and VoiceOver adjustment.
4. Confirm version 1.1.0 (12) in Settings and verify the footer remains as before.
