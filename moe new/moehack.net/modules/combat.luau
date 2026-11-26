--!native
--!optimize 2

--# Aliases

local FromOffset, FromScale, UDim2New = UDim2.fromOffset, UDim2.fromScale, UDim2.new
local Atan2, Rad, Pi, Abs, Minimum, Maximum, Floor, Clamp, Sqrt, Asin = math.atan2, math.rad, math.pi, math.abs, math.min, math.max, math.floor, math.clamp, math.sqrt, math.asin
local NewVector, NewVector3, NewCFrame = vector.create, Vector3.new, CFrame.new
local Create, IsA, IsDescendantOf, GetChildren, QueryDescendants = Instance.new, workspace.IsA, workspace.IsDescendantOf, workspace.GetChildren, workspace.QueryDescendants
local Spawn, Wait = task.spawn, task.wait
local ForEach, Insert, RemoveTable = table.foreach, table.insert, table.remove
local FindFirstChild, WaitForChild, Raycast = workspace.FindFirstChild, workspace.WaitForChild, clonefunction(workspace.Raycast)
local WorldToViewportPoint = workspace.CurrentCamera.WorldToViewportPoint
local GetService = Game.GetService

--# Services

local MarketplaceService = GetService(Game, "MarketplaceService")
local ReplicatedStorage = GetService(Game, "ReplicatedStorage")
local RunService = GetService(Game, "RunService")
local Stats = GetService(Game, "Stats")
local DataPing = Stats.Network.ServerStatsItem["Data Ping"]
local UserInputService = GetService(Game, "UserInputService")
local Players = GetService(Game, "Players")

local UserGameSettings = UserSettings():GetService("UserGameSettings")

local LocalPlayer = Players.LocalPlayer

--# Helper Funcs


--# Variables

local Utility = moehack.load_module("moehack.net/modules/utility.luau", true)
local EasingStyle = Utility.EasingStyle

local Toggles, Options = getgenv().Toggles, getgenv().Options
local Camera = workspace.CurrentCamera

local RaycastParams = RaycastParams.new()
local PlayersCache = Players:GetPlayers()

local HitboxCache = {}
local HitboxConnections = {}

--# Main

RaycastParams.FilterType = Enum.RaycastFilterType.Exclude

local Combat = {
    AimAssistTarget = nil,
    TriggerBotTarget = nil,
    TriggerBotTime = nil,
    RCSLastPitch = nil,
    RCSMouseSensitivity = 0.0025,
    RCSRecoil = 0,
    RCSCorrection = 0,
    MouseThingBruh = false
}

function Combat.IsBehindWalls(Target, Hitbox)
    local Character = IsA(Target, "Model") and Target or Target.Character

    if not Character or not Hitbox or not IsDescendantOf(Hitbox, Character) then
        return true
    end

    local Origin = Camera.CFrame.Position
    local Direction = Hitbox.Position - Origin
    local IgnoreList = {LocalPlayer.Character}

    for _ = 1, 20 do
        RaycastParams.FilterDescendantsInstances = IgnoreList

        local Result = Raycast(workspace, Origin, Direction, RaycastParams)

        if not Result then
            return false
        end

        local Part = Result.Instance

        if IsDescendantOf(Part, Character) then
            return false
        end

        if Part.Transparency >= 1 or not Part.CanCollide then
            Insert(IgnoreList, Part)
            Origin = Result.Position + Direction.Unit * 0.01
            Direction = Hitbox.Position - Origin
        else
            return true
        end
    end

    return true
end

