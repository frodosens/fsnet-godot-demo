# Existing-content generated UI icons

Complete14-asset runtime pack:4 existing skills (rally,strong_shot,ember,focus_bolt),bandage,and9 equipment bases (sword,wand,shield,helm,coat,gloves,boots,charm,ring). This does not introduce or modify game content.

All PNGs are128x128 RGBA,intended for32/40 logical pixels. Each was generated using approved UI references,then alpha-cleaned,cropped and uniformly normalized. No screenshot pixel extraction or scripted art drawing.

content-map.json binds existing IDs to relative filenames; healing_draught effect reuses bandage. Normal attack uses the existing generic action sword. Unknown mod IDs retain text fallback.

manifest.json contains source/PNG/prompt hashes,transformations,provenance and staticQA; prompts.json preserves generation requests. Full source originals and review images remain local,not runtime Git content.

Verified here:sourceSHA,PNG decode,RGBA,128px dimensions,transparent outer borders,static32/40px appearance and Git blobSHA. No fresh Godot import,screen-context/gameplay QA or accessibility certification is claimed.
