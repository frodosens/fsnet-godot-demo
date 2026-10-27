# Adela and Elsbet reserve art candidates

Asset-only pack. No gameplay, story, skills, default lineup or existing character changes.

Per character: one512x512 RGBA portrait; four96x128 diagonal map neutrals with foot anchor(48,120); five192x160 right-facing battle frames with foot anchor(96,144).

Map idle/movement remains same-facing static fallback; no walking or map breathing. Battle idle has two unique frames (450ms each); attack has three unique poses with anticipation reused for recovery (preview350/180/120/180/350ms); hurt has neutral + one new recoil (preview400/180/400ms). Static battle neutral is exactly the same bytes as idle_00 and is deduplicated.

PNG hashes and sequence metadata are in per-character manifests. Raw generation sources, previews, rejected frames and cancelled compositing trials are intentionally excluded. Assets are visually reviewed candidates, not runtime integration acceptance. Do not mirror asymmetrical equipment without review.

Preview ready/settle holds are not combat latency. Per-character manifests include measured weapon-tip/contact/hurt anchors and a separate unverified engineering timing suggestion. Elsbet contact is a high strike (tip y60): align against head/upper-body, never shift the grounded actor down24px to fake torso contact.
