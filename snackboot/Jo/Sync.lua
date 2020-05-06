require "Utilities/XCo"
require "Jo/GameRules"

Sync = {}

local Launches = {}
local StoredTravelTimes = {}

function Sync.Init()
  Sync.AddData = function(t)
    StoredTravelTimes[t] = true
  end
  require "Data/TravelTimes"
  Sync.AddData = nil

  DebugLog("Sync data loaded.")
  coroutine.yield()
end

--First few functions find out what the travel time is from a silo to a target.

--Gaussian elimination. M is a column-major augmented matrix.
local function Solve(M)
  local n = #M - 1
  local c
  for j = 1, n do
    for i = 1, n do
      if i ~= j then
        c = M[j][i] / M[j][j]
        for k = 1, n + 1 do
          M[k][i] = M[k][i] - c * M[k][j]
        end
      end
    end
  end
  local x = {}
  for i = 1, n do
    x[i] = M[n + 1][i] / M[i][i]
  end
  return x
end

--Globally linear approximation to travel time.
--This rule of thumb fails near the north pole, or for large dx.
local function TravelTimeLinear(dx, yi, yf)
  return (3600 / 337.5) * math.sqrt(dx ^ 2 + (yf - yi) ^ 2)
end

--Four closest stored travel times to given launch.
local function ClosestTravelTimes(dx, yi, yf)
  local res = {}

  local data = StoredTravelTimes
  local curdistance
  for point in pairs(data) do
    curdistance = (point[1] - dx) ^ 2
                + (point[2] - yi) ^ 2
                + (point[3] - yf) ^ 2
    for i = 1, 4 do
      if not res[i] then
        table.insert(res,
          {point[1], point[2], point[3], point[4], curdistance})
        break
      elseif curdistance < res[i][5] then
        table.insert(res, i,
          {point[1], point[2], point[3], point[4], curdistance})
        res[5] = nil
        break
      end
    end
  end

  return res
end

--Barycentric coordinates of point x, y, z wrt tetrahedron simp.
local function Barycentric(simp, x, y, z)
  return Solve({
    {simp[1][1], simp[1][2], simp[1][3], 1},
    {simp[2][1], simp[2][2], simp[2][3], 1},
    {simp[3][1], simp[3][2], simp[3][3], 1},
    {simp[4][1], simp[4][2], simp[4][3], 1},
    {x, y, z, 1}})
end

--Linearly interpolates between stored travel times to get nuke travel time.
--Should be accurate to within five seconds, falls back on rule of thumb otherwise.
local function TravelTime(xi, xf, yi, yf)
  local dx = XCo.NukeLength(xi, xf)
  local simp = ClosestTravelTimes(dx, yi, yf)

  coroutine.yield()

  --Are the points we found good enough?
  local maxdist = 0
  for i = 1, 4 do
    maxdist = math.max(maxdist, simp[i][5])
  end
  if maxdist > 225 then return TravelTimeLinear(dx, yi, yf) end

  --Find barycentric coordinates and interpolate time values.
  local bco = Barycentric(simp, dx, yi, rf)
  local time = 0
  for i = 1, 4 do
    time = time + bco[i] * simp[i][4]
  end

  return time
end

--Source and target are given as unitIDs or cityIDs.
local function TravelTimeUnit(source, target)
  local xi, xf = GetLongitude(source), GetLongitude(target)
  local yi, yf = GetLatitude(source), GetLatitude(target)
  return TravelTime(xi, xf, yi, yf)
end

--Next few functions are all about deciding in which order to hit targets.

local function TravelTimesForOrdering(silo, targets)
  local times = {}
  for i, target in ipairs(targets) do
    times[i] = TravelTimeUnit(silo, target)
  end
  return times
end

--Maximum gap between subsequent nukes.
local function BiggestArrivalGap(times)
  local gap = 0
  for i = 1, #times - 1 do
    gap = math.max(gap, times[i + 1] - times[i])
  end
  return gap
end

--Add two minutes to an ordered set of launches to allow for launch delay.
local function StaggerTravelTime(times)
  local staggered = {}
  for i = 1, #times do
    stagerred[i] = times[i] + 120 * i
  end
  return staggered
end

--Perform random pairwise swaps to the target ordering,
--to minimize the maximum gap between subsequent nukes.
--Simulated annealing metaheuristic.
local function OrderTargetsByGap(targets, times)
  local temperature = 300
  local coolrate = 0.8
  local gap = BiggestArrivalGap(StaggerTravelTime(times))
  local n, mr = #times, math.random
  local newgap

  repeat
    local i, j = mr(n), mr(n)
    --Perform swap.
    times[i], times[j] = times[j], times[i]
    newgap = BiggestArrivalGap(StaggerTravelTime(times))
    if newgap < gap + temperature then
      --Adopt swap.
      gap = newgap
      targets[i], targets[j] = targets[j], targets[i]
    else
      --Reject swap (by performing inverse of swap).
      times[i], times[j] = times[j], times[i]
    end
    temperature = temperature * coolrate
  until temperature < 1
end

function Sync.OrderTargetsByGap(silos, targets)
  OrderTargetsByGap(TravelTimesForOrdering(silos[1], targets))
end

local function GetTravelTimes(silos, target)
  local times = {}
  for i, silo in ipairs(silos) do
    times[silo] = TravelTimeUnit(silo, target)
  end
  return times
end

--Earliest time after which a silo can launch again.
local function TimeToNextLaunch(silo)
  if GetCurrentState(silo) == GameRules.LaunchState[GetUnitType(silo)] then
    local actions = GetActionQueue(silo)
    local timer = GetStateTimer(silo)
    actions = next(actions) == nil and 0 or #actions
    return timer + 120 * actions
  else return 120 end
end

--Targets should be in the correct order when this gets called.
function Sync.GetLaunchTimes(silos, targets)
  local traveltimes = GetTravelTimes(silos, targets[1])
  local launchtimes = {}
  local available = {}
  local arrivaltime = 0
  local currenttime = GetGameTime()
  for silo in pairs(silos) do
    available[silo] = TimeToNextLaunch(silo)
  end
  for silo, traveltime in pairs(traveltimes) do
    arrivaltime = math.max(arrivaltime,
      currenttime + available[silo] + traveltime)
  end
  for silo, traveltime in pairs(traveltimes) do
    launchtimes[silo] = arrivaltime - available[silo] - traveltime
  end
  return launchtimes, arrivaltime
end