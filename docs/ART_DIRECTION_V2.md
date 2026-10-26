# Amber Bridge — V2 art direction
Status: approved visual direction; assets in this branch are presentation inputs, not proof of runtime integration.

## North star
Quiet, modest European mercenary-town fantasy. Crisp pixel clusters, broad readable shapes, restrained detail. Slate water, moss vegetation, dusty terracotta roofs, warm-gray plaster/stone, charcoal-green UI, ivory text. Small amber accents identify focus or lamplight. No gilt frames, wax seals, ornate scrolls, glossy materials, bloom, epic orange poster lighting or decorative clutter.

## Runtime main menu asset
- `assets/ui/v2/menu_background.png`: 1920×1200, opaque PNG. Built-in image generation edit of approved V2; text and selection highlight removed. Do not use the approval mockup as an interactive screen.
- Preserve aspect ratio; use nearest filtering. Artwork is deliberately clustered-pixel illustration, not a strict single-resolution tile grid.
- Left 27% is text-safe. At a 1280×800 baseline, title starts around (54, 144), width 300; subtitle (55, 218). Four menu baselines approximately 366, 442, 518, 594. Scale UI coherently; retain safe margins on narrow screens.
- Exact title: 琥珀桥来信. Subtitle: AMBER BRIDGE. Native menu labels: 开始新游戏 / 读取存档 / 网络对局 / 退出游戏.
- Title 40–44 px at baseline; menu 27–30 px; supporting text at least 16 px. Refined readable Chinese Song-style title; readable native body font. Bundle only a separately verified licensed font; fallback is acceptable.
- Unfocused navigation is plain ivory text; focus uses a small amber diamond and quiet olive row fill. No textured button frames. Mouse hover and keyboard/gamepad focus share visual treatment. Disabled items are visibly quieter and still explained by native text.
- Typography, hover, focus, shortcuts, hit areas, accessibility and input routing MUST remain real Godot controls. Never bake labels into runtime artwork. Do not add an ornate panel asset merely to make UI look 'artistic'.

## Whole-game palette and hierarchy
Suggested semantic colors (implementation tokens, not a demand to quantize every image):
- ink/background: #202B29; panel: #293432; raised surface: #343C34
- primary text: #E4DCC5; secondary text: #ADB3A6; disabled: #777F77
- focus/lamplight: #CE9A57; friendly: #91AAA3; danger: #B77C6B
- stone: #85847A; roof/clay: #73594D; foliage: #59624B; water: #596D76
Maintain readable text contrast. Do not rely on color alone for teams, selection or errors.

## In-game UI
Battle HUD, inventory, save/load, lobby, editor, pause and dialogue share flat charcoal-green surfaces, generous spacing and thin low-contrast separators. Aim for one focal highlight per local group. No ornamental frame skins are required: the authored hierarchy and restrained shapes are intentional.
Dialogue uses a quiet lower-screen panel with native speaker/name/body controls; portrait has no giant gold frame. Menus must scroll and wrap at minimum supported window size. Tooltips, validation and locked states must remain legible.

## Characters and portraits
Consistent muted cloth/leather/iron palette; a few broad color groups per character, matte highlights, identity-led silhouette. Four real directions in front/back/left/right order; weapons retain handedness, never merely mirror asymmetric equipment. Keep common foot baseline and comparable scale; nearest sampling, transparent outside silhouette.
Portraits retain identities and costume hues from map sprites; same matte pixel-cluster treatment, restrained expressions, no photoreal skin, glossy jewelry or soft airbrushed anime finish. Existing brighter candidates are migration inputs, not automatically V2-approved final art.

## Maps
Match the modest inn/bridge architecture and broad muted material groups. Terrain silhouettes and walkability must remain readable before decorative texture. Avoid noisy microdetail and saturated highlights across every tile. Warmth comes from localized window/lantern pixels, not global bloom. Keep movement/attack overlays thin and unobtrusive; selection has a shape cue as well as a color cue.
Only normalize/crop/align generated artwork for technical use. Do not replace approved art with procedural painted imitations.

## Effects
Short, sparse stepped pixel clusters; restrained cream slash, dusty amber hit spark, cool slate/teal magic, muted ochre dust. No giant neon gradients, screen-covering particle clouds or full-screen bloom. Effects consume settled events only and never change deterministic rules. Respect skip/reduced-motion options.

## Production acceptance
Compare actual game screenshots against the approved V2 draft, not v1. Verify Chinese legibility, focus states, four-direction anatomy/handedness, anchor alignment, transparency and no clipping. Confirm every visible surface (including editor/dialogue/cutin) shares this direction. A source asset commit is not a completed visual migration.

## Delivery dimensions and slicing
Runtime menu background was cropped from 1672×941 to (0,0,1506,941), preserving left negative space and inn focal point, then nearest resized to 1920×1200. Source is preserved as assets/ui/v2/sources/menu_background.png. No pixel repainting was used.
Optional image-generated matte panel: assets/ui/v2/panel.png = 512×256, nine-patch margins 32 on all sides. Suitable for dialogue render 1240×224 with native text insets >=32. Optional secondary button skin: assets/ui/v2/button.png = 384×96, nine-patch margins x24/y20. Both are nearest-resized from the preserved panel source; no drawn replacement graphics. Keep MAIN MENU plain text as approved; these quiet skins are for secondary surfaces only. Do not tile the center; stretch/tint subtly if required. Verify center texture in a real rendered dialog before shipping. A tiny native amber diamond is permitted focus geometry, not replacement illustration.
