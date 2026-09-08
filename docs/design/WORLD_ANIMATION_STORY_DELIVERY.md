# World animation and story continuation — 7 September 2026

Build **11**, marketing version **1.0**. Continued the interrupted working tree. No build, simulator, installation, screenshot capture or UI automation was run by this pass. Runtime appearance and frame rate remain for the user's device review.

## 1. Files changed

Existing tracked files changed in this continuation:
- `SugarShift/Engine.swift`, `BoardRenderer.swift`, `Effects.swift`.
- `SugarShift/GameScene.swift`, `GameScene+SwapCascade.swift`, `GameScene+Modals.swift`, `GameScene+ComboSystems.swift`, `GameScene+WorldCombo.swift`, `GameScene+HUD.swift`, `GameScene+LevelEnd.swift`.
- `SugarShift/HomeScene.swift`, `HomeViewController.swift`, `LevelMapViewController.swift`.
- `SugarShift.xcodeproj/project.pbxproj`: all eight Debug/Release target configurations move from build 10 to 11.

Completed or extended the interrupted, already-present untracked files: `GamePresentationEvent.swift`, `WorldEffectAnimator.swift`, `WorldParticleFactory.swift`, `SignatureMotion.swift`, `StoryModel.swift`, `StoryStore.swift`, `CharacterPortrait.swift`, `StorySceneCard.swift`, and `SugarShiftTests/StoryFoundationTests.swift`. Fixed one unmatched parenthesis in the pre-existing `LevelExplorerViewController.swift`.

Existing menu, signature-motion, world-combo-policy and localization work was retained. No localization catalog edits were made by this continuation; Xcode may add extracted strings when the user builds.

## 2. Files created in this continuation

- `SugarShift/WorldAnimationProfile.swift`: presentation material profiles, separated from mechanical events.
- `SugarShift/GameScene+Presentation.swift`: the resolver adapter and cascade timing.
- `SugarShift/BoardSpecialAnimator.swift`: special-pair stages over the real footprint.
- `SugarShift/SpecialPresentationPlan.swift`: footprints and fish destinations captured before clearing.
- `SugarShift/SingleSpecialAnimator.swift`: bounded rocket, fish, UFO, stripe, wrapped and Color Bomb choreography.
- `SugarShift/WorldIdleAnimator.swift`: sampled material breathing, glints, sloshing and living particles.
- `SugarShift/WorldObjectReleaseAnimator.swift`: articulated shell/pearl, honey-spiral and winged scarab releases.
- `SugarShift/BlockerDamageArtwork.swift`: cached persistent damage detail derived from remaining layers.
- `SugarShift/ScorePopupReceipt.swift`: exact, bounded score subtotals.
- `SugarShiftTests/PresentationEventTests.swift`: thirteen mechanical/presentation contract tests.
- This delivery note.

## 3. Animation events

`Engine.clearMatches` returns immutable facts in `ClearResult.presentationEvents`: direct matches, removed pieces, blocker hits, damage transitions, destroyed layers, activated specials and special chains. Direct matches can be distinguished from collateral special clears. Events are ordered by board position.

`Engine.collapseAndRefillResult` adds created-piece events and actual portal transfers with piece IDs. The existing grid-returning API delegates with capture disabled. Presentation consumes no gameplay random numbers. The engine has no world, texture, SpriteKit or timing dependencies.

The scene supplies objective deltas, earned-special insertion, cascade/settle and combo events. `WorldEffectAnimator` selects material reactions from the existing theme. The adapter releases visual node slots without adding damage, score or objectives.

## 4. Particle and effect utilities

`WorldParticleFactory` shares procedural particle textures and pools sprites: 180 live pooled particles and up to 80 retained idle sprites. Short-lived artwork copies, rings, cracks and ribbons have separate node guards and remove themselves. Fruit keeps bounded fragments of its actual artwork. Board particles are cropped to the board rectangle; special-pair light and beams are cropped to the resolved cells.

Reset, Undo and scene exit cancel pending presentation work and recycle particles. Resize recreates presentation layers while retaining the pending mechanical transition. Clear/fall transition callbacks share the board's clock, including its existing slow-motion cues.

## 5. World animations

