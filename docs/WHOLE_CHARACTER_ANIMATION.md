# Active animation route: whole-character sprite frames

The user withdrew the layered/IK experiment. Runtime no longer constructs its SubViewport, calls its solver, or exposes its pause-menu switch. Original code/assets and historical evidence are retained, not repurposed as supposedly generated whole-character frames.

`view/unit_motion.gd` is again the sole map-walk presentation route: authored whole-character PNG sequences, phase driven by travelled distance, with presentation speed = stride × frame rate / frame count. Logical commands, paths, shared state, lighting, character scale, and the latest thinner overhead HP remain unchanged.

Current Mara back-right art is the previously published sequence. Its known ankle/stance quality problem is **not claimed fixed** by removing IK. Fresh source-generated whole-character frames are pending art review. They must show a coherent contact/pass/opposite-contact/pass cycle, stable character registration, normal knees/boots, and consistent camera angle. IK renders will not be baked and labelled as new source frames.

Historical IK capture/test scripts require revision `1de1f134d674a9292a6bf62ad5e6ed18aff94828`; they are excluded from the active test suite. Existing motion, distance/phase, cancellation, input and networking tests remain active.
