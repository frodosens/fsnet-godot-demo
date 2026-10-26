extends Control
const UI=preload("res://ui/style.gd")
const Content=preload("res://logic/content.gd")
const Grid=preload("res://ui/editor_grid.gd")
var data={}
var raw
var grid
var feedback
var brush
var unit_picker
var mod_picker
var saved_hash=""
var transitioning=false
func _ready():
    theme=UI.make_theme()
    var bg=ColorRect.new();bg.color=Color("202b29");bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(bg)
    var outer=PanelContainer.new();outer.position=Vector2(20,18);outer.custom_minimum_size=Vector2(1240,762);add_child(outer)
    var col=UI.column(outer,10)
    var bar=HBoxContainer.new();bar.add_theme_constant_override("separation",10);col.add_child(bar)
    var heading=UI.label("关卡工坊",26);heading.size_flags_horizontal=Control.SIZE_EXPAND_FILL;bar.add_child(heading)
    bar.add_child(UI.button("内容表单",open_forms))
    bar.add_child(UI.button("导入 JSON",import_dialog))
    bar.add_child(UI.button("保存 Mod",save_mod))
    bar.add_child(UI.button("试玩",play))
    bar.add_child(UI.button("返回",request_back))
    col.add_child(UI.paragraph("左侧绘制地形或放置单位。右侧可修改单位属性、剧情台词与触发、胜败条件、装备底材/词缀/掉落表。只接受数据，不执行外部 Lua。",1170))
    var controls=HBoxContainer.new();controls.add_theme_constant_override("separation",12);col.add_child(controls)
    brush=OptionButton.new()
    for name in ["草地 G","河水 W","石桥 B","障碍 X","单位出生点"]:brush.add_item(name)
    controls.add_child(brush)
    unit_picker=OptionButton.new();controls.add_child(unit_picker)
    controls.add_child(UI.button("应用 JSON 并校验",apply_json))
    mod_picker=OptionButton.new();mod_picker.custom_minimum_size.x=180;controls.add_child(mod_picker)
    controls.add_child(UI.button("重新加载",reload_selected))
    var row=HBoxContainer.new();row.add_theme_constant_override("separation",20);col.add_child(row)
    grid=Grid.new();grid.cell_clicked.connect(paint);row.add_child(grid)
    raw=TextEdit.new();raw.custom_minimum_size=Vector2(680,480);raw.add_theme_font_size_override("font_size",15);raw.wrap_mode=TextEdit.LINE_WRAPPING_NONE;row.add_child(raw)
    feedback=UI.paragraph("",1170);feedback.add_theme_font_size_override("font_size",16);col.add_child(feedback)
    data=App.editor_draft.duplicate(true) if not App.editor_draft.is_empty() else Content.default_content()
    if data.id=="amber_bridge":data.id="my_bridge";data.title="我的琥珀桥"
    sync_view();refresh_mods();saved_hash=Content.hash_of(data)
func sync_view():
    raw.text=JSON.stringify(data,"  ",true);grid.data=data;grid.queue_redraw()
    unit_picker.clear()
    for u in data.units:unit_picker.add_item(u.name+" · "+u.id)
    App.editor_draft=data.duplicate(true)
func apply_json():
    if raw.text.to_utf8_buffer().size()>Content.MAX_BYTES:feedback.text="内容超过 128 KiB。";return false
    var candidate=Content.normalize(Content.parse_json(raw.text))
    var error=Content.validate(candidate)
    if not error.is_empty():feedback.text="未应用："+error;return false
    var selected=unit_picker.selected
    data=candidate;sync_view();unit_picker.select(clampi(selected,0,data.units.size()-1))
    feedback.text="校验通过 · 内容版本 "+Content.hash_of(data).left(12)
    return true
func paint(cell):
    if not apply_json():return
    var candidate=data.duplicate(true)
    if brush.selected==4:
        candidate.units[unit_picker.selected].x=cell.x;candidate.units[unit_picker.selected].y=cell.y
    else:
        var line=candidate.terrain[cell.y]
        line[cell.x]=["G","W","B","X"][brush.selected]
        candidate.terrain[cell.y]=line
    var error=Content.validate(candidate)
    if not error.is_empty():feedback.text="未修改："+error;return
    data=candidate;sync_view();feedback.text="地图已修改；保存后可重新载入，或直接试玩。"
