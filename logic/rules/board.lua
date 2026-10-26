-- Bounded grid queries shared by player and AI action validation.
local function integer(n,lo,hi) return math.type(n)=='integer' and n>=lo and n<=hi end
local function walkable(x,y)
  return integer(x,0,content.width-1) and integer(y,0,content.height-1)
    and content.terrain[y+1]:sub(x+1,x+1)~='W' and content.terrain[y+1]:sub(x+1,x+1)~='X'
end
local function at(x,y)
  for i,u in ipairs(state.units) do if u.hp>0 and u.x==x and u.y==y then return i end end
end
local function distance(a,b) return math.abs(a.x-b.x)+math.abs(a.y-b.y) end
local function reachable(i)
  local u=state.units[i]; local cells={}; if not u or u.hp<=0 then return cells end
  local seen={[u.y*content.width+u.x]=true}; local q={{x=u.x,y=u.y,d=0}}; local cursor=1
  while cursor<=#q do
    local p=q[cursor]; cursor=cursor+1; cells[#cells+1]=p
    if p.d<u.movement then for _,v in ipairs(directions) do
      local x,y=p.x+v[1],p.y+v[2]; local key=y*content.width+x
      if walkable(x,y) and not seen[key] and not at(x,y) then
        seen[key]=true; q[#q+1]={x=x,y=y,d=p.d+1}
      end
    end end
  end
  return cells
end
