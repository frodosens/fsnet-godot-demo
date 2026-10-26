extends Window
signal accepted(data)
const UI=preload("res://ui/style.gd")
const Content=preload("res://logic/content.gd")
const SECTIONS={"单位与 AI":["units"],"技能与效果":["abilities"],"消耗品":["consumables"],"装备底材":["equipment","bases"],"装备词缀":["equipment","affixes"],"装备套装":["equipment","sets"],"初始物品":["equipment","starting"],"掉落表":["equipment","drops"],"剧情角色":["story","characters"],"剧情事件":["story","events"],"胜利目标":["victory"],"失败目标":["defeat"]}
const NAMES={"id":"稳定 ID","name":"名称","role":"职业外观","ally":"友方阵营标记","controller":"控制器","faction":"阵营 ID","policy":"AI 策略","escort":"护送目标 ID","leash":"活动半径","hp":"生命","mp":"法力","damage":"攻击","movement":"移动距离","reach":"攻击距离","armor":"护甲","resist":"抗性","x":"格子 X","y":"格子 Y","abilities":"可用技能 ID","skill_id":"默认技能 ID","target":"目标关系","mp_cost":"法力消耗","cooldown":"冷却回合","charges":"每场次数（0 无限）","stationary":"要求原地施放","reach_bonus":"额外射程","effects":"效果列表","op":"效果操作","value":"效果数值","radius":"范围半径","ability":"使用的技能 ID","count":"初始数量","minimum":"词缀下限","maximum":"词缀上限","effect":"特殊能力","kind":"目标类型","children":"组合子目标","unit":"单位 ID","round":"回合阈值","lines":"对话台词","speaker":"说话人 ID","text":"台词","trigger":"触发条件"}
const ENUMS={"damage_type":["physical","magic"],"controller":["player","ai"],"policy":["offensive","defensive","support","escort"],"role":["knight","archer","mage","raider","scout","brute"],"target":["self","ally","enemy"],"op":["damage","heal"],"effect":["none","move_action_plus1","mobile_cast"],"slot":["main_hand","off_hand","head","body","hands","feet","neck","ring"],"stat":["none","physical","spell","armor","resist","hp"],"kind":["defeat_all","all_allies","protect","reach","survive","all","any"]}
var draft={}
var section
var entries
var fields
var feedback
var row_index=0
var controls={}
func _ready():
    title="内容编辑表单";size=Vector2i(920,720);min_size=size;exclusive=true;theme=UI.make_theme()
    var outer=MarginContainer.new();outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    for side in ["left","right","top","bottom"]:outer.add_theme_constant_override("margin_"+side,16)
    add_child(outer);var col=UI.column(outer,10)
    var bar=HBoxContainer.new();col.add_child(bar)
    section=OptionButton.new();bar.add_child(section)
    for name in SECTIONS:section.add_item(name)
    section.item_selected.connect(func(_i):row_index=0;rebuild())
    entries=OptionButton.new();entries.custom_minimum_size.x=240;bar.add_child(entries);entries.item_selected.connect(func(i):row_index=i;build_fields())
    bar.add_child(UI.button("复制新增",duplicate_entry));bar.add_child(UI.button("删除本条",remove_entry))
    var scroll=ScrollContainer.new();scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;col.add_child(scroll)
    fields=UI.column(scroll,8);fields.size_flags_horizontal=Control.SIZE_EXPAND_FILL
    feedback=UI.paragraph("表单修改仅在校验通过后应用；保存 Mod 才会写入磁盘。",850);col.add_child(feedback)
    var footer=HBoxContainer.new();col.add_child(footer);footer.add_child(UI.button("校验并应用",apply_form));footer.add_child(UI.button("取消此表单",queue_free))
    close_requested.connect(queue_free);rebuild()
func collection():
    var value=draft
    for key in SECTIONS[section.get_item_text(section.selected)]:value=value[key]
    return value
func rebuild():
    entries.clear();var value=collection()
    if value is Array:
        for item in value:entries.add_item(str(item.get("name",item.get("id","未命名"))))
        row_index=clampi(row_index,0,maxi(0,value.size()-1));entries.select(row_index)
    else:entries.add_item("目标条件");row_index=0
    build_fields()
func build_fields():
    controls.clear()
    for child in fields.get_children():fields.remove_child(child);child.queue_free()
    var value=collection()
    if value is Array:
        if value.is_empty():fields.add_child(UI.label("列表为空，请使用 JSON 添加第一条模板。"));return
        value=value[row_index]
        if section.selected==0:
            # Materialize optional policy fields for editable, data-driven controllers.
            if not value.has("controller"):value.controller="player" if value.ally else "ai"
            if not value.has("faction"):value.faction="crew" if value.ally else "guards"
            if not value.has("policy"):value.policy="offensive"
            if not value.has("leash"):value.leash=4
            if not value.has("escort"):value.escort=""
    render_object(fields,value,0,"")
func render_object(parent,value,depth,path):
    if depth>6:return
    var keys=value.keys() if value is Dictionary else range(value.size())
    for key in keys:
        var item=value[key];var name=str(key);var full=path+"/"+name
        if item is Dictionary or item is Array:
            parent.add_child(UI.label("  ".repeat(depth)+NAMES.get(name,name),17))
            render_object(parent,item,depth+1,full)
            continue
        var row=HBoxContainer.new();row.add_theme_constant_override("separation",12);parent.add_child(row)
        var label=UI.label("  ".repeat(depth)+NAMES.get(name,name),16);label.custom_minimum_size.x=230;row.add_child(label)
        var input
        if item is bool:
            input=CheckBox.new();input.button_pressed=item;input.toggled.connect(func(v):value[key]=v)
        elif item is int:
            input=SpinBox.new();input.min_value=0;input.max_value=1000000;input.step=1;input.value=item;input.value_changed.connect(func(v):value[key]=int(v))
        elif ENUMS.has(name):
            input=OptionButton.new()
            for option in ENUMS[name]:input.add_item(option)
            input.select(ENUMS[name].find(item));input.item_selected.connect(func(i):value[key]=ENUMS[name][i])
        else:
            input=LineEdit.new();input.text=str(item);input.text_changed.connect(func(v):value[key]=v)
        input.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(input);controls[full]=input
func duplicate_entry():
    var value=collection()
    if not value is Array or value.is_empty():feedback.text="该部分不能复制；可在 JSON 中创建首条。";return
    var item=value[row_index].duplicate(true)
    if item.has("id"):item.id+="_copy"
    value.append(item);row_index=value.size()-1;rebuild();feedback.text="已复制。请修改稳定 ID / 出生点并修正引用后校验。"
func remove_entry():
    var value=collection()
    if not value is Array or value.is_empty():return
    value.remove_at(row_index);rebuild();feedback.text="已从表单草稿删除；所有引用仍需通过校验。"
func apply_form():
    var error=Content.validate(draft)
    if not error.is_empty():feedback.text="未应用："+error;return false
    accepted.emit(draft.duplicate(true));queue_free();return true
