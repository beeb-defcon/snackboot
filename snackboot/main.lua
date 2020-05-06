package.path = debug.getinfo(1, "S").source:match[[^@?(.*[\/])[^\/]-$]] .."?.lua;".. package.path

-- Required by luabot binding. Fires when the agent is selected.
function OnInit()
  require "Jo"

  --Initialize event queue. EventManager returns table with closure.
  require "EventManager"
  EventManager = EventManager()

  --Bot runs inside one big coroutine.
  --Use a global to indicate its status.
  main = coroutine.create(Jo.Init)
  live = true

  --Indicate successful initalization.
  SendChat("/name [BOT]snackboot")
  SendChat("Ready and raring.")

end

-- Also required. 100ms execution time limit. Use it wisely.
function OnTick()

  --50 real milliseconds.
  timeup = os.clock() + 0.05

  if EventManager.IsEmpty() then
    live, err = coroutine.resume(main)
    if err then
      return OnShutdown(err)
    end
  else
    return EventManager.Process()
  end
end

-- Required function. fires whenever an event happens in the game.
function OnEvent(eventType, sourceID, targetID, unitType, longitude, latitude)
  local f = EventManager.Handlers[eventType]

  if not f then return end

  EventManager.Enqueue(
    coroutine.create(
      function()
        return f(sourceID, targetID, unitType, longitude, latitude)
      end))

  return EventManager.Process()

end

-- Documentation says it's required, but it doesn't seem to get called. hmm...
function OnShutdown(err)
  OnTick = function() end
  OnEvent = function() end
  DebugLog(tostring(err), nil, "Error", 255, 0, 0)
  SendChat("Bye!")
  SendChat("/name [BOT]Deactivated")
end

