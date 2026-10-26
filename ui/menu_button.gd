extends Button
func _ready():
    alignment=HORIZONTAL_ALIGNMENT_LEFT
    if custom_minimum_size==Vector2.ZERO:custom_minimum_size=Vector2(320,56)
    if not has_theme_font_size_override("font_size"):add_theme_font_size_override("font_size",28)
    var UI=preload("res://ui/style.gd")
    for state in ["normal","hover","pressed","disabled","focus"]:
        var path="disabled" if state=="disabled" else ("normal" if state=="normal" else "selected")
        var skin=UI.generated_skin("buttons/"+path+".png")
        skin.content_margin_left=24
        add_theme_stylebox_override(state,skin)
    mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
    focus_entered.connect(queue_redraw);focus_exited.connect(queue_redraw)
