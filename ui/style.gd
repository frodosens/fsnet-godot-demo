extends RefCounted
static var font
const INK=Color("302d28")
const PAPER=Color("f0e5cb")
const GOLD=Color("b68b44")
static func make_theme():
    if not font:
        var base=FontFile.new()
        base.data=FileAccess.get_file_as_bytes("res://assets/fonts/NotoSansCJK-Regular.ttc")
        font=FontVariation.new();font.base_font=base;font.variation_face_index=2
    var t=Theme.new();t.default_font=font;t.default_font_size=18
    for kind in ["Label","Button","CheckButton","LineEdit","TextEdit","OptionButton","SpinBox"]:t.set_color("font_color",kind,INK)
    t.set_stylebox("panel","PanelContainer",box(PAPER,GOLD,12))
    for kind in ["Button","OptionButton"]:
        t.set_stylebox("normal",kind,box(Color("e6d7b5"),Color("bc9b64"),7))
        t.set_stylebox("hover",kind,box(Color("f8e7ba"),GOLD,7))
        t.set_stylebox("pressed",kind,box(Color("d5ba83"),Color("91682e"),7))
        t.set_stylebox("disabled",kind,box(Color("d8d1bf"),Color("b6af9f"),7))
        t.set_stylebox("focus",kind,box(Color(0,0,0,0),Color("855d29"),7,3))
        t.set_color("font_disabled_color",kind,Color("888275"))
        for state in ["font_hover_color","font_focus_color","font_pressed_color","font_hover_pressed_color"]:t.set_color(state,kind,INK)
    for kind in ["LineEdit","TextEdit"]:
        t.set_stylebox("normal",kind,box(Color("fff8e8"),Color("bca77f"),5))
        t.set_stylebox("focus",kind,box(Color("fff8e8"),GOLD,5,2))
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
    if FileAccess.file_exists(path):
        var img=Image.load_from_file(path)
        if img:control.texture=ImageTexture.create_from_image(img)
    return control
