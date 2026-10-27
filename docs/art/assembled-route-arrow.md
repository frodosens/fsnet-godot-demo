# Approved artwork route assembly candidate

The runtime atlas is the exact top 1774×400 crop of the approved transparent arrow artwork. Source asset commit: `766624b58f494775b9acb30b022fe85e233daed2`; SHA256 `a04a55bc7571c8f8052279cd26bcdfc0ed6bef6f84167d1da172f23144d04655`. The lower illustrated example and design screenshot are not runtime assets and are not committed.

`view/route_art.gd` samples the original straight strip, rounded turn, arrowhead, start cap and endpoint frame. It crops exact source pixels once into shared ImageTextures; no recoloring, hard alpha threshold, regeneration or per-frame image processing. AtlasTexture regions were not used as a 3D material shortcut because the initial graphical check showed the full atlas being sampled incorrectly. Smooth source alpha is preserved.

## Assembly contract

- All modules are flat ground-space geometry using the actual Lua path cell centers. The camera projects them once; no pre-skewed isometric artwork or fixed screen-coordinate path.
- Shaft scale is 0.12 world units / 56 source pixels. Straight strip region is (150,202,340,63); corner region (596,140,194,182), with turn intersection source (629,288). Incoming/outgoing trims are 148/161 source pixels. Corners remain entirely inside the turn cell and do not cut across blocked neighbours.
- Head region (950,156,211,152), tip (1155,232); start region (1220,190,110,83), center (1255,233). Open shaft ports remove the original closed caps. The endpoint uses (1505,133,202,202), uniformly fitted to a 0.86-world-unit square centered on the destination.
- Straight spans stretch only longitudinally between open ports. Corner/head/start modules preserve their source aspect. The artwork has slightly unequal authored port edges; this is calibrated assembly, not a claim of pixel-perfect identical seams at every zoom.
- Range fill and its 50% outer alpha floor are unchanged. Artwork draws above that transparent range at ground height 0.029 with depth testing still enabled, below opaque character pixels. HUD and HP rendering are unchanged.
- New routes fade in using the existing bounded reveal progress; reduced motion shows the complete route immediately. There is no new glow, flicker or moving particle layer. Invalid/cancelled routes clear all modules. Textures are cached and geometry plans update only when the route changes.

The prior procedural ribbon is retained through `ground_overlay.art_route_enabled=false`; missing/invalid atlas dimensions also fall back to it. No gameplay command, BFS, content, character art, animation, speed or native library changes are included.

## Verification

`tests/test_route_art.gd` covers cardinal orientations, straight/one-cell/multiple-turn/reverse routes, empty/start-equals-end and invalid adjacency, module footprint bounds, cached textures, material depth, actual Lua previews, fallback, cancellation, resizing and both scene modes. Optional `AMBER_ROUTE_CAPTURE` writes local screenshots and performs an actual ivory-core pixel visibility check with viewport-to-image scaling. Existing route/range, input confirmation, character and network regressions remain in `tools/test.sh`.

`tests/record_route_art.gd` records actual legal path previews, cancellation, an unreachable cell and confirmed movement in fixed-background and 3D scenes. Its labeled test fixture raises only the test actor's allowed movement budget to eight; shipped content is untouched. Record with Godot Movie Maker `--fixed-fps 60 --write-movie /local/output.avi --resolution 1280x800`. Playback uses normal simulation speed; offline recording throughput is not hardware FPS. Screenshots and video are delivered outside Git. Validation environment is Linux Godot 4.6.3 Compatibility/llvmpipe, not Windows visual execution.

Validation: complete suite exited 0 with 38,586 assertions, five basic network suites, 33 movement network scenarios and the real-network targeting test. Final extra viewport/reselection coverage passed 450 headless route checks and 454 graphical route checks (including four actual ivory-core pixel samples). Both resolutions and render modes were visually inspected. The game recording has 1,350 frames at 60 Hz, 22.5 seconds. New art preserves continuous joins at normal inspected sizes, but the generated source has unequal interface edges and this remains a visual-review candidate rather than a pixel-perfect reference-match claim.
