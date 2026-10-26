-- Original rules. No engine, transport, clock, float arithmetic or ambient RNG.
-- Array iteration and BFS direction order are part of the deterministic contract.
local M = {}
local state
local content
local effects={}
local directions = {{-1,0},{1,0},{0,-1},{0,1}}
local function unit(name,role,ally,x,y,hp,movement,reach,damage)
  return {name=name,role=role,ally=ally,x=x,y=y,hp=hp,max_hp=hp,movement=movement,
    reach=reach,damage=damage,moved=false,acted=false,skill=true}
end
local function fresh(seed)
  local result={version=2,step=0,rng=seed,round_number=1,outcome='playing',story_flags=0,preparation=true,units={}}
  for _,d in ipairs(content.units) do
    local u=unit(d.name,d.role,d.ally,d.x,d.y,d.hp,d.movement,d.reach,d.damage)
    u.id=d.id;u.mp=d.mp;u.max_mp=d.mp;u.moves_used=0;u.move_actions=1;u.armor=d.armor;u.resist=d.resist
    result.units[#result.units+1]=u
  end
  return result
end
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
  local seen={[u.y*content.width+u.x]=true}; local q={{x=u.x,y=u.y,d=0}}; local cursor=1
  while cursor<=#q do
    local p=q[cursor]; cursor=cursor+1; cells[#cells+1]=p
    if p.d<u.movement then for _,v in ipairs(directions) do
      local x,y=p.x+v[1],p.y+v[2]; local key=y*content.width+x
      if walkable(x,y) and not seen[key] and not at(x,y) then
        seen[key]=true; q[#q+1]={x=x,y=y,d=p.d+1}
      end
    end end
  end
  return cells
end
local function nearest(i)
  local u=state.units[i]; local best
  for j,v in ipairs(state.units) do
    if v.hp>0 and v.ally~=u.ally and (not best or distance(u,v)<distance(u,state.units[best])) then best=j end
  end
  return best
end
local function roll()
  state.rng=(state.rng*16807)%2147483647
  return state.rng%2
end
local function outcome()
  state.outcome='playing'
  local a,b=0,0
  for _,u in ipairs(state.units) do if u.hp>0 then if u.ally then a=a+1 else b=b+1 end end end
  if a==0 then state.outcome='defeat' elseif b==0 then state.outcome='victory' end
  if content.defeat.kind=='protect' then
    for _,u in ipairs(state.units) do if u.id==content.defeat.unit and u.hp==0 then state.outcome='defeat' end end
  end
  if state.outcome=='playing' and content.victory.kind=='reach' then
    for _,u in ipairs(state.units) do if u.id==content.victory.unit and u.hp>0 and u.x==content.victory.x and u.y==content.victory.y then state.outcome='victory' end end
  end
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
  content=args.content;state=fresh(seed);effects={};story_update(true,false);return M.view()
end
function M.view()
  state.width=content.width;state.height=content.height;state.terrain=content.terrain
  return state
end
function M.events() return effects end
function M.reachable(args) return reachable((args.unit or -1)+1) end
function M.apply(c)
  effects={}
  if state.outcome~='playing' or not integer(c.step,1,1000000) or c.step~=state.step+1 then return false end
  if c.kind=='end_turn' then
    for i,u in ipairs(state.units) do if not u.ally and u.hp>0 then
      local target=nearest(i)
      if target and distance(u,state.units[target])>u.reach then
        local best={x=u.x,y=u.y}
        for _,p in ipairs(reachable(i)) do
          if distance(p,state.units[target])<distance(best,state.units[target]) then best=p end
        end
        u.x,u.y=best.x,best.y
      end
      target=nearest(i)
      if target and distance(u,state.units[target])<=u.reach then
        local v=state.units[target]; v.hp=math.max(0,v.hp-u.damage-roll())
      end
      outcome(); if state.outcome~='playing' then break end
    end end
    state.round_number=state.round_number+1
    for _,u in ipairs(state.units) do u.moved=false;u.moves_used=0;u.acted=false;u.mp=math.min(u.max_mp,u.mp+1) end
  else
    if not integer(c.unit,0,#state.units-1) then return false end
    local u=state.units[c.unit+1]
    if u.hp<=0 or not u.ally then return false end
    if c.kind=='move' then
      if u.moves_used>=u.move_actions or not walkable(c.x,c.y) or at(c.x,c.y) then return false end
      local found=false
      for _,p in ipairs(reachable(c.unit+1)) do if p.x==c.x and p.y==c.y then found=true; break end end
      if not found then return false end
      u.x,u.y=c.x,c.y;u.moves_used=u.moves_used+1;u.moved=u.moves_used>=u.move_actions
    elseif c.kind=='attack' or c.kind=='skill' then
      local special=c.kind=='skill'
      if u.acted or (special and not u.skill) then return false end
      if special and u.role=='knight' then
        if c.target~=c.unit then return false end
        u.hp=math.min(u.max_hp,u.hp+3)
      else
        if not integer(c.target,0,#state.units-1) then return false end
        local v=state.units[c.target+1]
        local reach=u.reach+(special and 1 or 0)
        if v.hp<=0 or v.ally or distance(u,v)>reach then return false end
        local damage=u.damage+(special and 1 or 0)+roll()
        if special and u.role=='mage' then
          for _,foe in ipairs(state.units) do
            if not foe.ally and foe.hp>0 and distance(foe,v)<=1 then foe.hp=math.max(0,foe.hp-damage) end
          end
        else v.hp=math.max(0,v.hp-damage) end
      end
      u.acted=true; if special then u.skill=false end
      outcome()
    else return false end
  end
  state.step=c.step;state.preparation=false
  story_update(false,c.kind=='end_turn')
  return true
end
-- A canonical, bounded, numeric snapshot. Never evaluates code from a peer.
function M.snapshot()
  local values={2,state.step,state.rng,state.round_number,({playing=0,victory=1,defeat=2})[state.outcome],state.story_flags,state.preparation and 1 or 0,#state.units}
  for _,u in ipairs(state.units) do
    for _,v in ipairs({u.x,u.y,u.hp,u.moves_used,u.acted and 1 or 0,u.skill and 1 or 0,u.mp}) do values[#values+1]=v end
  end
  return table.concat(values,',')
end
function M.restore(args)
  local raw=args.snapshot
  if type(raw)~='string' or #raw>8192 or not raw:match('^%d[%d,]*%d$') then return false end
  local values={}
  for v in raw:gmatch('[^,]+') do
    if #v>10 then return false end
    local n=math.tointeger(v);if not n then return false end;values[#values+1]=n
  end
  local count=#content.units
  if #values~=8+count*7 or table.concat(values,',')~=raw or values[1]~=2 or not integer(values[2],0,1000000)
    or not integer(values[3],1,2147483646) or not integer(values[4],1,1000001) or not integer(values[5],0,2)
    or not integer(values[6],0,(1 << #content.story.events)-1) or not integer(values[7],0,1) or values[8]~=count then return false end
  local candidate=fresh(values[3]);candidate.step=values[2];candidate.round_number=values[4]
  candidate.outcome=({'playing','victory','defeat'})[values[5]+1];candidate.story_flags=values[6];candidate.preparation=values[7]==1
  local occupied={}
  for i,u in ipairs(candidate.units) do
    local k=9+(i-1)*7;local x,y,hp=values[k],values[k+1],values[k+2]
    if not walkable(x,y) or not integer(hp,0,u.max_hp) or not integer(values[k+3],0,u.move_actions) or not integer(values[k+6],0,u.max_mp) then return false end
    for j=4,5 do if not integer(values[k+j],0,1) then return false end end
    if hp>0 then local key=y*content.width+x;if occupied[key] then return false end;occupied[key]=true end
    u.x,u.y,u.hp=x,y,hp;u.moves_used=values[k+3];u.moved=u.moves_used>=u.move_actions;u.acted=values[k+4]==1;u.skill=values[k+5]==1;u.mp=values[k+6]
  end
  local expected=candidate.outcome
  local old=state;state=candidate;outcome()
  if state.outcome~=expected then state=old;return false end
  effects={};return true
end
return M
