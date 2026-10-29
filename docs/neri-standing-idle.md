# Neri standing idle correction

Based on the reviewed combined candidate d60f127. Two source-frame-zero images replace only Neri's static idle references in four facings. Right views mirror their corresponding left view; the 160 canvas, root (80,144), body scale, current walk frames/weights/cadence and every other character remain unchanged. Original idle files are retained. New image bytes match art commit acce3739113491337a37d4b56b67f5e333034632; external provider task metadata is omitted from the consumed receipt.

The selected pose has uncrossed feet. All nontransparent pixels end at or above y144, unlike the previous crossed-legs pose. This is a static held pose, not a breathing loop. Source styling differs slightly from the later generated walking frames; stopping can therefore show a style change. No per-frame deformation or depth-disable is added.

Focused tests cover both resolutions and fixed/3D views, exact image/flip/root/scale, ghost and health placement, unchanged-state Runtime replacement, legal movement and stop/skip. Existing hero sequence, latest-policy and character-details tests are retained. Real network directions are checked separately. Linux only; no Android/Windows hardware claim. No screenshots or recordings are committed.
