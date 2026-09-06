# Sugar Shift project instructions

## Protected footer — explicit user direction, 6 September 2026

The user likes the current footer and said: **"it must not be touched unless I say so."**

Preserve the current booster tray and bottom navigation exactly. Do not redesign,
restyle, resize, reposition, replace assets, or alter interactions in that footer
without a subsequent explicit instruction from the user authorizing that change.
General requests to match the visual references do not override this protection.

This includes `buildFooterCard()` in `SugarShift/GameScene+PremiumHUD.swift`, its
Hammer / Swap / Shuffle / +Moves / Life controls, Map / PLAY / Shop navigation,
footer-specific artwork, and the booster / navigation geometry in
`SugarShift/GameplayLayout.swift`. Shared helpers must not change the footer as a
side effect. Work on the header, level card, board, worlds and combos around the
existing footer. Retain its live values and existing accessibility behavior.

## Continuing the redesign

Continue the current working tree. Preserve existing local changes, localization,
saved progress and mature gameplay systems. Read `docs/design/IMPLEMENTATION_PLAN.md`
and the latest delivery notes before continuing. The supplied reference pack is
the visual acceptance target; use `docs/design/SUGAR_SHIFT_VISUAL_BIBLE.md` and
`docs/design/ASSET_MANIFEST.md` to track measured gaps and production assets.
Validate meaningful visual batches with actual screenshots. Never claim a screen
matches the reference just because it builds.
