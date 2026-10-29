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
          local raw=(definition.damage_type=='magic' and u.base_damage+u.spell_bonus or u.damage)+effect.value+random
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
        local raw=(definition.damage_type=='magic' and u.base_damage+u.spell_bonus or u.damage)+effect.value
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
