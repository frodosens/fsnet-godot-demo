# User-flow audit — 2026-10-26

Functional scope is a bounded playable prototype, not a finished commercial game. The latest user priority is contact-correct combat presentation, contextual game UI with portraits, and shared-rule movement-path preview; existing functions remain supported.

| Requested feature | Working implementation | Remaining boundary |
|---|---|---|
| Friendly/enemy AI | Separate faction/controller; offensive, defensive leash, support heal and escort policies submit the same legal action pipeline | Offensive policy uses ordinary attacks; no general offensive-skill/item scoring, formations or tactical search |
| Battle objectives | Bounded all/any, defeat-all, ally-loss, protected-unit loss, reach and survive; failure wins ties | `protect` is a loss predicate, intended for defeat conditions; no interactive visual objective-tree builder or scenario scripting |
| Skills/items | Target relation, LOS/range, MP, cooldown, charges, stationary-only, damage/heal AoE; consumable quantity and same ability validation | Only damage/heal effect operations; no status durations, displacement, environmental effects or consumable loot |
| Equipment | Nine slots, bag, derived stats, base/affix/quality/unique/two-piece set data, deterministic victory roll; extra movement and mobile-cast traits | Small sample library; no trading/selling, stash, multi-battle progression or broad triggered-effect catalog; comparison is current item versus bag descriptions, not a full calculated delta UI |
| Mod/editor | Terrain/spawns, recursive forms, JSON import/validation, save/reload/play; data hash and budget validation | Empty-list templates and structural array changes may require JSON; map size and complex target trees lack bespoke tools; no custom code/assets import |
| Story/save | Intro/round/terminal events, portraits, local cursors, offline atomic slots, validation and incompatible-version feedback | No migration, campaign branching or server durable save; auto slot is save-and-leave, not periodic autosave |
| Network | Real local fsnet server plus clients, ordered deterministic Lua, content/rules binding, checkpoint+replay reconnect; shared team controls | Loopback only, no per-player unit ownership, lobby discovery, public hosting, identity/anti-cheat or durable host recovery |
| Art/presentation | V2 art skin, authored portraits/environment, partial elevated sprites/walk, three attacks against Oren | All-role elevated/attack/hit sets pending; user rejected fixed-distance melee and software-like action layout, now being corrected explicitly |

## Confirmed defects fixed in this audit

- Editor raw JSON was lost on menu roundtrip despite claiming an in-memory draft. Raw and validated draft are now retained separately; reloading/importing over edits requires an actual confirmation. Invalid unfinished text also survives the roundtrip.
- Story chapter title/ID were not validated although narrator UI reads them. Invalid content now fails before loading a scene.
- HUD described skills by hardcoded role instead of actual Mod definitions. Names/effects now come from content; item target/cost hints use the referenced ability.
- Supported large party/item lists could extend beyond the viewport. Scroll containers bound these lists. Friendly AI is visibly noncontrollable; player-controlled units are selectable independently of ally classification; gear picks an actual player controller rather than assuming index0.

These repairs do not claim the current UI layout meets the user's new production-art acceptance. That redesign is a separate active priority, preserving the corrected data behavior.
