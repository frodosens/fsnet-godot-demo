# Fixed first-battle asset contract

Map character: 96x128 RGBA PNG, transparent, unpremultiplied; foot pivot (48,120), top safe padding >=8px. Nearest sampling, Sprite3D pixel_size0.01125, canvas world size1.08x1.44 cells, board cell1.0. Do not bake ground/background/text/cast shadow/strong directional light. Assets/characters: knight,archer,mage,raider,scout,brute.png. Static first delivery is not a finished animation set.

Portrait:512x512 RGBA transparent bust;32px safe margin; no typography/frame. assets/portraits/mara,finn,neri,oren,tessa,bram.png. Oren/Tessa/Bram are the stable narrative identities of Raider/Scout/Brute. Missing images have a readable initial/role fallback.

Optional normal maps must match image/pivot, tangent space, linear data. The initial map uses shaded billboard planes with actual directional/point lighting and shadows; it does not pretend flat normals provide sculpted character volume. Stronger per-pixel normal support is a later material extension.

GBA-style battle cut-in is separate from map art:192x160 RGBA frames, foot pivot(96,144), attacker facing right; target can face left. First sword attack24 frames, phases anticipation4/approach4/strike6/recovery4/return4/idle2. Target idle/hit frames separate. No copied Fire Emblem frames, names or art. The runtime can speed/skip presentation; damage/outcome is already determined by shared Lua. Static map sprites are never described as final close-up animation.

Equipment icon suggestion64x64 RGBA,4px safe margin, no names baked in. Deferred until corresponding item IDs/content are settled.
