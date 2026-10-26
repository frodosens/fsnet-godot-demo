extends Control
const UI=preload("res://ui/style.gd")
var card
var page
var feedback
var busy=false
var transitioning=false
var network_status
var enter_button
var token_edit
var exit_dialog
var workshop_link
var port_edit
func _ready():
    theme=UI.make_theme()
    var bg=TextureRect.new();bg.texture=load("res://assets/ui/v2/menu_background.png");bg.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;bg.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED;bg.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);bg.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(bg)
    var title=UI.label("琥珀桥来信",42);title.position=Vector2(54,144);add_child(title)
    var subtitle=UI.label("AMBER BRIDGE",19,Color("adb3a6"));subtitle.position=Vector2(55,218);add_child(subtitle)
    card=PanelContainer.new();add_child(card)
    workshop_link=UI.menu_button("关卡工坊",show_workshop);workshop_link.position=Vector2(48,696);workshop_link.add_theme_font_size_override("font_size",18);add_child(workshop_link)
    show_home()
    for arg in OS.get_cmdline_user_args():
        if arg=="--battle" or arg=="--scene-smoke":start_new()
        elif arg.begins_with("--connect="):
            App.start_room(false,int(arg.trim_prefix("--connect=")),OS.get_environment("AMBER_TOKEN"));open_battle()
    capture_if_requested()
func clear_page(title):
    if page:card.remove_child(page);page.queue_free()
    card.position=Vector2(420,140);card.custom_minimum_size=Vector2(740,0);card.size=Vector2(740,0);card.remove_theme_stylebox_override("panel");workshop_link.hide()
    page=UI.column(card,12);page.add_child(UI.label(title,26));network_status=null;enter_button=null
func show_home():
    busy=false;clear_page("")
    card.position=Vector2(48,326);card.custom_minimum_size=Vector2(330,0);card.size=Vector2(330,0);card.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
    page.get_child(0).hide();page.add_theme_constant_override("separation",20);workshop_link.show()
    page.add_child(UI.menu_button("开始新游戏",start_new))
    page.add_child(UI.menu_button("读取存档",show_load))
    page.add_child(UI.menu_button("网络对局",show_network))
    page.add_child(UI.menu_button("退出游戏",request_exit))
    page.get_child(1).grab_focus()
func start_new():
    if busy:return
    busy=true;App.new_game();open_battle()
func open_battle():
    if transitioning:return
    transitioning=true;busy=true;get_tree().call_deferred("change_scene_to_file","res://main.tscn")
func show_load():
    clear_page("读取旅程")
    for slot in App.SLOT_IDS:
        var result=App.inspect_slot(slot)
        var caption={"auto":"自动存档","slot1":"存档一","slot2":"存档二","slot3":"存档三"}[slot]
        var button=UI.button(caption+" · "+(result.error if not result.error.is_empty() else "第 %d 回合 · %s"%[result.round,result.saved_at]),load_selected.bind(slot))
        button.disabled=not result.error.is_empty();button.tooltip_text=result.error;page.add_child(button)
    feedback=UI.paragraph("旧规则或损坏存档不会覆盖当前文件。",460);page.add_child(feedback)
    page.add_child(UI.button("返回",show_home))
func load_selected(slot):
    if busy:return
    if App.load_slot(slot):busy=true;open_battle()
    else:feedback.text=App.last_error
func show_network():
    clear_page("本机网络对局")
    page.add_theme_constant_override("separation",8)
    page.add_child(UI.paragraph("双方合作控制同一支小队。主机离开会结束房间。本版仅支持本机 127.0.0.1。",460))
    var row=HBoxContainer.new();page.add_child(row);row.add_child(UI.label("端口"))
    port_edit=SpinBox.new();port_edit.min_value=1024;port_edit.max_value=65535;port_edit.value=27840;row.add_child(port_edit)
    token_edit=LineEdit.new();token_edit.placeholder_text="房间口令（至少16个字符）";token_edit.max_length=96;page.add_child(token_edit)
    var buttons=HBoxContainer.new();page.add_child(buttons)
    buttons.add_child(UI.button("创建房间",begin_room.bind(true)))
    buttons.add_child(UI.button("加入房间",begin_room.bind(false)))
    network_status=UI.paragraph("创建时可留空，系统会生成口令；复制给另一客户端。",460);page.add_child(network_status)
    page.add_child(UI.button("复制口令",func():DisplayServer.clipboard_set(token_edit.text)))
    enter_button=UI.button("进入战场",open_battle);enter_button.disabled=true;page.add_child(enter_button)
    page.add_child(UI.button("取消 / 返回",cancel_network))
func begin_room(host):
    if busy:return
    var secret=token_edit.text.strip_edges()
    if host and secret.is_empty():secret=Crypto.new().generate_random_bytes(16).hex_encode();token_edit.text=secret
    if secret.length()<16:network_status.text="口令至少需要16个字符。";return
    busy=true
    if not App.start_room(host,int(port_edit.value),secret):network_status.text="连接失败："+App.last_error;busy=false
    else:network_status.text="正在连接房间……"
func cancel_network():
    App.close_room();App.session=null;busy=false;show_home()
func _process(_delta):
    if is_instance_valid(network_status) and App.session and App.session.online:
        if App.session.failed:network_status.text="连接失败："+App.session.status;busy=false;enter_button.disabled=true
        elif App.session.status.begins_with("Online"):
            network_status.text="已连接 · 共享内容校验通过\n主机端口 %d，进入后可合作行动。"%App.room_port;enter_button.disabled=false
        else:network_status.text="连接中 / 正在重连……"
func show_workshop():
    if ResourceLoader.exists("res://ui/editor.tscn"):get_tree().change_scene_to_file("res://ui/editor.tscn")
    else:
        clear_page("关卡工坊")
        page.add_child(UI.paragraph("数据校验器已准备；可视编辑流程尚未接通。本入口暂不可编辑。",460))
        page.add_child(UI.button("返回",show_home))
func request_exit():
    if is_instance_valid(exit_dialog):return
    var dialog=ConfirmationDialog.new();exit_dialog=dialog;dialog.exclusive=true;dialog.title="结束今天的旅程？";dialog.dialog_text="确定退出游戏吗？";dialog.ok_button_text="退出游戏";dialog.cancel_button_text="留下";dialog.theme=theme
    add_child(dialog);dialog.confirmed.connect(func():App.close_room();get_tree().quit());dialog.canceled.connect(dialog.queue_free);dialog.popup_centered(Vector2i(450,180))
func _unhandled_input(event):
    if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
        if busy:cancel_network()
        else:show_home()
func capture_if_requested():
    for arg in OS.get_cmdline_user_args():
        if arg.begins_with("--capture-menu="):
            if DisplayServer.get_name()=="headless":get_tree().quit(1);return
            for i in range(8):await get_tree().process_frame
            await RenderingServer.frame_post_draw
            var code=get_viewport().get_texture().get_image().save_png(arg.trim_prefix("--capture-menu="))
            get_tree().quit(0 if code==OK else 1)
