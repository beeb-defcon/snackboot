--Behaviour trees, constructed bottom up.
BT = {}

--Basic action, wraps around a Boolean function.
function BT.Action(f)
  local t = {}

  t.Execute = f

  t.Remove = function()
    if t.Parent then
      t.Parent.Remove(t)
     end
    t = nil
  end

  return t
end

--Decorator, don't run actions unless it's been too long.
function BT.Delay(duration, action)
  local lastrun, lastresult = 0, false
  local function ExecuteIfStale()
    local time = GetGameTime()
    if time > lastrun + duration then
      lastresult = action.Execute()
      lastrun = time
    end
    return lastresult
  end

  --Inherit Remove from Action.
  action.Parent = BT.Action(ExecuteIfStale)

  return action.Parent
end

--Decorator, run only if action hasn't returned true.
function BT.RememberTrue(action)
  local lastresult = false
  local function ExecuteIfFalse()
    if not lastresult then lastresult = action.Execute() end
    return lastresult
  end

  action.Parent = BT.Action(ExecuteIfFalse)

  return action.Parent
end

--Internal node containing an arbitrary, dynamic number of children.
function BT.Compose()
  local children = {}
  local t = {}

  t.Add = function(action)
    table.insert(children, action)
    action.Parent = t
  end

  t.Remove = function(action)
    action.Parent = nil
    for i, child in ipairs(children) do
      if child == action then
        return table.remove(t, i)
      end
    end
  end

  --Tear the node down.
  t.Delete = function()
    for _, child in pairs(children) do
      child.Parent = nil
    end
    if t.Parent then t.Parent.Remove(t) end
    children = nil
    t = nil
  end

  t.Children = function() return children end

  return t
end

function BT.Sequence(initialChildren)
  initialChildren = initialChildren or {}
  local t = BT.Compose()

  t.Execute = function()
    for _, child in ipairs(t.Children()) do
      if not child.Execute() then return false end
    end
    return true
  end

  for _, child in ipairs(initialChildren) do
    t.Add(child)
  end

  return t
end

--Cycles through each subtree until the tick is over.
function BT.Parallel(initialChildren)
  local t, threads = BT.Compose(), {}

  local Add = t.Add
  t.Add = function(child)
    table.insert(threads, coroutine.create(function()
      while true do child.Execute() coroutine.yield() end end))
    return Add(child)
  end

  t.Threads = function() return threads end
  
  t.Execute = coroutine.wrap(function()
    local ip = 1
    while true do
      while next(threads) == nil or os.clock() > timeup do
        coroutine.yield(true)
      end
      if ip > #threads then ip = 1 end
      _, err = coroutine.resume(threads[ip])
      if err and err ~= true then
        DebugLog("Error in parallel node:")
        return OnShutdown(err)
      end
      ip = ip + 1
    end
  end)

  local Remove = t.Remove
  t.Remove = function(child)
    for i, action in ipairs(children) do
      if action == child then
        table.remove(threads, i)
      end
    end
    return Remove(child)
  end

  t.Delete = function()
    if t.Parent then t.Parent.Remove(t) end
    t = nil
  end

  for _, child in ipairs(initialChildren) do
    t.Add(child)
  end

  return t
end

function BT.ParallelOnce(initialChildren)
  local t = BT.Parallel(initialChildren)
  local threads = t.Threads()

  --Runs through each subtree only once per tick.
  t.Execute = coroutine.wrap(function()
    local ip = 1
    while true do
      while next(threads) == nil or os.clock() > timeup do
        coroutine.yield(true)
      end
      if ip > #threads then
        ip = 1
        coroutine.yield(true)
      end
      _, err = coroutine.resume(threads[ip])
      if err and err ~= true then
        DebugLog("Error in parallel node:")
        return OnShutdown(err)
      end
      ip = ip + 1
    end
  end)

  return t
end

function BT.Fallback(initialChildren)
  initialChildren = initialChildren or {}
  local t = BT.Compose()

  t.Execute = function()
    for _, child in ipairs(t.Children()) do
      if child.Execute() then return true end
    end
    return false
  end

  for _, child in ipairs(initialChildren) do
    t.Add(child)
  end

  return t
end

