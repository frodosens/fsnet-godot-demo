# Reference-conditioned battle UI runtime art

This directory contains generated in-game UI textures and one separately identified approved character illustration. It does not contain full concepts, trial sheets, screenshots, videos or QA proofs.

Preferred buttons: buttons/normal.png, selected.png, disabled.png, all124x127 RGBA. Panels match measured reference layout: action/movement690x149, character517x157, end-turn280x79, round347x50. HP/MP shells204x20 and independent fills190x10. Icons are128x128 RGBA, intended for24/32/40 logical pixels.

All chrome and icons were generated using approved design references, then cropped/alpha-cleaned/resampled. Panel center/edges use nine-slice normalization to preserve corner proportions without changing the approved layout. They are reference-conditioned reconstructions, not pixel-identical screenshot layers.

character/portrait-mara.png is explicitly retained approved character illustration with extracted/estimated alpha; it is not claimed as newly generated UI.

Use the actual selected actor silhouette for target ghost. UI range/path topology comes from authoritative Lua state. Wait is a per-character action, distinct from end-turn. Dynamic text and HP/MP values remain live UI.

manifest.json records sources, hashes, transformations and image-only checks. layout.json gives measured positions. Local alpha and native-scale visual checks are not Godot import, GPU, multiplayer or gameplay validation. No canonical game-dev CLI package is claimed.

Ground range textures are separate512x512 border/fill RGBA. Map square UV to the real horizontal cell quad; do not double-apply isometric projection. Fill median alpha32/255. Neighbor tile edge bytes match, with half-stroke edges to avoid doubled shared lines. See manifest for measured geometry and limitations.

Generated overlay additions: target_cell_border_gold.png uses the same square ground UV as cyan. route_arrowhead_ivory.png is256x256, points+U/right, pivot128,128. Rotate along route in screen space OR world-ground space before projection, not both. Ghost remains the actual selected actor, never a baked illustration.
