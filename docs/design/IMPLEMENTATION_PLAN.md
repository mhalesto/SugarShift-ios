# Sugar Shift redesign implementation plan

## Established baseline

Branch `codex-gameplay-pass`, baseline `9af2022`. Existing user edit: `SugarShift/Localizable.xcstrings`, preserved. Baseline simulator unit tests and campaign/Tower reports pass (`/tmp/sugarshift-redesign.GWqXVF/Baseline.xcresult`). Audit found mature Engine, level factory/simulator, tactical hints, specials, shaped masks, economy/cloud/missions/Tower. No application changes existed at continuation.

## Incremental sequence

- [x] Inspect existing structure and supplied visual/motion references; record visual bible and initial asset manifest.
- [ ] A. Regression fixtures for 7×6 geometry, anchored tiles/blockers, portal transfer, conveyor single tick, blocked input, full-life purchase and safe shuffle. Extend existing Engine and scene adapter; preserve legacy interfaces while introducing typed pieces and board metadata.
- [ ] B. Responsive shared shell (`GameplayLayout`, art cache, HUD renderer): top logo/economy, level objectives/moves/stars, navy board, glass boosters, Map/Play/Shop. All controls invoke existing workflows with state guards.
- [ ] C. Generate original transparent shared fruit/logo/boosters/UI; inspect contact sheets and integrate optimized artwork.
- [ ] D. Generate specials/blockers; extend model rules and deterministic combos with tests. Use reusable damage/footprint logic and consistent art mapping.
- [ ] E. Candy Valley world end to end; data-driven objectives and first 7×6 level; retain the 200-level IDs, legacy modes, saves and reward ledgers.
- [ ] F. Build, run, exercise swaps and boosters, capture/compare real simulator screenshots at three sizes.
- [ ] G/H. Data-driven world catalog, original backgrounds, mechanical skin aliases, progressive world grouping on map. Introduce remaining worlds without separate GameScenes.
- [ ] I. Themed major-combo presentation over real resolved footprints. Volcano crack/rupture/shake/haptics, whale travel/splash and other shared hero treatments. Respect accessibility and budgets.
- [ ] J. Full tests, release compile, simulator regression, asset/memory inspection, final screenshots and accurate delivery report.

## Contracts and preservation

Gameplay model/Engine contain no SpriteKit nodes. `LevelConfig` remains compatible with existing generators, simulation, Tower and daily challenge. New level data supplies additional objectives/pieces/tiles without changing old save keys. World presentation cannot choose gameplay rules. Existing Flow/Smash/Undo remain reachable. Short phones shrink decorative space first. Asset generation uses the built-in image tool, with prompts/output provenance in the manifest. No commits, pushes, backend deployment, store submission or data resets are part of this local implementation.

## Verification commands

### September 6 continuation — current checkpoint

Build number is **10** (all Debug/Release app, widget and test configurations; marketing version unchanged).

Implemented in the working tree, not all device-validated:
- Typed pieces and anchored cell/blocker metadata; rectangular geometry, portal/conveyor corrections, input/life-purchase guards, authored opening levels, objective tracker and additive campaign records.
- Responsive real-data HUD, generated fruit/specials/boosters/core blocker art, Candy Valley background.
- Volcano (46–60) and Coral (61–75) backgrounds and original combo heroes; shared high-value trigger/timing policy, actual-footprint effects, bounded particles, cancellation cleanup and overlapping-shake origin restoration. These are **presentations of existing clears**, not additional gameplay damage.
- Updated reference level card: cream/pink icing, objective inset, ivory Moves card/divider, blue progress, gold star silhouettes and centered score; logo/world-sign collision corrected in layout code.
- Visible DEBUG **Levels** button reuses the existing tester. Previous/next, direct level entry and world shortcuts. No life charge or automatic unlock merely from jumping; completing levels still writes ordinary game progress. Disabled during resolution.

Verification cadence changed by user request: **no simulator retry loop and no build after each small edit**. Small native policy checks are allowed; one phone check follows a meaningful batch. The standalone world-combo checks ran red then green; syntax parsing, project plist validation and `git diff --check` passed. New SpriteKit UI regression tests are written but not run in this batch. Read-only device inspection reports build 10 on the connected iPhone 12 Pro Max; this does not establish that the latest card/effect changes are installed or visually validated.

Remaining: run-time validation of the new card/effects/level picker, eight other world backgrounds and hero treatments, map/end-screen polish, audio provenance/final themed sounds, remaining blocker art, complete staged wrapped gameplay integration and broad engine regressions. Do not mark the baseline as visually matched or the whole redesign complete yet.

The localization file has ongoing local/Xcode changes; preserve it exactly. The existing historical checklist below is a phase-level acceptance checklist, not a claim that partially implemented phases contain no work.

`xcodebuild test -project SugarShift.xcodeproj -scheme SugarShift -destination 'platform=iOS Simulator,id=9A88A55D-E45C-4E0C-A8C5-9C8610775C78' -derivedDataPath /tmp/sugarshift-redesign.GWqXVF/DerivedData -only-testing:SugarShiftTests CODE_SIGNING_ALLOWED=NO SWIFT_EMIT_LOC_STRINGS=NO`

Use narrower suites during phases; run campaign/Tower simulation after engine integration. `git diff --check` and a final diff of the original localization file protect the handoff. All generated/captured artifacts receive stable paths and honest status, including failures.