| World | Implemented material reactions and major presentation |
|---|---|
| Firefly Forest | In-jar wandering lights, glow, rattle, popped lid, circling/escaping fireflies; vine recoil/leaves; flower bloom, butterflies and rising petals; edge fireflies on cascades; existing jar hero and target trails. |
| Ice Age | Moving cold glints, persistent layer cracks, chips, shards and frost mist; released fruit bounce; frost hero/beam and expanding rings. |
| Honey Haven | Glossy sloshing, sticky squash, thinning, stretch and ribbon snap; jar lid, rising honey spiral, bee and drops; spinning donut/sprinkles; honey hero and golden beams. |
| Volcano Valley | Bright cracks, stone chips, embers, smoke and magma-colored burst; existing core anticipation, eruption and impact trails. |
| Coral Reef | Articulated shell opening, pearl release, bubbles, seaweed recoil, floating underwater fragments; existing travelling whale and wave presentation. |
| Cloud Kingdom | Breathing clouds, soft squash/puffs, rainbow sparkles, star collection; balloon hero and rainbow trails. |
| Golden Desert | Sandstone chips/dust and amber fracture; gold jars use amber optics; gold hero, rays and shockwave. |
| Sahara Sands | Crumbling sand, pottery fragments, unfolding scarab wings and curved collection flight with gold/blue accents; sandstorm charge, spiral and debris. |
| Galaxy Getaway | Low-gravity fragments, purple glows/rings, actual entry/exit portal travel; cosmic core/orbit presentation. |
| Sakura Sky | Pink crystal shards, blooming flowers, petals and rising lantern tokens; blossom hero and petal cross/storm. |
| Core world | Tactile fruit clears, jelly/cream deformation, metal/wood fragments and shared special reactions. |

Idle effects sample at most three cells each tick, including rocket thrusters, fish wiggles, UFO underglow and special glints. One portal endpoint can receive a short inward spiral; portal breathing respects Reduce Motion. Existing sparse world ambience stays behind the board. Large hero effects remain transient.

## 6. Blocker hits and destruction

The renderer now names the actual blocker art, including procedural fallbacks, so the animator can target it. A hit animates the old layer before refreshing the surviving cell. Cached transparent overlays preserve cracks, loosened strands and thinning between hits, using actual remaining layers. Soft materials deform instead of receiving rock cracks. Final destruction leaves a brief material copy/debris while the exposed fruit bounces. Existing hit counts, damage rules and layer textures remain authoritative.

## 7. Objective collection

Flights use only actual progress deltas and contributors. Fireflies, petals, sparks, bubbles or small representative tokens travel from board to objective. Up to six representative flights accompany each objective batch. The visual counter catches up at arrival; authoritative tracker values and accessible counts update immediately. Ingredient/key sets are explicitly sorted into arrays at this boundary, fixing the two type errors reported by the user.

## 8. Objective completion

An arriving completed objective receives a pulse, green/gold check, sparkle, light haptic and existing success/tap sound hook. Completion celebrations are deduplicated; checks restore quietly after HUD rebuilds and resize, and clear on Undo when progress is incomplete. Key-opened chests now contribute to the same objective tracker as match-opened chests.

## 9. Special creation

Matching contributors converge on the actual earned-special anchor. The real node forms there before gravity: stripe ribbons, wrapped ribbons/shell bounce, rainbow Color Bomb corona, fish bubbles, rocket/UFO smoke and shared sparkles. The win finale also emits creation and material-clear events.

## 10. Special combos

The existing world hero is supplemented with affected-cell anticipation and clipped mechanical stages: crossed stripes, thick multi-lane blasts, two pulses for wrapped pairs, color-to-stripe/wrapped conversion sprites followed by activations, and board-wave rings for paired Color Bombs. Presentation does not add a second mechanical damage pass to wrapped combinations.

Single-special choreography is capped at twelve visible activations per batch: rocket compression/ignition/launch/smoke, directional stripes, a line-blast cross, wrapped double pulse, curved fish flight with bubbles, UFO hover/links to its footprint, and Color Bomb energy travelling to the selected color. Fish retain the destination selected before the clear; the old renderer incorrectly selected from the already-cleared board. Rendering introduces no new target or damage.

## 11. Cascades, score and praise

Incidental specials activate in a bounded stagger; collateral clears follow. Secondary specials wait for the fish or beam reaching them, with a one-visit bound on cycles. Praise retains the existing rarity policy. Score popups show one to four exact subtotals, including the actual layer and banana-modifier credits; no sample mockup numbers are used. **All brown praise panels have been removed at the user's request.** Praise is now brief, small text in the existing gap above the board, with no backing panel or decorative particles. It is omitted where that gap cannot fit readable text; it never borrows board or HUD space. Chain scoring, audio and other feedback continue.

## 12. Shake, haptics and audio

Shake targets the world/board container, with origin restoration. Major material sequences use existing world timing and hooks. Each material-clear batch emits at most one additional material sound/haptic cue. In-app and system Reduce Motion suppress particles and large travel; existing sound and haptic preferences are respected. The existing sound library is reused, not a new set of bespoke recordings.

## 13. Story architecture

Data-driven chapters, scenes, beats, dialogue, choices, character references, validation and unlock conditions. Trigger types cover before/after levels, world unlock/completion, star milestones and events. Only the opening is authored and connected; additional story triggers are extension points, not dozens of new automatic interruptions.

