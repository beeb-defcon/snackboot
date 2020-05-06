require "Jo/Behaviours"
require "Jo/GameRules"
require "Jo/Map"
require "Jo/Placement"
require "Jo/Units"
require "Jo/Scout"
require "Jo/ScoutBB"
require "Jo/Sync"

Jo = {}

--Sequential part of the program. Once the bot needs to do several things at once,
--this function tail calls into a scheduler.
function Jo.Init()
  Jo.myid = GetOwnTeamID()
  Jo.opid = Jo.GetOpponentId()
  if Jo.opid == nil then
    SendChat("1v1s only.")
    return OnShutdown()
  end
  Units.Init()
  Sync.Init()
  Map.Init()
  Placement.PlaceD5()
  ScoutBB.MoveScouts()
  Jo.WaitForDefcon(4)

  --Scout should not be initialized until we can see enemies.
  ScoutBB.Pursuit()
  Scout.Init()
  Placement.PlaceD4()
  while true do
    Behaviours.Tree().Execute()
    coroutine.yield()
  end
end

function Jo.WaitForDefcon(level)

  RequestGameSpeed(20)
  repeat coroutine.yield()
  until GetDefconLevel() <= level
  RequestGameSpeed(1)

end

function Jo.GetOpponentId()
  local ids = GetAllTeamIDs()
  if #ids ~= 2 then return end
  for _, id in pairs(ids) do
    if (id ~= Jo.myid) then return id end
  end
end

function Jo.Land(team)
  return function(x, y)
    return IsValidTerritory(team, x, y, false)
  end
end

function Jo.Sea(team)
  return function(x, y)
    return IsValidTerritory(team, x, y, true)
  end
end
