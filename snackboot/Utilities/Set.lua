-- Originally written by Martin
-- martindevans@gmail.com
-- http://martindevans.appspot.com/blog
-- Point set.

require "Utilities/BoundingBox"
require "Utilities/Iterator"

Set = {}

local function Ball(r)
  local xs, ys = {}, {}
  for x, y in Iterator.Disk(r) do
    table.insert(xs, x)
    table.insert(ys, y)
  end
  coroutine.yield()
  return xs, ys, #xs
end

Set.New = function()
  local t = {}
  local s = {}

  s.Values = function()
    return t
  end

  s.Contains = function(x, y)
    return t[x] and t[x][y]
  end

  s.ContainsReal = function(x, y)
    x, y = math.floor(x), math.floor(y)
    return t[x] and t[x][y]
  end

  s.BB = BoundingBox.New()
  
  s.Add = function(x, y)
    if t[x] then
      t[x][y] = true
    else
      t[x] = {[y] = true}
    end
    s.BB.Expand(x, y)
  end

  s.Empty = function()
    return (next(t) == nil)
  end

  s.Remove = function(x, y)
    if t[x] then
      t[x][y] = nil
      if next(t[x]) == nil then t[x] = nil end
    end
  end

  s.Walk = function()
    return coroutine.wrap(function()
      for x, line in pairs(t) do
        for y, _ in pairs(line) do
          coroutine.yield(x, y)
        end
      end
    end)
  end

  s.Draw = function(self)
    local i = 0
    for x, y in self.Walk() do
      i = i + 1
      if i == 25 then
        coroutine.yield()
        i = 0
      end
      WhiteboardDraw(x - 0.5, y - 0.5, x + 0.5, y + 0.5)
    end
  end

  --Dilate by disk radius r. Not seam-safe.
  s.Dilate = function(self, r, mask)
    local dilation = Set.New()
    local bx, by, n = Ball(r)
    local Inside = (type(mask) == "table") and mask.Contains or mask

    DebugLog("Dilating. Structuring element size: "..n, nil, "Dilate", 100)
    -- Outer loop for timing.
    local pause = math.ceil(4000 / n)
    for i = math.max(-180, self.BB.x - r), math.min(180, self.BB.X + r), pause do
      for x = i, i + pause do
        for y = self.BB.y - r, self.BB.Y + r do
          if not mask or Inside(x, y) then
            for j = 1, n do
              if self.Contains(x - bx[j], y - by[j]) then
                dilation.Add(x, y)
                break
              end
            end
          end
        end
      end
      coroutine.yield()
    end
    coroutine.yield()
    return dilation
  end

  s.Copy = function()
    local copy = Set.New()
    local vals = copy.Values()
    local i = 0
    for x, line in pairs(t) do
      i = i + 1
      if i == 250 then coroutine.yield()
        i = 0
      end
      vals[x] = {}
      for y in pairs(line) do
        vals[x][y] = true
      end
    end
    copy.BB = BoundingBox.New(s.BB.x, s.BB.X, s.BB.y, s.BB.Y)
    coroutine.yield()
    return copy
  end

  s.Union = function(self, set)
    local union = Set.New()
    local i = 0
    for x, y in self.Walk() do 
      i = i + 1
      if i == 250 then coroutine.yield()
        i = 0
      end
      union.Add(x, y) 
    end
    for x, y in set.Walk() do 
      i = i + 1
      if i == 250 then coroutine.yield()
        i = 0
      end
      union.Add(x, y) 
    end
    coroutine.yield()
    return union
  end

  s.Difference = function(self, set)
    local out = Set.New()
    local i = 0
    for x, y in self.Walk() do
      if not set.Contains(x, y) then out.Add(x, y) end
      i = i + 1
      if i == 250 then coroutine.yield()
        i = 0
      end
    end
    coroutine.yield()
    return out
  end

  s.Intersection = function(self, set)
    local out = Set.New()
    local i = 0
    for x, y in self.Walk() do
      if set.Contains(x, y) then out.Add(x, y) end
      i = i + 1
      if i == 250 then coroutine.yield()
        i = 0
      end
    end
    coroutine.yield()
    return out
  end

  local ax = {}
  local ay = {}

  function s:Sample()
    local mr = math.random
    --First time you call this function, copy map to array.
    if next(ax) == nil then
      for x, y in self.Walk() do
        table.insert(ax, x)
        table.insert(ay, y)
      end
      --Empty maps can't be sampled. Try again next time.
      if next(ax) == nil then return end
    end

    --Or, redefine function to continue to sample from array.
    self.Sample = function()
      local i = mr(#ax)
      return mr() - 0.5 + ax[i], mr() - 0.5 + ay[i]
    end
    return self.Sample()
  end

  --Closest point to given point.
  function s:NN(x, y)
    if next(self.Values()) == nil then return end
    if self.ContainsReal(x, y) then
      return math.floor(x), math.floor(y),
        GetDistance(math.floor(x), math.floor(y), x, y)
    end
    local i, mind, minx, miny, d = 0, math.huge
    for a, b in self.Walk() do
      i = i + 1
      if i == 250 then coroutine.yield()
        i = 0
      end
      d = (x - a) ^ 2 + (y - b) ^ 2
      if d < mind then
        mind = d
        minx = a
        miny = b
      end
    end
    return minx, miny, math.sqrt(mind)
  end

  return s
end
