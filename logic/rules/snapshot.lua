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
