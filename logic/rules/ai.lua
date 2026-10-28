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
