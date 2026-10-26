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
    t.set_stylebox("panel","PanelContainer",skin("panel",Color.WHITE,32,32))
    for kind in ["Button","OptionButton"]:
        t.set_stylebox("normal",kind,skin("button",Color.WHITE,24,20))
        t.set_stylebox("hover",kind,skin("button",Color(1.15,1.15,1.10),24,20))
        t.set_stylebox("pressed",kind,skin("button",Color(0.8,0.85,0.8),24,20))
        t.set_stylebox("disabled",kind,skin("button",Color(0.65,0.65,0.65),24,20))
        t.set_stylebox("focus",kind,box(Color(0,0,0,0),GOLD,0,1))
        t.set_color("font_disabled_color",kind,Color("777f77"))
        for state in ["font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color"]:t.set_color(state,kind,INK)
    for kind in ["LineEdit","TextEdit"]:
        t.set_stylebox("normal",kind,box(Color("202b29"),Color("59624b"),5))
        t.set_stylebox("focus",kind,box(Color("202b29"),GOLD,5,2))
        t.set_color("caret_color",kind,INK)
    return t
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
    var path="res://assets/portraits/"+id+".png"
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
