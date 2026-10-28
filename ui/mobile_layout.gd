extends RefCounted
# Safe rectangles are in viewport coordinates. Scene cameras never consume UI offsets.
static func safe_rect(viewport, enabled=false, physical_override=Rect2i()):
    var full=viewport.get_visible_rect()
    if not enabled:return full
    var physical=physical_override
    if physical.size==Vector2i.ZERO:
        if not OS.has_feature("android"):return full
        physical=DisplayServer.get_display_safe_area()
    if physical.size.x<=0 or physical.size.y<=0:return full
    var logical=viewport.get_screen_transform().affine_inverse()*Rect2(physical)
    var clipped=full.intersection(logical)
    return clipped if clipped.has_area() else full
