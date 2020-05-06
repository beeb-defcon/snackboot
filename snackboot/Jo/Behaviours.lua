require "Utilities/BT"
require "Jo/GameRules"
require "Jo/Sync"
require "Jo/Units"

Behaviours = {}
Blackboard = {}
Behaviours.Data = Blackboard
--This is the glue holding the bot together.
--The behaviour of the bot after placement is governed by the behaviour tree at the bottom of this file.
--The behaviour tree is built during runtime - a subtree is added for each fleet,
--each unit has its own subtree.

local function Stop(id)
  return BT.Action(
    function()
      SetMovementTarget(id, GetLongitude(id), GetLatitude(id))
      coroutine.yield()
      return true
    end)
end

local function DebugMessage(id)
  return BT.Action(function()
    DebugLog("BT Tick: "..tostring(id), nil, nil, 200, 150, 175)
    return true
  end)
end

local function Surface(id)
  local state = GameRules.LaunchState[GetUnitType(id)]
  local function set()
    SetState(id, state)
    coroutine.yield()
    return GetCurrentState(id) == state
  end
  return BT.Action(set)
end

local Open = Surface

--Search every enemy unit for the one closest to the given unit.
local function TargetClosestUnit(id)
  local function f()
    local mindistance = math.huge
    local target, d
    local myunit = Units.Me[id]
    for targetid, unit in pairs(Units.Current) do
      if unit.team ~= Jo.myid and unit.time > Units.Time - 60 then
        d = GetDistance(myunit.longitude, myunit.latitude,
                        unit.longitude, unit.latitude)
        if d < mindistance then
          target = targetid
          d = mindistance
        end
      end
    end
    if not target then return false end
    coroutine.yield()

    Blackboard[id].Target = {
      ["id"] = target,
      ["x"] = GetLongitude(target),
      ["y"] = GetLatitude(target)}

    DebugLog("Assigned target "..tostring(target).." to id "..tostring(id))

    return true
  end
  return BT.Action(f)
end

local function HasTarget(id)
  return BT.Action(function()
    local target = Blackboard[id].Target
    if target.id or target.x then return true end
    return false
  end)
end

local function MoveToTarget(id)
  local function f()
    local target = Blackboard[id].Target
    SetMovementTarget(id, target.x, target.y)
    return true
  end
  return BT.Action(f)
end

local function AttackTarget(id)
  local function f()
    local target = Blackboard[id].Target
    if not target then return false end
    SetActionTarget(id, target.id)
    return true
  end
  return BT.Action(f)
end

local function Wait()
  return BT.Action(function() coroutine.yield() return true end)
end

local function PivotToTarget(id)
  return BT.Sequence{
    Stop(id),
    MoveToTarget(id)}
end

local function CanLaunch()
  return BT.RememberTrue(BT.Action(function() return GetDefconLevel() == 1 end))
end

local trees = {["Fleet"] = {}}

trees.Fighter = function(id)
  return BT.Sequence{
    DebugMessage(id)
    BT.Delay(20, TargetClosestUnit(id)),
    HasTarget(id),
    AttackTarget(id)}
end

trees.Bomber = function(id)
  return BT.Sequence{}
end

trees.BattleShip = function(id)
  return BT.Sequence{}
end

trees.Carrier = function(id)
  return BT.Sequence{}
end

trees.Sub = function(id)
  return BT.Sequence{}
end

trees.Silo = function(id)
  return BT.Sequence{}
end

trees.AirBase = function(id)
  return BT.Sequence{}
end

trees.Fleet.BattleShip = function(fleet)
  return BT.Sequence{}
end

trees.Fleet.Carrier = function(fleet)
  return BT.Sequence{}
end

trees.Fleet.Silo = function(fleet)
  return BT.Sequence{}
end

trees.Fleet.Fighter = function(fleet)
  return BT.Sequence{}
end

trees.Fleet.Bomber = function(fleet)
  return BT.Sequence{}
end

trees.Fleet.Sub = function(fleet)
  return BT.Sequence{}
end

trees.Fleet.AirBase = function(fleet)
  return BT.Sequence{}
end

function Behaviours.Unit(id)
  Blackboard[id] = {}
  return trees[GetUnitType(id)](id)
end

function Behaviours.Fleet(fleet)
  DebugLog("Adding fleet to behaviour tree.")
  local type = fleet.Type()
  DebugLog("Type: "..tostring(type))
  Blackboard[fleet] = {}
  return trees.Fleet[type](fleet)
end

--Root node for fleets. Units.NewFleet adds a new subtree here.
Behaviours.Fleets = BT.ParallelOnce{}

function Behaviours.Tree()
  return BT.Parallel{
    BT.Sequence{
      BT.Delay(30, BT.Action(Units.Update)),
      BT.Delay(30, BT.Action(Scout.Update)),
      BT.Delay(30, BT.Action(Scout.Flush)),
      Behaviours.Fleets}}
end