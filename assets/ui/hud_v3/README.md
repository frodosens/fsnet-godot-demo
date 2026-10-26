# Amber Bridge HUD v3 raster components

Original raster artwork generated with built-in image generation, then cropped using alpha > 80 visible bounds with 12 source-pixel padding and nearest-neighbor normalized. No procedural replacement artwork, recoloring, background painting, or alpha thresholding. Very low-alpha original edge pixels are retained; test at intended native UI scale, not enlarged.

- HP/MP: frame 320x24 to logical 160x12. Fill is a separate 312x16 texture to logical 156x8 at offset (2,2), beneath frame. Clip filled texture horizontally to current/max; do not draw a programmatic progress rectangle. Shared brass frame geometry deliberately keeps both meters aligned. Center remains transparent.
- Frame horizontal nine-patch cap margins source L/T/R/B: 20/4/20/4; scale at nominal size preferentially. Fill cap width 8 source pixels if stretched; progress uses clipping, not horizontal rescale.
- Action menu: 96x96 selected/unselected diamond textures to 64x64 logical. No nine-patching for diamonds; selected/unselected need identical centered Control rect. Icon sits at center, text/hotkeys native outside.
- Main portrait: 128x160, open center, minimal sides and brass underline. Ally frame: 48x60; draw portrait below frame.
- Property icons: heart, crystal, boot, fourpoint action spark. Render property icons at 20x20 logical; action menu icons at 28x28 logical. Nearest filtering.
- No values, labels, hotkeys, names or numbers baked. Preserve native localization and dynamic values. Movement/action values and selection animation remain native UI.
- Assets are components, not a complete HUD screenshot or proof of engine integration. Layout, binding and animation require in-engine QA.

Manifest includes source and logical sizes, center anchors, crop bounds, and nine-patch guidance. Selected/unselected appearance differences are artwork; animate position/scale/opacity natively rather than generating animation frames.
