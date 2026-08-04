# SugarShift Improvement Roadmap

## Stakes & Honest Choices Pass (completed)

The previous passes gave the game depth; this one makes that depth mean
something. Every item here removes a way the game was quietly letting the
player off the hook, or a choice that only looked like a choice.

**Sugar Tower — the run is now a real run**

- **Walking out of a floor is a loss.** The mode's entire premise is "one loss
  ends the run", but a floor left mid-play simply waited to be replayed, so
  force-quitting a doomed floor dodged the only rule that mattered.
  `TowerRun.floorInProgress` is set the moment a move is spent on a floor and
  cleared when the floor resolves; `TowerMode.resume()` ends any run that comes
  back with the flag still set, and the tower card reports "Left on Floor N".
  Between floors the flag is clear, which is what keeps "Take a break (run
  saved)" an honest offer. This closes the follow-up the Tower pass left open.
- **Floors have objectives, not just score bars.** Every floor was "reach a
  score", so a twenty-floor climb was twenty rounds of the same fight.
  `TowerMode.floorGoal` now rotates score, clear-the-blockers, collect-a-colour,
  and create-specials across the ladder. It is pure in the values
  `floorConfig` already computed, so a floor can never ask for something its
  own board does not seed.
- **Goals that stop moving.** `clearBlockers` is withheld from floors carrying
  rising syrup or spreading chocolate (the count never settles) and from crate
  floors (three hits each against a shrinking move budget). Floors 1-2 stay a
  plain score climb so the ladder teaches itself.
- **The perk draft is a decision again.** Perks stacked without limit, so
  taking Sugar Legs every time it appeared outran the escalation curve — the
  move budget grew faster than the target did and the tower got *easier* the
  higher you climbed. Stacks now cap at 3 (`TowerPerk.maxStacks`), capped perks
  drop off the draft table, and each card shows its own `×n/3`. The choice is
  now depth versus breadth instead of one correct answer.
- **Drafting with the next floor in view.** The draft card and the tower card
  both name the upcoming floor's objective, so "Bigger Blasts" can be weighed
  against "clear the blockers" instead of picked blind.
- **The score curve no longer outruns the board.** Adding
  `testTowerFloorBalanceReport` (the deterministic bot over floors 1-20, with a
  per-floor win/stars/moves attachment) immediately exposed a pre-existing
  break: **floors 10, 11, 15, 16 and 20 all won 0% of attempts.** The target
  grew a flat 450 a floor while the move budget shrank toward 14, so floor 20
  demanded ~700 points a move — arithmetically impossible, not hard.
  Points-per-move now ramps to a **ceiling** (`min(250, 55 + floor * 14)`)
  rather than growing without bound; because the tower has no last floor, any
  per-floor increase against a floored move budget would eventually break
  again. Escalation above the plateau comes from the mechanic bands and the
  shrinking budget instead. No floor sits at 0% any more.
- **Objectives sized to the real clear rate.** The first retune left objective
  floors finishing with a third of the budget untouched (floor 19 won with 12.5
  of 17 moves spare). Counts are now pegged to the rate the bot actually
  sustains — a little over two target tiles a move, a special roughly every
  second move — so an objective floor is a fight rather than a formality.
- **Perks can't cancel themselves.** Targets and objective counts key off the
  *base* move budget, never the perked one; otherwise drafting Sugar Legs would
  raise the very bar it was bought to clear.
- A fast pure guard (`pointsPerMove <= 420` across floors 1-40) catches this
  class of regression without paying for a simulator run.

**Campaign fairness**

- **`clearBlockers` can no longer fight a rising tide.** The same moving-target
  flaw was live in the campaign generator, and the new invariant caught real
  levels: syrup coats a fresh row every N moves, so a tick landing after the
  player empties the board reopens a goal they had already met.
  `Levels.defaultGoal` now gives those levels their archetype's alternate goal,
  `LevelBalanceAnalyzer.goalLooksFeasible` rejects the pairing (which puts it
  under the existing all-200-levels "no warnings" assertion), and
  `clearBlockerGoalsNeverFightARisingTide` states the invariant directly so a
  future generator change fails loudly.

