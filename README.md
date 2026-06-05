# SugarShift iOS

SugarShift is a SpriteKit match-3 game with a level map, shaped boards,
blockers, specials, an in-game coin economy, and a 200-level campaign.

## Current Release Notes

- Campaign content runs through level 200, with crowned levels from 100 onward.
- Early levels 1-20 have gentler score goals, more moves on constrained boards,
  and easier 2/3-star thresholds.
- Star targets require beating the score goal instead of duplicating the win target.
- Ice and lock blockers now absorb hits before the tile underneath clears.
- Chocolate spreader blockers appear from level 80; one spreads each turn
  unless adjacency keeps it in check.
- Fruit baskets drop down from late levels — `LevelGoal.collectIngredients`
  rewards routing them to the bottom of the column.
- Boss-level flag (`LevelConfig.isBoss`) on every multiple of 10 + finales,
  with `Levels.bossReward(for:)` paying out an extra prize on first clear.
- Replaying older levels no longer rolls back campaign progress.
- Level-map settings and shop buttons open their panels directly.
- Wall-clock life regeneration via `Persistence.lives` (25 min/life, capped
  at `Economy.livesMax = 6`); `secondsUntilNextLife` / `nextLifeCountdownText`
  surface the timer for any HUD that wants to show it.
- iCloud Key-Value Store sync (`Persistence.Cloud.start()`) mirrors stars,
  rewards, and currency between devices. No-op without the iCloud entitlement.
- Game Center scaffolding (`GameCenterService.shared`) submits leaderboard
  scores and achievements. No-op until the capability is enabled.
- Local push reminders (`PushService.shared`) for life-full and the daily
  challenge reset. Asks for permission on first call and remembers the answer.
- Piggy bank (`Persistence.piggyCoins`) fills as the player matches and is
  surfaced in the shop with a fill meter; cracking pays out the pot. Coin
  doubler day pass (`Persistence.applyCoinDoubler`) doubles reward coins for
  24 hours per purchase and shows an active timer.
- Smarter idle hint suggests a swap that *creates a special* over a plain
  3-match when both are available.
- Rewarded ads are test-enabled in Debug builds for economy tuning; Release
  builds keep them disabled until a real ad provider is configured.
- Near-miss losses can offer one rewarded continue (+5 moves) per attempt, so
  ads are tied to clear value instead of interruption.
- Special candies now support premium combo swaps: striped+striped,
  striped+wrapped, color bomb+striped, color bomb+wrapped, and bomb+color bomb.
- The shop is split into Earn, Boosts, Special, and Coins tabs so ads,
  boosters, timed perks, piggy bank, and StoreKit purchases are not shown as
  one crowded grid.
- StoreKit 2 coin-pack purchases load prices from StoreKit, use the local
  `Products.storekit` file in Debug, and credit coins through an idempotent
  transaction ledger so transaction updates cannot double-credit consumables.
- Firebase Auth + Firestore + callable Functions are wired for Apple-account
  progress sync. Signed-in players push/pull progress snapshots and StoreKit
  delivery IDs through Functions so a device switch can restore consumable
  balances from the backend.
- Lightweight analytics events are logged for level starts, wins/fails,
  abandons, ad rewards, booster use, and coin spend.

## Capabilities to flip in Xcode before shipping

Several systems compile dormant and only light up once the matching capability
is enabled in the SugarShift target:

- **iCloud (Key-Value)**: turn on `iCloud → Key-value storage`. Required for
  `Persistence.Cloud` to actually mirror progress.
- **Game Center**: turn on the capability and create the leaderboards /
  achievements with the IDs in `GameCenterService.Leaderboard` and
  `GameCenterService.Achievement`.
- **Push Notifications**: not strictly required for the local notifications
  in `PushService` (those work without the capability), but enable it before
  adding remote-push features.
- **In-App Purchase**: configure the products `CoinProduct.small` /
  `CoinProduct.large` in App Store Connect with the IDs in `Economy.swift`.
  The code path in `MonetizationServices.swift` is already wired.
- **Sign in with Apple**: the entitlement is present in
  `SugarShift.entitlements`; enable the capability for the app identifier in
  Apple Developer and keep the Firebase Apple provider enabled.
- **Firebase**: register the iOS app with bundle ID `com.currenttech.SugarShift`,
  add `GoogleService-Info.plist` to `SugarShift/`, then deploy
  `firestore.rules` and the callable Functions in `functions/`. The project
  must be on Blaze billing before Cloud Functions can deploy.

## Firebase Backend

The app expects these Firebase callables in `europe-west1`:

- `syncProgress`: writes the signed-in player's sanitized progress snapshot to
  `users/{uid}/state/progress`.
- `recordStoreKitDelivery`: records each StoreKit transaction ID once under
  `users/{uid}/storeKitTransactions/{transactionID}` after validating the
  transaction against Apple's App Store Server API. It also writes a global
  `storeKitTransactions/{transactionID}` ledger document so one transaction
  cannot be replayed by another signed-in account.

Configure these Functions environment variables before treating paid delivery
as production-ready:

- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_PRIVATE_KEY`
- `APP_STORE_BUNDLE_ID` (optional, defaults to `com.currenttech.SugarShift`)

`ALLOW_UNVERIFIED_STOREKIT_DELIVERY=true` is available only for local StoreKit
configuration testing. Do not enable it in production.

Deploy with:

```bash
npm --prefix functions install
npm --prefix functions run build
firebase deploy --only functions,firestore:rules --project sugarshiftios
```

## Verification

Build the app:

```bash
xcodebuild build -project SugarShift.xcodeproj -scheme SugarShift -destination 'platform=iOS Simulator,name=iPhone 17'
```

Compile the app and test bundle:

```bash
xcodebuild build-for-testing -project SugarShift.xcodeproj -scheme SugarShift -destination 'platform=iOS Simulator,name=iPhone 17'
```
