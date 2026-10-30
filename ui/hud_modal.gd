extends RefCounted
# Modal screens: pause menu, save slots, restart/leave confirmation, chapter
# transition and feedback settings. It owns no nodes; every control lives on the
# HUD it is given, which keeps battle_hud.gd focused on the battle layout.

const UI=preload("res://ui/style.gd")

var hud


func _init(owner) -> void:
    hud = owner

func clear_modal():
    hud.picker_context={}
    hud.gear_open=false
    if is_instance_valid(hud.modal):
        # Keep the pressed control in-tree until the touch/emulated-mouse dispatch finishes.
        hud.modal.hide();hud.modal.queue_free();hud.modal=null;hud.action_menu_open=true
    hud.refresh_story()

func modal_page(title):
    hud.game.clear_move_preview()
    clear_modal()
    hud.modal=ColorRect.new();hud.modal.color=Color(0.08,0.07,0.05,0.7);hud.modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);hud.modal.z_index=100;hud.root.add_child(hud.modal)
    var p=PanelContainer.new();p.position=Vector2((hud.root.size.x-600)*0.5,100);p.custom_minimum_size=Vector2(600,0);hud.modal.add_child(p)
    var c=UI.column(p,12);c.add_child(UI.label(title,28));hud.refresh_story();return c

func confirm_next_chapter():
    if not App.next_chapter_ready():return
    var chapter=App.next_chapter_label()
    var c=modal_page("前往"+chapter)
    if hud.game.session.online:
        c.add_child(UI.paragraph("网络房间不能单方换图。请双方返回主菜单，在网络对局中选择对应的下一章；同一关卡版本才能连接。",550))
    else:
        c.add_child(UI.paragraph("先建立独立的当前章节结尾检查点，再开始下一章。检查点可在读档界面恢复，不会被下一章自动存档覆盖。下一章使用预设队伍与装备，恢复生命、魔力和行动；不继承本场背包。已有手动存档保留。",550))
        c.add_child(UI.button("保存结尾并进入"+chapter,func():
            if App.enter_next_chapter():hud.get_tree().call_deferred("change_scene_to_file","res://main.tscn")
            else:
                var failure=modal_page("未进入"+chapter);failure.add_child(UI.paragraph(App.last_error,550));failure.add_child(UI.button("返回",clear_modal))))
    c.add_child(UI.button("返回",clear_modal))

func toggle_pause():
    if is_instance_valid(hud.modal):clear_modal();return
    var c=modal_page("旅程菜单")
    c.add_child(UI.paragraph("本地暂停操作不会暂停网络房间。" if hud.game.session.online else "休息片刻，旅程会等你。",550))
    c.add_child(UI.button("继续战斗",clear_modal))
    var save=UI.button("保存旅程",show_save);save.disabled=hud.game.session.online;save.tooltip_text="网络房间由主机维护，本版不允许客户端写本地战斗存档。";c.add_child(save)
    var gear=UI.button("装备整备 / 背包",hud.show_gear);c.add_child(gear)
    if not hud.game.session.online:c.add_child(UI.button("重新开始本场",confirm_restart))
    c.add_child(UI.button("返回主界面",confirm_leave.bind(false)))
    c.add_child(UI.button("退出游戏",confirm_leave.bind(true)))
    var scene_button=UI.button("场景：固定背景 → 切回 3D" if hud.game.scene_view.active else "场景：3D → 固定背景样板",toggle_scene_renderer)
    scene_button.disabled=not hud.game.scene_view.active and not hud.game.scene_view.available()
    scene_button.tooltip_text="仅支持已标定的内置关卡；自定义地图保留3D兼容视图。"
    c.add_child(scene_button)
    var brightness=HBoxContainer.new();c.add_child(brightness)
    brightness.add_child(UI.label("角色补光",18))
    var level=HSlider.new();level.min_value=0;level.max_value=0.6;level.step=0.05;level.value=App.character_emission;level.custom_minimum_size=Vector2(320,44);level.tooltip_text="只调整角色原色补光，保留场景光照与阴影。"
    level.value_changed.connect(func(value):App.character_emission=value)
    brightness.add_child(level)
    c.add_child(UI.button("音效与动态效果",show_feedback_settings))
    c.get_child(2).grab_focus()

