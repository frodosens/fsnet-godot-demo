extends RefCounted
# Presentation geometry only. Reference coordinates are measured from the approved art.
const REFERENCE=Vector2(1672,941)
const PORTRAIT_ASPECT=323.0/406.0
static var contract={}
static func put(node,rect):
    node.position=rect.position;node.size=rect.size
static func rect(x,y,w,h):return Rect2(x,y,w,h)
static func ref_rect(key,scale):
    var a=contract.reference_rects_px[key]
    return Rect2((Vector2(a[0],a[1])-Vector2(94,57))*scale,Vector2(a[2],a[3])*scale)
static func arrange(p):
    if contract.is_empty():contract=JSON.parse_string(FileAccess.get_file_as_string(p.ART+"layout_contract.json"))
    var ratio=p.ui_ratio();var pixel=1.0/ratio
    var fit=minf(p.size.x/REFERENCE.x,p.size.y/REFERENCE.y)
    p.compact=p.size.y*ratio<600 or fit*26*ratio<16
    p.layout_scale=fit
    if p.compact:compact(p,pixel)
    else:desktop(p,fit)
    var text_scale=fit if not p.compact else pixel
    for label in p.find_children("*","Label",true,false):
        if not label.has_meta("details_font"):continue
        var reference=label.get_meta("details_font")
        var font=reference*text_scale
        if p.compact:
            font=({44:24,38:21,30:18,29:18,26:16,23:16,21:14,18:12}.get(reference,16))*pixel
        label.add_theme_font_size_override("font_size",roundi(font))
    for b in p.find_children("*","Button",true,false):
        b.add_theme_font_size_override("font_size",roundi(18*pixel if p.compact else 29*fit))
        if b in p.rows:
            b.custom_minimum_size.y=p.hit_size()
            b.add_theme_font_size_override("font_size",roundi(16*pixel if p.compact else 24*fit))
        b.add_theme_constant_override("icon_max_width",roundi(24*pixel if p.compact else 32*fit))
    # Content padding is independent of texture caps: no 75px implicit button minimum.
    for name in p.skins:
        var spec=p.manifest[name];var caps=spec.get("cap_margins_ltrb_px",[0,0,0,0]);var pads=spec.get("content_padding_ltrb_px",[0,0,0,0])
        var style=p.skins[name];var scale=pixel if p.compact else fit
        for i in range(4):
            var side=[SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM][i]
            style.set_texture_margin(side,caps[i]);style.set_expand_margin(side,0)
            style.set_content_margin(side,pads[i]*scale)
    var u=pixel if p.compact else fit
    contents(p,u)
    p.list.visible=p.tab!=0
    for r in p.stat_rows:r.root.visible=p.tab==0
    p.attributes_heading.text=["基础属性","角色技能","队伍道具","装备整备"][p.tab]
    p.traits_heading.text="装备特性" if p.tab==0 else "详细说明"
    p.footer_label.visible=p.tab!=3 and not p.compact
    # Inner description overlay retains all navigation outside its scroll area.
    put(p.detail_layer,Rect2(p.panel.position+Vector2(16,16)*pixel,p.panel.size-Vector2(32,32)*pixel))
    var d=p.detail_layer.size
    put(p.detail_back,rect(d.x-156*pixel,12*pixel,144*pixel,48*pixel))
    put(p.detail_scroll,rect(20*pixel,72*pixel,d.x-40*pixel,d.y-92*pixel))
static func desktop(p,s):
    var offset=(p.size-REFERENCE*s)/2
    put(p.panel,Rect2(offset+Vector2(94,57)*s,Vector2(1484,826)*s))
    put(p.title_label,ref_rect("title",s));put(p.close_button,ref_rect("close",s))
    put(p.identity_panel,ref_rect("identity_panel",s))
    # Portrait content remains 323:406; the decorative frame surrounds it.
    put(p.portrait,rect(12*s,13*s,323*s,406*s))
    put(p.portrait_frame,rect(0,0,347*s,432*s))
    for item in [[p.identity,417,46],[p.class_label,468,36],[p.level_label,506,36],[p.summary,579,30]]:
        put(item[0],rect(12*s,item[1]*s,323*s,item[2]*s))
    put(p.xp_group,rect(20*s,548*s,305*s,23*s))
    for i in range(4):
        var x=[493,745,1003,1261][i]
        var w=[240,246,246,278][i]
        put(p.tabs[i],rect((x-94)*s,104*s,w*s,67*s))
    put(p.back,ref_rect("return",s))
    put(p.full,rect(399*s,747*s,226*s,64*s))
    put(p.equip,rect(909*s,747*s,226*s,64*s))
    put(p.footer_label,rect(652*s,767*s,485*s,30*s))
    put(p.body_scroll,rect(399*s,187*s,738*s,540*s))
    p.body_canvas.custom_minimum_size=Vector2(0,540*s);p.body_canvas.size=Vector2(738*s,540*s)
    put(p.attributes_panel,rect(0,0,738*s,376*s));put(p.traits_panel,rect(0,389*s,738*s,151*s))
    if p.equipment_panel.get_parent()!=p.panel:p.equipment_panel.reparent(p.panel,false)
    put(p.equipment_panel,ref_rect("equipment_summary",s))
