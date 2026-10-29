class_name Style
extends RefCounted
static var font
const INK=Color("e4dcc5")
const PAPER=Color("293432")
const GOLD=Color("ce9a57")
static func make_theme():
    if not font:
        var base=FontFile.new()
        base.data=FileAccess.get_file_as_bytes("res://assets/fonts/NotoSansCJK-Regular.ttc")
        font=FontVariation.new();font.base_font=base;font.variation_face_index=2
    var t=Theme.new();t.default_font=font;t.default_font_size=18
    for kind in ["Label","Button","CheckButton","LineEdit","TextEdit","OptionButton","SpinBox"]:t.set_color("font_color",kind,INK)
    t.set_stylebox("panel","PanelContainer",generated_skin("panels/action-dock.png"))
    for kind in ["Button","OptionButton"]:
        t.set_stylebox("normal",kind,generated_skin("buttons/normal.png"))
        t.set_stylebox("hover",kind,generated_skin("buttons/selected.png"))
        t.set_stylebox("pressed",kind,generated_skin("buttons/selected.png",Color(0.9,0.9,0.9)))
        t.set_stylebox("disabled",kind,generated_skin("buttons/disabled.png"))
        t.set_stylebox("focus",kind,generated_skin("buttons/selected.png"))
        t.set_color("font_disabled_color",kind,Color("777f77"))
        for state in ["font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color"]:t.set_color(state,kind,INK)
    for kind in ["LineEdit","TextEdit"]:
        t.set_stylebox("normal",kind,generated_skin("buttons/normal.png"))
        t.set_stylebox("focus",kind,generated_skin("buttons/selected.png"))
        t.set_color("caret_color",kind,INK)
    for kind in ["PopupMenu","Window","AcceptDialog"]:
        t.set_stylebox("panel",kind,generated_skin("panels/action-dock.png"))
    t.set_stylebox("hover","PopupMenu",generated_skin("buttons/selected.png"))
    t.set_color("font_color","PopupMenu",INK)
    t.set_color("font_hover_color","PopupMenu",INK)
    small_controls(t)
    return t
static func generated_skin(path,tint=Color.WHITE):
    var style=StyleBoxTexture.new();style.texture=load("res://assets/ui/bottom_dock_reference/"+path);style.modulate_color=tint
    for side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:style.set_texture_margin(side,12)
    style.content_margin_left=18;style.content_margin_right=18;style.content_margin_top=12;style.content_margin_bottom=12
    return style
static func box(fill,border,radius=8,width=1):
    var b=StyleBoxFlat.new();b.bg_color=fill;b.border_color=border;b.set_border_width_all(width);b.set_corner_radius_all(radius)
    b.content_margin_left=16;b.content_margin_right=16;b.content_margin_top=10;b.content_margin_bottom=10
    return b
static func label(text,size=18,color=INK):
    var n=Label.new();n.text=text;n.add_theme_font_size_override("font_size",size);n.add_theme_color_override("font_color",color);return n
static func button(text,action):
    var b=Button.new();b.text=text;b.custom_minimum_size=Vector2(0,44);b.pressed.connect(action);return b
static func paragraph(text,width=450):
    var l=label(text);l.custom_minimum_size.x=width;l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;return l
static func column(parent,separation=10):
    var c=VBoxContainer.new();c.add_theme_constant_override("separation",separation);parent.add_child(c);return c
static func portrait(id,size=128):
    var control=TextureRect.new();control.custom_minimum_size=Vector2(size,size);control.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;control.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    var path=preload("res://view/reserve_art.gd").portrait_path(id)
    if ResourceLoader.exists(path):control.texture=load(path)
    return control

static func skin(name,tint=Color.WHITE,xmargin=32,ymargin=32):
    var style=StyleBoxTexture.new();style.texture=load("res://assets/ui/v2/"+name+".png");style.modulate_color=tint
    for side in [SIDE_LEFT,SIDE_RIGHT]:style.set_texture_margin(side,xmargin)
    for side in [SIDE_TOP,SIDE_BOTTOM]:style.set_texture_margin(side,ymargin)
    style.content_margin_left=16;style.content_margin_right=16;style.content_margin_top=10;style.content_margin_bottom=10
    return style
