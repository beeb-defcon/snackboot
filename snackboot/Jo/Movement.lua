Movement = {}

local function GetStopLocation(unitID)
  local fleet = unitID:GetFleetID()
  if not fleet then return unitID:GetLongitude(), unitID:GetLatitude() end
  local x, y = 0, 0
  fleet = GetFleetUnits(fleet)
  for _, id in ipairs(fleet) do
    x, y = x + id:GetLongitude(), y + id:GetLatitude()
  end
  return x / #fleet, y / #fleet
end

local function Stop(id)
  SetMovementTarget(id, GetStopLocation(id))
end

Movement.Stop = Stop
Movement.Retarget = Stop

local function Pivot(id, x, y)
  Stop(id)
  SetMovementTarget(id, x, y)
end

Movement.Pivot = Pivot

function Movement.Swivel(id)
  local x, y = id:GetVelocity()
  Stop(id)
  SetMovementTarget(id,
    GetLongitude(id) - 100 * x,
    GetLatitude(id) - 100 * y)
end

function Movement.Follow(follower, leader)
  local x, y = GetVelocity(leader)
  Pivot(follower, GetLongitude(leader) + 20 * x, GetLatitude(leader) + 20 * y)
end