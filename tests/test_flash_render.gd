extends SceneTree
func _initialize():call_deferred("run")
func run():
    assert(DisplayServer.get_name()!="headless")
    var texture=load("res://assets/battle/ranged_magic/runtime/finn/00_idle.png")
    var plain=TextureRect.new();plain.texture=texture;plain.position=Vector2(20,20);root.add_child(plain)
    var flashed=TextureRect.new();flashed.texture=texture;flashed.position=Vector2(240,20);var shader=ShaderMaterial.new();shader.shader=load("res://view/hit_flash.gdshader");flashed.material=shader;root.add_child(flashed)
    for i in range(5):await process_frame
    await RenderingServer.frame_post_draw
    var image=root.get_texture().get_image();var matches=0
    for y in range(40,140,5):
        for x in range(65,135,5):
            assert(image.get_pixel(x+20,y+20).is_equal_approx(image.get_pixel(x+240,y+20)))
            matches+=1
    shader.set_shader_parameter("flash_strength",1.0)
    for i in range(3):await process_frame
    await RenderingServer.frame_post_draw
    image=root.get_texture().get_image()
    var white=image.get_pixel(240+95,20+90)
    assert(white.r>0.9 and white.g>0.9 and white.b>0.9)
    print("FLASH_GPU_PASS equal_unflashed_pixels=",matches," victim_only_white=true")
    quit()