static func compact(p,k):
    var margin=12*k;var gap=8*k
    put(p.panel,Rect2(Vector2.ONE*margin,p.size-Vector2.ONE*margin*2))
    var w=p.panel.size.x;var h=p.panel.size.y
    put(p.title_label,rect(60*k,4*k,w-120*k,44*k));put(p.close_button,rect(w-48*k,0,48*k,48*k))
    var tabs_y=52*k;var body_y=108*k;var bottom=h-56*k;var body_h=maxf(150*k,bottom-body_y)
    var left=(w-3*gap)*.25;var main_x=gap+left+gap;var main_w=w-main_x-gap
    for i in range(4):put(p.tabs[i],rect(gap+i*(w-2*gap)/4,tabs_y,(w-2*gap)/4-4*k,48*k))
    put(p.identity_panel,rect(gap,body_y,left,body_h))
    var ph=minf(body_h*.53,body_h-148*k);ph=minf(ph,(left-24*k)/PORTRAIT_ASPECT);ph=maxf(24*k,ph)
    var pw=ph*PORTRAIT_ASPECT;var px=(left-pw)/2
    put(p.portrait,rect(px,8*k,pw,ph));put(p.portrait_frame,rect(px-6*k,2*k,pw+12*k,ph+12*k))
    var y=ph+18*k
    put(p.identity,rect(8*k,y,left-16*k,28*k));y+=28*k
    put(p.class_label,rect(8*k,y,left-16*k,23*k));y+=23*k
    put(p.level_label,rect(8*k,y,left-16*k,23*k));y+=24*k
    put(p.xp_group,rect(12*k,y,left-24*k,16*k));y+=18*k
    put(p.summary,rect(6*k,y,left-12*k,21*k))
    var stacked=main_w/k<900
    var right=main_w*.29
    var center=main_w if stacked else main_w-right-gap
    put(p.body_scroll,rect(main_x,body_y,center,body_h))
    # Reserve scrollbar width even before overflow is computed, keeping columns stable.
    var inner=center-16*k
    var ah=242*k;var th=150*k;var eh=400*k
    var total=ah+gap+th+(gap+eh if stacked else 0)
    p.body_canvas.custom_minimum_size=Vector2(0,total);p.body_canvas.size=Vector2(inner,total)
    put(p.attributes_panel,rect(0,0,inner,ah));put(p.traits_panel,rect(0,ah+gap,inner,th))
    if stacked:
        if p.equipment_panel.get_parent()!=p.body_canvas:p.equipment_panel.reparent(p.body_canvas,false)
        put(p.equipment_panel,rect(0,ah+gap+th+gap,inner,eh))
    else:
        if p.equipment_panel.get_parent()!=p.panel:p.equipment_panel.reparent(p.panel,false)
        put(p.equipment_panel,rect(main_x+center+gap,body_y,right,body_h))
    put(p.back,rect(w-148*k,h-52*k,140*k,48*k))
    put(p.full,rect(main_x,h-52*k,140*k,48*k))
    put(p.equip,rect(main_x+148*k,h-52*k,120*k,48*k))
static func contents(p,u):
    var pad=20*u if not p.compact else 12*u
    var header=54*u if not p.compact else 40*u
    var a=p.attributes_panel.size
    put(p.attributes_heading,rect(pad,10*u,a.x-2*pad,header-10*u))
    var gap=24*u if not p.compact else 10*u
    var col=(a.x-2*pad-gap)/2
    var row_h=(a.y-header-16*u)/5
    for i in range(10):
        var r=p.stat_rows[i];var x=pad+(i%2)*(col+gap);var y=header+floori(i/2.0)*row_h
        put(r.root,rect(x,y,col,row_h));put(r.icon,rect(0,5*u,32*u,row_h-12*u))
        var value_w=90*u if not p.compact else 66*u
        put(r.label,rect(38*u,4*u,col-38*u-value_w,row_h-6*u));put(r.value,rect(col-value_w,4*u,value_w,row_h-6*u))
        put(r.divider,rect(0,row_h-6*u,col,6*u))
    put(p.list,rect(pad,header,a.x-2*pad,a.y-header-12*u))
    p.column.add_theme_constant_override("separation",roundi(6*u))
    var t=p.traits_panel.size
    put(p.traits_heading,rect(pad,8*u,t.x-2*pad,header-8*u))
    put(p.description,rect(pad,header,t.x-2*pad,t.y-header-12*u))
    var e=p.equipment_panel.size
    put(p.equipment_heading,rect(pad,10*u,e.x-2*pad,header-10*u))
    put(p.equipment_scroll,rect(pad,header,e.x-2*pad,e.y-header-16*u))
    p.equipment_text.add_theme_constant_override("line_spacing",roundi(8*u))
    p.xp_frame.size=p.xp_group.size
    put(p.xp_bar,Rect2(Vector2(10,5)*u,p.xp_group.size-Vector2(20,10)*u))