### Next up

- **Tower difficulty is still spiky rather than smooth.** After the retune the
  simulated curve runs 100% through floor 9, then oscillates — floors 10/15/20
  (all score floors) land at 60/40/50% while the objective floors between them
  sit at 90-100%. That is largely a property of the bot: score floors are where
  greedy play is optimal and objective floors are where it is weakest, so the
  spread overstates the real unevenness. A run ending around floors 15-20 is a
  defensible roguelite shape; smoothing the adjacent-floor swing wants human
  playtests, because pushing the numbers around against a greedy bot risks
  over-fitting to it.
- Score targets plateau by design, so the displayed target dips slightly (4750
  → 4500) where the move budget steps down. Difficulty per move is flat across
  that step, but it is worth confirming players don't read the smaller number
  as an easier floor.
- Tower floors above 20 are unverified by simulation; extend the report once
  the bot handles long-horizon objective routing well enough for the numbers to
  mean something.
- Per-level campaign objective tuning still needs human playtests — the bot is
  greedy and its 0%-win levels are mostly bot blind spots, not unfair design.
- **The campaign now simulates at 85.9% average bot win**, not the ~44% quoted
  in the older Gameplay Pass notes below. The bot gained Flow, Sugar Rush and
  the tiered player Smash along with real players, and it uses them well; only
  levels 38 and 195 still win 0%. Whether the campaign has become genuinely
  too soft or the bot simply got good at it is the question a playtest pass
  should answer before any targets move.

## Precision Smash Command Pass (completed)

- **Choose power instead of wasting it:** when multiple Smash tiers are
  affordable, tapping the meter cycles Mega → Cross → Focused. Each tier spends
  exactly 100/75/50 charge, so a deliberate smaller release preserves the rest.
- **Aim, inspect, confirm:** the first board tap shows the exact canonical Smash
  footprint; a second tap on that target commits it. Objective hits are green,
  urgent hazards orange, ordinary impact purple, and a banked Rush extension
  pink. The confirmation badge states the useful outcome before any move or
  meter is spent.
- **One rules path:** `Engine.playerSmashFootprint` and
  `TacticalSmashEvaluator` now drive live resolution, target previews, and the
  deterministic bot. Holes, chained specials, Bigger Blasts, objectives,
  hazards, and Sugar Rush therefore cannot drift between those surfaces.
- **Honest resource economy:** player Smashes no longer generate fresh Smash
  charge from their own clear or resulting cascade. Remaining meter is visibly
  earned by choosing a cheaper tier, and undo restores the selected tier.
- **Accessible and taught:** meter captions, VoiceOver announcements, the combo
  guide, analytics, tests, and all five starter localizations cover tier choice
  and confirm-before-commit targeting.

## Tactical Flow & Foresight Pass (completed)

- **Objective-aware move intelligence:** `TacticalMoveEvaluator` layers the
  current goal, urgent fuses/chocolate/syrup/vines, predicted special creation,
  and exact special-combo footprints over the Engine's canonical legal moves.
  Live hints and the deterministic bot now choose from the same ranked list.
- **Consequences before commitment:** drag previews label the move's purpose and
  distinguish objective cells (green), hazards (orange), ordinary footprint
  cells (gold), and a charged Sugar Rush cross (pink). Players can see “creates
  wrapped”, “objective +3”, or “defuses hazard” before releasing the swap.
- **Multi-turn Flow mastery:** deliberate objective progress, created specials,
  blocker pressure, and planned power-up combinations build visible Flow up to
  five. Routine clears cool it by one announced step. Purposeful/powerful/
  masterful turns earn bounded score and Smash bonuses; spending Player Smash
  preserves Flow without recursively generating more meter.
- **Aimed Sugar Rush:** reaching Flow 3 or producing a deep cascade banks Sugar
  Rush. The next committed move expands from the tile the player deliberately
  moved, with its real cross shown in the preview, instead of choosing an
  arbitrary sorted match after resolution.
