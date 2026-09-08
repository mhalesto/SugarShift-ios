# Sugar Shift asset manifest

## September 7 material-animation integration

The world-motion/story continuation reuses the existing original world art, special art and sounds. Its shared particle textures and family portraits are procedural native assets; no new raster image was generated or downloaded. Optional future artwork and runtime acceptance gaps are tracked in [the delivery note](WORLD_ANIMATION_STORY_DELIVERY.md). The new animation mockups did not change UI, board geometry or the protected footer.

## Level-card follow-up — September 6

The [level-card correction](LEVEL_CARD_CORRECTION.md) adds the Ice Age environment (`world_ice_background`, 853×1844 JPEG, original master retained) and revises the cached card/icing/stars/booster surfaces. Ice levels 16–30 now use their own background; seven other environment fallbacks remain. Legacy fixed-blocker objectives display their actual per-type counts and visible art. Missing lock/cage/crate textures use metal/wood braces drawn in code. The earlier ledger below describes the preceding checkpoint.

## Current production ledger — September 6, build 10

The original audit table below is retained as a historical inventory. **This ledger supersedes its Generated/Integrated flags.** All art is original built-in image generation; no external art was downloaded. Master files live in `art/masters/`; shipping resources live in `SugarShift/Assets.xcassets/`.

| ID / family | Category | World | Purpose | State | Source master | Master dimensions | Shipping dimensions | Alpha | Generated | Integrated |
|---|---|---|---|---|---|---|---|---|---|---|
| sugar_shift_logo | Brand | shared | central logo | EXISTING | sugar_shift_logo.png | 1536×1024 | 1536×1024 | yes, exported | yes | yes |
| fruit_strawberry/grape/orange/blueberry/banana/leaf/heart, ui_coin | Fruit/UI | shared | match pieces/currency | EXISTING | core_fruit_atlas.png | 1774×887 | 443–444px cells | yes, exported | yes | yes |
| special_striped_horizontal/vertical, wrapped/color_bomb/fish/rocket/line_blast/ufo | Specials | shared | board specials | REWORK | core_special_atlas.png | 1774×887 | 443–444px cells | yes, exported | yes | yes; wrapped/line glow matte needs refinement |
| booster_hammer/swap/shuffle/moves/life, ui_settings/map/shop | Boosters/UI | shared | controls | EXISTING | core_ui_atlas.png | 1774×887 | 443–444px cells | yes, exported | yes | yes |
| blocker_ice_01–03, jelly_01–02, chocolate, honey_01–03 | Blockers | shared | visible layers | REWORK | blocker_layers_atlas.png | 1254×1254 | native cropped cells | yes, exported | yes | yes; chocolate edge cleanup remains |
| blocker_stone_01–03, cream_01–05 | Blockers | shared | visible layers | EXISTING | stone_cream_atlas.png | 1774×887 | native cropped cells | yes, exported | yes | yes |
| world_candy_background | Environment | candy | background only | EXISTING | world_candy_background.png | 845×1862 | 845×1862 JPEG | no | yes | yes |
| world_volcano_background | Environment | volcano | background only | EXISTING | world_volcano_background.png | 853×1844 | 853×1844 JPEG, 385KB | no | yes | yes |
| world_coral_background | Environment | coral | background only | EXISTING | world_coral_background.png | 853×1844 | 853×1844 JPEG, 487KB | no | yes | yes |
| combo_volcano_core | World effect | volcano | cracking/rupture hero | EXISTING | combo_volcano_core.png | 1254×1254 | 768×768 PNG, 727KB | yes, exported | yes | yes |
| combo_whale | World effect | coral | travelling/splash hero | EXISTING | combo_whale.png | 1536×1024 | 768×512 PNG, 273KB | yes, exported | yes | yes |
| eruption cracks, target links, shockwave, bubbles/embers | Effects | volcano/coral | real-clear feedback/ambience | PROCEDURAL | GameScene+WorldCombo.swift | code / points | cached 48px particles | yes | no | yes |
| level card / icing / objective strip / progress stars | UI | shared | live reference-matched card | PROCEDURAL | PremiumHUD / HUD | code / points | 3× cached panels | yes | no | yes; device comparison pending |

Resolution honesty: the image tool returned the dimensions listed above despite requests for larger portrait masters. Nothing was enlarged to fake resolution. Hero exports exceed their usual @3x display needs; **world backgrounds are below native full-screen iPhone 12 Pro Max resolution and still need higher-resolution replacement for the strict final art bar**. Detailed source PNGs are preserved. Contact sheets for both new heroes were inspected against navy: complete silhouettes, transparent surroundings, consistent gloss and no visible checkerboard boxes.

Remaining world environments: Ice, Honey, Cloud, Golden, Firefly, Sahara, Galaxy, Sakura. Their level ranges/theme colors exist, but currently use Candy Valley as the background fallback. Remaining core blocker/target art and themed heroes are identified in the original inventory below. Themed sound playback currently uses the existing gated SFX layers; final volcanic-crack and whale-splash recordings/synthesis remain AUDIO work.

New output provenance (built-in image tool):
- Volcano environment: `exec-0ce4cba9-0588-4302-b323-ce6c9f6745c9.png`
- Coral environment: `exec-ad3bef97-705e-4723-a280-2f7ba05924b8.png`
- Volcano core: `exec-20593ef2-07fb-426d-8090-d244edf7a42d.png`
- Whale: `exec-86d35781-bfb1-445c-be6f-510c5e038d28.png`

Source output directory: `/Users/halalisanimbanjwa/.codex/generated_images/01a07213-9f7e-7601-9afa-ed4fdaa9084c/`. Project assets reference only workspace copies, never that external location. Generated previews contain RGB checkerboards; the established native export pipeline removes connected exterior matte, creates real alpha, then checks navy contact sheets. Original masters remain unchanged.

