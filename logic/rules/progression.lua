-- Fixed integer campaign growth. No clocks, new RNG draws, or client XP commands.
local progression_config={thresholds={0,60,150,270,420,600,810,1050,1320,1620},kill_xp=30,victory_xp=90,hp_per_level=1,mp_per_level=1,attack_every_levels=2}
local function valid_id(id)
  return type(id)=='string' and #id>=1 and #id<=40 and not id:find('[^a-z0-9_%-]')
end
local function exact_keys(t,keys)
  if type(t)~='table' then return false end
  for k in pairs(t) do if not keys[k] then return false end end
  return true
end
local function dense(t,limit)
  if type(t)~='table' or #t>limit then return false end
  for k in pairs(t) do if not integer(k,1,#t) then return false end end
  return true
end
local function import_campaign(s,c,chapter_id)
  if not exact_keys(c,{roster=true,completed=true}) or not dense(c.roster,32) or not dense(c.completed,32) then return false end
  local roster,completed={},{};local seen={}
  for _,r in ipairs(c.roster) do
    if not exact_keys(r,{id=true,xp=true}) or not valid_id(r.id) or seen[r.id] or not integer(r.xp,0,1620) then return false end
    seen[r.id]=true;roster[#roster+1]={id=r.id,xp=r.xp}
  end
  seen={}
  for _,id in ipairs(c.completed) do
    if not valid_id(id) or seen[id] then return false end
    seen[id]=true;completed[#completed+1]=id
  end
  -- Reserve a completion slot before a playable state can be admitted.
  if #completed==32 and not seen[chapter_id or content.id] then return false end
  for _,u in ipairs(s.units) do if u.controller=='player' then
    local found=false;for _,r in ipairs(roster) do if r.id==u.id then found=true end end
    if not found then roster[#roster+1]={id=u.id,xp=0} end
  end end
  if #roster>32 then return false end
  table.sort(roster,function(a,b)return a.id<b.id end);table.sort(completed)
  s.campaign={roster=roster,completed=completed};return true
end
initialize_progression=function(s)
  s.progression_settled=false;assert(import_campaign(s,{roster={},completed={}}))
end
derive_progression=function(u,d,s)
  local xp=0
  if u.controller=='player' then for _,r in ipairs(s.campaign.roster) do if r.id==u.id then xp=r.xp;break end end end
  local level=1;for i,v in ipairs(progression_config.thresholds) do if xp>=v then level=i end end
  u.xp=xp;u.level=level;u.xp_floor=progression_config.thresholds[level];u.xp_next=progression_config.thresholds[level+1] or u.xp_floor
  u.base_hp=d.hp+(level-1)*progression_config.hp_per_level
  u.base_damage=d.damage+(level-1)//progression_config.attack_every_levels
  u.max_mp=d.mp+(d.mp>0 and (level-1)*progression_config.mp_per_level or 0)
  u.mp=math.min(u.mp,u.max_mp)
end
settle_progression=function()
  if state.outcome=='playing' or state.progression_settled then return end
  state.progression_settled=true
  if state.outcome~='victory' then return end -- Failed attempts earn nothing; no defeat farming.
  for _,id in ipairs(state.campaign.completed) do if id==content.id then return end end
  assert(#state.campaign.completed<32,'campaign chapter limit')
  local players,factions={},{}
  for _,u in ipairs(state.units) do if u.controller=='player' then players[#players+1]=u;factions[u.faction]=true end end
  table.sort(players,function(a,b)return a.id<b.id end)
  local pool=progression_config.victory_xp
  for i,u in ipairs(state.units) do
    if not factions[u.faction] and u.hp<=0 and definition_of(u).hp>0 then pool=pool+progression_config.kill_xp end
  end
  if #players>0 then
    for i,u in ipairs(players) do
      local amount=pool//#players+(i<=pool%#players and 1 or 0)
      for _,r in ipairs(state.campaign.roster) do if r.id==u.id then
        local before=r.xp;r.xp=math.min(1620,r.xp+amount)
        effects[#effects+1]={kind='experience',actor=u.id,amount=r.xp-before,xp=r.xp}
      end end
    end
  end
  state.campaign.completed[#state.campaign.completed+1]=content.id;table.sort(state.campaign.completed)
  derive_equipment(state) -- Never heals, resurrects, or resets action/cooldown state.
end
function M.progression()return {campaign=state.campaign,config=progression_config,settled=state.progression_settled} end

function M.validate_campaign(args)return import_campaign({units={}},args.campaign) end