- **State and balance parity:** Flow, best Flow, Rush, turn intent, and objective
  credit are undo-safe and analytics-visible. The campaign simulator applies the
  same Flow policy, tactical ranking, player-selected Rush anchor, score bonus,
  and Smash bonus before reporting win rates.
- **Discoverability:** Flow/Rush status sits above the Smash meter, participates
  in VoiceOver, has a one-time teaching toast and Settings reference, and appears
  in the end-level mastery summary. All new copy is localized into the existing
  German, Spanish, French, Japanese, and Brazilian Portuguese starter set.

## Physical Smash & Agency Pass (completed)

- **Causal combo choreography:** the pure combo footprint still resolves once,
  but each result now carries a deterministic presentation plan. Stripes sweep
  their real lanes, bombs and wraps pulse outward, color specials link to their
  targets, fish visibly travel to objective-ranked cells, and board clears
  ripple from the swap instead of deleting every tile at once.
- **Fruit-weight motion:** cleared fruit compresses before breaking into cropped
  pieces of its own texture. Refill timing scales with travel distance, columns
  land with a small stagger, gravity accelerates into a squash-and-settle, and
  deeper cascades resolve faster without becoming linear or weightless.
- **Earned spectacle:** routine matches use fewer particles and no arbitrary
  screen-wide beam. Confetti is reserved for deep cascades, a 100-charge Mega
  Smash, board clears, and level-scale celebrations; the emitter is lighter and
  protected by the existing cooldown.
- **Layered impact identity:** new pre-rendered procedural accents distinguish
  fruit cracks, stripe whooshes, wrapped thumps, fish flights, color charging,
  landings, Smash-ready, and Smash discharge. Board position drives stereo pan,
  major impacts duck music briefly, and cached intensity-aware haptics avoid a
  fresh generator allocation on every tile hit.
- **Tactical Smash releases:** 50 charge unlocks a targeted 3x3 Focused Smash,
  75 unlocks a row+column Cross Smash, and 100 adds the centre blast for Mega.
  Planned power-up combinations earn more charge than automatic cascades,
  objective hits add credit, player Smash cannot immediately refill itself, and
  the old invisible plain-turn meter decay is gone.
- **Less manufactured assistance:** refill bias was roughly halved and now grows
  only after repeated failures. The random 30% late special became a single,
  visible, deterministic Second Wind tied to fail history and objective progress;
  shared Daily and Tower boards remain untouched.
- **Balance parity:** the deterministic simulation now accumulates intentional vs
  passive Smash charge, releases the same three Smash tiers, and banks/consumes
  Sugar Rush, so campaign reports include the systems available to real players.

## Sugar Tower — Roguelite Gauntlet (completed)

The app's new centrepiece mode: climb floors, draft a run-long perk after
every win, one loss ends the run.

- **Weekly shared towers** (`TowerMode`): floors are seeded from the ISO week
  (same FNV path as the daily challenge), so every player climbs the
  identical tower and best-floor scores are comparable. A run keeps the week
  it started in across the rollover.
- **Escalation curve** (`TowerMode.floorConfig`, pure + unit-tested): boards
  grow 7x7 → 9x9, colours 4 → 6, moves shrink, score targets climb, and each
  floor features a signature mechanic band (ice/jelly/crates/vines/locks,
  chocolate from floor 6, fuses from 12, syrup pressure every 5th floor).
  Boosters are locked (`noBoosters`) and there are no continues.
- **Six draftable perks** (stacking): Sugar Legs (+3 moves/floor), Bomb
  Pocket (starting bomb), Sweet Simplicity (one fewer colour), Bigger Blasts
  (`specialsExplodeBigger`), Head Start (Smash charge), Gold Rush (+50%
  coins). Perks feed straight into the floor config / scene hooks.
- **Flow**: the Tower tab (replacing the release-redundant Tools tab) opens
  the tower card (best floor, run status, perk list, start/continue). Wins
  bypass the campaign end card for a perk-draft interstitial; losses end the
  run with a summary card (floors, coins, best) and instant "New run".
  Floor coins pay out per clear (milestone bonus every 5th); the run
  persists across app relaunches, and "Take a break" leaves mid-run safely.