func show_feedback_settings():
    var c=modal_page("音效与动态效果")
    var reduced=CheckButton.new();reduced.text="减弱震动与闪光";reduced.button_pressed=App.reduced_motion;reduced.toggled.connect(func(on):App.reduced_motion=on);c.add_child(reduced)
    var avoid=CheckButton.new();avoid.text="头顶血条自动避让";avoid.button_pressed=App.health_bar_avoidance;avoid.tooltip_text="默认关闭；开启后血条会横向避让附近角色，头顶跟随始终保留。";avoid.toggled.connect(App.set_health_bar_avoidance);c.add_child(avoid)
    var sound=CheckButton.new();sound.text="战斗音效";sound.button_pressed=App.sfx_enabled;sound.toggled.connect(func(on):App.sfx_enabled=on);c.add_child(sound)
    var volume=HSlider.new();volume.min_value=-30;volume.max_value=0;volume.step=1;volume.value=App.sfx_volume_db;volume.custom_minimum_size=Vector2(320,36);volume.tooltip_text="音效音量 dB";volume.value_changed.connect(func(value):App.sfx_volume_db=value);c.add_child(volume)
    c.add_child(UI.button("返回暂停菜单",func():clear_modal();toggle_pause()))

func toggle_scene_renderer():
    if hud.game.scene_view.set_fixed(not hud.game.scene_view.active):
        App.scene_renderer="fixed" if hud.game.scene_view.active else "three_d"
        clear_modal();hud.game.refresh()

func show_save():
    var c=modal_page("选择存档位置")
    for slot in App.SLOT_IDS:
        var info=App.inspect_slot(slot)
        var text={"auto":"自动存档","slot1":"存档一","slot2":"存档二","slot3":"存档三"}[slot]
        text+=" · "+(info.error if not info.error.is_empty() else "第 %d 回合"%info.round)
        c.add_child(UI.button(text,confirm_save.bind(slot)))
    c.add_child(UI.button("返回",func():clear_modal();toggle_pause()))

func confirm_save(slot):
    if FileAccess.file_exists(App.save_path(slot)):
        var c=modal_page("替换现有存档？")
        c.add_child(UI.paragraph("只有新文件完整写入后才会替换原文件。",550))
        c.add_child(UI.button("确认保存",perform_save.bind(slot)))
        c.add_child(UI.button("取消",show_save))
    else:perform_save(slot)

func perform_save(slot):
    var error=App.save_slot(slot)
    if error.is_empty():clear_modal();hud.log_lines.append("旅程已保存。");hud.refresh()
    else:
        var c=modal_page("保存未完成");c.add_child(UI.paragraph(error,550));c.add_child(UI.button("返回战斗",clear_modal))

func confirm_restart():
    var c=modal_page("重新开始？");c.add_child(UI.paragraph("本场未保存的行动和剧情阅读进度会重置。已有存档保留。",550))
    c.add_child(UI.button("重新开始",func():clear_modal();hud.game.restart()))
    c.add_child(UI.button("继续当前旅程",clear_modal))

func confirm_leave(quit_game):
    if not App.dirty() and not hud.game.session.online:leave(quit_game);return
    var c=modal_page("退出游戏？" if quit_game else "返回主界面？")
    if hud.game.session.online:
        c.add_child(UI.paragraph("你是主机，离开会关闭房间，其他玩家将断开。网络进度本版不会保存。" if App.server else "离开将断开网络对局。当前房间由主机继续维护。",550))
    else:
        c.add_child(UI.paragraph("当前旅程有未保存进度。可以保存到自动存档后离开。",550))
        c.add_child(UI.button("保存并离开",save_and_leave.bind(quit_game)))
    c.add_child(UI.button("直接离开" if hud.game.session.online else "不保存，离开",leave.bind(quit_game)))
    c.add_child(UI.button("继续旅程",clear_modal))

func save_and_leave(quit_game):
    var error=App.save_slot("auto")
    if error.is_empty():leave(quit_game)
    else:
        var c=modal_page("无法保存");c.add_child(UI.paragraph(error,550));c.add_child(UI.button("继续旅程",clear_modal))

func leave(quit_game):
    if quit_game:App.close_room();hud.get_tree().quit()
    else:App.return_to_menu()
