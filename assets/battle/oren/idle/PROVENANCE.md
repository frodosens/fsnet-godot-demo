# Oren LEFT-facing defensive idle candidate

Host-native image_gen reference edit; original nearest-neighbor8x input, output full-canvas nearest-neighbor192x160 normalization. No pose warping, attack/hurt edits, or demo media in Git. Engine mapping pending; this source is not the separate attack idle.

## Exact prompt and metrics

Edit this exact image very conservatively. This is an 8x nearest-neighbor enlargement of an existing tiny game battle sprite, Oren. Keep the existing enlarged pixel blocks, no smoothing, detail enhancement, redesign, or anatomy reinterpretation. Preserve exact transparent canvas layout and occupancy. ONE same older gray-haired bearded male soldier faces LEFT, carrying same round wooden shield and short sword angled down-left. Change ONLY within the dark olive chest tunic, brown shoulder armor, and neck collar: redraw tiny inhalation, raising collar and upper chest fold ONE original pixel block (8 image pixels), with lower chest/belt fixed. Shoulder upper glint may rise ONE original pixel block. Keep head and face nearly unchanged. DO NOT move either boot, legs, knees, pelvis, sword, shield, hands, elbows, or silhouette outline. Do not change weapon lengths, grip, stance, physical scale, palette, costume, face, or direction. Rest of input should look copied exactly. One complete character only. Same image aspect ratio, same position, same margins. Actual transparent background remains transparent, no ground shadow. Almost no perceptible change except tiny internal chest/shoulder inhalation.
{
  "neutral": {
    "bbox": [
      59,
      40,
      130,
      143
    ],
    "foot_left": [
      66,
      130,
      85,
      143
    ],
    "foot_right": [
      114,
      130,
      128,
      143
    ]
  },
  "inhale": {
    "bbox": [
      58,
      39,
      130,
      144
    ],
    "foot_left": [
      66,
      130,
      85,
      144
    ],
    "foot_right": [
      113,
      130,
      128,
      144
    ]
  },
  "original_git_blob": "2bef9cb406ef1361fd2e379a9c63651d860d6eab",
  "source_sha256": "a799601265ccab72a7843a5100536272bfd4c88dc0bd11b2abf3d149d8cfa8db",
  "runtime_sha256": "8c452655955b82290ee0747c6041548806e3d8dc6d83f55117f06281430d5ce1",
  "status": "awaiting_visual_review"
}