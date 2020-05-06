BoundingBox = {}

BoundingBox.New = function(x, X, y, Y)
  x = x or 180
  X = X or -180
  y = y or 90
  Y = Y or -90

  local min, max, rand = math.min, math.max, math.random
  local bb = {x = x, X = X, y = y, Y = Y}
  
  bb.Expand = function(a, b)
    bb.x = min(bb.x, a)
    bb.X = max(bb.X, a)
    bb.y = min(bb.y, b)
    bb.Y = max(bb.Y, b)
  end

  bb.Sample = function()
    return rand(x, X), rand(y, Y)
  end

  bb.SampleReal = function()
    return x + rand() * (X - x), y + rand() * (Y - y)
  end

  bb.Inside = function(a, b)
    return a > x and a < X
      and  b > y and b < Y
  end

  bb.Draw = function()
    WhiteboardDraw(x, y, X, y)
    WhiteboardDraw(X, y, X, Y)
    WhiteboardDraw(X, Y, X, y)
    WhiteboardDraw(X, y, x, y)
  end

  return bb
end