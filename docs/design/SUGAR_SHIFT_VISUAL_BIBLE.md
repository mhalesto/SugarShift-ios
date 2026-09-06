# Sugar Shift visual bible

## Locked footer and fidelity requirement — current user direction

The existing footer is approved and protected by [AGENTS.md](../../AGENTS.md).
It must not be touched unless the user explicitly says so. This overrides footer
differences in the concepts. Every other detail is an acceptance target: card
dimensions, world sign placement and material, objective silhouettes, type scale,
board mask/rim/cells, large fruit, layered blockers, scenery and meaningful combo
timing. The user specifically reinforced: **"every little detail must match"**.
Runtime values reflect real levels; example counts and transient effects are not
permanent screen decoration.

All twelve supplied PNGs were individually re-inspected for this continuation.
Both MP4s were sampled across their full five-second timelines at 0.5-second
intervals; review sheets are in `reference-review/`. Volcano uses a cracking core,
hot cross, debris and expanding ring. Whale has a visible anticipation/travel,
large curved hero, water trails and a board wave. Generated-video counter
distortions are not gameplay requirements. The current 0.6-second generic heroes,
centered thin world-name pill and candy background fallbacks do not meet this bar.

## Authority and composition

The user-approved standard gameplay concept (`ChatGPT Image Sep 5, 2026, 03_29_46 PM.png`) defines the base screen. The asset sheet (`03_37_12 PM.png`) defines the shared art family. The old screenshot is a functionality reference only. All twelve September 5 world concepts and both five-second motion clips have been inspected.

Master composition: **946 × 2048**, approximately **9:19.5**, independent of reference PNG metadata. Runtime layout uses points, safe areas, available height and independent row/column counts. Square cells and aspect-fit sprites never stretch. Essential controls never crop. Short devices compress decoration before reducing board clarity.

## Persistent shell

1. Top: protruding glossy heart, real lives/timer and green plus; one central orange/pink Sugar Shift logo; coin wallet/green plus; settings.
2. Small runtime world-name sign below the logo region.
3. Cream/translucent level card: level and difficulty, concise objectives with art/current/required, large contrasting Moves inset, score fill and exactly three threshold stars.
4. Centered navy board: independent width/height, inactive-cell shapes, subtle recessed tiles, narrow gaps, glossy large pieces, warm or world-tinted illuminated rim.
5. Glass booster tray: the same Hammer, Swap, Shuffle, +Moves, Life family everywhere. Inventory or explicitly marked coin price. Selected/disabled/pressed states.
6. Map / raised pink Play / Shop. Confirm abandonment after an attempt begins. Existing Flow, Smash and Undo remain available as compact secondary controls.

Every game value and interaction remains live. No screenshot-as-interface, image-baked numbers, or world-specific GameScene forks.

## Shared art language

Glossy stylized 3D, molded rounded forms, saturated distinct silhouettes, upper-left soft key light, controlled highlights, ambient occlusion and soft contact shadows. Fruit: strawberry, grapes, orange, blueberry, banana, leaf, heart. No emoji or SF Symbol replacement for generated shared artwork. Fruit/special masters have real transparency, generous but bounded padding and consistent scale. Code draws scalable panels, rims, gradients and progress bars. Localized Avenir Next rounded/heavy text remains native and high contrast. Shape/pattern accessibility survives art replacement.

## Worlds and progression

Worlds group the existing 200-level campaign; example level numbers in images do not redefine progression. Existing saved level IDs, Tower, Rush, missions and reward ledgers remain stable. A world skin never changes a gameplay rule.

