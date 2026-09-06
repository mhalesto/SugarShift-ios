# Volcano / Coral production assets

Generated with the built-in image-generation tool, September 6. No stock or other-game artwork used. Sources and actual dimensions are in ASSET_MANIFEST.md.

## Environment prompts

Volcano: Original Sugar Shift premium iOS game environment only, not a screenshot. Crisp high-resolution tall portrait, composition 946:2048, requested 1892×4096 if supported. Rounded dark-plum basalt cliffs, majestic active volcano in upper-middle distance, luminous orange lava waterfalls and river winding toward bottom, saturated red-orange sunset against deep purple sky, subtle embers. Stylized 3D molded materials, controlled gloss, orange rim light. Top 25% open sky for live HUD; central 35–72% quiet dark misty valley and reduced contrast for a real board; dramatic lava detail at sides/bottom. Same Sugar Shift family as candy mountains, not photoreal or gritty. Environment fills canvas; no UI, pieces, board, text, logo, numbers, buttons or watermark.

Coral: Original Sugar Shift underwater world background only, not UI. Crisp high-resolution tall portrait in 946:2048 composition, requested 1892×4096 if supported. Luminous turquoise surface and soft sun rays through sapphire water; sculptural pink/orange/purple corals and rounded sea plants framing edges; distant shipwreck silhouette and treasure off to sides; silky seabed path receding through middle; subtle bubbles. Glossy stylized 3D casual game art, rounded molded forms, saturated reflections and soft ambient occlusion. Top 25% airy aqua breathing room; central 35–72% low contrast quiet water for a board; rich soft coral/seashell depth at bottom. No whale, pieces, board, UI, text, logos, numbers, buttons, watermark or phone frame.

## Hero prompts

Use case: stylized-concept. Asset type: single isolated game-ready hero sprite for original Sugar Shift Volcano Valley combo animation. A large spherical volcanic core, round molded dark plum obsidian armor plates separated by deep branching glowing orange and yellow magma fissures, amber molten center visible in cracks, tactile soft glossy 3D casual game material, bright upper-left key light and hot orange rim reflections. Front three-quarter view, compact strong circular silhouette. On genuinely transparent background with alpha, no painted checkerboard, no backdrop, no ground plane, no cast shadow outside silhouette, no floating debris, no outer glow cloud. The actual object must be opaque, only the surroundings transparent. Center object with 8% transparent gutter, complete silhouette unclipped. No face, no text, no logo. Crisp highest-quality 1024x1024 source master, suitable for native-resolution iPhone animation. Premium stylized 3D illustration, not photoreal, not flat vector.

Use case: stylized-concept. Asset type: one isolated production hero sprite for original Sugar Shift Coral Reef combo animation. A charming beautiful large rounded humpback-inspired fantasy blue whale with a pale icy-blue pleated belly, sapphire-to-turquoise glossy smooth body, friendly small expressive eye, elegant broad flippers and lifted tail, swimming toward the RIGHT, complete side-three-quarter silhouette visible. Expensive premium casual game stylized 3D illustration with soft upper-left key light, cyan rim reflections, controlled gloss, rounded molded forms. Bright sculptural surface detail and strong readable silhouette, not photo, not emoji or flat vector. Entire whale alone centered occupying 84% canvas width on a genuinely transparent background with alpha. No ocean, no splash, no trail, no bubbles, no checkerboard, no ground shadow, no panel, no text, no logo. No cropping of tail or flippers. Crisp highest-quality high-resolution 1536x1024 master.

## Runtime integration

- Volcano levels 46–60 and Coral levels 61–75 select their own environment, accent/rim, sparse rising ambience and hero skin.
- Only powerful special pairs and earned Mega Smash trigger the large presentation. Ordinary matches, normal color-bomb swaps and lower Smash tiers retain existing effects.
- Gameplay computes the affected cells first. The visual layer receives that footprint; it never modifies the board or adds damage.
- Volcano: swelling molten core, branching cracks toward real targets, firm anticipation haptic, heavy impact, decaying board-only shake, fragments and shockwave.
- Coral: curved whale travel, splash ring/bubbles and links to affected cells, bounded board shake and impact haptic.
- One short-lived parent owns delayed actions and emitters. End-of-presentation removal precedes gravity/input release. New level cancels lingering hero and restores shake origin.
- Reduce Motion removes hero travel, cracks/debris and shake, retaining a short soft halo and gated haptic. Particle/link budgets cap at 48/16.
- Final dedicated world audio remains outstanding; current cues reuse existing sound-toggle-aware layers.

## Validation

Standalone production-policy checks passed after a failing baseline. Syntax parse and diff checks passed. Two navy hero contact sheets inspected. Actual phone animation smoothness, haptic feel and final card screenshot remain unverified in this batch; no simulator/build retry loop was started.