func refresh_mods():
    mod_picker.clear();DirAccess.make_dir_recursive_absolute("user://mods")
    for file in DirAccess.get_files_at("user://mods"):
        if file.ends_with(".json"):mod_picker.add_item(file)
    if mod_picker.item_count==0:mod_picker.add_item("暂无已保存 Mod");mod_picker.set_item_disabled(0,true)
func save_mod():
    if not apply_json():return
    var path="user://mods/"+data.id+".json"
    if FileAccess.file_exists(path):
        var dialog=ConfirmationDialog.new();dialog.title="替换同名 Mod？";dialog.dialog_text="将替换用户目录中的 "+data.id+"。内置战役不会被修改。";dialog.ok_button_text="保存替换";dialog.cancel_button_text="取消";dialog.exclusive=true;dialog.theme=theme;add_child(dialog)
        dialog.confirmed.connect(func():perform_save(true);dialog.queue_free());dialog.canceled.connect(dialog.queue_free);dialog.popup_centered(Vector2i(580,180))
    else:perform_save(false)
func perform_save(overwrite):
    var error=Content.write_mod(data,overwrite)
    feedback.text="已保存 Mod："+data.id if error.is_empty() else error
    if error.is_empty():saved_hash=Content.hash_of(data);refresh_mods()
func reload_selected():
    if mod_picker.item_count==0 or mod_picker.is_item_disabled(mod_picker.selected):feedback.text="没有可加载的 Mod。";return
    var name=mod_picker.get_item_text(mod_picker.selected)
    if name.contains("/") or name.contains("\\"):feedback.text="无效文件名。";return
    var result=Content.from_file("user://mods/"+name)
    if not result.error.is_empty():feedback.text=result.error;return
    data=result.data;sync_view();saved_hash=Content.hash_of(data);feedback.text="已重新加载："+data.title
func import_dialog():
    var dialog=FileDialog.new();dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE;dialog.access=FileDialog.ACCESS_FILESYSTEM;dialog.filters=PackedStringArray(["*.json ; 数据型 Mod"]);dialog.title="导入数据型 Mod";dialog.theme=theme;add_child(dialog)
    dialog.file_selected.connect(func(path):
        var result=Content.from_file(path)
        if not result.error.is_empty():feedback.text="未导入："+result.error
        else:data=result.data;sync_view();feedback.text="已载入编辑缓冲；点击保存才会写入用户 Mod 目录。"
        dialog.queue_free())
    dialog.canceled.connect(dialog.queue_free);dialog.popup_centered_ratio(0.8)
func play():
    if transitioning or not apply_json():return
    transitioning=true;App.editor_draft=data.duplicate(true);App.new_game(data)
    get_tree().call_deferred("change_scene_to_file","res://main.tscn")
func request_back():
    if raw.text!=JSON.stringify(data,"  ",true) or Content.hash_of(data)!=saved_hash:
        var dialog=ConfirmationDialog.new();dialog.title="离开工坊？";dialog.dialog_text="未保存编辑会保留在本次运行的草稿中，但退出程序后不会保留。先保存可避免丢失。";dialog.ok_button_text="离开";dialog.cancel_button_text="继续编辑";dialog.theme=theme;dialog.exclusive=true;add_child(dialog)
        dialog.confirmed.connect(func():get_tree().change_scene_to_file("res://ui/menu.tscn"));dialog.canceled.connect(dialog.queue_free);dialog.popup_centered(Vector2i(620,210))
    else:get_tree().call_deferred("change_scene_to_file","res://ui/menu.tscn")
func request_exit():
    var dialog=ConfirmationDialog.new();dialog.title="退出工坊与游戏？";dialog.dialog_text="未保存的 Mod 编辑将丢失。";dialog.ok_button_text="退出";dialog.cancel_button_text="返回编辑";dialog.theme=theme;dialog.exclusive=true;add_child(dialog);dialog.confirmed.connect(func():get_tree().quit());dialog.canceled.connect(dialog.queue_free);dialog.popup_centered(Vector2i(520,190))

func open_forms():
    if not apply_json():return
    var form=preload("res://ui/content_form.gd").new();form.draft=data.duplicate(true)
    form.accepted.connect(func(value):data=value;sync_view();feedback.text="表单已应用；保存 Mod 才会写入磁盘。")
    add_child(form);form.popup_centered()
    return form
