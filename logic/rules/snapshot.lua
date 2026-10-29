-- Canonical numeric snapshot v6. Content owns static definitions; no executable input.
function M.snapshot()
  local values={6,state.step,state.rng,state.round_number,({playing=0,victory=1,defeat=2})[state.outcome],state.story_flags,state.preparation and 1 or 0,#state.units}
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
  local function append_id(id)
    values[#values+1]=#id;for i=1,#id do values[#values+1]=id:byte(i) end
  end
  values[#values+1]=state.progression_settled and 1 or 0
  values[#values+1]=#state.campaign.roster
  for _,r in ipairs(state.campaign.roster) do append_id(r.id);values[#values+1]=r.xp end
  values[#values+1]=#state.campaign.completed
  for _,id in ipairs(state.campaign.completed) do append_id(id) end
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
  if #values<11+count*stride or table.concat(values,',')~=raw or (values[1]~=6 and not (values[1]==5 and args.allow_legacy==true)) or not integer(values[2],0,1000000)
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
  if values[1]==6 then
    local settled=values[cursor];local records=values[cursor+1];cursor=cursor+2
    if not integer(settled,0,1) or not integer(records,0,32) then return false end
    local function read_id()
      local n=values[cursor];cursor=cursor+1
      if not integer(n,1,40) then return nil end
      local chars={};for i=1,n do
        if not integer(values[cursor],0,127) then return nil end
        chars[i]=string.char(values[cursor]);cursor=cursor+1
      end
      return table.concat(chars)
    end
    local campaign={roster={},completed={}};local previous=''
    for i=1,records do
      local id=read_id();local xp=values[cursor];cursor=cursor+1
      if not valid_id(id) or id<=previous then return false end
      previous=id;campaign.roster[i]={id=id,xp=xp}
    end
    local completed=values[cursor];cursor=cursor+1
    if not integer(completed,0,32) then return false end
    previous=''
    for i=1,completed do
      local id=read_id();if not valid_id(id) or id<=previous then return false end
      previous=id;campaign.completed[i]=id
    end
    if not import_campaign(candidate,campaign) or #candidate.campaign.roster~=records then return false end
    candidate.progression_settled=settled==1
    if candidate.progression_settled~=(candidate.outcome~='playing') then return false end
  else
    -- Explicit legacy import is separately authenticated by the save reader.
    candidate.progression_settled=candidate.outcome~='playing'
    if candidate.outcome=='victory' then candidate.campaign.completed={content.id} end
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
