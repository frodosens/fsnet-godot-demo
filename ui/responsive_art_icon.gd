extends TextureRect
# Select raster detail from physical output size, not logical canvas or OS DPI alone.
var asset_name=""
var large_texture:Texture2D
var small_texture:Texture2D
var using_small=false
var rendered_px=0.0
func _ready():
    large_texture=load("res://assets/ui/hud_v3/"+asset_name+".png")
    var path="res://assets/ui/hud_v3/"+asset_name+"_small.png"
    if ResourceLoader.exists(path):small_texture=load(path)
    update_variant()
func _process(_delta):update_variant()
func update_variant():
    if not is_inside_tree():return
    # CanvasLayer's screen transform does not include Window canvas-items stretch.
    # Window.size is the actual rendering pixel extent, including HiDPI output.
    var window=get_window()
    var logical=window.get_visible_rect().size
    var pixel_scale=Vector2(window.size)/logical
    var transform=get_global_transform_with_canvas()
    rendered_px=minf((transform.x*pixel_scale).length()*size.x,(transform.y*pixel_scale).length()*size.y)
    using_small=small_texture!=null and rendered_px<=20.01
    var desired=small_texture if using_small else large_texture
    if texture!=desired:texture=desired
