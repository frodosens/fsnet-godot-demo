AMBER BRIDGE — FOUR-DIRECTION STATIC MAP SPRITES, BATCH 01

24 independently illustrated view assets: six characters, four views each.
Not walk cycles, attack animation, or engine-validated final release art.

Names: knight=Mara, archer=Finn, mage=Neri, raider=Oren,
scout=Tessa, brute=Bram.

View meaning is image/camera relative: front faces toward viewer;
back faces away; left faces image-left; right faces image-right.
These names do not encode world north/east/south/west; runtime must map
camera-relative facing explicitly. Never mirror a sprite to change facing.

Runtime: 96x128 RGBA PNG, feet pivot (48,120), nearest filtering.
Use transparent alpha; no cast ground shadows or directional light baked in.
Source sheets retained without alteration. Built-in imagegen generated each
character's four-view sheet using the project's original map/portrait art.
Only user-authorized crop, nearest resize and foot alignment were scripted.
normalize.py reproduces runtime preparation and the labeled QA contact sheet.

Weapons remain anatomical-right for Mara/Oren swords, Neri staff, Tessa
blade and Bram work hammer. Finn bow remains anatomical-left. Near/far
occlusion differs across profiles. Original source candidates and revision
prompts are retained for provenance; runtime uses approved latest source.

Visual QA: inspect actual full source and normalized contact sheet for back
anatomy, asymmetry/handedness, clothing identity and unobstructed silhouettes.
Technical QA: 24 unique images, actual alpha and transparent borders, correct
size, no horizontal-mirror equivalence. Integration lighting/camera QA pending.
