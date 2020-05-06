XCo = {}

local function ShortLength(x1, x2)
  return math.min(math.abs(x1 - x2),
                  math.abs(x1 - x2 + 360),
                  math.abs(x1 - x2 - 360))
end

local function RightLength(from, to)
  if from > to then return RightLength(from, to + 360) end
  return to - from
end

local function LongLength(x1, x2)
  return math.max(RightLength(x1, x2),
                  RightLength(x2, x1))
end

--Intervals where the nuke takes the longer path.
local LongIntervals = {
  {180, 0, 180},
  {185, 5, 165},
  {190, 12.5, 157.5},
  {195, 20, 145},
  {200, 27.5, 132.5},
  {205, 40, 115},
  {210, 57.5, 87.5},
  {math.huge, 180, -180}}

local function InLongInterval(dx, from)
  if dx > 180 then
    local a, b
    for _, interval in ipairs(LongIntervals) do
      if interval[1] >= dx then
        a, b = interval[2], interval[3]
        return from >= a and from <= b
      end
    end
  end
  return InLongInterval(360 - dx, -from)  
end

XCo.NukeLength = function(from, to)
  local ll = LongLength(from, to)
  if ll < 145 or ll > 215
   or not InLongInterval(ll, from) then
    return ShortLength(from, to)
  end
  return ll
end

--meridian lies between -180 and 180.
--coordinates of meridian in the patch centered at prime.
--If calling several times for a fixed prime meridian, use RelativizeCached.
XCo.Relativize = function(prime, meridian)
  if prime > 0 then
    if meridian + 180 < prime then return meridian + 360
    else return meridian end
  else
    if meridian - 180 > prime then return meridian - 360
    else return meridian end
  end
end

XCo.RelativizeCached = function(prime)
  if prime > 0 then
    return function(meridian)
      return meridian + ((meridian + 180 < prime) and 360 or 0)
    end
  else
    return function(meridian)
      return meridian - ((meridian - 180 > prime) and 360 or 0)
    end
  end
end

XCo.SideCached = function(prime)
  if prime > 0 then
    return function(meridian)
      return ((meridian + ((meridian + 180 < prime) and 360 or 0)) > 0)
    end
  else
    return function(meridian)
      return ((meridian - ((meridian - 180 > prime) and 360 or 0)) > 0)
    end
  end
end