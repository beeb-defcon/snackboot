require "EventManager"

Units = {}

--Copy one level deep.
local function Copy(t)
  ret = {}
  for id, data in pairs(t) do
    ret[id] = data
  end
  return ret
end

--Group free units into fleets.
local function FindFleetForUnit(id, unit)
  DebugLog("Locating "..tostring(unit.type).." fleet.")
  for fleet in pairs(Units.Fleets) do
    if fleet.Type() == unit.type and
      GetDistance(unit.longitude, unit.latitude, fleet.Centroid()) < 30 then
        return fleet.Add(id)
    end
  end
  local fleet = Units.NewFleet(unit.type)
  fleet.Add(id)
end

--Allocate unit to fleet.
local function GroupUnits()
  for id, unit in pairs(Units.Me) do
    if (not Units.FleetAssoc[id]) and
       GameRules.ActiveUnits[unit.type] then
      DebugLog("Grouping unit "..tostring(id))
      FindFleetForUnit(id, unit)
    end
  end
end

--Update all unit info.
local function Update()

  local current = Units.Current
  local history = Units.History
    
  table.insert(history, 1, Copy(current))
  if #history == 10 then history[10] = nil end
  Units.Time = GetGameTime()
  GetAllUnitData(current)

  local me = {}
  Units.Me = me
  for _, id in ipairs(GetOwnUnits()) do
    me[id] = current[id]
  end

  coroutine.yield()

  GroupUnits()
    
  coroutine.yield()

  return true
end

local function Destroyed(source, target, type, long, lat)
  --Called upon destroyed event.
  --Ghosts stay in Units.Current, destroyed units are gone for good.

  --We need to keep track of units destroyed so far,
  --sometimes a Destroyed event is sent several times for the same unit.
  if Units.Destroyed[target] then return end

  if Units.Current[target].team == Jo.myid then
    Orders.RemoveUnit(target)
    if Units.FleetAssoc[target] then
      Units.FleetAssoc[target].fleet.Remove(target)
    end
  end
  
  if Units.Current[target].type == "RadarStation"
    and  Units.Current[target].team == Jo.opid then
    --Expensive function which should only be evaluated seven times each game.
    Scout.OpponentRadarDestroyed(target, long, lat)
  end
  
  Units.Current[target] = nil
  Units.Destroyed[target] = true
end

local function GetFleet(id)
  local assoc = Units.FleetAssoc[target]
  return assoc and assoc.fleet
end

function Units.Init()
  if Units.Initialized then return end
  DebugLog("Initializing unit tracker.", nil, "Units.Init")
  Units.Initalized = true
  Units.Current = {}
  Units.History = {}
  Units.New = {}
  Units.Me = {}
  Units.Op = {}
  Units.Destroyed = {}
  Units.Fleets = {}
  Units.FleetAssoc = {}
  Units.GetFleet = GetFleet
  Units.GetFleetData = GetFleetData
  Units.Update = Update
  EventManager.Handlers.Destroyed = Destroyed
end

--A fleet is an array of ships.
function Units.NewFleet(type)
  local t, fleet, fleetdata = {}, {}, {}
  local fleets, fleetassoc, current = Units.Fleets, Units.FleetAssoc, Units.Current 

  t.Array = function() return fleet end

  t.Type = function() return type end

  t.Data = function() return fleetdata end

  --Type must be defined before calling Behaviours.Fleet
  local behaviour = Behaviours.Fleet(t)
  Behaviours.Fleets.Add(behaviour)

  t.Add = function(unit)
    DebugLog("Unit "..tostring(unit).." added to fleet "..tostring(t),
      nil, nil, 155, 165, 65)
    local index = #fleet + 1
    fleet[index] = unit
    if not fleetassoc[unit] then fleetassoc[unit] = {} end
    fleetassoc[unit].fleet = t
    fleetassoc[unit].index = index
    fleetassoc[unit].bt = Behaviours.Unit(unit)
    behaviour.Add(fleetassoc[unit].bt)
  end

  t.RemoveIndex = function(index)
    return t.Remove(fleet[index])
  end

  t.Remove = function(unit)
    DebugLog("Unit "..tostring(unit).." removed from fleet "..tostring(t),
      nil, nil, 155, 165, 65)
    table.remove(fleet, fleetassoc[unit].index)
    fleetassoc[unit].bt.Delete()
    fleetassoc[unit] = nil
  end

  t.Move = function(unit, newfleet)
    t.Remove(unit)
    return newfleet.Add(unit)
  end

  t.Split = function(units)
    newfleet = Units.NewFleet(type)
    for id in pairs(units) do
      t.Move(unit, newfleet)
    end
  end

  t.Merge = function(newfleet)
    for _, unit in ipairs(fleet) do newfleet.Add(unit) end
    return t.Delete()
  end

  --Clean up references and upvalues.
  t.Delete = function()
    for _, unit in ipairs(fleet) do t.Remove(unit) end
    fleets[t] = nil
    behaviour.Delete()
    behaviour, current = nil
    t, fleet, fleets, fleetassoc, fleetdata = nil
  end

  t.Centroid = function()
    local unit
    local x, y = 0, 0
    for i = 1, #fleet do
      unit = current[fleet[i]]
      x, y = x + unit.longitude, y + unit.latitude
    end
    return x / #fleet, y / #fleet
  end

  DebugLog("New fleet: "..tostring(t), nil, "Units.NewFleet", 155, 165, 65)
  
  fleets[t] = fleetdata
  return t
end