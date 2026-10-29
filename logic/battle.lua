-- Original rules. No engine, transport, clock, float arithmetic or ambient RNG.
-- Array iteration and BFS direction order are part of the deterministic contract.
local M = {}
local state
local content
local definitions_by_id={}
local function definition_of(u) return assert(definitions_by_id[u.id],"unknown instance configuration") end
local effects={}
local initialize_inventory,derive_equipment,equip_action,drop_reward
local initialize_progression,derive_progression,settle_progression
local directions = {{-1,0},{1,0},{0,-1},{0,1}}
local function unit(name,role,ally,x,y,hp,movement,reach,damage)
  return {name=name,role=role,ally=ally,x=x,y=y,hp=hp,max_hp=hp,movement=movement,
    reach=reach,damage=damage,moved=false,acted=false,skill=true}
end
local function fresh(seed)
  local result={version=6,step=0,rng=seed,round_number=1,outcome='playing',story_flags=0,preparation=true,units={}}
  for _,d in ipairs(content.units) do
    local u=unit(d.name,d.role,d.ally,d.x,d.y,d.hp,d.movement,d.reach,d.damage)
    u.template_ref=d.template_ref;u.presentation_ref=d.presentation_ref
    u.id=d.id;u.controller=d.controller or (d.ally and "player" or "ai");u.faction=d.faction or (d.ally and "crew" or "guards");u.mp=d.mp;u.max_mp=d.mp;u.moves_used=0;u.move_actions=1;u.armor=d.armor;u.resist=d.resist
    u.abilities={};for j,id in ipairs(d.abilities) do u.abilities[j]=id end;u.skill_id=d.skill_id;u.cooldowns={};u.charges={}
    for j,ability in ipairs(content.abilities) do u.cooldowns[j]=0;u.charges[j]=ability.charges end
    result.units[#result.units+1]=u
  end
  initialize_progression(result);initialize_inventory(result);derive_equipment(result)
  result.supplies={};for i,item in ipairs(content.consumables) do result.supplies[i]=item.count end
  return result
end
-- @module board
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
-- @module progression
-- @module equipment
-- @module objectives
function M.reset(args)
  local seed=args.seed or 12345
  assert(integer(seed,1,2147483646),'invalid seed')
  assert(type(args.content)=='table','content required')
  -- Reject incompatible campaign imports before changing an existing VM/session.
  if args.campaign then
    local probe={units={}}
    for _,d in ipairs(args.content.units) do probe.units[#probe.units+1]={id=d.id,controller=d.controller or (d.ally and 'player' or 'ai')} end
    assert(import_campaign(probe,args.campaign,args.content.id),'invalid campaign')
  end
  local by_id={}
  for _,d in ipairs(args.content.units) do assert(type(d.id)=="string" and not by_id[d.id],"duplicate instance ID");by_id[d.id]=d end
  content=args.content;definitions_by_id=by_id;state=fresh(seed);effects={}
  if args.campaign then assert(import_campaign(state,args.campaign),'invalid campaign');derive_equipment(state) end
  for _,u in ipairs(state.units) do u.hp=u.max_hp;u.mp=u.max_mp end
  outcome();drop_reward();settle_progression();story_update(true,false);return M.view()
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
-- @module abilities
-- @module actions
-- @module ai
local function apply_command(c)
  effects={}
  if (state.outcome~='playing' and c.kind~='equip' and c.kind~='finish_story') or not integer(c.step,1,1000000) or c.step~=state.step+1 then return false end
  if c.kind=='finish_story' then
    if state.outcome~='victory' or type(c.event_id)~='string' then return false end
    local pending
    for i,event in ipairs(content.story.events) do
      if event.trigger=='campaign_finish' and (state.story_flags & (1 << (i-1)))==0 then pending=i;break end
    end
    if not pending or content.story.events[pending].id~=c.event_id then return false end
    state.story_flags=state.story_flags | (1 << (pending-1))
  elseif c.kind=='end_turn' then
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
  drop_reward();settle_progression()
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
-- @module snapshot
return M
