Iterator = {}

--Not seam safe.
--Proceed from x2 to x1 along a straight line.
function Iterator.LineSegment(x1, y1, x2, y2, n)
  n = n or 15
  return coroutine.wrap(function()
    for i = n, 0, -1 do
      coroutine.yield(x1 * i / n + x2 * (1 - i / n), y1 * i / n + y2 * (1 - i / n))
    end
  end)
end

function Iterator.Disk(r, a, b)
  local rs = r * r
  a, b = a and math.floor(a) or 0, b and math.floor(b) or 0
  return coroutine.wrap(function()
    for x = -r, r do
      for y = -r, r do
        if x * x + y * y < rs then
          coroutine.yield(x + a, y + b)
        end
      end
    end
  end)
end

--Takes normal vector and center, finds evenly spaced points on line.
function Iterator.Segment(cx, cy, nx, ny)
  return coroutine.wrap(function()
    for i = 1, 12 do
      coroutine.yield(cx - ny * i, cy + nx * i)
      coroutine.yield(cx + ny * i, cy - nx * i)
    end
  end)
end

--Takes normal vector and center, finds scrunched-up line.
function Iterator.Bellow(cx, cy, nx, ny)
  return coroutine.wrap(function()
    local ox, oy = -ny, nx
    local c, s = 0.5, 0.5 * math.sqrt(3)
    local vecx, vecy = {ox * c - oy * s, -ox * c - oy * s, -ox * c + oy * s, ox * c + oy * s},
                       {ox * s + oy * c, ox * s - oy * c, -ox * s - oy * c, -ox * s + oy * c}
    local xplus, yplus, xnega, ynega = cx, cy, cx, cy
    coroutine.yield(xplus, yplus)
    for i = 1, 12 do
      xplus, yplus = xplus + vecx[1], yplus + vecy[1]
      coroutine.yield(xplus, yplus)
      xnega, ynega = xnega + vecx[2], ynega + vecy[2]
      coroutine.yield(xnega, ynega)
      xplus, yplus = xplus + vecx[4], yplus + vecy[4]
      coroutine.yield(xplus, yplus)
      xnega, ynega = xnega + vecx[3], ynega + vecy[3]
      coroutine.yield(xnega, ynega)
    end
  end)
end

function Iterator.BellowPolar(cx, cy, r, theta)
  return Iterator.Bellow(cx, cy, r * math.sin(theta), r * math.cos(theta))
end

function Iterator.Spiral(cx, cy, r, n)
  return coroutine.wrap(function()
    local sqrt = math.sqrt
    r = r / sqrt(n)
    local th = math.pi * (3 - sqrt(5))
    local c, s = math.cos(th), math.sin(th)
    local x, y = r, 0
    for i = 1, n do
      r = sqrt((i + 1) / i)
      x, y = r * (x * c - y * s) , r * (x * s + y * c)
      coroutine.yield(x + cx, y + cy)
    end
  end)
end