function Combat.GetHitboxes(Character)
	if not Character or not Character.Parent then
		return {}
	end

	local Cached = HitboxCache[Character]

	if Cached then
		return Cached.List
	end

	local List = {}
	local Lookup = {}

	for _, Part in QueryDescendants(Character, "BasePart") do
		if Part.Parent and Part.Transparency < 1 then
			List[#List + 1] = Part
			Lookup[Part] = true
		end
	end

	Cached = {
		List = List,
		Lookup = Lookup
	}

	HitboxCache[Character] = Cached

	local DescendantAdded = Character.DescendantAdded:Connect(function(Descendant)
		if not Descendant.Parent or not IsA(Descendant, "BasePart") then
			return
		end

		if Descendant.Transparency >= 1 or Lookup[Descendant] then
			return
		end

		Lookup[Descendant] = true
		List[#List + 1] = Descendant
	end)

	local DescendantRemoving = Character.DescendantRemoving:Connect(function(Descendant)
		if not Lookup[Descendant] then
			return
		end

		Lookup[Descendant] = nil

		for Index = #List, 1, -1 do
			if List[Index] == Descendant then

                if List and Index then
                    RemoveTable(List, Index)
                end
				break
			end
		end
	end)

	HitboxConnections[Character] = {
		DescendantAdded,
		DescendantRemoving
	}

	return List
end

function Combat.ClearHitboxCache(Character)
	if not Character then
		return
	end

	HitboxCache[Character] = nil

	local Connections = HitboxConnections[Character]

	if Connections then
		for _, Connection in Connections do
			if Connection.Connected then
				Connection:Disconnect()
			end
		end

		HitboxConnections[Character] = nil
	end
end

function Combat.GetTarget(FOV: number, NearestHitbox: boolean)
    local ViewportSize = Camera.ViewportSize
    local Center = NewVector(ViewportSize.X * 0.5, ViewportSize.Y * 0.5)
    local BestTarget = nil
    local PlayerTarget = nil
    local BestHitboxPart = nil
    local BestDistance = FOV

    if moehack.data.game_name == "Operation One" then
        local Viewmodels = FindFirstChild(workspace, "Viewmodels")

        if not Viewmodels then
            return
        end

        for _, Character in GetChildren(Viewmodels) do
            if Character.Name == "LocalViewmodel" then
                continue
            end

            if NearestHitbox then
                for _, Hitbox in Combat.GetHitboxes(Character) do
                    if Hitbox.Parent and Hitbox.Transparency < 1 then
                        local Position, OnScreen = WorldToViewportPoint(Camera, Hitbox.Position)

                        if OnScreen and Position.Z > 0 then
                            local Distance = (NewVector(Position.X, Position.Y) - Center).Magnitude

                            if Distance <= BestDistance then
                                BestDistance = Distance
                                BestTarget = Character
                                BestHitboxPart = Hitbox
                            end
                        end
                    end
                end
            else
                local Hitbox = FindFirstChild(Character, "head")

                if Hitbox and IsA(Hitbox, "BasePart") and Hitbox.Transparency < 1 then
                    local Position, OnScreen = WorldToViewportPoint(Camera, Hitbox.Position)

                    if OnScreen and Position.Z > 0 then
                        local Distance = (NewVector(Position.X, Position.Y) - Center).Magnitude

                        if Distance <= BestDistance then
                            BestDistance = Distance
                            BestTarget = Character
                            BestHitboxPart = Hitbox
                        end
                    end
                end
            end
        end

        return BestTarget, BestHitboxPart
    end

    if moehack.data.game_name == "Killstreak" then
        local TargetUtil = filtergc("table", { Keys = { "getValidTargets", "isValidTarget" } }, true)

        if TargetUtil then
            local Bones = NearestHitbox and { "Head", "UpperTorso", "LowerTorso" } or { "Head" }

            for _, Entry in TargetUtil:getValidTargets() do
                local Character = Entry.Instance

                for _, Name in Bones do
                    local Hitbox = Character and FindFirstChild(Character, Name)

                    if Hitbox and Hitbox.Parent and IsA(Hitbox, "BasePart") and Hitbox.Transparency < 1 then
                        local Position, OnScreen = WorldToViewportPoint(Camera, Hitbox.Position)

                        if OnScreen and Position.Z > 0 then
                            local Distance = (NewVector(Position.X, Position.Y) - Center).Magnitude

                            if Distance <= BestDistance then
                                BestDistance = Distance
                                BestTarget = Character
                                PlayerTarget = Players:GetPlayerFromCharacter(Character)
                                BestHitboxPart = Hitbox
                            end
                        end
                    end
                end
            end
        end

        return BestTarget, BestHitboxPart, PlayerTarget
    end

    for _, Player in PlayersCache do
        if Player == LocalPlayer then
            continue
        end

        if Utility.IsTeammate(Player, LocalPlayer) and not Toggles["combat/settings/targetteammates"].Value then
            continue
        end

        local Character = Utility.GetCharacter(Player)

        if not Character then
            continue
        end

        local RootPart = Character.PrimaryPart

        if not RootPart then
            continue
        end

        local _, Health = Utility.GetHealth(Player, Character)

        if not Health or Health <= 0 then
            continue
        end

        if NearestHitbox then
            for _, Hitbox in Combat.GetHitboxes(Character) do
                if Hitbox.Parent and Hitbox.Transparency < 1 then
                    local Position, OnScreen = WorldToViewportPoint(Camera, Hitbox.Position)

                    if OnScreen and Position.Z > 0 then
                        local Distance = (NewVector(Position.X, Position.Y) - Center).Magnitude

                        if Distance <= BestDistance then
                            BestDistance = Distance
                            BestTarget = Character
                            PlayerTarget = Player
                            BestHitboxPart = Hitbox
                        end
                    end
                end
            end
        else
            local Position, OnScreen = WorldToViewportPoint(Camera, RootPart.Position)

            if OnScreen and Position.Z > 0 then
                local Distance = (NewVector(Position.X, Position.Y) - Center).Magnitude

                if Distance <= BestDistance then
                    BestDistance = Distance
                    BestTarget = Character
                    PlayerTarget = Player
                    BestHitboxPart = RootPart
                end
            end
        end
    end

    return BestTarget, BestHitboxPart, PlayerTarget
end

function Combat.Tick(Delta)

    if Library.IsOpen then return end
    
    if Toggles["combat/aimassist"].Value and Options["combat/aimassist/key"]:GetState() then
        
        local FOV = Options["combat/aimassist/fov"].Value
        local UseNearestHitbox = Toggles["combat/aimassist/usenearhitbox"].Value
        local StickyAim = Toggles["combat/aimassist/stickyaim"].Value
        local IgnoreBehindWalls = Toggles["combat/aimassist/ignorebehindwalls"].Value
        local Method = Options["combat/aimassist/method"].Value
        local InstantSnap = Toggles["combat/aimassist/instasnap"].Value
        local EasingName = Options["combat/aimassist/easingstyle"].Value
        local Speed = Options["combat/aimassist/speed"].Value

        local Target
        local Hitbox

        if StickyAim and Combat.AimAssistTarget then
            local Character = IsA(Combat.AimAssistTarget, "Model") and Combat.AimAssistTarget or Combat.AimAssistTarget.Character
            local MaxHealth, Health = Utility.GetHealth(Combat.AimAssistPlayer, Character)
            if Health > 0 then
                if UseNearestHitbox then
                    local BestDistance = FOV
                    local ViewportSize = Camera.ViewportSize
                    local Center = NewVector(ViewportSize.X * 0.5, ViewportSize.Y * 0.5)

                    for _, Part in Character:GetChildren() do
                        if IsA(Part, "BasePart") then
                            local Position, OnScreen = WorldToViewportPoint(Camera, Part.Position)

                            if OnScreen and Position.Z > 0 then
                                local Distance = (NewVector(Position.X, Position.Y) - Center).Magnitude

                                if Distance <= BestDistance then
                                    BestDistance = Distance
                                    Hitbox = Part
                                end
                            end
                        end
                    end
                else
                    Hitbox = Character.PrimaryPart
                end

                Target = Combat.AimAssistTarget
            else
                Combat.AimAssistTarget = nil
                Combat.AimAssistPlayer = nil
            end
        end

        if not Target then
            Target, Hitbox, Player = Combat.GetTarget(FOV, UseNearestHitbox)

            if Target then
                Combat.AimAssistTarget = Target
                Combat.AimAssistPlayer = Player
            end
        end

        if Target and Hitbox then
            local Position, OnScreen = WorldToViewportPoint(Camera, Hitbox.Position)

            if OnScreen and Position.Z > 0 then
                local ViewportSize = Camera.ViewportSize
                local CenterX = ViewportSize.X * 0.5
                local CenterY = ViewportSize.Y * 0.5

                local OffsetX = Position.X - CenterX
                local OffsetY = Position.Y - CenterY

                local Distance = Sqrt(OffsetX * OffsetX + OffsetY * OffsetY)

                if Distance <= FOV then
                    local Visible = true

                    if IgnoreBehindWalls then
                        Visible = not Combat.IsBehindWalls(Target, Hitbox)
                    end

                    if Visible then
                        local Alpha

                        if InstantSnap then
                            Alpha = 1
                        else
                            Alpha = Clamp(Speed * Delta, 0, 1)

                            local Easing = EasingStyle[EasingName]

                            if Easing then
                                Alpha = Easing(Alpha)
                            end
                        end

                        if Method == "Camera" then
                            local AimCFrame = CFrame.lookAt(Camera.CFrame.Position, Hitbox.Position)

                            Camera.CFrame = Camera.CFrame:Lerp(AimCFrame, Alpha)
                        elseif Method == "Mouse" then
                            local MoveX = OffsetX * Alpha
                            local MoveY = OffsetY * Alpha

                            if Abs(MoveX) < 1 and Abs(OffsetX) > 0.5 then
                                MoveX = OffsetX > 0 and 1 or -1
                            end

                            if Abs(MoveY) < 1 and Abs(OffsetY) > 0.5 then
                                MoveY = OffsetY > 0 and 1 or -1
                            end

                            mousemoverel(MoveX, MoveY)
                        end
                    end
                elseif not StickyAim then
                    Combat.AimAssistTarget = nil
                    Combat.AimAssistPlayer = nil
                end
            elseif not StickyAim then
                Combat.AimAssistTarget = nil
                Combat.AimAssistPlayer = nil
            end
        end
    else
        Combat.AimAssistTarget = nil
        Combat.AimAssistPlayer = nil
    end

    if Toggles["combat/triggerbot"].Value and Options["combat/triggerbot/key"]:GetState() then
        local FOV = Options["combat/triggerbot/fov"].Value
        local ReactionTime = Options["combat/triggerbot/reactiontime"].Value / 1000
        local IgnoreBehindWalls = Toggles["combat/triggerbot/ignorebehindwalls"].Value

        local Target, Hitbox = Combat.GetTarget(FOV, true)

        if Combat.MouseThingBruh then
            mouse1release()
        end

        if Target and Hitbox then
            local Visible = true

            if IgnoreBehindWalls then
                Visible = not Combat.IsBehindWalls(Target, Hitbox)
            end

            if Visible then
                if Combat.TriggerBotTarget ~= Target then
                    Combat.TriggerBotTarget = Target
                    Combat.TriggerBotTime = os.clock()
                end

                if Combat.TriggerBotTime and os.clock() - Combat.TriggerBotTime >= ReactionTime then
                    if Combat.MouseThingBruh then
                        mouse1release()
                    else
                        mouse1press()
                    end
                    Combat.MouseThingBruh = not Combat.MouseThingBruh
                end
            else
                Combat.TriggerBotTarget = nil
                Combat.TriggerBotTime = nil
            end
        else
            Combat.TriggerBotTarget = nil
            Combat.TriggerBotTime = nil
        end
    else
        Combat.TriggerBotTarget = nil
        Combat.TriggerBotTime = nil
    end

    if Toggles["combat/rcs"].Value and Options["combat/rcs/key"]:GetState() then
        local MouseY = UserInputService:GetMouseDelta().Y
        local LookVector = Camera.CFrame.LookVector
        local CurrentPitch = Asin(Clamp(-LookVector.Y, -1, 1))

        if not Combat.RCSLastPitch then
            Combat.RCSLastPitch = CurrentPitch
        else
            local CameraDelta = CurrentPitch - Combat.RCSLastPitch
            Combat.RCSLastPitch = CurrentPitch

            local Sensitivity = Combat.RCSMouseSensitivity or 0.0025
            local Correction = Combat.RCSCorrection or 0
            local RealMouseY = MouseY - Correction

            Combat.RCSCorrection = 0
            if Abs(RealMouseY) >= 2 and Abs(CameraDelta) < 0.035 then
                local MeasuredSensitivity = CameraDelta / RealMouseY

                if MeasuredSensitivity > 0.0001 and MeasuredSensitivity < 0.02 then
                    Combat.RCSMouseSensitivity += (MeasuredSensitivity - Sensitivity) * Clamp(Delta * 2, 0, 1)
                    Combat.RCSMouseSensitivity = Clamp(Combat.RCSMouseSensitivity, 0.0001, 0.02)
                    Sensitivity = Combat.RCSMouseSensitivity
                end
            end

            local ExpectedCameraDelta = RealMouseY * Sensitivity
            local RecoilDelta = CameraDelta - ExpectedCameraDelta

            if Abs(RecoilDelta) > 0.0005 then
                Combat.RCSRecoil += RecoilDelta
            end

            Combat.RCSRecoil = Clamp(Combat.RCSRecoil, -0.5, 0.5)

            local Speed = Options["combat/rcs/speed"].Value
            if Sensitivity > 0.0001 and Abs(Combat.RCSRecoil) > 0.0005 then
                local Pixels = -Combat.RCSRecoil / Sensitivity
                local CorrectionAmount = Pixels * (Options["combat/rcs/strength"].Value / 1000) * Clamp(Speed * Delta, 0, 1)

                CorrectionAmount = Clamp(CorrectionAmount, -15, 15)

                if Abs(CorrectionAmount) >= 0.05 then
                    mousemoverel(0, CorrectionAmount)

                    Combat.RCSCorrection = CorrectionAmount
                    Combat.RCSRecoil -= CorrectionAmount * Sensitivity
                end
            end
        end
    else
        Combat.RCSLastPitch = nil
        Combat.RCSRecoil = 0
        Combat.RCSCorrection = 0
    end
end

Library:GiveSignal( Players.PlayerAdded:Connect(function(Player)
    PlayersCache[Player] = Player
end) )

Library:GiveSignal(Players.PlayerRemoving:Connect(function(Player)
	PlayersCache[Player] = nil

	local Character = Player.Character

	if Character then
		Combat.ClearHitboxCache(Character)
	end
end))

return Combat