- **Leaderboard hook**: `GameCenterService.Leaderboard.towerFloor` — create
  it in App Store Connect as a *weekly recurring* leaderboard to activate.
- Localized into the 5 starter languages; VoiceOver labels on all tower UI.
- **Known follow-up**: abandoning a floor mid-play (quit to map before the
  last move) doesn't end the run, so a determined player can dodge a loss.
  Counting abandon-after-N-moves as a loss is the tightening pass.

## Feel, Retention & Reach Pass (completed)

- **Feedback-intensity ladder** (`TurnFeedbackPolicy`): celebration channels
  are now strictly tiered — banner (nice) → screen shake (big/huge) → confetti
  (deep cascades only) — so a lone bomb no longer confettis and a
  plain 3-match only gets a light haptic. The policy is a pure, unit-tested
  function of cascade depth + tiles cleared, and is the first slice of turn
  resolution lifted out of `GameScene+SwapCascade` behind a testable seam.
  Confetti additionally has a 3s cooldown so one deep chain can't stack
  emitters.
- **Daily missions** (`DailyMissions`): three deterministic, date-seeded
  missions per day (clear fruits, create/trigger power-ups, chain reactions,
  win levels, total score) with claim-once coin rewards (doubler applies).
  Progress hooks ride the existing chain/score/win choke points; a strip on
  the level map (above the streak strip) opens the missions card with
  progress bars and claim pills. Storage self-prunes to one day.
- **Starter localizations**: the full string catalog (353 keys + 24 new ones
  from this pass) is machine-translated into **Spanish, Brazilian Portuguese,
  French, German, and Japanese**, merged as `needs_review` so a human pass
  can polish before shipping. Format specifiers validated programmatically.
- **VoiceOver sweep**: labels/traits added to the remaining tappable
  controls — settings action rows, toggles (with live On/Off value), footer
  buttons, shop tabs/tiles/close, end-card thumbs rating, map coins pill +
  gear, bottom-bar tabs, event banner, streak/missions strips, close buttons,
  and level map circles (with stars/locked state).
- **Seed replay** (debug): the Level Tester overlay gained a "Replay seed…"
  entry — paste the `seed` from `level_start` analytics to relaunch that
  exact opening board via a one-shot `debugReplaySeed` override.

## Combo Smash Overhaul (completed)

- **One combo rules engine:** all 21 unordered special pairings classify and
  resolve through the same pure Engine path used by gameplay, previews, hints,
  no-move checks, and the deterministic balance simulator.
- **Distinct pair identities:** bomb + stripe fires three lanes, color + fish
  releases an objective-seeking school, wrapped + bomb makes a super blast,
  and every fish pairing inherits its partner's behavior.
- **Player Smash meter:** matches, blocker hits, and triggered specials build a
  persistent 0-100 meter. The player can release tactical clears at 50/75/100,
  tap the meter, and choose the impact centre; the state is fully undoable.
- **Sugar Rush repaired:** deep cascades now bank Sugar Rush for the next
  committed move instead of resetting the charge before it could activate.
- **Intentional placement and truthful previews:** first-cascade specials favor
  the moved tile, every special-pair drag previews its exact footprint, wrapped
  guidance matches its real 5x5 blast, and fish targets are deterministic.
- **Combo contracts:** each eligible level has an optional configuration-aware
  bonus such as triggering specials, hitting blockers in one chain, or combining
  two power-ups. Completion awards coins plus Smash charge.
- **Real boss phases:** boss boards have a required crown shield, combo-driven
  shield damage, a final-smash window, and periodic Crown Strike vines while the
  primary objective is still active. Simulation models the same phase pressure.
- **Feedback and summaries:** combo audio now rises in pitch/rate with depth,
  special impacts have distinct treatments, routine banners obscure less of the
  board, analytics capture turn/combo outcomes, and win cards summarize the run.
- **Regression coverage:** exhaustive pair classification, deterministic
  footprints, hint/legal-move parity, moved-tile placement, drop-item safety,
  contract feasibility, boss shields, and campaign balance are covered by tests.