static func menu_button(text,action):
    var control=preload("res://ui/menu_button.gd").new();control.text=text;control.pressed.connect(action);return control

# Derived from the bundled OFL font; no external font dependency.
static func impact_font():
    make_theme()
    var face=FontVariation.new();face.base_font=font;face.variation_embolden=0.3
    face.spacing_glyph=2
    return face

static var portrait_regions={}
static func framed_portrait(id):
    if portrait_regions.has(id):return portrait_regions[id]
    var path=preload("res://view/reserve_art.gd").portrait_path(id)
    if not ResourceLoader.exists(path):return null
    var texture=load(path);var image=texture.get_image();var bounds=image.get_used_rect()
    # Retain all nontransparent pixels, removing delivery padding rather than stretching the face.
    var atlas=AtlasTexture.new();atlas.atlas=texture;atlas.region=bounds;atlas.filter_clip=true
    portrait_regions[id]=atlas;return atlas

static func control_texture(name):
    return load("res://assets/ui/bottom_dock_reference/controls/"+name+".png")
static func control_track(name,margins,tint=Color.WHITE):
    var style=StyleBoxTexture.new();style.texture=control_texture(name);style.modulate_color=tint
    for side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:style.set_texture_margin(side,margins[side])
    return style
static func small_controls(t):
    for kind in ["CheckBox","CheckButton"]:
        for checked in ["checked","unchecked"]:
            t.set_icon(checked,kind,control_texture("checkbox_"+checked))
            t.set_icon(checked+"_disabled",kind,control_texture("checkbox_"+checked))
        t.set_color("font_disabled_color",kind,Color("a4aaa4"))
        for state in ["normal","hover","pressed","hover_pressed","focus"]:
            t.set_stylebox(state,kind,generated_skin("buttons/selected.png" if state=="focus" else "buttons/normal.png"))
    for state in ["slider","grabber_area","grabber_area_highlight"]:t.set_stylebox(state,"HSlider",control_track("slider_track",[4,2,4,2]))
    for state in ["grabber","grabber_highlight","grabber_disabled"]:t.set_icon(state,"HSlider",control_texture("slider_thumb"))
    for state in ["scroll","scroll_focus"]:t.set_stylebox(state,"VScrollBar",control_track("scrollbar_track",[2,4,2,4]))
    for state in ["grabber","grabber_highlight","grabber_pressed"]:t.set_stylebox(state,"VScrollBar",control_track("scrollbar_thumb",[2,4,2,4],Color(1.1,1.1,1.1) if state!="grabber" else Color.WHITE))
    for direction in ["up","down"]:
        t.set_icon("increment" if direction=="down" else "decrement","VScrollBar",control_texture("indicator_"+direction))
    t.set_icon("arrow","OptionButton",control_texture("indicator_down"))
    t.set_icon("submenu","PopupMenu",control_texture("indicator_right"))

static var content_icons={}
static func content_icon(category,id):
    var key=category+":"+id
    if content_icons.has(key):return content_icons[key]
    var path=""
    if key=="skill:attack":path="res://assets/ui/bottom_dock_reference/icons/icon_attack.png"
    else:
        var base="res://assets/ui/bottom_dock_reference/content/"
        var mapping=JSON.parse_string(FileAccess.get_file_as_string(base+"content-map.json"))
        if mapping.has(key):path=base+mapping[key]
    var texture=load(path) if not path.is_empty() and ResourceLoader.exists(path) else null
    content_icons[key]=texture;return texture
static func decorate_content(button,category,id):
    button.icon=content_icon(category,id)
    button.expand_icon=true;button.add_theme_constant_override("icon_max_width",32)
    button.add_theme_constant_override("h_separation",12)
    button.icon_alignment=HORIZONTAL_ALIGNMENT_LEFT
    button.add_theme_color_override("icon_disabled_color",Color(0.82,0.82,0.82,1))
    button.set_meta("content_icon_key",category+":"+id)
    return button
