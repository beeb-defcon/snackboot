require "Jo/GameRules"
require "Jo/Map"
require "Jo/Units"
require "Utilities/Set"

Scout = {}

--Mobile units that may be scouting enemy territory.
--Call after placement.
local function GetScouts()
  local opradar = Map.OpRadar.ContainsReal
  local scouttype = GameRules.Scouts
  local scouts = {}
  for id, unit in pairs(Units.Me) do
    if scouttype[unit.type] and opradar(unit.longitude, unit.latitude) then
      scouts[id] = unit
    end
  end
  return scouts
end


local function GetMyStations()
  local opradars = {}
  for id, unit in pairs(Units.Current) do
    if unit.type == "RadarStation" and unit.team == Jo.myid then
      opradars[id] = unit
    end
  end
  return opradars
end

local function GetOpponentStations()
  local opradars = {}
  for id, unit in pairs(Units.Current) do
    if unit.type == "RadarStation" and unit.team == Jo.opid then
      opradars[id] = unit
    end
  end
  return opradars
end

--Called frequently to monitor newly scouted region.
--Most of the work is done in Update, which produces the table of scouts.
local function AddNewlyScouted(scouts)
  local unscouted, newlyscouted, scouted = Scout.Unscouted, Scout.NewlyScouted, Scout.Scouted
  for id, unit in pairs(scouts) do
    for x, y in Iterator.Disk(GameRules.RadarRadius[unit.type][unit.state],
                              unit.longitude, unit.latitude) do
      if not scouted.Contains(x, y) then
        scouted.Add(x, y)
        newlyscouted.Add(x, y)
        unscouted.Remove(x, y)
      end
    end
    --Indicate that we're not done.
    coroutine.yield(false)
  end
  return true
end

--Expensive function to update opradar given newly scouted points.
local function ClearNewlyScouted(opstations)
  local r = GameRules.RadarRadius.RadarStation[0]
  local inradar --sentinel
  local RemoveFromRadar = Map.OpRadar.Remove
  local unscouted, newlyscouted = Scout.Unscouted, Scout.NewlyScouted
  for x, y in newlyscouted.Walk() do
    inradar = false
    for _, radar in pairs(opstations) do
      --Can't clear if radar can see the point.
      if GetDistance(x, y, radar.longitude, radar.latitude) < r then
        inradar = true
        break
      end
    end
    if not inradar then
      for a, b in Iterator.Disk(r, x, y) do
        if unscouted.Contains(a, b) then
          inradar = true
          break
        end
      end
      if not inradar then RemoveFromRadar(x, y) end
      newlyscouted.Remove(x, y)
    end
  end
  return true
end

local function OpponentRadarDestroyed(id, long, lat)
  local r = GameRules.RadarRadius.RadarStation[0]
  local scouted, unscouted = Scout.Scouted.Contains, Scout.Unscouted.Contains
  local opradars = GetOpponentStations()
  opradars[id] = nil
  local inradar
  local RemoveFromRadar = Map.OpRadar.Remove
  for x, y in Iterator.Disk(r, long, lat) do
    for id, station in pairs(opradars) do
      if GetDistance(x, y, station.longitude, station.latitude) < r then
        inradar = true
        break
      end
    end
    if scouted(x, y) and not inradar then
      for a, b in Iterator.Disk(r, x, y) do
        if unscouted(a, b) then
          inradar = true
          break
        end
      end
      if not inradar then RemoveFromRadar(x, y) end
    end
  end
  return true
end

local function GetScoutingTargets()

end

--Call at Defcon 4.
function Scout.Init()
  Scout.NewlyScouted = Set.New()
  Scout.Scouted = Set.New()
  Scout.Unscouted = Map.OpLand:Copy()
  AddNewlyScouted(GetMyStations())
  Scout.Update = function() return AddNewlyScouted(GetScouts()) end
  Scout.Flush = function() return ClearNewlyScouted(GetOpponentStations()) end
  Scout.OpponentRadarDestroyed = OpponentRadarDestroyed
end


--Adds a boundary field to opradar in place.
function Scout.BuildRadarBoundary(opradar)

end

function Scout.GetRadarBoundary(opradar)

end