## Production Review Roadmap

### Must Fix Before Submission

- Replace the Debug rewarded-ad stub with a real rewarded-ad provider before
  enabling rewarded ads in Release.
- Perform device playtests for levels 1-25, one mid-campaign blocker level,
  one Crown level, and every shop purchase path with sandbox testers.
- Complete App Store Connect and capability setup listed below before archive
  submission.

## Gameplay Pass (completed)

Depth, feel, and retention work shipped after the code-health pass — all behind
a clean `xcodebuild` build + full test suite (41 unit tests + balance report +
UI tests):

Retention & feel:
- **Fail-streak mercy** (`applyFailStreakAssistIfNeeded`): after 3 losses on a
  level the player gets a free starting bomb; at 5+, also +3 moves. Skipped when
  the perk picker is up. Quiet dynamic difficulty so spikes don't churn players.
- **Sugar Crush finale** (`runSugarCrushFinale`): winning with moves left plants
  a special per leftover move and detonates them in one blast before the card.
- **Last-move tension** (`maybeLowMovesTension`): moves badge pulses + escalating
  haptic at ≤3 moves.

Combo depth (the matrix is now complete, and taught):
- **Color bomb + color bomb → full board clear**; **wrapped + wrapped → double
  blast**.
- **Combo-meter payoff:** the meter unlocks progressively stronger player-targeted
  Focused, Cross, and Mega Smashes instead of dropping a random free special.
- **Specials & Combos reference** in the in-game Settings + a one-time
  **adjacency nudge** when two power-ups touch.

Progression & variety:
- **Star milestone track** (`Persistence.claimedStarMilestone`): every 25 total
  stars pays an escalating coin bonus (with catch-up for existing saves) — a
  reason to 3-star.
- **Countdown-fuse hazard** (`BlockerType.countdown`): a tile that ticks down
  each turn and, at 0, costs a move and re-arms — defuse by matching it. Seeded
  sparsely on a few late, non-boss levels.
- **Score Rush** endless mode (`Levels.endlessLevel`): a replayable big-board
  score-attack reached from the map's Rush tab, scoring into the leaderboard.
- **Onboarding** guided move-hints now span levels 1–3, not just level 1.

Balance tooling:
- `BalanceReportTests` runs the deterministic bot across all 200 levels and
  attaches a per-level win-rate / stars / stuck-rate report, plus an aggregate
  regression guard. The pass found the campaign averages ~44% bot win (the bot
  is greedy and underestimates objective levels), and the two hardest late bands
  were eased slightly (`balancedTarget` `basePerMove`). **Per-level objective
  tuning still needs human playtests** — the bot can't play objective levels
  optimally, so its 0%-win levels are mostly a bot limitation, not unfair design.

## Code Health Pass (completed)

The following shipped in the latest maintenance pass and are verified by a clean
`xcodebuild` for the `SugarShift` scheme:

- **Reach**: minimum deployment target lowered from iOS 26.2 to **iOS 16.0**
  (the only availability guard in the codebase is `iOS 16.0`), massively
  widening the installable device base.
- **Localization**: ~300 user-facing strings wrapped in `String(localized:)`
  across all scenes/cards; `Localizable.xcstrings` added; `LevelDifficulty`
  gained a localized `displayName` so the raw value stays a stable identifier.
  The app is now fully internationalized in code — adding a language is just
  translating the catalog in Xcode.
- **Accessibility**: every board tile is now a VoiceOver element with a spoken
  label (fruit + special + blocker), and the in-game HUD readouts (moves,
  goal, lives, score, coins) speak their caption + value.
- **Logging**: `print` diagnostics that leaked into Release now route through an
  `os.Logger` facade (`Log.swift`).
