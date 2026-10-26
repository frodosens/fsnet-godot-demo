-- One execution path for both player and internal AI commands.
-- Callers cannot request the internal capability through a network field.
local function execute_action(c,index)
    local u=state.units[index]
    if not u or u.hp<=0 then return false end
    if c.kind=='move' then
      if u.moves_used>=u.move_actions or not walkable(c.x,c.y) or at(c.x,c.y) then return false end
      local found=false
      for _,p in ipairs(reachable(index)) do if p.x==c.x and p.y==c.y then found=true; break end end
      if not found then return false end
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
