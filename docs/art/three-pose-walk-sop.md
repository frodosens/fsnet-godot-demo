# Three-pose character walking: production SOP

## Status and limits

Finn front-right v5 establishes a useful first method: two independent whole-frame edits of the same canonical neutral substantially reduced upper-body popping in the first game comparison. It is **not a fully automatic batch pipeline**. Other directions and a second character still require verification. Eight implemented characters and four diagonal facings are the intended scope; design-only elf/boss and new identities are excluded.

Use **three unique images**, displayed as four beats: `N / L / N / R`. The repeated N is the existing exact neutral, not a fourth drawing. One cycle equals **one actual grid travelled**, chosen by the user. This is a readable stylized gait, not a physically exact continuous footplant simulation.

## 1. Lock sources before making art

- For each character/facing identify the CURRENT accepted neutral in the repository. Record commit, path, Git blob and SHA256. Do not silently substitute an older sprite with similar naming.
- Preserve N byte-for-byte. Record canvas, root, facing, weapon hands, costume and baseline size.
- Inspect retained walk images against CURRENT N before generating. Reuse a pair only if connected opposite legs, identity, equipment and actual transitions pass. Index00/02 or matching hashes do not establish suitability.
- Oren front-right old00/02 were not admitted: opposite legs and consistent sword/shield hands, but old00 lowers the head3px and gear shifts. The current Oren candidate uses two independent edits of the current N instead.

## 2. Make independent step drawings

For a new pair, use the SAME canonical N as the sole character reference for each separate edit. Generate L, review it, then generate R independently from N. Never derive R from generated L, or condition a requested contact on an opposite-contact character image.

Finn's successful preparation: original96x128 RGBA, transparent16px padding on each horizontal side to128x128, then nearest-neighbor8x to1024 square. This prevents an output-aspect change from squashing the character. Preserve exact relative position and transparent margins. Inspect the prepared reference before calling image generation.

Ask for a modest readable lead-leg change while locking head, face, hair, torso, cape, hands, weapon, colors and silhouette. Specify BOTH anatomical ownership and the corresponding image-space leg for this facing. Camera/back views change image-side mapping; never copy Finn's image-side wording blindly to every facing.

Use whole-character host image edits. No local head/chest/limb grafts, whole-body warps/bobbing, runtime IK, weapon mirroring, or external video synthesis. A fresh diagram can guide a leg pose but is not a second character-identity reference.

## 3. Technical registration, never artistic repair

- Keep generated raw outputs and exact prompts privately with source hashes and call count.
- Verify actual output dimensions and alpha; do not trust requested dimensions.
- For square-reference outputs, apply ONE uniform full-canvas resize back to128 square, then remove the original16px horizontal padding. Do not fit each figure's bounding box separately.
- Finn v5 used nearest-neighbor resampling and discarded alpha below8 before resize. Record this threshold; it is technical normalization, not a universal artistic requirement. Never remove meaningful pixels to conceal defects.
- Do not translate each frame to make the lowest sole equal120. Fixed root registration must survive across the cycle; bottom alignment can erase intended leg motion.
- Save independent candidate files. Never overwrite canonical N or an accepted baseline during a trial.

## 4. Visual acceptance checklist

Review N/L/N/R at native size, then nearest3x:

- [ ] Same face/hair, torso size, cape, weapon shape, palette and position; no conspicuous head/gear pop.
- [ ] Hip→knee→ankle→boot attachments show opposite advancing legs; no inverted phase, detached ankle, merged boots or knee-high kick.
- [ ] Shoulder→elbow→hand remains connected. Advancing left leg normally pairs with free right arm forward, and vice versa. A weapon/shield-holding arm can remain restrained; do not claim full counter-swing if absent. Never swap weapon hands to obtain a pose.
- [ ] Transparent margins and feet survive the renderer. For current96x128/root(48,120), inspect alpha thresholds and last occupied row explicitly. Bbox bottom121 means occupied y120, not121. A conservative opaque sole limit is y119; y120 requires actual engine inspection. Never crop/re-align to fake a pass.
- [ ] No drift hidden by independently aligning head, body or feet. Numeric ROI metrics are diagnostics, not substitutes for the normal-size viewing gate.

Document intended stance leg, visible sole landmarks with uncertainty, held-object hand, alpha extrema, bbox, hashes and registration. Record deviations honestly; generated edits are not pixel-identical.

## 5. Runtime contract and real-route gate

Phase is accumulated **actual post-collision distance in grid units modulo1**, not elapsed time or an earlier art-derived stride estimate. Beats are N at0, L at.25, N at.5, R at.75. Do not advance while blocked. Current nominal timings differ: fixed-background grid≈.8s, 3D grid≈1s. Keep path and speed authoritative.

Test exact canonical N at stop and full-grid turns; interruptions, skip/accelerated travel and direction changes must not reveal another identity or leave a step frozen. Check all four facings once they exist. Compare baseline and candidate on the same route at ordinary display size in BOTH fixed-background and3D modes, including feet/depth/shadows. Keep depth testing enabled.

Held drawings inherently slip between changes. Separate per-hold root travel from stance-landmark drift; do not claim zero sliding. Camera ground slope is approximately.7071 for the measured configuration, not a best-fit line through generated feet. Do not alter gameplay speed or camera to make art appear correct.

Only after art review and real-route tests pass should intended runtime PNGs and compact provenance/geometry metadata be staged for engineering review. Keep screenshots, GIFs, videos, raw generations, prompts and private machine paths out of the runtime repository. Preserve remote changes. Candidate staging is not default activation or production acceptance.

## 6. Bounded refinement and lessons

- A closest SAME-PHASE reference is appropriate for a small correction to an already accepted pose; it is not a substitute for canonical-N identity conditioning when building a new pair.
- Earlier opposite-contact conditioning inverted the requested contact; repeated atlas prompts often produced the same half-cycle. Do not multiply such outputs across characters.
- Finn v5 used one L and one R generation independently from N. This successful example does not imply a guaranteed two-call yield for every character.
- Optional arm-swing trial: one whole-frame edit from v5L shifted the free hand modestly but also redrew head/hair and boot contours. The visible benefit was insufficient; stopped before R and retained v5. The user subsequently abandoned further arm-swing experiments; keep the baseline held-arm method. Do not reintroduce body pop for a marginal swing.
- Stop on a failed invariant, save evidence and choose a distinct bounded strategy rather than endless same-prompt retries. Keep the known-good baseline.

## Batch gate

Finish Finn's runtime checks, then verify a second character before declaring the method batch-validated. Thereafter process one character/facing pair at a time using the same checklist. Track each as source-verified, generated/reused, art-reviewed, runtime-tested and accepted separately. Human visual review remains part of production.

## Tool reproducibility

`tools/art/register_walk_frame.py` requires Python 3, Pillow and NumPy (optional development requirements in `tools/art/requirements.txt`; no game runtime dependency). It refuses existing output/receipt files and writes PNG exclusively. Tests use synthetic transparent images, not reconstructed generator outputs. Raw generated source images and exact instantiated prompts are not in this repository: their recorded hashes identify provenance, but the repository alone cannot regenerate those original images. The script only reproduces technical normalization when the corresponding raw source is available.
