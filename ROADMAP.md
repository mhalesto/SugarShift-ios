# SugarShift Improvement Roadmap

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
- **Combo-meter payoff** (`grantComboFreeSpecialIfCharged`): a max-tier cascade
  chain plants a free special.
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

- VoiceOver button labels: tiles + HUD are covered; a sweep to add
  `accessibilityLabel` to the remaining tappable buttons across the card/scene
  extensions would complete the screen-reader pass.
- Translate `Localizable.xcstrings` into target languages (the extraction is
  done; only the translations remain).
- Deeper refactor: lift turn-resolution out of `GameScene+SwapCascade.swift`
  into a pure, unit-testable controller (the engine is already pure; this is
  the scene-side seam).

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
- Add a small in-game or debug-menu level seed replay entry so a tester can
  paste a seed from analytics and launch the exact opening board.
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