| World | Campaign | Colors | Environment / ambience | Blocker/objective skins | Major presentation | Reference |
|---|---|---|---|---|---|---|
| Candy Valley | 1–15 | pink #FF4D99, sky #38BDF8, cream #FFF0DF | blue sky, candy peaks, falls, foliage; sparkles | original fruit, jelly, cream | Sugar Surge; rainbow cross | base concept |
| Ice Age | 16–30 | cyan #6DE6FF, frost #E8FAFF, blue #397AE8 | frozen waterfalls, snowcaps; drifting snow | layered ice, cracked ice, magic frost | Frost Break; shards and blue shockwave | zzz.png |
| Honey Haven | 31–45 | honey #FFB72B, amber #FF8C21 | sunny orchard, honey glow; droplets | honey layers/jars, chocolate, honeycomb | Honey Burst; golden sticky cross | ssss.png |
| Volcano Valley | 46–60 | lava #FF6122, gold #FFD55B, charcoal #271830 | volcano, lava river, basalt; embers | magma stone, hardened lava, cores | Volcanic Combo; cracking core, two impacts, lava cross | vvvvv.png / Volcano.MP4 |
| Coral Reef | 61–75 | aqua #20DDF6, blue #087ADD | underwater rays, coral, shipwreck; bubbles | pearl/shell/starfish, seaweed cage, stone/barrel | Whale Combo; travelling whale, luminous splash | llllli.png, sssse.png / Whale Combo.MP4 |
| Cloud Kingdom | 76–90 | pink #FF9CDD, sky #A2DAFF | floating islands/castles/rainbows; cloud drift | cloud frosting, rainbow, star, balloon | Rainbow Rush; balloon and rainbow beams | cccckklll.png |
| Golden Desert | 91–110 | gold #FFC943, amber #DC8D27 | oasis, ruins, palm trees, amber; sand | sandstone, tablets, amber jars, crates | Golden Bloom; shards and rays | ggggg.png |
| Firefly Forest | 111–130 | indigo #183A67, light #FFE867 | nighttime forest/cottages, lanterns/falls; fireflies | firefly jar, vines, flowers, crates | Firefly Burst; jar and targeted light trails | beeee.png |
| Sahara Sands | 131–150 | sand #FFD08C, bronze #BD742C | pyramids, oasis, fantasy sandstone city; sand | sand layers, scarab, urns, desert plants | Sandstorm; spiral and debris | hhhhhhh.png |
| Galaxy Getaway | 151–175 | purple #AB6AFF, violet #482782 | nebula, planets, futuristic silhouettes; stars | asteroid stone, energy locks, portals, rockets | Cosmic Blast; orbit rings and shockwave | gfrrrrrrrr.png |
| Sakura Sky | 176–200 | blossom #FF84D6, midnight #27235F | moon, blossom branches, lanterns, falls; petals | blossom, lantern, pink crystal, rope | Petal Storm; blossom, elegant pink cross | bbbbbbbb.png |

`yyyy.png` is a mixed-mechanic stress reference: ice, chocolate, donut, key, lock, cage, cream, portal, rocket and chained specials must be readable at rest. `llllli.png` uses an octopus variation; Coral's main hero is the whale from the explicit Whale reference.

## Theme architecture

One `WorldThemeDefinition` supplies stable ID, level range, background, card/accent/rim colors, ambient particles, blocker/objective art overrides, sign name, major-combo title/hero/effect palette and audio treatment. Board masks/objectives/blocker rules stay in level data. A theme-specific hero presents the existing resolved mechanical footprint (cross, area, targeted, board wave); it does not add unexplained clears.

## Motion and sound

Normal swap 0.15s; compress/pop about 0.18s; distance-based fall. High-value combos: 0.12–0.20s anticipation, expanding core, directional or targeted energy, impact fragments, bounded shake and layered haptic, then complete removal of temporary nodes. Volcano cracks pulse before a heavier rupture; Whale travels on a curved path before splash. Major heroes only accompany strong special pairs or earned Mega Smash, once per action. Existing Smash supplies earned power; no competing world currency/meter is necessary.

Effects use cached textures, short-lived SpriteKit nodes/emitters, emission budgets and cleanup. Ambient particles are sparse and behind the board. Reduce Motion removes shake and large travel; disabled haptics and sound are respected. Never shake the HUD or allow repeated shake to drift board origin.

## Background production

Original environment-only portrait masters with 946:2048 composition. No logo, sign text, level, moves, board, counters, controls or UI. Sky/headroom near top; reduced contrast behind center board; rich but soft foliage/terrain below tray. Ship optimized images without stretching. One shared logo, one shared booster family, no downloaded game assets.

## Validation

September 6 card correction from the supplied actual Level 24 screenshot and desired Level 87 concept: remove circular star backings; use a bright blue progress line, cream Moves inset, subtle vertical divider, translucent objective strip, restrained pink icing at the upper-left and centered score. Keep actual objective count rather than filling empty space with invented goals. The world sign must sit below—not over—the central logo. Debug builds add a compact Levels control in the spare left-side header space.

Build/test cadence now follows the user's correction: avoid repeated simulator builds and retries. Perform one meaningful-batch check on the connected iPhone 12 Pro Max; record source-only changes separately from actual runtime verification.

Run engine tests after each change in behavior, build after each phase, and capture real simulator gameplay on a standard Dynamic Island iPhone, a short iPhone and a Pro Max. Compare actual logo/card/board/tray/nav placement to the base composition. Exercise swaps, invalid swaps, targeted boosters, shuffle, win/fail/continue, map confirmation and themed combos. Screenshots alone do not establish playability or frame-rate performance.