- **Maintainability**: `GameScene.swift` (6,382 lines) and
  `LevelMapScene.swift` (3,962 lines) were split into focused
  `extension`-per-file modules (`GameScene+HUD.swift`, `+Boosters.swift`,
  `+Modals.swift`, `+SwapCascade.swift`, `+LevelEnd.swift`, `+Touch.swift`,
  `+IdleHint.swift`; `LevelMapScene+Vistas.swift`, `+Scrolling.swift`,
  `+LevelCircles.swift`, `+Decorations.swift`, `+HUD.swift`, `+TabIcons.swift`,
  `+Path.swift`, `+Modals.swift`, `+Background.swift`). Each scene's core file
  now holds only state + lifecycle; moves were verbatim so behavior is
  unchanged.

### Remaining engineering follow-ups

- ~~VoiceOver button labels~~ — done in the Feel/Retention/Reach pass.
- ~~Translate `Localizable.xcstrings`~~ — machine-translated into es, pt-BR,
  fr, de, ja as `needs_review`; a human review pass is still recommended
  before featuring those storefronts.
- Deeper refactor: lift turn-resolution out of `GameScene+SwapCascade.swift`
  into a pure, unit-testable controller (the engine is already pure; this is
  the scene-side seam). `TurnFeedbackPolicy` is the first extracted slice;
  scoring/spawn decisions are the next candidates.

## External Tasks (owner-only — cannot be automated in code)

These need Apple/Google web consoles, third-party accounts, or physical
devices. The app code paths are already wired and compile dormant; these steps
light them up. Do them before App Store submission.

1. **Rewarded-ad provider.** `MonetizationServices.swift` ships a Debug-only
   stub; Release keeps rewarded ads disabled. Integrate a real SDK (Google
   AdMob or similar): add the SPM/pod dependency, set the ad-unit IDs, and
   implement the provider behind the existing `Monetization` interface so
   `Monetization.rewardedAdsAvailable` and the continue/double-rewards flows go
   live. Add the `GADApplicationIdentifier` / SKAdNetwork entries to Info.plist.
2. **App Store Connect in-app purchases.** Create consumable products with the
   exact IDs in `Economy.swift` (`CoinProduct`), matching the prices in
   `Products.storekit`. Without these, StoreKit price loading falls back to the
   local config and real purchases will not work.
3. **Game Center leaderboards & achievements.** In App Store Connect, create
   the leaderboards and achievements whose IDs are declared in
   `GameCenterService.Leaderboard` and `GameCenterService.Achievement`. The
   contact-sheet art is in `marketing/GameCenter-*`.
4. **Xcode capabilities** (target → Signing & Capabilities): enable iCloud
   Key-Value storage, Game Center, Push Notifications, In-App Purchase, and
   Sign in with Apple. The entitlement file is already present; the code no-ops
   until each capability is on.
5. **Firebase / Cloud Functions.** Register the app (bundle id
   `com.currenttech.SugarShift`), keep `GoogleService-Info.plist` in the target,
   set the App Store Connect API key env vars in `functions/.env.example`
   (`APP_STORE_CONNECT_ISSUER_ID`, `_KEY_ID`, `_PRIVATE_KEY`), and deploy
   `firestore.rules` + the callable Functions (project must be on Blaze).
6. **Device & sandbox playtests.** On real hardware with sandbox testers: play
   levels 1–25, one mid-campaign blocker level, one Crown level, and exercise
   every shop purchase path. Verify VoiceOver navigates the board and HUD.

## Engine And Level-Design Production Roadmap

### Completed In This Pass

- Deterministic level-attempt seeds now drive opening-board generation, refill
  randomness, chocolate spread, special IDs, and in-level reshuffles. The
  `level_start` analytics event logs the seed and opening move score so a bad
  board can be replayed and debugged.
- Opening-board setup moved into `LevelBoardFactory`, giving gameplay,
  validation, and simulation one shared path for masks, blockers, bombs,
  chocolate, color locks, and ingredient starts.
- `Engine.scoredLegalMoves` exposes the same move ranking used by hints, so
  tools and bots can reason about the board without scraping `GameScene`.
- `LevelSimulationBot` can run deterministic bot attempts and report win rate,
  average score, average stars, moves left, stuck-board rate, and warnings.
- `LevelBalanceAnalyzer` now validates that generated opening boards have at
  least one legal move and that ingredient goals have enough exit columns.
