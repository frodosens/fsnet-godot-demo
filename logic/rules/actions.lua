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
    elseif c.kind=='attack' or c.kind=='skill' then
      local special=c.kind=='skill'
      if u.acted or (special and not u.skill) then return false end
      if special and u.role=='knight' then
        if c.target~=index-1 then return false end
        u.hp=math.min(u.max_hp,u.hp+3)
      else
        if not integer(c.target,0,#state.units-1) then return false end
        local v=state.units[c.target+1]
        local reach=u.reach+(special and 1 or 0)
        if v.hp<=0 or v.faction==u.faction or distance(u,v)>reach then return false end
        local damage=u.damage+(special and 1 or 0)+roll()
        if special and u.role=='mage' then
          for _,foe in ipairs(state.units) do
            if foe.faction~=u.faction and foe.hp>0 and distance(foe,v)<=1 then foe.hp=math.max(0,foe.hp-damage) end
          end
        else
          local before=v.hp;v.hp=math.max(0,v.hp-damage)
          effects[#effects+1]={kind='attack',actor=u.id,target=v.id,damage=before-v.hp,hp=v.hp}
        end
      end
      u.acted=true; if special then u.skill=false end
      outcome()
    else return false end
    return true
end
