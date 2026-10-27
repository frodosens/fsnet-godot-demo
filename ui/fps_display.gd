extends CanvasLayer
# Engine-reported rendered frame rate; not GPU time or a network/logic tick rate.
var label:Label
var elapsed=0.0
func _ready():
    layer=100
    process_mode=Node.PROCESS_MODE_ALWAYS
    label=Label.new();label.name="FPSLabel";label.text="FPS —"
    label.mouse_filter=Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size",16)
    label.add_theme_color_override("font_color",Color.WHITE)
    label.add_theme_color_override("font_outline_color",Color.BLACK)
    label.add_theme_constant_override("outline_size",4)
    label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
    add_child(label)
    label.anchor_left=1;label.anchor_right=1
    label.offset_left=-116;label.offset_right=-8;label.offset_top=0;label.offset_bottom=22
func _process(delta):
    elapsed+=delta
    if elapsed<0.5:return
    elapsed=0.0
    label.text="FPS %d"%Engine.get_frames_per_second()
