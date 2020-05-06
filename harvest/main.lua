--Harvest is a bot used to gather nuke silo launch times.
package.path = debug.getinfo(1, "S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path
require "XCo"

-- Required by luabot binding. Fires when the agent is selected.
function OnInit()
  SendChat("/name [BOT]Harvest")
  SendChat("Harvest is a bot used to gather data about the rules of DEFCON.")
  main = coroutine.create(Collect)
  live = true
end

-- Also required. 100ms execution time limit. Use it wisely.
function OnTick()
  if live ~= false then
    live, err = coroutine.resume(main)
    if live == false then DebugLog(err) end
  end
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
  while GetRemainingUnits("Silo") > 0 do
    local locx = math.random() * 360 - 180
    local locy = math.random() * 180 - 90
    if IsValidPlacementLocation(locx, locy, "Silo") then
      PlaceStructure(locx, locy, "Silo")
      DebugLog("Placed at: "..locx..", "..locy, nil, "PlaceSilos")
      coroutine.yield()
    else
      DebugLog("Could not place at: "..locx..", "..locy, nil, "PlaceSilos", 255, 0, 0)
    end
  end
end

function WaitForDefcon1()
  RequestGameSpeed(20)
  while GetDefconLevel() ~= 1 do coroutine.yield() end
end

function GetTargets()
  local cities = GetCityIDs()
  local targets = {}
  table.sort(cities, function(a, b) return a:GetCityPopulation() > b:GetCityPopulation() end)
  for i = 1, 10 do
    targets[cities[i]] = true
  end
  return targets
end

function ReadySilos()
  local targets = GetTargets()
  RequestGameSpeed(1)
  for _, silo in pairs(GetAllUnits()) do
    silo:SetState(0)
    for target in pairs(targets) do silo:SetActionTarget(target) end
    coroutine.yield()
  end
end

function MonitorTargets()
  RequestGameSpeed(5)
  DebugLog("Monitoring:")
  local nukes = {}
  local hits = {}
  local time = 0
  while not (IsVictoryTimerActive() and GetVictoryTimer() < 1200) do
    time = GetGameTime()
    nukes = GetAllUnitData(nukes)
    for id, nuke in pairs(nukes) do
      if nuke.type == "Nuke" then
        if not hits[id] then
          hits[id] = {i =
            {x = nuke.longitude,
             y = nuke.latitude,
             t = nuke.time}}
        elseif nuke.time < time and not hits[id].f then
          DebugLog("Hit", id, "Hits", 100, 0, 0)
          hits[id].f =
            {x = nuke.longitude,
             y = nuke.latitude,
             t = nuke.time}
        end
      end
    end
    coroutine.yield()
  end
  RequestGameSpeed(20)
  return hits
end

function WriteToFile(data)
  local file = io.open("AI/sync/Data/TravelTimes.lua", "a+")
  io.output(file)
  coroutine.yield()

  local dx, yi, yf, dt = 0, 0, 0, 0
  for _, p in pairs(data) do 
    if p.f then
      dx = XCo.NukeLength(p.i.x, p.f.x)
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
  io.write("DebugLog(\"Batch loaded.\")\n")
  DebugLog("Finished writing.") 
  io.close(file)
end

function DrawHits(data)
  for _, p in pairs(data) do
    if p.f then WhiteboardDraw(p.i.x, p.i.y, p.f.x, p.f.y) end
    coroutine.yield()
  end
end

--Function wrapped in coroutine, executes for most of the game.
function Collect()
  PlaceSilos()
  WaitForDefcon1()
  ReadySilos()
  hits = MonitorTargets()
  WriteToFile(hits)
  if GetOptionValue("DebugMode") == 1 then DrawHits(hits) end
  while true do
    coroutine.yield()
  end
end