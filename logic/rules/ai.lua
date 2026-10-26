-- Deterministic internal expansion of the one authoritative end_turn command.
-- The same move/attack validator and effect application serve both sides.
local function run_ai_phase()
  for i,u in ipairs(state.units) do if u.controller=='ai' and u.hp>0 then
    local target=nearest(i)
    if target and distance(u,state.units[target])>u.reach then
      local best={x=u.x,y=u.y}
      for _,p in ipairs(reachable(i)) do
        if distance(p,state.units[target])<distance(best,state.units[target]) then best=p end
      end
      if best.x~=u.x or best.y~=u.y then
        assert(execute_action({kind='move',x=best.x,y=best.y},i),'AI produced illegal move')
      end
    end
    target=nearest(i)
    if target and distance(u,state.units[target])<=u.reach then
      assert(execute_action({kind='attack',target=target-1},i),'AI produced illegal attack')
    end
    outcome();if state.outcome~='playing' then break end
  end end
end
