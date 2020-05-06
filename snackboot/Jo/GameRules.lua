--Properties of the game constant over all games.
GameRules = {}

GameRules.ShipTypes = {
  ["Sub"] = true,
  ["Carrier"] = true,
  ["BattleShip"] = true}

GameRules.BuildingTypes = {
  ["AirBase"] = true,
  ["RadarStation"] = true,
  ["Silo"] = true}

GameRules.Scouts = {
  ["Carrier"] = true,
  ["BattleShip"] = true,
  ["Fighter"] = true,
  ["Bomber"] = true}

GameRules.ActiveUnits = {
  ["BattleShip"] = true,
  ["Carrier"] = true,
  ["Fighter"] = true,
  ["AirBase"] = true,
  ["Bomber"] = true,
  ["Silo"] = true,
  ["Sub"] = true,}

--Minimum radii that units must be placed apart.
GameRules.PlacementRadius = {
  ["AirBase"] = 5,
  ["BattleShip"] = 1,
  ["Carrier"] = 1,
  ["Fleet"] = 1,
  ["RadarStation"] = 5,
  ["Silo"] = 5,
  ["Sub"] = 1}

GameRules.LaunchState = {
  ["Silo"] = 0,
  ["Bomber"] = 1,
  ["Sub"] = 2}

--How far can each unit shoot?
GameRules.CombatRadius = {
  ["Carrier"] = {[0] = 45.0},
  ["Silo"] = {[0] = 0, [1] = 30.0},
  ["BattleShip"] = {[0] = 10.0},
  ["Bomber"] = {[0] = 20.0, [1] = 25.0},
  ["Fighter"] = {[0] = 10.0},
  ["Sub"] = {[0] = 0.0, [1] = 2.5, [2] = 45.0}}

--Fog of war: how far can each unit see?
GameRules.RadarRadius = {
  ["RadarStation"] = {[0] = 20.0},
  ["Silo"] = {[0] = 10.0, [1] = 10.0},
  ["Carrier"] = {[0] = 15.0, [1] = 15.0, [2] = 15.0},
  ["BattleShip"] = {[0] = 10.0},
  ["Bomber"] = {[0] = 10.0, [1] = 5.0},
  ["Fighter"] = {[0] = 5.0},
  ["Sub"] = {[0] = 0, [1] = 0, [2] = 2.5}}