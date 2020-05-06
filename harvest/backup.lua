--Harvest is a bot used to gather nuke silo launch times.
package.path = debug.getinfo(1, "S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

-- Required by luabot binding. Fires when the agent is selected.
function OnInit()
  SendChat("/name [BOT]Harvest")
  SendChat("Harvest is a bot used to gather data about the rules of DEFCON.")
  nukeloop = coroutine.wrap(Collect)
  firingterritory = "SouthAmerica"
end

-- Also required. 100ms execution time limit. Use it wisely.
function OnTick()
  tick = GetGameTick()
  nukeloop()
end

-- Required function. fires whenever an event happens in the game.
function OnEvent(eventType, sourceID, targetID, unitType, longitude, latitude)
  DebugLog(eventType)
  DebugLog(tostring(sourceID))
  DebugLog(tostring(targetID))
  DebugLog(unitType)
  DebugLog(longitude)
  DebugLog(latitude)
  io.write(GetGameTime())
end

-- Documentation says it's required, but it doesn't seem to get called. hmm...
function OnShutdown()
  SendChat("Bye!")
  SendChat("/name [BOT]n00b")
end

function PlaceSilos()
  while (GetRemainingUnits("Silo") > 11) do
    local locx = math.random() * 360 - 180
    local locy = math.random() * 180 - 90
    if IsValidPlacementLocation(locx, locy, "Silo") and
      GetTerritoryName(locx, locy) == firingterritory
    then
      PlaceStructure(locx, locy, "Silo")
      DebugLog("Placed at: "..locx..", "..locy, nil, "PlaceSilos")
      coroutine.yield()
    else
      DebugLog("Could not place at: "..locx..", "..locy, nil, "PlaceSilos", 255, 0, 0)
    end
  end
end

function ReadySilos()
  for _, silo in pairs(GetAllUnits()) do silo:SetState(0) end
  return GetGameTime()
end

function WaitForDefcon1()
  while GetDefconLevel() ~= 1 do coroutine.yield() end
end

function GenerateSilo()
  --Assumes all units are my silos.
  for _, silo in pairs(GetAllUnits()) do
    coroutine.yield(silo, silo:GetLongitude(), silo:GetLatitude())
  end
end

function TargetCities(start)
  RequestGameSpeed(1)
  local data = {}
  local delay = 1200
  local GetSilo = coroutine.wrap(GenerateSilo)
  local silo, sx, sy
  for _, city in pairs(GetCityIDs()) do
    if GetTerritoryName(city:GetLongitude(), city:GetLatitude()) ~= firingterritory then
      if delay == 1200 then
        coroutine.yield()
        silo, sx, sy = GetSilo()
        if not silo then return data end
        delay = 0
      end

      silo:SetActionTarget(city)
      delay = delay + 120
      data[city] = {}
      data[city].i = {
        ["pop"] = city:GetCityPopulation(),
        ["x"] = sx,
        ["y"] = sy,
        ["t"] = start + delay}
      data[city].f = {
        ["x"] = city:GetLongitude(),
        ["y"] = city:GetLatitude()}
      DebugLog("City: "..tostring(city))
    end
  end
  return data
end

function MonitorTargets(data)
  RequestGameSpeed(5)
  DebugLog("Monitoring:")
  while not IsVictoryTimerActive() do
    for city, rec in pairs(data) do
      if (not rec.f.t) and
         (city:GetCityPopulation() < rec.i.pop) then
        DebugLog("Hit")
        rec.f.t = GetGameTime()
      end
    end
    coroutine.yield()
  end
  RequestGameSpeed(20)
  return data
end

function WriteToFile(data)
  local file = io.open("AI/sync/Data/TravelTimes.lua", "a+")
  io.output(file)
  coroutine.yield()

  local dx, yi, yf, dt = 0, 0, 0, 0
  for _, p in pairs(data) do 
    if p.f.t then
      dx = WrapLength(p.f.x, p.i.x)
      yi = p.i.y
      yf = p.f.y
      dt = p.f.t - p.i.t

      io.write("Sync.AddData{")
      io.write(tostring(dx)..",")
      io.write(tostring(yi)..",")
      io.write(tostring(yf)..",")
      io.write(tostring(dt).."}\n")
      io.flush()
    end
    coroutine.yield()
  end
  io.write("DebugLog(\"Batch loaded.\")")
  io.close(file)
end

function WrapLength(x1, x2)
  return math.min(math.abs(x1 - x2),
                  math.abs(x1 - x2 + 360),
                  math.abs(x1 - x2 - 360))
end

--Function wrapped in coroutine, executes for most of the game.
function Collect()
  RequestGameSpeed(20)
  PlaceSilos()
  WaitForDefcon1()
  WriteToFile(MonitorTargets(TargetCities(ReadySilos())))
  while true do
    coroutine.yield()
  end
end