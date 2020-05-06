require "Utilities/XCo"
require "Utilities/Iterator"
require "Jo/Fitness"

Placement = {}

--Normalize longitude correctly (e.g. Bot Russia can place in Alaska by reaching past the seam).
local IsValidPlacementLocation = XCo.IsValidPlacementLocation

local DebugPlacement = function() return nil, "Placement", 66, 171, 66 end

local function ValidPlacementSet(r, Valid)
  local rmin = r * r + 0.01 --wiggle room
  return function(xs, ys)
    if not xs[1] then return false end
    for i = 1, #xs do
      if not Valid(xs[i], ys[i]) then return false end
      for j = 1, i - 1 do
        if (xs[i] - xs[j])^ 2 + (ys[i] - ys[j])^ 2 <= rmin then return false end
      end
    end
    return true
  end
end

--Subroutine for getting a set of sample points from a map.
--Modifies xs and ys in place.
local function Sample(xs, ys, n, Samp, Valid)
  local k = 0
  repeat
    k = k + 1
    if k % 100 == 0 then
      coroutine.yield()
      if k == 10000 then
        DebugLog("Failed to sample.")
        return true
      end
    end
    for i = 1, n do
      xs[i], ys[i] = Samp()
    end
  until Valid(xs, ys)
  coroutine.yield()
end

local function SimulatedAnnealing(fit, map, type, units, maxtick, minfit)

  units = units or GetRemainingUnits(type)
  if units < 1 or not map:Sample() then return end
  maxtick = GetGameTick() + (maxtick or (100 * units))

  local Valid = ValidPlacementSet(GameRules.PlacementRadius[type],
    function(x, y) return
      IsValidPlacementLocation(x, y, type) and
      map.ContainsReal(x, y)
    end)

  local temp, cooldown = 100, 0.9
  local xs, ys, cxs, cys = {}, {}, {}, {}
  local failedtosample = Sample(xs, ys, units, map.Sample, Valid)
  if failedtosample then return end

  local mr, maxfit, curfit = math.random, -math.huge, -math.huge

  while temp > 1 and GetGameTick() < maxtick do
    for i = 1, units do
      cxs[i], cys[i] = xs[i] + temp * (mr() - 0.5), ys[i] + temp * (mr() - 0.5)
    end
    if Valid(cxs, cys) then
      curfit = fit(cxs, cys)
      if curfit > maxfit then
        maxfit = curfit
        temp = temp * cooldown
        for i = 1, units do
          WhiteboardDraw(xs[i], ys[i], cxs[i], cys[i])
          xs[i], ys[i] = cxs[i], cys[i]
        end
      end
    end
    coroutine.yield()
  end
  if minfit and (maxfit < minfit) then
    DebugLog("Annealer: "..type.." location not found. Fitness: "..maxfit)
    return 
  end
  DebugLog("Annealer: "..type.." location found. Fitness: "..maxfit)
  return xs, ys, type
end

