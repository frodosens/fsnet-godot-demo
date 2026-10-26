-- Original rules. No engine, transport, clock, float arithmetic or ambient RNG.
-- Array iteration and BFS direction order are part of the deterministic contract.
local M = {}
local state
local directions = {{-1,0},{1,0},{0,-1},{0,1}}
local function unit(name,role,ally,x,y,hp,movement,reach,damage)
  return {name=name,role=role,ally=ally,x=x,y=y,hp=hp,max_hp=hp,movement=movement,
    reach=reach,damage=damage,moved=false,acted=false,skill=true}
end
local function fresh(seed)
  return {version=1,step=0,rng=seed,round_number=1,outcome='playing',units={
    unit('Mara','knight',true,3,6,12,3,1,3),
    unit('Finn','archer',true,4,6,8,3,3,2),
    unit('Neri','mage',true,5,6,8,3,2,2),
    unit('Raider','raider',false,3,1,6,2,1,2),
    unit('Scout','raider',false,5,1,5,3,1,2),
    unit('Brute','brute',false,6,2,8,2,1,2)}}
end
local function integer(n,lo,hi) return math.type(n)=='integer' and n>=lo and n<=hi end
local function walkable(x,y)
  return integer(x,0,9) and integer(y,0,7) and ((y~=3 and y~=4) or x==4 or x==5)
end
local function at(x,y)
  for i,u in ipairs(state.units) do if u.hp>0 and u.x==x and u.y==y then return i end end
end
local function distance(a,b) return math.abs(a.x-b.x)+math.abs(a.y-b.y) end
local function reachable(i)
  local u=state.units[i]; local cells={}; if not u or u.hp<=0 then return cells end
  local seen={[u.y*10+u.x]=true}; local q={{x=u.x,y=u.y,d=0}}; local cursor=1
  while cursor<=#q do
    local p=q[cursor]; cursor=cursor+1; cells[#cells+1]=p
    if p.d<u.movement then for _,v in ipairs(directions) do
      local x,y=p.x+v[1],p.y+v[2]; local key=y*10+x
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
end
function M.reset(args)
  local seed=args.seed or 12345
  assert(integer(seed,1,2147483646),'invalid seed')
  state=fresh(seed); return M.view()
end
function M.view()
  return state
end
function M.reachable(args) return reachable((args.unit or -1)+1) end
function M.apply(c)
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
    for _,u in ipairs(state.units) do u.moved=false; u.acted=false end
  else
    if not integer(c.unit,0,2) then return false end
    local u=state.units[c.unit+1]
    if u.hp<=0 then return false end
    if c.kind=='move' then
      if u.moved or not walkable(c.x,c.y) or at(c.x,c.y) then return false end
      local found=false
      for _,p in ipairs(reachable(c.unit+1)) do if p.x==c.x and p.y==c.y then found=true; break end end
      if not found then return false end
      u.x,u.y=c.x,c.y; u.moved=true
    elseif c.kind=='attack' or c.kind=='skill' then
      local special=c.kind=='skill'
      if u.acted or (special and not u.skill) then return false end
      if special and u.role=='knight' then
        if c.target~=c.unit then return false end
        u.hp=math.min(u.max_hp,u.hp+3)
      else
        if not integer(c.target,3,5) then return false end
        local v=state.units[c.target+1]
        local reach=u.reach+(special and 1 or 0)
        if v.hp<=0 or distance(u,v)>reach then return false end
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
  state.step=c.step
  return true
end
-- A canonical, bounded, numeric snapshot. Never evaluates code from a peer.
function M.snapshot()
  local values={1,state.step,state.rng,state.round_number,({playing=0,victory=1,defeat=2})[state.outcome]}
  for _,u in ipairs(state.units) do
    for _,v in ipairs({u.x,u.y,u.hp,u.moved and 1 or 0,u.acted and 1 or 0,u.skill and 1 or 0}) do values[#values+1]=v end
  end
  return table.concat(values,',')
end
function M.restore(args)
  local raw=args.snapshot
  if type(raw)~='string' or #raw>1024 or not raw:match('^%d[%d,]*%d$') then return false end
  local values={}
  for v in raw:gmatch('[^,]+') do
    if #v>10 then return false end
    local n=math.tointeger(v); if not n then return false end
    values[#values+1]=n
  end
  if #values~=41 or table.concat(values,',')~=raw or values[1]~=1 or not integer(values[2],0,1000000)
    or not integer(values[3],1,2147483646) or not integer(values[4],1,1000001) or not integer(values[5],0,2) then return false end
  local candidate=fresh(values[3]); candidate.step=values[2]; candidate.round_number=values[4]
  candidate.outcome=({'playing','victory','defeat'})[values[5]+1]
  local occupied={}
  for i,u in ipairs(candidate.units) do
    local k=6+(i-1)*6; local x,y,hp=values[k],values[k+1],values[k+2]
    if not walkable(x,y) or not integer(hp,0,u.max_hp) then return false end
    for j=3,5 do if not integer(values[k+j],0,1) then return false end end
    if hp>0 then local key=y*10+x; if occupied[key] then return false end; occupied[key]=true end
    u.x,u.y,u.hp=x,y,hp; u.moved=values[k+3]==1;u.acted=values[k+4]==1;u.skill=values[k+5]==1
  end
  local expected=candidate.outcome
  local old=state;state=candidate;outcome()
  if state.outcome~=expected then state=old;return false end
  return true
end
return M
