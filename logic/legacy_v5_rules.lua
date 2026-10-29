-- Original rules. No engine, transport, clock, float arithmetic or ambient RNG.
-- Array iteration and BFS direction order are part of the deterministic contract.
local M = {}
local state
local content
local effects={}
local initialize_inventory,derive_equipment,equip_action,drop_reward
local directions = {{-1,0},{1,0},{0,-1},{0,1}}
local function unit(name,role,ally,x,y,hp,movement,reach,damage)
  return {name=name,role=role,ally=ally,x=x,y=y,hp=hp,max_hp=hp,movement=movement,
    reach=reach,damage=damage,moved=false,acted=false,skill=true}
end
local function fresh(seed)
  local result={version=5,step=0,rng=seed,round_number=1,outcome='playing',story_flags=0,preparation=true,units={}}
  for _,d in ipairs(content.units) do
    local u=unit(d.name,d.role,d.ally,d.x,d.y,d.hp,d.movement,d.reach,d.damage)
    u.id=d.id;u.controller=d.controller or (d.ally and "player" or "ai");u.faction=d.faction or (d.ally and "crew" or "guards");u.mp=d.mp;u.max_mp=d.mp;u.moves_used=0;u.move_actions=1;u.armor=d.armor;u.resist=d.resist
    u.abilities=d.abilities;u.skill_id=d.skill_id;u.cooldowns={};u.charges={}
    for j,ability in ipairs(content.abilities) do u.cooldowns[j]=0;u.charges[j]=ability.charges end
    result.units[#result.units+1]=u
  end
  initialize_inventory(result);derive_equipment(result)
  result.supplies={};for i,item in ipairs(content.consumables) do result.supplies[i]=item.count end
  return result
end
-- Bounded grid queries shared by player and AI action validation.
local function integer(n,lo,hi) return math.type(n)=='integer' and n>=lo and n<=hi end
local function walkable(x,y)
  return integer(x,0,content.width-1) and integer(y,0,content.height-1)
    and content.terrain[y+1]:sub(x+1,x+1)~='W' and content.terrain[y+1]:sub(x+1,x+1)~='X'
end
local function at(x,y)
  for i,u in ipairs(state.units) do if u.hp>0 and u.x==x and u.y==y then return i end end
end
local function distance(a,b) return math.abs(a.x-b.x)+math.abs(a.y-b.y) end
local function reachable(i)
  local u=state.units[i]; local cells={}; if not u or u.hp<=0 then return cells end
  local seen={[u.y*content.width+u.x]=true}; local q={{x=u.x,y=u.y,d=0,parent=0}}; local cursor=1
  while cursor<=#q do
    local p=q[cursor]; cursor=cursor+1; cells[#cells+1]=p
    if p.d<u.movement then for _,v in ipairs(directions) do
      local x,y=p.x+v[1],p.y+v[2]; local key=y*content.width+x
      local occupant=at(x,y)
      if walkable(x,y) and not seen[key] and (not occupant or state.units[occupant].faction==u.faction) then
        seen[key]=true; q[#q+1]={x=x,y=y,d=p.d+1,parent=cursor-1}
      end
    end end
  end
  return cells
end
-- Integer Bresenham sight line; solid X terrain blocks projectiles, water does not.
local function line_of_sight(a,b)
  local x,y=a.x,a.y;local dx,dy=math.abs(b.x-x),math.abs(b.y-y)
  local sx,sy=x<b.x and 1 or -1,y<b.y and 1 or -1;local err=dx-dy
  while x~=b.x or y~=b.y do
    local doubled=2*err
    if doubled>-dy then err=err-dy;x=x+sx end
    if doubled<dx then err=err+dx;y=y+sy end
    if content.terrain[y+1]:sub(x+1,x+1)=='X' then return false end
  end
  return true
end

local function nearest(i)
  local u=state.units[i]; local best
  for j,v in ipairs(state.units) do
    if v.hp>0 and v.faction~=u.faction and (not best or distance(u,v)<distance(u,state.units[best])) then best=j end
  end
  return best
end
local function roll()
  state.rng=(state.rng*16807)%2147483647
  return state.rng%2
end
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

-- Outcome and deterministic story triggers. Shared lexical context; no IO.
local function objective_met(goal)
  if goal.kind=='all' or goal.kind=='any' then
    for _,child in ipairs(goal.children) do
      local met=objective_met(child)
      if goal.kind=='all' and not met then return false end
      if goal.kind=='any' and met then return true end
    end
    return goal.kind=='all'
  end
  if goal.kind=='survive' then return state.round_number>=goal.round end
  if goal.kind=='defeat_all' or goal.kind=='all_allies' then
    local ally=goal.kind=='all_allies'
    for _,u in ipairs(state.units) do if u.ally==ally and u.hp>0 then return false end end
    return true
  end
  for _,u in ipairs(state.units) do if u.id==goal.unit then
    if goal.kind=='protect' then return u.hp<=0 end
    if goal.kind=='reach' then return u.hp>0 and u.x==goal.x and u.y==goal.y end
  end end
  return false
end
local function outcome()
  -- Defeat wins simultaneous objectives. Restores recompute, rather than trust, terminal state.
  state.outcome='playing'
  if objective_met(content.defeat) then state.outcome='defeat'
  elseif objective_met(content.victory) then state.outcome='victory' end
end
local function story_update(initial,turn_start)
  for i,event in ipairs(content.story.events) do
    local t=event.trigger
    local fire=(initial and t=='chapter_enter_before_first_player_action')
      or (state.outcome=='victory' and t=='battle_terminal_victory')
      or (state.outcome=='defeat' and t=='battle_terminal_defeat')
    if state.outcome=='playing' and turn_start then
      fire=fire or (t=='first_player_turn_started_with_round_gte_2' and state.round_number>=2)
        or (t=='first_player_turn_started_with_round_gte_3' and state.round_number>=3)
        or (t=='round' and state.round_number>=event.round)
    end
    if fire then state.story_flags=state.story_flags | (1 << (i-1)) end
  end
end

function M.reset(args)
  local seed=args.seed or 12345
  assert(integer(seed,1,2147483646),'invalid seed')
  assert(type(args.content)=='table','content required')
  content=args.content;state=fresh(seed);effects={};outcome();drop_reward();story_update(true,false);return M.view()
end
function M.view()
  state.width=content.width;state.height=content.height;state.terrain=content.terrain
  return state
end
function M.events() return effects end
function M.reachable(args)
  local index=(args.unit or -1)+1;local destinations={}
  -- BFS keeps allied transit nodes for parent-chain reconstruction. The public
  -- range exposes only legal landing cells (plus the origin for UI context).
  for _,p in ipairs(reachable(index)) do
    local occupant=at(p.x,p.y)
    if not occupant or occupant==index then destinations[#destinations+1]=p end
  end
  return destinations
end
function M.path(args)
  local index=(args.unit or -1)+1;local u=state.units[index]
  if not u or u.hp<=0 or u.controller~='player' or state.outcome~='playing' or u.moves_used>=u.move_actions or at(args.x,args.y) then return {} end
  local cells=reachable(index)
  for j,p in ipairs(cells) do if p.x==args.x and p.y==args.y and p.d>0 then
    local result={};local cursor=j
    while cursor>0 do local cell=cells[cursor];table.insert(result,1,{x=cell.x,y=cell.y});cursor=cell.parent end
    return result
  end end
  return {}
end
-- Data-defined targeting, resource/charge/cooldown admission, then bounded effects.
-- Registry is trusted code. Mods supply only validated operation data.
local function ability_admission(u,index,id,target,consumable)
  local definition,slot
  local known=false;for _,candidate in ipairs(u.abilities) do if candidate==id then known=true end end
  if not known and not consumable then return false end
  for i,ability in ipairs(content.abilities) do if ability.id==id then definition=ability;slot=i;break end end
  if not definition or u.acted or u.mp<definition.mp_cost or u.cooldowns[slot]>0 then return false end
  if definition.charges>0 and u.charges[slot]<=0 then return false end
  if definition.stationary and u.moves_used>0 and not u.mobile_cast then return false end
  if not integer(target,0,#state.units-1) then return false end
  local v=state.units[target+1]
  if v.hp<=0 or distance(u,v)>u.reach+definition.reach_bonus then return false end
  if definition.los and not line_of_sight(u,v) then return false end
  if definition.target=='self' and target~=index-1 then return false end
  if definition.target=='ally' and v.faction~=u.faction then return false end
  if definition.target=='enemy' and v.faction==u.faction then return false end
  return definition,slot,v
end
local function cast_ability(u,index,id,target,consumable)
  local definition,slot,v=ability_admission(u,index,id,target,consumable)
  if not definition then return false end
  -- All validation precedes resource/RNG mutation. apply's candidate protects errors too.
  u.mp=u.mp-definition.mp_cost;u.cooldowns[slot]=definition.cooldown
  if definition.charges>0 then u.charges[slot]=u.charges[slot]-1 end
  for _,effect in ipairs(definition.effects) do
    local random=effect.op=='damage' and roll() or 0
    local critical=false
    if effect.op=='damage' and (definition.crit_chance or 0)>0 then critical=random_value(state,100)<definition.crit_chance end
    for _,recipient in ipairs(state.units) do
      if recipient.hp>0 and recipient.faction==v.faction and distance(recipient,v)<=effect.radius then
        if effect.op=='heal' then
          local before=recipient.hp;recipient.hp=math.min(recipient.max_hp,recipient.hp+effect.value)
          effects[#effects+1]={kind='heal',actor=u.id,target=recipient.id,amount=recipient.hp-before}
        elseif effect.op=='damage' then
          local raw=(definition.damage_type=='magic' and content.units[index].damage+u.spell_bonus or u.damage)+effect.value+random
          if critical then raw=raw*(definition.crit_multiplier or 150)//100 end
          local before=recipient.hp;recipient.hp=math.max(0,recipient.hp-math.max(1,raw-(definition.damage_type=='magic' and recipient.resist or recipient.armor)))
          effects[#effects+1]={kind='attack',actor=u.id,target=recipient.id,ability=id,is_critical=critical,damage=before-recipient.hp,hp=recipient.hp}
        else error('unsupported effect') end
      end
    end
  end
  u.acted=true
  if id==u.skill_id and definition.charges>0 then u.skill=u.charges[slot]>0 end
  return true
end

-- Read-only admission and conservative damage intervals. Never inspect or advance RNG.
function M.preview(args)
  local index=(args.unit or -1)+1;local u=state.units[index]
  if not u or u.hp<=0 or u.controller~='player' or state.outcome~='playing' then return {legal=false} end
  local id=args.ability;local consumable=false
  if args.kind=='attack' then id='attack' elseif args.kind=='skill' then id=u.skill_id
  elseif args.kind=='item' then
    for j,item in ipairs(content.consumables) do if item.id==args.consumable and state.supplies[j]>0 then id=item.ability;consumable=true;break end end
    if not consumable then return {legal=false} end
  end
  local definition,slot,v=ability_admission(u,index,id,args.target,consumable)
  if not definition then return {legal=false} end
  local variants={{hp=v.hp,damage=0,healing=0,critical=false}}
  local chance=definition.crit_chance or 0
  for _,effect in ipairs(definition.effects) do
    local next_variants={}
    for _,branch in ipairs(variants) do
      if branch.hp<=0 then next_variants[#next_variants+1]=branch
      elseif effect.op=='heal' then
        local restored=math.min(v.max_hp-branch.hp,effect.value)
        next_variants[#next_variants+1]={hp=branch.hp+restored,damage=branch.damage,healing=branch.healing+restored,critical=branch.critical}
      else
        local raw=(definition.damage_type=='magic' and content.units[index].damage+u.spell_bonus or u.damage)+effect.value
        local armor=definition.damage_type=='magic' and v.resist or v.armor
        for critical=0,1 do if (critical==0 and chance<100) or (critical==1 and chance>0) then
          for random=0,1 do
            local power=raw+random
            if critical==1 then power=power*(definition.crit_multiplier or 150)//100 end
            local amount=math.min(branch.hp,math.max(1,power-armor))
            next_variants[#next_variants+1]={hp=branch.hp-amount,damage=branch.damage+amount,healing=branch.healing,critical=branch.critical or critical==1}
          end
        end end
      end
    end
    variants=next_variants
  end
  local low,high,critical_low,critical_high,healing=1000000,0,1000000,0,0
  for _,branch in ipairs(variants) do
    low=math.min(low,branch.damage);high=math.max(high,branch.damage);healing=math.max(healing,branch.healing)
    if branch.critical then critical_low=math.min(critical_low,branch.damage);critical_high=math.max(critical_high,branch.damage) end
  end
  return {legal=true,low=low,high=high,critical_low=critical_low==1000000 and 0 or critical_low,critical_high=critical_high,crit_chance=chance,healing=healing}
end

-- One execution path for both player and internal AI commands.
-- Callers cannot request the internal capability through a network field.
local function execute_action(c,index)
    local u=state.units[index]
    if not u or u.hp<=0 then return false end
    if c.kind=='wait' then
      if u.acted and u.moves_used>=u.move_actions then return false end
      u.moves_used=u.move_actions;u.moved=true;u.acted=true
      effects[#effects+1]={kind='wait',actor=u.id}
    elseif c.kind=='move' then
      if u.moves_used>=u.move_actions or not walkable(c.x,c.y) or at(c.x,c.y) then return false end
      local found
      local cells=reachable(index)
      for j,p in ipairs(cells) do if p.x==c.x and p.y==c.y then found=j; break end end
      if not found then return false end
      local path={};local cursor=found
      while cursor>0 do local p=cells[cursor];table.insert(path,1,{x=p.x,y=p.y});cursor=p.parent end
      effects[#effects+1]={kind='move',actor=u.id,path=path}
      u.x,u.y=c.x,c.y;u.moves_used=u.moves_used+1;u.moved=u.moves_used>=u.move_actions
    elseif c.kind=='item' then
      local item,slot
      for j,d in ipairs(content.consumables) do if d.id==c.consumable then item=d;slot=j;break end end
      if not item or state.supplies[slot]<=0 then return false end
      if not cast_ability(u,index,item.ability,c.target,true) then return false end
      state.supplies[slot]=state.supplies[slot]-1;outcome()
    elseif c.kind=='attack' or c.kind=='skill' or c.kind=='ability' then
      local id=c.kind=='attack' and 'attack' or (c.kind=='skill' and u.skill_id or c.ability)
      if not cast_ability(u,index,id,c.target) then return false end
      outcome()
    else return false end
    return true
end

-- Bounded deterministic policies. Every proposed action uses execute_action;
-- system authority exists only inside the ordered EndTurn expansion.
local function sorted_units(predicate)
  local result={}
  for i,u in ipairs(state.units) do if u.hp>0 and predicate(u,i) then result[#result+1]=i end end
  table.sort(result,function(a,b) return state.units[a].id<state.units[b].id end)
  return result
end
local function run_ai_phase()
  local actors=sorted_units(function(u) return u.controller=='ai' end)
  for _,i in ipairs(actors) do
    local u=state.units[i];local config=content.units[i];local policy=config.policy or 'offensive'
    if u.hp>0 then
      local anchor={x=config.x,y=config.y};local leash=config.leash or 4
      if policy=='escort' then
        for _,other in ipairs(state.units) do if other.id==config.escort and other.hp>0 then anchor=other;break end end
      end
      local function within_policy(v)
        return policy~='defensive' and policy~='escort' or distance(anchor,v)<=leash
      end
      local enemies=sorted_units(function(v) return v.faction~=u.faction and within_policy(v) end)
      local target
      for _,j in ipairs(enemies) do if not target or distance(u,state.units[j])<distance(u,state.units[target]) then target=j end end
      local wounded=sorted_units(function(v) return v.faction==u.faction and v.hp<v.max_hp end)
      table.sort(wounded,function(a,b)
        local x,y=state.units[a],state.units[b];local missing_x,missing_y=x.max_hp-x.hp,y.max_hp-y.hp
        return missing_x>missing_y or (missing_x==missing_y and x.id<y.id)
      end)
      local function heal()
        if policy~='support' then return false end
        for _,j in ipairs(wounded) do for _,id in ipairs(u.abilities) do
          for _,ability in ipairs(content.abilities) do if ability.id==id and ability.target~='enemy' then
            local healing=false;for _,effect in ipairs(ability.effects) do if effect.op=='heal' then healing=true end end
            if healing and execute_action({kind='ability',ability=id,target=j-1},i) then return true end
          end end
        end end
        return false
      end
      heal()
      local destination=target and state.units[target] or nil
      if policy=='support' and #wounded>0 and not u.acted then destination=state.units[wounded[1]] end
      if policy=='escort' and distance(u,anchor)>2 then destination=anchor end
      if destination and distance(u,destination)>(destination.faction==u.faction and 1 or u.reach) then
        local best={x=u.x,y=u.y}
        for _,p in ipairs(reachable(i)) do
          if not at(p.x,p.y) and within_policy(p) and distance(p,destination)<distance(best,destination) then best=p end
        end
        if best.x~=u.x or best.y~=u.y then
          assert(execute_action({kind='move',x=best.x,y=best.y},i),'AI produced illegal move')
        end
      end
      if not u.acted then heal() end
      if not u.acted then
        for _,j in ipairs(enemies) do
          if execute_action({kind='attack',target=j-1},i) then break end
        end
      end
      outcome();if state.outcome~='playing' then break end
    end
  end
end

local function apply_command(c)
  effects={}
  if (state.outcome~='playing' and c.kind~='equip') or not integer(c.step,1,1000000) or c.step~=state.step+1 then return false end
  if c.kind=='end_turn' then
    run_ai_phase()
    state.round_number=state.round_number+1
    for _,u in ipairs(state.units) do u.moved=false;u.moves_used=0;u.acted=false;u.mp=math.min(u.max_mp,u.mp+1)
      for j,value in ipairs(u.cooldowns) do u.cooldowns[j]=math.max(0,value-1) end
    end
  else
    local index
    if type(c.actor_id)=='string' then
      for i,u in ipairs(state.units) do if u.id==c.actor_id then index=i;break end end
      if not index then return false end
      if c.unit~=nil and c.unit~=index-1 then return false end
    elseif integer(c.unit,0,#state.units-1) then index=c.unit+1 end
    if not index or state.units[index].controller~='player' then return false end
    if type(c.target_id)=='string' then
      local target
      for j,v in ipairs(state.units) do if v.id==c.target_id then target=j-1;break end end
      if target==nil or (c.target~=nil and c.target~=target) then return false end
      c.target=target
    end
    if c.kind=='equip' then
      if not equip_action(c,index) then return false end
    elseif not execute_action(c,index) then return false end
  end
  outcome()
  state.step=c.step;if c.kind~='equip' then state.preparation=false end
  drop_reward()
  story_update(false,c.kind=='end_turn')
  return true
end
-- Work on a candidate so any rejected action or caught Lua error is atomic.
local function clone(value)
  if type(value)~='table' then return value end
  local result={};for key,v in pairs(value) do result[key]=clone(v) end;return result
end
function M.apply(c)
  local previous=state;state=clone(previous)
  local ok,accepted=pcall(apply_command,c)
  if not ok or not accepted then state=previous;effects={};return false end
  return true
end
-- Canonical numeric snapshot v4. Content owns static definitions; no executable input.
function M.snapshot()
  local values={5,state.step,state.rng,state.round_number,({playing=0,victory=1,defeat=2})[state.outcome],state.story_flags,state.preparation and 1 or 0,#state.units}
  for _,u in ipairs(state.units) do
    for _,v in ipairs({u.x,u.y,u.hp,u.moves_used,u.acted and 1 or 0,u.skill and 1 or 0,u.mp}) do values[#values+1]=v end
    for i=1,#content.abilities do values[#values+1]=u.cooldowns[i];values[#values+1]=u.charges[i] end
    for _,uid in ipairs(u.equipment) do values[#values+1]=uid end
  end
  for _,count in ipairs(state.supplies) do values[#values+1]=count end
  values[#values+1]=state.next_item;values[#values+1]=state.rewarded and 1 or 0;values[#values+1]=#state.inventory
  for _,item in ipairs(state.inventory) do
    for _,v in ipairs({item.uid,item.base,item.quality,item.seed,#item.affixes}) do values[#values+1]=v end
    for _,a in ipairs(item.affixes) do values[#values+1]=a.index;values[#values+1]=a.value end
  end
  return table.concat(values,',')
end
function M.restore(args)
  local raw=args.snapshot
  if type(raw)~='string' or #raw>16384 or not raw:match('^%d[%d,]*%d$') then return false end
  local values={}
  for v in raw:gmatch('[^,]+') do
    if #v>10 then return false end
    local n=math.tointeger(v);if not n then return false end;values[#values+1]=n
  end
  local count=#content.units;local stride=16+2*#content.abilities
  if #values<11+count*stride or table.concat(values,',')~=raw or values[1]~=5 or not integer(values[2],0,1000000)
    or not integer(values[3],1,2147483646) or not integer(values[4],1,1000001) or not integer(values[5],0,2)
    or not integer(values[6],0,(1 << #content.story.events)-1) or not integer(values[7],0,1) or values[8]~=count then return false end
  local candidate=fresh(values[3]);candidate.rng=values[3];candidate.step=values[2];candidate.round_number=values[4]
  candidate.outcome=({'playing','victory','defeat'})[values[5]+1];candidate.story_flags=values[6];candidate.preparation=values[7]==1
  local cursor=9+count*stride
  candidate.supplies={}
  for i,item in ipairs(content.consumables) do
    if not integer(values[cursor],0,item.count) then return false end
    candidate.supplies[i]=values[cursor];cursor=cursor+1
  end
  if not integer(values[cursor],1,1000001) or not integer(values[cursor+1],0,1) or not integer(values[cursor+2],0,32) then return false end
  candidate.next_item=values[cursor];candidate.rewarded=values[cursor+1]==1;candidate.inventory={}
  local items=values[cursor+2];cursor=cursor+3;local by_uid={}
  for i=1,items do
    local uid,base,quality,seed,affix_count=values[cursor],values[cursor+1],values[cursor+2],values[cursor+3],values[cursor+4];cursor=cursor+5
    if not integer(uid,1,candidate.next_item-1) or by_uid[uid] or not integer(base,1,#content.equipment.bases) or not integer(quality,0,3) or not integer(seed,1,2147483646) or not integer(affix_count,0,16) then return false end
    local item={uid=uid,base=base,quality=quality,seed=seed,affixes={}};local seen={}
    for j=1,affix_count do
      local index,value=values[cursor],values[cursor+1];cursor=cursor+2
      if not integer(index,1,#content.equipment.affixes) or seen[index] then return false end
      local a=content.equipment.affixes[index]
      if not integer(value,a.minimum,a.maximum) then return false end
      seen[index]=true;item.affixes[j]={index=index,value=value}
    end
    candidate.inventory[i]=item;by_uid[uid]=item
  end
  if cursor~=#values+1 then return false end
  local equipped={};local slots={'main_hand','off_hand','head','body','hands','feet','neck','ring','ring'}
  for i,u in ipairs(candidate.units) do
    local k=9+(i-1)*stride+7+2*#content.abilities
    for slot=1,9 do
      local uid=values[k+slot-1]
      if not integer(uid,0,candidate.next_item-1) then return false end
      if uid~=0 then
        if not by_uid[uid] or equipped[uid] or content.equipment.bases[by_uid[uid].base].slot~=slots[slot] then return false end
        equipped[uid]=true
      end
      u.equipment[slot]=uid
    end
  end
  derive_equipment(candidate)
  local occupied={}
  for i,u in ipairs(candidate.units) do
    local k=9+(i-1)*stride;local x,y,hp=values[k],values[k+1],values[k+2]
    if not walkable(x,y) or not integer(hp,0,u.max_hp) or not integer(values[k+3],0,u.move_actions) or not integer(values[k+6],0,u.max_mp) then return false end
    for j=4,5 do if not integer(values[k+j],0,1) then return false end end
    if hp>0 then local key=y*content.width+x;if occupied[key] then return false end;occupied[key]=true end
    for j,ability in ipairs(content.abilities) do
      local offset=k+7+(j-1)*2
      if not integer(values[offset],0,ability.cooldown) or not integer(values[offset+1],0,ability.charges) then return false end
      u.cooldowns[j]=values[offset];u.charges[j]=values[offset+1]
    end
    u.x,u.y,u.hp=x,y,hp;u.moves_used=values[k+3];u.moved=u.moves_used>=u.move_actions;u.acted=values[k+4]==1;u.skill=values[k+5]==1;u.mp=values[k+6]
  end
  local expected=candidate.outcome;local old=state;state=candidate;outcome()
  if state.outcome~=expected then state=old;return false end
  effects={};return true
end

return M
