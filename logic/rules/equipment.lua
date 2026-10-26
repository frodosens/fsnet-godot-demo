-- Small, data-only item registry. Nine slots; gear is locked by the first combat action.
local slot_names={'main_hand','off_hand','head','body','hands','feet','neck','ring','ring'}
local function definition_index(list,id)
  for i,d in ipairs(list) do if d.id==id then return i end end
end
local function random_value(s,maximum)
  s.rng=(s.rng*16807)%2147483647;return s.rng%maximum
end
local function make_item(s,base,quality,affix_ids)
  if #s.inventory>=32 then return nil end
  local item={uid=s.next_item,base=base,quality=quality,seed=s.rng,affixes={}}
  s.next_item=s.next_item+1
  for _,id in ipairs(affix_ids) do
    local index=assert(definition_index(content.equipment.affixes,id));local a=content.equipment.affixes[index]
    local value=a.minimum
    if a.maximum>a.minimum then value=value+random_value(s,a.maximum-a.minimum+1) end
    item.affixes[#item.affixes+1]={index=index,value=value}
  end
  s.inventory[#s.inventory+1]=item;return item
end
initialize_inventory=function(s)
  s.inventory={};s.next_item=1;s.rewarded=false
  for _,d in ipairs(content.equipment.starting) do make_item(s,assert(definition_index(content.equipment.bases,d.base)),d.quality,d.affixes) end
  for _,u in ipairs(s.units) do u.equipment={0,0,0,0,0,0,0,0,0} end
end
local function item_by_uid(s,uid)
  for _,item in ipairs(s.inventory) do if item.uid==uid then return item end end
end
derive_equipment=function(s)
  for index,u in ipairs(s.units) do
    local d=content.units[index];local stats={physical=0,spell=0,armor=0,resist=0,hp=0};local sets={};local move_bonus=0
    u.mobile_cast=false
    local function add(values) for key,value in pairs(values) do stats[key]=stats[key]+value end end
    for _,uid in ipairs(u.equipment) do if uid~=0 then
      local item=assert(item_by_uid(s,uid));local base=content.equipment.bases[item.base];add(base.stats)
      if base.set_id and base.set_id~='' then sets[base.set_id]=(sets[base.set_id] or 0)+1 end
      for _,entry in ipairs(item.affixes) do
        local a=content.equipment.affixes[entry.index]
        if a.stat~='none' then stats[a.stat]=stats[a.stat]+entry.value end
        if a.effect=='move_action_plus1' then move_bonus=move_bonus+1 end
        if a.effect=='mobile_cast' then u.mobile_cast=true end
      end
    end end
    for _,set in ipairs(content.equipment.sets) do if (sets[set.id] or 0)>=set.pieces then add(set.stats) end end
    u.max_hp=d.hp+stats.hp;u.hp=math.min(u.hp,u.max_hp)
    u.damage=d.damage+stats.physical;u.spell_bonus=stats.spell;u.armor=d.armor+stats.armor;u.resist=d.resist+stats.resist
    u.move_actions=1+math.min(1,move_bonus);u.moved=u.moves_used>=u.move_actions
  end
end
equip_action=function(c,index)
  local u=state.units[index]
  if not u or u.controller~='player' or not (state.preparation or state.outcome~='playing') then return false end
  if not integer(c.slot,0,8) or not integer(c.item,0,1000000) then return false end
  if c.item~=0 then
    local item=item_by_uid(state,c.item)
    if not item or content.equipment.bases[item.base].slot~=slot_names[c.slot+1] then return false end
    for i,other in ipairs(state.units) do for slot,uid in ipairs(other.equipment) do
      if uid==c.item and (i~=index or slot~=c.slot+1) then return false end
    end end
  end
  u.equipment[c.slot+1]=c.item;derive_equipment(state);return true
end
drop_reward=function()
  if state.outcome~='victory' or state.rewarded then return end
  state.rewarded=true
  local drops=content.equipment.drops
  if random_value(state,100)>=drops.chance or #state.inventory>=32 then return end
  local id=drops.base_pool[random_value(state,#drops.base_pool)+1]
  local base_index=assert(definition_index(content.equipment.bases,id));local base=content.equipment.bases[base_index]
  local total=0;for _,weight in ipairs(drops.quality_weights) do total=total+weight end
  local choice=random_value(state,total);local quality=0
  for i,weight in ipairs(drops.quality_weights) do if choice<weight then quality=i-1;break end;choice=choice-weight end
  local affixes={}
  if quality==3 then for _,a in ipairs(base.unique_affixes) do affixes[#affixes+1]=a end
  elseif quality>0 and #base.affix_pool>0 then
    local start=random_value(state,#base.affix_pool)
    for i=1,math.min(quality,#base.affix_pool) do affixes[#affixes+1]=base.affix_pool[(start+i-1)%#base.affix_pool+1] end
  end
  make_item(state,base_index,quality,affixes)
end
