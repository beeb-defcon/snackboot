require "Jo/GameRules"
require "Utilities/Set"

Map = {}

--Computes spatial information about the world that:
--Changes between games. Depends on the team, cities, mod maps &c.
--Requires frequent queries and efficient data structures.

local function DebugMap()
  return nil, "Map", 167, 214, 167
end

local function Land(team) return function(x, y)
  return IsValidTerritory(team, x, y, false)
end end

local function Sea(team) return function(x, y)
  return IsValidTerritory(team, x, y, true)
end end

local function Draw()
  for name, bitmap in pairs(Map) do
    if type(bitmap) == "table" and bitmap.Draw then
      DebugLog("Drawing "..name, DebugMap())
      bitmap:Draw()
      DebugLog(name.." drawn.", DebugMap())
      local tick = GetGameTick()
      while GetGameTick() < tick + 15 do coroutine.yield() end
      WhiteboardClear()
    end
  end
end

local function FirstPass()
  DebugLog("First pass.", DebugMap())
  local myland, mysea, opland, opsea = Set.New(), Set.New(), Set.New(), Set.New()
  local me, op = Jo.myid, Jo.opid
  local In = IsValidTerritory
  --Nine ticks.
  for i = -180, 180, 40 do
    for x = i, i + 39 do
      for y = -90, 90 do
        if In(me, x, y, false) then myland.Add(x, y) end
        if In(me, x, y, true) then mysea.Add(x, y) end
        if In(op, x, y, false) then opland.Add(x, y) end
        if In(op, x, y, true) then opsea.Add(x, y) end
      end
    end
    coroutine.yield()
  end
  return myland, mysea, opland, opsea
end

local function SampleTest(bitmap)
  local x, y = bitmap:Sample()
  for i = 1, 25 do
    x, y = bitmap.Sample()
    WhiteboardDraw(x - 0.5, y - 0.5, x + 0.5, y + 0.5)
  end
  coroutine.yield()
  return true
end

Map.Init = function()
  RequestGameSpeed(1)

  local me, op = Jo.myid, Jo.opid
  local myland, mysea, opland, opsea = FirstPass()
  DebugLog("First pass finished.", nil, "FirstPass")

  local rradar = GameRules.RadarRadius.RadarStation[0]
  local rsubs = GameRules.CombatRadius.Sub[2]
  local d3submove = 25

  DebugLog("Mapping opponent radar.", DebugMap())
  local OpR = opland:Dilate(rradar)
  coroutine.yield()

  DebugLog("Mapping land placement.", DebugMap())
  local PlaceLand = myland:Difference(OpR)
  coroutine.yield()

  DebugLog("Mapping scout-vulnerable land.", DebugMap())
  local MS3 = (opland:Union(opsea)):Dilate(rsubs, myland)
  coroutine.yield()

  DebugLog("Mapping sub-vulnerable land.", DebugMap())
  local OpSM = opsea:Dilate(d3submove, IsSea)
  local MySM = mysea:Dilate(d3submove, IsSea)

--My territory likely to be nuked by enemy subs at defcon 1.
  local OpM = (OpSM:Difference(myland:Dilate(rradar))):Dilate(rsubs, myland)

--Sea border.
  DebugLog("Mapping sea border.", DebugMap())
  local SeaBorder = OpSM:Intersection(MySM)

  DebugLog("Mapping friendly sea border.", DebugMap())
  local SeaBorderPlacement = SeaBorder:Intersection(mysea)

--My sea territory which can move and launch to the opponent at defcon 1:
  --Possible launch zones - close to my sea territory and outside enemy radar.
  DebugLog("Mapping early launch zones.", DebugMap())
  local SubPlacement = MySM:Difference(OpR:Union(OpSM))

  --Score enemy cities.
  DebugLog("Mapping enemy cities.", DebugMap())
  local cityscorenorm = 100 / GetOptionValue("PopulationPerTerritory")
  local OpCities = {}
  for _, c in pairs(GetCityIDs()) do
    if c:GetTeamID() == op then
      OpCities[c] = {
        ["p"] = c:GetCityPopulation(),
        ["x"] = c:GetLongitude(),
        ["y"] = c:GetLatitude()}
      --Nukes required to get city to 0.3M (assuming 100% hit rate).
      OpCities[c].score =
        math.ceil(math.log(cityscorenorm * OpCities[c].p / 300000) / math.log(2))
    end
  end

  --Score my cities.
  DebugLog("Mapping my cities.", DebugMap())
  local MyCities = {}
  for _, c in pairs(GetCityIDs()) do
    if c:GetTeamID() == me then
      MyCities[c] = {
        ["p"] = c:GetCityPopulation(),
        ["x"] = c:GetLongitude(),
        ["y"] = c:GetLatitude()}
      --Nukes required to get city to 0.3M (assuming 100% hit rate).
      MyCities[c].score =
        math.ceil(math.log(cityscorenorm * MyCities[c].p / 300000) / math.log(2))
    end
  end

  DebugLog("Mapping safe placement.", DebugMap())
  local SeaSafePlacement = SubPlacement:Intersection(mysea)

  Map = {MyLand    = myland,
         MySea     = mysea,
         MyCities  = MyCities,
         OpCities  = OpCities,
         OpLand    = opland,
         OpSea     = opsea,
         OpScout   = OpScout,
         OpRadar   = OpR,
         VulnScout = MS3,
         VulnSubs  = OpM,
         SeaPlace  = SeaSafePlacement,
         SubPlace  = SubPlacement,
         SeaPlaceB = SeaBorderPlacement,
         SeaBorder = SeaBorder,
         LandPlace = PlaceLand,
         ["Draw"]  = Draw}
end