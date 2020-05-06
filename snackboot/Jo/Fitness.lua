require "Utilities/Iterator"
Fitness = {}

local BallIterator = Iterator.Disk

function Fitness.FleetNucleus(tx, ty)
  return function(xs, ys)
    local score = 0
    for i = 1, #xs do
      score = score +
        1 / (GetSailDistance(xs[i], ys[i], tx, ty) + 0.01)
    end
    return score
  end
end

--Greedy fitness function for blocking border.
function Fitness.BlockBB(x, y)
  local OpSea = Jo.Sea(Jo.opid)
  for a = -1, 1 do
    for b = -1, 1 do
      if not OpSea(x + a, y + b) then
        return true
      end
    end
  end
end

local function ScoutBBRedundancy(bbs, rs, x, y)
  for _, bb in pairs(bbs) do
     if (bb.longitude - x) ^ 2 + (bb.latitude - y) ^ 2 <= rs then
      return 1.5
    end
  end
  return 0
end

--Scout BBs, for scouting.
local function ScoutBB(xs, ys, bbs)
  local scoutzone = 0
  --Heuristic: an unblocked battleship can scout effectively within twice its range.
  local r = GameRules.RadarRadius.BattleShip[0] * 2
  local Border = Map.SeaBorder.ContainsReal
  local OpSea = Jo.Sea(Jo.opid)
  local OpLand = Jo.Land(Jo.opid)
  local MySea = Jo.Sea(Jo.myid)
  local rs = r * r
  local n = #xs
  local x, y, pointvalue = xs[1], ys[1], 0
  for a, b in Iterator.Disk(r, x, y) do
    if OpSea(a, b) and not MySea(a, b) then
      pointvalue = 3
    elseif OpLand(a, b) then
      pointvalue = 4
    else
      pointvalue = false
    end
    if pointvalue then
      scoutzone = scoutzone + pointvalue * (1 - ScoutBBRedundancy(bbs, rs, a, b))
    end
  end
  return scoutzone
end

local function Placed(type)
  local placed = {}
  for id, data in pairs(GetAllUnitData()) do
    if data.type == "BattleShip" and data.team == Jo.myid then
      placed[id] = data
    end
  end
  return placed
end

function Fitness.ScoutBB()
  local placed = Placed("BattleShip")
  return function(xs, ys)
    return ScoutBB(xs, ys, placed)
  end
end

function Fitness.AirBase(xs, ys)
  return 5
end

local function RadarStation(xs, ys, silos, radar)
  return 5
end

--Main set of radar stations (between 4 and 7 of them).
--Tries to balance between silo protection and coastal visibility.
function Fitness.RadarStation()
  local silos = Placed("Silo")
  local radar = Placed("RadarStation")
  return function(xs, ys)
    return RadarStation(xs, ys, silos, radar)
  end  
end

local function ScoutRadarRedundancy(a, b, i, xs, ys, rs)
  local redundancy = 0
  for j = 1, i - 1 do
    if (xs[j] - a) ^ 2 + (ys[j] - b) ^ 2 <= rs then
      redundancy = redundancy + 1.5
    end
  end
  return redundancy
end

function Fitness.ScoutRadar(xs, ys)
  local scoutzone = 0
  local r = GameRules.RadarRadius.RadarStation[0]
  local OpSea  = Jo.Sea(Jo.opid)
  local OpLand = Jo.Land(Jo.opid)
  local OpRadar = Map.OpRadar.Contains
  local MyLand = Jo.Land(Jo.myid)
  local rs = r * r
  local pointvalue
  for i = 1, #xs do
    for a, b in Iterator.Disk(r, xs[i], ys[i]) do
      if OpLand(a, b) then pointvalue = 3
      elseif OpSea(a, b) then pointvalue = 2
      elseif OpRadar(a, b) and not MyLand(a, b) then pointvalue = 1
      else pointvalue = false end
      if pointvalue then
        scoutzone = scoutzone +
          pointvalue * (1 - ScoutRadarRedundancy(a, b, i, xs, ys, rs))
      end
    end
  end
  return scoutzone
end

function Fitness.Silo(xs, ys)
  local proximity, protection, vulnerability, split = 0, 0, 0, 0
  local DOA = Map.OpRadar.ContainsReal
  local Scoutable = Map.VulnScout.ContainsReal
  local InSubRange = Map.VulnSubs.ContainsReal
  local rshot = GameRules.CombatRadius.Silo[1]

  --Assumption: a silo can protect a city regardless of orientation.
  --Later this function should be informed by likely incoming nuke trajectories.
  local ProtectionOffered = function(d)
    --Protection offered by a silo drops linearly with distance.
    return math.max(0, 0.5 * rshot - d) / rshot
  end

  local MutualProtection = function(i)
    local prot, count = 0, 0
    for j = 1, i - 1 do
      local d = GetDistance(xs[i], ys[i], xs[j], ys[j])
      if 2 * d < rshot then count = count + 1 end
      prot = prot + count * ProtectionOffered(d)
    end
    return prot
  end

  for i = 1, #xs do
    local x, y = xs[i], ys[i]

    if DOA(x, y) then vulnerability = vulnerability + 10 end
    if Scoutable(x, y) then vulnerability = vulnerability + 5 end
    if InSubRange(x, y) then vulnerability = vulnerability + 3 end

    for id, city in pairs(Map.MyCities) do
      protection = protection + 
        ProtectionOffered(GetDistance(x, y, city.x, city.y)) * city.score
    end

    proximity = proximity + MutualProtection(i)
  end

  return 15 * proximity + protection - vulnerability + split
end

