-- Stolen from Martin
-- martindevans@gmail.com
-- http://martindevans.appspot.com/blog

--Events should block the execution of the main coroutine, "main".
--The events may take longer than one tick to process,
--and several may be triggered during the same tick.
--They should be processed in the order received.

function EventManager()
  local t = {}

  --This table holds the functions to be called, indexed by EventType.
  t.Handlers = {}
  
  local last = 0
  local first = 0

  t.Process = function()
    local GetTime, Continue = os.clock, coroutine.resume
    repeat
      local live, err = Continue(t[first])
      if not live then
        t.Dequeue()
        if err then
          DebugLog(err, nil, "Error", 255, 0, 0)
        end
      end
    until last == first or GetTime() > timeup
  end
  
  t.IsEmpty = function()
    return last == first
  end
  
  t.Size = function()
    return last - first
  end
  
  t.Enqueue = function(value)
    t[last] = value
    last = last + 1
  end
  
  t.Dequeue = function()
    local v = t[first]
    first = first + 1
    return v
  end
  
  t.Peek = function()
    return t[first]
  end
  
  return t
end