extends RefCounted
# Explicitly select retained assets for legacy loader/fallback tests.
# Shipped selection is covered separately by test_latest_map_policy.gd.
static func apply(app):
    for id in app.hero_map_refresh_previews:app.hero_map_refresh_previews[id]=false
    for id in app.idle_sequence_previews:app.idle_sequence_previews[id]=false
    for key in ["mara_sequence_preview","finn_motion_preview","oren_sequence_preview","bram_sequence_preview","tessa_motion_preview","neri_motion_preview","adela_motion_preview","elsbet_motion_preview","rodd_motion_preview"]:app.set(key,false)