## 14. Character and avatar architecture

Stable character IDs, roles, portrait IDs, expressions, relationships, unlock state and metadata. The player appearance stores base, skin, hair/style/color, outfit, shoes, accessories, glasses, hat and backpack. Original vector family portraits render current parts; production portrait sets and a full wardrobe UI can be added through the same interface. Existing avatar records decode with defaults for new slots.

## 15. Working opening scene

“The memory box”: Grandpa introduces a glowing map and places needing help. “What is this place?” and “I'll help.” produce different replies, then Mum joins and the routes reconnect. New players see this at Play and continue into level 1 through the existing map/game host. Skip also continues. Existing campaigns enter their usual map. Home has an explicit replay button; replay returns home and cannot replace saved choices.

## 16. Persistence

One additive local JSON record, `ss.story.foundation.v1`, holds the cursor, choices, flags, seen/skipped scenes, unlocked characters and avatar. Unfinished stories resume. Completed/skipped openings do not auto-replay. Progress made elsewhere suppresses an unfinished opening without deleting it. Story/appearance is local-only and does not change campaign, economy or cloud schemas. No saved data was cleared.

## 17. Verification

Source syntax was checked with the installed `swift-format` parser, discarding formatted output; no source was reformatted. All 36 changed/new Swift files passed syntax parsing. Project/widget plist lint and `git diff --check` passed. The two user-reported set/array assignment errors were corrected after reading the engine return types. A pre-existing unmatched parenthesis in the level explorer was corrected.

There are thirteen presentation contract tests and fourteen story foundation tests authored in the working tree. Coverage includes layered damage versus piece clears, rejected hits, deterministic event ordering, portal occupancy/cycles, identical refill/RNG state with capture on/off, exact popup totals, objective contributors, world material selection, captured fish destinations, blast-blocking walls, causal special timing, story branches, resume/skip/replay isolation, milestones and old avatar decoding. **Tests were not executed and no build/type-check was run**, per the user's instruction. Syntax validation cannot establish full compile or runtime correctness.

## 18. Assets still needed

No new raster asset is required for the implemented paths. Existing original artwork and procedural effects are reused. Butterfly, bee and scarab-wing particles now use original procedural shapes. More elaborate face/pose sets and distinct recorded world sounds remain optional future production work.

## 19. Known limitations

Device feel, visual reference fidelity, overdraw, accessibility traversal and frame rate require the user's runtime review. Several detailed reference behaviors use representative procedural effects rather than texture-frame animation or fluid simulation. Long portal routes show at most four transfer stages while preserving the actual final exit. The avatar is a foundation with a few rendered part styles, not a full character creator. Only one story scene is playable. Story saves do not cloud-sync.

The protected booster/navigation footer and `GameplayLayout.swift` were verified unchanged. No gameplay HUD redesign or world reordering was made.

## 20. Device checks

1. Build/run version 1.0 (11). Confirm the two `Set<Pos>` assignment errors are gone.
2. Test an ordinary match, invalid swap, layered blocker hit, final blocker release and the next immediately available move. Confirm no disappearing fruit on non-clearing ice damage.
3. Visit Firefly 111–130, Ice 16–30, Honey 31–45, Volcano 46–60, Coral 61–75, Cloud 76–90, Golden 91–110, Sahara 131–150, Galaxy 151–175 and Sakura 176–200. Exercise the world-specific items actually present in each selected level.
4. Trigger stripe/stripe, stripe/wrapped, wrapped/wrapped, Color Bomb/stripe, Color Bomb/wrapped, Color Bomb/Color Bomb and Mega Smash. Also trigger individual rockets, fish and UFOs. Fish must reach the actual cleared target, secondary specials must follow incoming effects, and rocket beams must stop at walls. Watch highlights, conversion, impacts and gravity occur in order. The board must settle to a readable state.
5. Reach a deep cascade and confirm praise (including `UNREAL!`) has no brown panel and never covers fruit. Check popup subtotals against the actual score change, including a banana-bonus level.
6. Collect ingredients and keys; open a chest with a key; finish an individual objective. Watch the flight, counter and check. Undo and confirm the objective/readout restore.
7. On portal levels, test occupied exits and chained transfers. Only actual transfers should play entry/exit effects, ending on the correct cell.
8. Restart/change level, leave for Map and return, and background/foreground during a large combo. Check for lingering effects, shifted board origin or stuck input.
9. Repeat with Reduce Motion, system Reduce Motion, sound off, haptics off, VoiceOver and Large Text. Confirm the footer remains as before.
10. Use Home → The memory box to replay both branches on an existing save. On a fresh profile, Play should show the opening once, resume its cursor after relaunch, skip successfully and hand off into level 1. Replaying must not change rewards, progression or the canonical choice.
