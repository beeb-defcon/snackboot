--Scout battleship movement.
require "Jo/Map"
require "Jo/GameRules"
require "Utilities/Iterator"
ScoutBB = {}

local function GetEnemyScouts()
  local res = {}
  for id, unit in pairs(GetAllUnitData()) do
    if unit.team == Jo.opid
       and unit.visible == true
       and GameRules.Scouts[unit.type] 
       and IsValidPlacementLocation(unit.longitude, unit.latitude, "BattleShip")
       then
      res[id] = unit
    end
  end
  return res
end

--Units need not be initialized.
local function GetBattleShips()
  local res = {}
  for id, unit in pairs(GetAllUnitData()) do
    if unit.type == "BattleShip" and unit.team == Jo.myid then
      res[id] = unit
    end
  end
  return res
end

function ScoutBB.MoveScouts()
  local bbs = GetBattleShips()
  local sea = IsSea
  local enemyland = Map.OpLand.Walk
  local cx, cy, tx, ty
  local maxdist = 225 --squared maximum distance a bb will travel to scout.

  for id, bb in pairs(bbs) do
    DebugLog("Moving battleship to scout.", id, "Scout", 151, 242, 151)  
    cx, cy = bb.longitude, bb.latitude
    local d, i = math.huge, 0
    for x, y in enemyland() do
      if i % 1000 == 0 then coroutine.yield() end
      if ((x - cx) ^ 2 + (y - cy) ^ 2) < d then
        tx, ty = x, y
        break
      end
    end
    for x, y in Iterator.LineSegment(tx, ty, cx, cy) do
      if sea(x, y) then
        DebugLog("Battleship moved.")
        WhiteboardDraw(cx, cy, x, y)
        id:SetMovementTarget(x, y)
        coroutine.yield()
        break
      end
    end
  end
end

function ScoutBB.Pursuit()
  local mybbs, opbbs = GetBattleShips(), GetEnemyScouts()
  for _, scout in pairs(opbbs) do
    for _, bb in pairs(mybbs) do
      if GetDistance(bb.longitude, bb.latitude, scout.longitude, scout.latitude) < 10 then
        scout.covered = true
        break
      end
    end
    if not scout.covered then
      DebugLog("Blocking attempt failed, placing another battleship.")
      PlaceFleet(scout.longitude, scout.latitude, "BattleShip")
      scout.covered = true
      coroutine.yield()
    end
  end
end