- `LevelDesignReport` now exports cadence, design tags, opening move score,
  estimated win rate, and estimated average stars in addition to mechanics and
  warnings.

### Next Tuning Loop

- Run `LevelDesignReport.simulationRows(levelRange:attemptsPerLevel:)` over
  the full 200-level campaign after playtesting candidate builds. Retune any
  level below roughly 40% simulated win rate, above 98% with high stars, or
  with repeated stuck-board reshuffles.
- ~~Add a small in-game or debug-menu level seed replay entry~~ — done: the
  Level Tester overlay's "Replay seed…" button.
- Split the visual/animation half of `GameScene` from turn resolution in a
  dedicated refactor. The pure simulator now proves the engine direction; the
  remaining work is reducing the scene file without changing gameplay feel.
- Build a designer-facing CSV review workflow around `LevelDesignReport.csv()`
  so cadence tags, mechanics, rewards, and telemetry sit in one spreadsheet.
- Use real production telemetry to tune generated levels 51-200 by chapter:
  relief levels should recover after hard spikes, bosses should be memorable
  but not coin sinks, and ingredient/chocolate levels should stay rare enough
  to feel special.

### Fixed From Production Review

- StoreKit delivery is idempotent. Purchases now credit rewards through one
  ledger-backed path, and transaction updates cannot double-credit consumables.
- Apple-account cloud sync is wired through Firebase Auth, Firestore, and
  callable Functions. Local progress exports to a backend snapshot and imports
  on sign-in/sync so coin balances, lives, boosters, stars, rewards, themes,
  and delivered StoreKit transaction IDs can follow the player to another phone.
- Firestore rules deny client writes and only allow each signed-in player to
  read their own `users/{uid}` tree; server writes go through callable
  Functions.
- Firebase is registered for bundle ID `com.currenttech.SugarShift`, and
  `SugarShift/GoogleService-Info.plist` is present for the app target.
- `recordStoreKitDelivery` now validates coin-pack transactions through the
  App Store Server API before writing the StoreKit ledger, and also keeps a
  global transaction ledger to block cross-account replay of the same
  transaction ID.
- The Settings card now exposes Apple Account sign-in/sync/sign-out rows and
  the scroller drag speed is damped for smoother side-handle movement.
- Shop product prices come from StoreKit when available, with local `.storekit`
  fallback for development.
- Lives, refill countdowns, and refill notifications stay in sync when lives
  are spent or bought.
- Piggy bank and coin-doubler systems have visible shop/HUD states.
- The shop now separates earn, boost, special, and coin-purchase flows into
  tabs, with piggy bank and coin doubler promoted to full-width feature rows.
- Economy purchases clamp to `Economy.livesMax` consistently.

### Production Owner Tasks

- Configure App Store Connect in-app purchases for the product IDs in
  `CoinProduct`, using the same prices as `Products.storekit`.
- Create an App Store Connect API key with In-App Purchase access, then set the
  Functions environment variables in `functions/.env.example` before relying on
  production StoreKit delivery validation.
- Enable the iCloud Key-Value, Game Center, and any future remote-push
  capabilities on the SugarShift target after bundle ID/certificates are final.
- Create the Game Center leaderboards and achievements listed in
  `GameCenterService`.

## Implemented In This Pass

- Difficulty instrumentation: aggregate per-level attempts, wins, fails, stars,
  fail gaps, moves left, and booster use in local analytics.
- Better level goals: score, clear blockers, collect fruit, create specials, and
  detonate bombs are available as level objectives.
- Clearer star targets: the game HUD exposes current objective progress and the
  next star score.
- Smarter end-level feedback: losses explain the remaining score/objective gap.
- Chapter progression: the 200-level campaign is split into named chapters.
- Reward pacing: milestone and daily rewards are claim-once and tracked.
- Daily challenge: the map Daily tab opens a rotating daily level preview.
- Guided onboarding: early teaching levels show a directed move hint quickly.
- Level preview: map taps open a preview with chapter, goal, blockers, stars,
  and suggested booster before launching.
- Accessibility polish: high contrast, large text, and candy label toggles are
  persisted settings and used in gameplay surfaces.
