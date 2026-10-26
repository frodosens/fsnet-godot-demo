# Pending art UI and directional sprite contract

The user approved the restrained low-saturation pixel-art v2 mockup. Art UI integration awaits the actual art branch assets. Existing controls remain functional; current StyleBox theme is a functional layout, not finished art design.

Base viewport: 1280×800, canvas-items scaling, native text/buttons retained. Suggested isolated transparent texture assets, no baked labels:
- Main menu background: 1920×1200 (16:10), crop-safe central1280×800 composition. Title art optional separate; no button/text baked into production background.
- Large parchment panel: 512×256 RGBA, nine-patch margins32 each; corners/ornament inside32px, flat/repeat-safe central stretch area. Current menu card and battle dialogue can share this material if the approved design calls for it.
- Button normal/hover/pressed/disabled: each384×96 RGBA, nine-patch margins24 left/right,20 top/bottom. Content must remain legible after horizontal stretch; native localized text centered with16px minimum inset.
- Dialogue panel: 1240×224 displayed at(20,558); optional bespoke1240×224 decoration with nine-patch48px sides/32px vertical. Portrait slot164×184 displayed, actual portrait140×160 keep-aspect (512² source).
- Top battle bar:1240×64 at(20,16), party panel210px wide at(20,98), action/log panel1006×172 at(254,610). If ornate margins require more than16px content inset, agree a layout revision before generating final assets.
- Small icons:64×64 RGBA, visible shape inside48×48; displayed24–32px. Move/attack/skill/item/save/back/pause, no words baked in.

Directional map sprites: six stable character IDs mara/finn/neri/oren/tessa/bram; each has four independently drawn frames (no mirrored substitute),96×128 RGBA, foot anchor(48,120), identical scale and empty padding. Accepted worker paths `assets/sprites/directional/{role}_{front,back,left,right}.png`; role mapping knight/archer/mage/raider/scout/brute corresponds to stable IDs mara/finn/neri/oren/tessa/bram.

Directions are **screen-facing appearances**, selected from a projected world movement vector; not fixed world north/east because camera is oblique. Positive screenX→right, negative→left, positive screenY→front (toward viewer), negative→back. Use dominant projected axis. Current camera projects worldX and worldZ diagonally. Movement/attack updates local presentation facing, standing retains it. Facing is excluded from shared rules hash and never changes attack legality. New clients/restores may choose a deterministic default facing before the next action; any exact visual-resume facing can live in local presentation save data. No movement animation claim from four static direction frames.

Next screenshot should show approved art UI and actual four-direction sample when supplied; do not resend current programmatic layout as an art-complete result.

For the current camera, +worldX maps right, -worldX left, +worldZ front, -worldZ back. Runtime projects the vector rather than hardcoding this assumption. Direction assets are still pending delivery; fallback remains the existing static sprite.
