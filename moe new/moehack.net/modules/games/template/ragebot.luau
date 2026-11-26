--!native
--!optimize 2

--# Aliases

local NewVector3, NewCFrame = Vector3.new, CFrame.new
local Minimum = math.min
local Insert, RemoveTable, TableFind = table.insert, table.remove, table.find
local FindFirstChild, Raycast = workspace.FindFirstChild, workspace.Raycast
local GetService = Game.GetService
local Tick = tick
local GetParts = workspace.GetPartBoundsInRadius

--# Services

local Players = GetService(Game, "Players")
local ReplicatedStorage = GetService(Game, "ReplicatedStorage")
local ReplicatedFirst = GetService(Game, "ReplicatedFirst")
local RunService = GetService(Game, "RunService")

--# Variables

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local PlayersCache = Players:GetPlayers()

local RaycastParameters = RaycastParams.new()
RaycastParameters.FilterType = Enum.RaycastFilterType.Exclude

--# Custom Modules

local Combat = moehack.load_module("moehack.net/modules/combat.luau")
local Utility = moehack.load_module("moehack.net/modules/utility.luau")

--# Game-specific

local Ragebot = {}

function Ragebot:Scan()

end

Library:GiveSignal(RunService.Stepped:Connect(function() 
    Ragebot:Scan() 
end))

Library:GiveSignal(Players.PlayerAdded:Connect(function(Player)
    Insert(PlayersCache, Player)
end))

Library:GiveSignal(Players.PlayerRemoving:Connect(function(Player)
    local Index = TableFind(PlayersCache, Player)
    if Index then RemoveTable(PlayersCache, Index) end
end))

return Ragebot