- Automated balance checks: tests validate the 200-level catalog, goal
  feasibility, early difficulty, chapters, and daily challenge selection.

## Implemented In The Second Pass

- New board mechanics after level 20:
  - Jelly tiles require direct matches.
  - Sugar crates take three hits.
  - Color locks show the required fruit.
  - Portals swap candies after gravity.
  - Conveyor rows shift candies after gravity.
- Difficulty tags: levels now expose Normal, Hard, Super Hard, or Crown
  Challenge labels in config and previews.
- Chapter identity: gameplay backgrounds now shift by campaign chapter.
- Reward depth: 3-star clears, daily streaks, active events, and cosmetic theme
  unlocks now have reward hooks.
- Better loss coaching: failed levels show the gap plus a suggested next tactic.
- Event layer: Daily weekday and weekend events rotate deterministic event
  levels and rewards.
- Level design tool: `LevelDesignReport` exports campaign rows and warnings for
  balance review.
- Game-feel pass: objective completion now triggers a dedicated celebration.

## Implemented In The Third Pass

- Wall-clock life regeneration: lives refill on a 25-minute timer that
  survives app close, with `secondsUntilNextLife` / `nextLifeCountdownText`
  for HUD use.
- iCloud Key-Value Store sync: progress mirrors to `NSUbiquitousKeyValueStore`
  with max-wins on stars and OR-wins on reward flags so device swaps don't
  roll back. Calls are no-ops without the iCloud entitlement.
- Piggy bank that fills with play (`Persistence.addToPiggy`,
  `Economy.piggyMax`) — 1 coin per ~100 score, unlocked by purchase or ad.
- 24h coin-doubler day pass (`Persistence.coinDoublerActive`,
  `applyCoinDoubler`) so reward coins double when active.
- Smarter idle hint: ranks candidate swaps by special-activation,
  special-creation, then match length, so the nudge teaches a *good* play.
- Chocolate spreader blocker: spreads to one orthogonal neighbor each turn
  unless the player damaged a chocolate that turn. Auto-seeded on
  multiple-of-9 levels from 80+.
- Boss-level flag and bonus reward: every multiple of 10 plus all `.finale`
  archetype levels, with extra coins/lives/boosters via `Levels.bossReward`.
- Ingredient drop mechanic: `LevelGoal.collectIngredients(count:)` plus a
  fruit-basket overlay; baskets fall with gravity and are collected at the
  bottom playable row. Auto-seeded on multiple-of-11 non-bombrush levels
  from 65+.
- Game Center scaffolding (`GameCenterService`): auth + leaderboard submit +
  achievements. Compiles without the Game Center entitlement; activates when
  the capability is added in Xcode and IDs are created in App Store Connect.
- Push notification scaffolding (`PushService`): local "lives full" reminder
  scheduled when lives are spent, plus a daily-challenge reminder at 10 AM
  local time. No-op when authorization is denied.
- Eight new tests cover chocolate spread, ingredient drop, smart hint,
  life regen, piggy bank, coin doubler, and boss reward generation.

## Next Tuning Loop

- Enable the iCloud capability in Xcode and create the matching container in
  App Store Connect to actually start syncing.
- Add Game Center capability + create leaderboards/achievements with the IDs
  in `GameCenterService.Leaderboard` / `Achievement`.
- Configure StoreKit products in App Store Connect with the IDs in
  `CoinProduct` so the existing scaffolding goes live.
- Enable Sign in with Apple on the Apple Developer app identifier and confirm
  the Firebase Auth Apple provider remains enabled.
- Replace the Debug rewarded-ad stub with the final ad SDK or disable rewarded
  ad entry points in Release until the provider is approved.
- Split `GameScene.swift` (4,757 lines) and `LevelMapScene.swift` (3,806)
  into focused extension files — left intentionally for a dedicated session
  since project-file edits are riskier than feature work.
- Review telemetry after playtests and retune levels with low win rate, low
  average stars, or high fail-score gaps.
- Capture new level 200 marketing screenshots once the final board feel is
  approved.