local function DifferentialEvolution(fit, map, type, units, maxtick)

  units = units or GetRemainingUnits(type)
  if units < 1 or not map:Sample() then return end
  maxtick = GetGameTick() + (maxtick or (100 * units))

  --function that determines whether a configuration is valid
  local Valid = ValidPlacementSet(GameRules.PlacementRadius[type],
    function(x, y) return
      IsValidPlacementLocation(x, y, type) and
      map.ContainsReal(x, y)
    end)
  
  local crossover, diffweight, popsize = 1 / units, 0.2, 50

  --Initialize population.
  DebugLog("Initializing population.", DebugPlacement())
  local popx, popy, fitnesses = {}, {}, {}
  for i = 1, popsize do
    popx[i] = {}
    popy[i] = {}
    local failedtosample = Sample(popx[i], popy[i], units, map.Sample, Valid)
    if failedtosample then return end
    fitnesses[i] = fit(popx[i], popy[i])
  end

  --Optimization loop.
  local cxs, cys, mr, a, b, c, j = {}, {}, math.random

  DebugLog("Optimizing candidates.", DebugPlacement())
  repeat
    for i = 1, popsize do
      --Select three other agents.
      repeat
        a, b, c = mr(popsize), mr(popsize), mr(popsize)
      until a ~= b and b ~= c and c ~= a and a ~= x and b ~= x and c ~= x

      --Generate new candidate location from a, b, c.
      j = mr(units)
      for k = 1, units do
        if k == j or mr() < crossover * j then
          cxs[k] = popx[a][k] + diffweight * (popx[b][k] - popx[c][k])
          cys[k] = popy[a][k] + diffweight * (popy[b][k] - popy[c][k])
        else
          cxs[k], cys[k] = popx[i][k], popy[i][k]        
        end
      end

      --Improved candidate replaces existing agent.
      if Valid(cxs, cys) then
        curfitness = fit(cxs, cys)
        if curfitness > fitnesses[i] then
         fitnesses[i] = curfitness
         for k = 1, units do
           --WhiteboardDraw(popx[i][k], popy[i][k], cxs[k], cys[k])
           popx[i][k], popy[i][k] = cxs[k], cys[k]
         end
        end
      end
      if i % 15 == 0 then coroutine.yield() end
    end
    coroutine.yield()
  until GetGameTick() > maxtick

  --Select the agent with highest fitness.
  local maxfitness, xs, ys = -math.huge
  for i = 1, popsize do
    if fitnesses[i] > maxfitness then
      maxfitness = fitnesses[i]
    end
    xs = popx[i]
    ys = popy[i]
  end
  DebugLog("DE: "..units.." "..type.."s. Fitness: "..maxfitness, DebugPlacement())
  for i = 1, units - 1 do
    WhiteboardDraw(xs[i], ys[i], xs[i + 1], ys[i + 1])
  end
  WhiteboardDraw(xs[units], ys[units], xs[1], ys[1])
  return xs, ys, type, maxfitness
end

--Sample eligible placement vectors, pick the best one found.
local function HillClimb(fit, map, type, units, maxtick, discardfit, minfit)

  units = units or GetRemainingUnits(type)
  if units < 1 or not map:Sample() then return end
  minfit = minfit or math.huge
  maxtick = GetGameTick() + (maxtick or (100 * units))

  local Valid = ValidPlacementSet(GameRules.PlacementRadius[type],
    function(x, y) return IsValidPlacementLocation(x, y, type) end)
  local xs, ys, cxs, cys = {}, {}, {}, {}
  local curfitness, maxfitness =  -math.huge, -math.huge

  repeat
    Sample(cxs, cys, units, map.Sample, Valid)

    curfitness = fit(cxs, cys)
    if curfitness > maxfitness then
      maxfitness = curfitness
      for i = 1, units do
        WhiteboardDraw(xs[i] or 0, ys[i] or 0, cxs[i], cys[i])
        xs[i], ys[i] = cxs[i], cys[i]
      end
    end
  until maxfitness > minfit or GetGameTick() > maxtick

  if discardfit and (maxfitness < discardfit) then return end
  DebugLog("Sampler: "..units.." "..type.."s. Fitness: "..maxfitness, DebugPlacement())
  WhiteboardClear()
  return xs, ys, type
end

