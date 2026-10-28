# Previously accepted map animation defaults

This candidate enables the existing Oren, Bram, Tessa and Adela map options for
fresh configuration and missing keys. Existing explicit OFF values remain OFF;
there is no migration or rewriting of saved choices. The existing settings give
independent rollback. Mara/Finn/Neri V2 defaults, legacy Finn/Neri preferences,
portraits, combat, chapters, rules and movement timing are unchanged.

No assets are generated, modified or replaced. Review uses the admitted runtime
frames, not a new examination of the original provider videos.

- Oren: four directions, 128 square/root(64,120); 48-tick idle and 42-weight walk,
  the latter maps to one grid. Existing render scale 1.05 applies once. Known
  torso bend and shuffle remain; this is the accepted provisional animation.
- Bram: four directions, 128 square/root(64,120); 41-tick idle and 23-weight walk.
  Accepted gestures/turning and shuffle remain. Some shoe pixels reach y123.
- Tessa: four independent movement directions, 128x136/root(64,120), 24-weight
  walk. Existing idle is unchanged. Front-facing extended feet can be trimmed by
  ground depth; extra canvas padding is not a depth-occlusion fix.
- Adela: two source directions, 128 square/root(64,120), right facings mirrored,
  25-weight walk. Existing idle stays unchanged; handedness/style can change
  when stopping. Mirror state must reset on idle and other characters.

Legacy tests assumed unrelated characters always used unmirrored static art or
had default-OFF settings. They now compare the actual unrelated actor state
before/after the tested toggle. This preserves isolation coverage while allowing
the already shipped hero V2 defaults and these accepted defaults.

Validation uses isolated user directories, the existing Linux bridge, real legal
Lua moves, graphical scene tests and authority/client synchronization. No claim
of Android device verification, new gait quality or completion of all remaining
characters is made. Diagnostic images/logs stay local and are not Git assets.

Focused validation: 23,177 assertions across eleven Oren/Bram/Tessa/Adela
headless scripts, 142 Finn isolation assertions, 31 preference assertions plus
five checks in a separate restart process, and 356 source integrity checks.
Four directions per actor passed sixteen real authority/client movement cases,
each with 31 Runtime replacements and no replay. Graphical regression exercises
the existing scene suites plus actual settings mouse/keyboard input. The prior
accepted visual limitations remain; changing defaults does not improve them.