Prompts and integration notes: [WORLD_COMBO_ASSETS.md](WORLD_COMBO_ASSETS.md).

## Original audit inventory (historical)

Status at continuation: eight bundled emoji fruit PNGs, code-drawn BrandLogo/HUD/specials/blockers, nine MP3s and procedural Effects. No suitable world backgrounds or texture atlases. Existing AppIcon is retained. No third-party downloadable art is used.

`EXISTING`: suitable and retained. `REWORK`: existing but stylistically unsuitable. `MISSING`: original generation required. `PROCEDURAL`: scalable code/particles. `AUDIO`: new recording/synthesis or provenance review needed. Generation and integration are separate facts; both begin **no** below.

| ID | Category | World | Purpose/state | Status | Source | Master | Shipping | Alpha | Generated | Integrated |
|---|---|---|---|---|---|---|---|---|---|---|
| app_icon | Brand | shared | app icon | EXISTING | project | existing | asset catalog | no | no | yes |
| sugar_shift_logo | Brand | shared | central wordmark | REWORK | original generation | requested high resolution | optimized PNG | yes | no | no |
| fruit_strawberry, fruit_grape, fruit_orange, fruit_blueberry, fruit_banana, fruit_leaf, fruit_heart | Fruit | shared | seven match pieces | REWORK | original generation; prior emoji retained for compatibility | high resolution sprite master | atlas regions | yes | no | no |
| special_striped_horizontal, special_striped_vertical, special_wrapped, special_color_bomb, special_fish, special_line_blast, special_rocket, special_ufo | Specials | shared | clear/creation art | MISSING | original generation | sprite master | atlas regions | yes | no | no |
| booster_hammer, booster_swap, booster_shuffle, booster_moves, booster_life | Boosters | shared | constant icon family | MISSING | original generation | sprite master | atlas regions | yes | no | no |
| ui_heart, ui_coin, ui_plus, ui_settings, ui_map, ui_shop, ui_star, ui_play | UI | shared | live controls | MISSING | original generation | sprite master | atlas regions | yes | no | no |
| blocker_ice_01, blocker_ice_02, blocker_ice_03 | Blockers | shared/ice | three layers | REWORK | original generation | sprite master | atlas regions | yes | no | no |
| blocker_jelly_01, blocker_jelly_02 | Blockers | shared | under-piece layers | REWORK | original generation | sprite master | atlas regions | yes | no | no |
| blocker_honey_01, blocker_honey_02, blocker_honey_03 | Blockers | honey | trapped fruit layers | MISSING | original generation | sprite master | atlas regions | yes | no | no |
| blocker_stone_01, blocker_stone_02, blocker_stone_03 | Blockers | shared | immovable layers | MISSING | original generation | sprite master | atlas regions | yes | no | no |
| blocker_cream_01, blocker_cream_02, blocker_cream_03, blocker_cream_04, blocker_cream_05 | Blockers | shared | frosting stages | MISSING | original generation | sprite master | atlas regions | yes | no | no |
| blocker_chocolate, blocker_cage, blocker_lock, objective_key, blocker_licorice, blocker_bubble, blocker_magic_frost, blocker_crate, blocker_x, blocker_donut | Blockers/Objectives | shared | obstruction states | REWORK | original generation | sprite master | atlas regions | yes | no | no |
| tile_portal, tile_conveyor, tile_cake, tile_cookie, tile_waffle, tile_chocolate, tile_frosting, tile_candy | Tile | shared | fixed board decoration | MISSING | original generation | sprite master | atlas regions | yes | no | no |
| world_candy_background | Worlds | candy | environment only | MISSING | original generation | portrait 946:2048 composition | optimized portrait | no | no | no |
| world_ice_background, world_honey_background, world_volcano_background, world_coral_background, world_cloud_background, world_golden_background, world_firefly_background, world_sahara_background, world_galaxy_background, world_sakura_background | Worlds | named | environments only | MISSING | original generation | portrait 946:2048 composition | optimized portrait | no | no | no |
| combo_volcano_core, combo_whale, combo_blossom, combo_firefly_jar, combo_sandstorm, combo_planet, combo_balloon, combo_ice_crystal, combo_honey_jar, combo_amber | Effects | named | transient major combo hero | MISSING | original generation | sprite master | atlas regions | yes | no | no |
| world_blocker_overrides, world_objective_overrides | Blockers/Objectives | named | skinned existing mechanical roles | MISSING | original generation | sprite master | atlas regions | yes | no | no |
| hud_panels, board_rim, recessed_tile, world_sign, progress_fill, glass_tray, button_bodies | UI | shared/themes | scalable surfaces, runtime labels | PROCEDURAL | UIKit/SpriteKit | vector/points | cached texture | yes | no | existing rework |
| sparkle, shard, snow, ember, bubble, petal, firefly, sand, star, leaf, honey_drop | Effects | shared/themes | particle families | PROCEDURAL | SpriteKit | vector/points | cached texture | yes | no | partial |
| swap, invalid, match, combo, bomb, win, lose, tap, music | Audio | shared | existing MP3 treatment | EXISTING | bundled project audio | existing | decoded/cache | n/a | no | yes |
| star, coin, ice_crack, stone_crack, volcanic_rupture, whale_splash, world_ambience | Audio | named | distinct hooks and treatments | AUDIO | original synthesis or new licensed recordings | PCM | cached | n/a | no | no |

## Production ledger

Record output paths, dimensions, alpha inspection, prompt provenance, review result and integration here as generation completes. The supplied screenshots and MP4s are references, not shipping interfaces or video overlays. No external licensed assets have been downloaded.
