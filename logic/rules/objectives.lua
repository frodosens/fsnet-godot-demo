-- Outcome and deterministic story triggers. Shared lexical context; no IO.
local function objective_met(goal)
  if goal.kind=='all' or goal.kind=='any' then
    for _,child in ipairs(goal.children) do
      local met=objective_met(child)
      if goal.kind=='all' and not met then return false end
      if goal.kind=='any' and met then return true end
    end
    return goal.kind=='all'
  end
  if goal.kind=='survive' then return state.round_number>=goal.round end
  if goal.kind=='defeat_all' or goal.kind=='all_allies' then
    local ally=goal.kind=='all_allies'
    for _,u in ipairs(state.units) do if u.ally==ally and u.hp>0 then return false end end
    return true
  end
  for _,u in ipairs(state.units) do if u.id==goal.unit then
    if goal.kind=='protect' then return u.hp<=0 end
    if goal.kind=='reach' then return u.hp>0 and u.x==goal.x and u.y==goal.y end
  end end
  return false
end
local function outcome()
  -- Defeat wins simultaneous objectives. Restores recompute, rather than trust, terminal state.
  state.outcome='playing'
  if objective_met(content.defeat) then state.outcome='defeat'
  elseif objective_met(content.victory) then state.outcome='victory' end
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
