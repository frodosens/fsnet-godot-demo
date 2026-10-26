-- Data-defined targeting, resource/charge/cooldown admission, then bounded effects.
-- Registry is trusted code. Mods supply only validated operation data.
local function cast_ability(u,index,id,target,consumable)
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
  -- All validation precedes resource/RNG mutation. apply's candidate protects errors too.
  u.mp=u.mp-definition.mp_cost;u.cooldowns[slot]=definition.cooldown
  if definition.charges>0 then u.charges[slot]=u.charges[slot]-1 end
  for _,effect in ipairs(definition.effects) do
    local random=effect.op=='damage' and roll() or 0
    for _,recipient in ipairs(state.units) do
      if recipient.hp>0 and recipient.faction==v.faction and distance(recipient,v)<=effect.radius then
        if effect.op=='heal' then recipient.hp=math.min(recipient.max_hp,recipient.hp+effect.value)
        elseif effect.op=='damage' then
          local before=recipient.hp;recipient.hp=math.max(0,recipient.hp-math.max(1,(definition.damage_type=='magic' and content.units[index].damage+u.spell_bonus or u.damage)+effect.value+random-(definition.damage_type=='magic' and recipient.resist or recipient.armor)))
          effects[#effects+1]={kind='attack',actor=u.id,target=recipient.id,ability=id,damage=before-recipient.hp,hp=recipient.hp}
        else error('unsupported effect') end
      end
    end
  end
  u.acted=true
  if id==u.skill_id and definition.charges>0 then u.skill=u.charges[slot]>0 end
  return true
end