--Greedy algorithm for covering a region.
--fit is an indicator function for the region.
local function Greedy(fit, map, type, units, punchout)

  local r = GameRules.PlacementRadius[type]
  local Valid = function(x, y) return IsValidPlacementLocation(x, y, type) end

  local xs, ys = {}, {}
  r = math.ceil(math.max(r, punchout or 0))
  for i = 1, units do
    for x, y in map:Walk() do
      if Valid(x, y) and fit(x, y) then
        xs[i], ys[i] = x, y
        for a, b in Iterator.Disk(r) do
          map.Remove(x + a, y + b)
        end
        break
      end
    end
    if not xs[i] or map.Empty() then break end
  end
  DebugLog("Greedy: "..#xs.." "..type.."s.", DebugPlacement())
  return xs, ys, type
end

--Find places to put ships, based on a fleet's position and orientation.
local function FleetLocation(cx, cy, type, units, nx, ny)
  if not units or (units < 1) then return end
  units = math.min(units, GetRemainingUnits(type))

  --Get unit normal vector. Default to horizontal.
  nx, ny = nx or 0, ny or 1
  local norm = math.sqrt(nx * nx + ny * ny)
  if norm == 0 then
    nx, ny = 0, 1
  else
    norm = (0.01 + GameRules.PlacementRadius[type]) / norm
    nx, ny = norm * nx, norm * ny
  end

  local Valid = ValidPlacementSet(GameRules.PlacementRadius[type],
    function(x, y) return IsValidPlacementLocation(x, y, type) end)
  
  --Try rigid placement, followed by fluid placement.
  local function CandidatePoints()
    return coroutine.wrap(
      function()
        for x, y in Iterator.Bellow(cx, cy, nx, ny) do coroutine.yield(x, y) end
        for x, y in Iterator.Spiral(cx, cy, 10, 50) do coroutine.yield(x, y) end
      end)
  end

  --Main loop.
  local xs, ys = {}, {}
  local i = 1
  for x, y in CandidatePoints() do
    xs[i], ys[i] = x, y
    if Valid(xs, ys) then
      if i == units then return xs, ys, type end
      i = i + 1
    end
    coroutine.yield()
  end

  if not Valid(xs, ys) then
    xs[i], ys[i] = nil, nil
    if not Valid(xs, ys) then return end
  end

  return xs, ys, type
end

local function PlaceUnits(xs, ys, type)
  if not xs then return end
  local place
  if GameRules.ShipTypes[type] then
    place = function(x, y)
      WhiteboardDraw(x - 0.5, y - 0.5, x + 0.5, y + 0.5)
      PlaceFleet(x, y, type)
    end
  else
    place = function(x, y)
      WhiteboardDraw(x - 0.5, y - 0.5, x + 0.5, y + 0.5)
      PlaceStructure(x, y, type)
    end
  end
  for i = 1, #xs do
    place(xs[i], ys[i])
    --Simulate low APM.
    for j = 1, 10 do coroutine.yield() end
  end
  return xs, ys, type
end

--Last ditch.
local function PlaceRandomly()

  local x, y, HasRemainingUnits

  if GetOptionValue("VariableUnitCounts") == 1 then
    HasRemainingUnits = function(type)
      return (GetRemainingUnits(type) > 0) and
             (GetTypeCreditCost(type) <= GetUnitCreditsRemaining()) and
             (GetDefconLevel() > 3)
    end
  else
    HasRemainingUnits = function(type)
      return (GetRemainingUnits(type) > 0) and
             (GetDefconLevel() > 3)
    end
  end

  for type in pairs(GameRules.ShipTypes) do
    while HasRemainingUnits(type) do
      x, y = Map.SeaPlace:Sample()
      PlaceFleet(x, y, type)
      coroutine.yield()
    end
  end

  for type in pairs(GameRules.BuildingTypes) do
    while HasRemainingUnits(type) do
      x, y = Map.LandPlace:Sample()
      PlaceStructure(x, y, type)
      coroutine.yield()
    end
  end

end

--Single-use subroutine for finding the best placement for subs
--for launching at defcon 1.
local function FirstLaunchSubs()

  --Get copy of array of enemy cities.
  --We use a greedy algorithm: once we've found a good placement for the first subs,
  --we place them and then reduce the score accordingly.
  local targets = {}
  for city, info in pairs(Map.OpCities) do
    targets[city] = {}
    for a, b in pairs(info) do
      targets[city][a] = b
    end
  end

  coroutine.yield()

  local candidates = Map.SubPlace
  local i, score, r = 0, 0, GameRules.CombatRadius.Sub[2] ^ 2
  local inrange, maxscore, bestx, besty
  local newfleet
  repeat
    DebugLog("Placing Sub cluster.", DebugPlacement())
    maxscore, bestx, besty = -math.huge
    for x, y in candidates.Walk() do

      --Find value of launch point.
      inrange, score = false, 0
      for _, city in pairs(targets) do
        if (x - city.x) ^ 2 + (y - city.y) ^ 2 < r then
          score = score + city.score
          inrange = true
        end
      end

      --Points too far from any city are removed.
      if not inrange then candidates.Remove(x, y) end
      if score > maxscore then
        maxscore, bestx, besty = score, x, y
      end

      --Timing, points per tick.
      i = i + 1
      if i == 250 then
        i = 0
        coroutine.yield()
      end
    end

    --Sanity check.
    if maxscore <= 0 then break end

    --Remove targeted cities from consideration.
    for id, city in pairs(targets) do
      if (city.x - bestx) ^ 2 + (city.y - besty) ^ 2 < r then
        targets[id] = nil
      end
    end

    --Place enough subs to cover targets. Score = nukes to get to 0.3% of pop.
    DebugLog("Finding placements.", DebugPlacement())
    local toplacenum = math.floor(maxscore / 5)
    local toplacex, toplacey = Map.SeaPlace:NN(bestx, besty)
  
    --Sanity check: did we find a placement zone?
    if not (toplacex and toplacey and toplacenum) then break end
    WhiteboardDraw(toplacex, toplacey - 0.5, toplacex, toplacey + 0.5)
    WhiteboardDraw(toplacex - 0.5, toplacey, toplacex + 0.5, toplacey)
    DebugLog("Building cluster.", DebugPlacement())
    PlaceUnits(FleetLocation(toplacex, toplacey, "Sub", toplacenum))
    
  until GetRemainingUnits("Sub") < 4
  DebugLog("Defcon 1 subs placed.", DebugPlacement())
end

local function BlockShips()
  DebugLog("Placing blocking BattleShip.", DebugPlacement())
  PlaceUnits(Greedy(
    Fitness.BlockBB, Map.SeaPlaceB:Intersection(Map.OpSea),
    "BattleShip", 5, GameRules.RadarRadius.BattleShip[0] * 1.5))
end

local function ScoutShips()
  --Scout BBs
  DebugLog("Placing scout BattleShips.", DebugPlacement())
  for i = 1, 3 do
    local xs, ys = HillClimb(
      Fitness.ScoutBB(), Map.SeaPlaceB,
      "BattleShip", 1, 100, 100)
    if not xs then break end
    PlaceUnits(xs, ys, "BattleShip")
  end
end

local function ScoutRadar()
  DebugLog("Placing border RadarStations.", DebugPlacement())
  local landborder = Map.MyLand:Difference(Map.LandPlace)
  local maxfit = 50
  local xs, ys
  for i = 1, 3 do
    local cxs, cys, _, fitness = DifferentialEvolution(
      Fitness.ScoutRadar, landborder,
      "RadarStation", i, 200)
    if not cxs then break end
    if fitness > maxfit then
      maxfit = fitness
      xs, ys = cxs, cys
    end
  end
  PlaceUnits(xs, ys, "RadarStation")
end

local function Silos()
  DebugLog("Placing silos.", DebugPlacement())
  PlaceUnits(DifferentialEvolution(
    Fitness.Silo, Map.LandPlace,
    "Silo", nil, 600))
end

local function Fleets()
  DebugLog("Placing fleets.", DebugPlacement())
  local leadxs, leadys = DifferentialEvolution(
    Fitness.FleetNucleus(Map.OpSea:Sample()), Map.SeaPlace,
    "Carrier", 3, 250)
  for i = 1, 3 do
    PlaceUnits(FleetLocation(leadxs[i], leadys[i], "Carrier", 4))
    PlaceUnits(FleetLocation(leadxs[i], 2 + leadys[i], "BattleShip", 4))
  end
end

function Placement.PlaceD5()

  BlockShips()
  ScoutShips()
  ScoutRadar()

end

function Placement.PlaceD4()

  Silos()
  Fleets()
  FirstLaunchSubs()
  PlaceRandomly()
  
end