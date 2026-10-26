extends Range
# Real raster artwork: fill is clipped by TextureProgressBar, never drawn as a flat rectangle.
var kind="hp"
var fill:TextureProgressBar
var frame:TextureRect
func _ready():
    mouse_filter=Control.MOUSE_FILTER_IGNORE
    fill=TextureProgressBar.new();fill.texture_progress=load("res://assets/ui/hud_v3/"+kind+"_fill.png");fill.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;fill.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(fill)
    frame=TextureRect.new();frame.texture=load("res://assets/ui/hud_v3/"+kind+"_frame.png");frame.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;frame.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(frame)
    resized.connect(layout);value_changed.connect(sync.unbind(1));changed.connect(sync);layout();sync()
func layout():
    if not fill:return
    var factor=size.x/320.0
    frame.size=Vector2(320,24);frame.scale=Vector2.ONE*factor
    fill.size=Vector2(312,16);fill.scale=Vector2.ONE*factor;fill.position=Vector2(4,4)*factor
func sync():
    if not fill:return
    fill.min_value=min_value;fill.max_value=max_value;fill.value=value
