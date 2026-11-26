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

local BulletHandler = require(ReplicatedStorage.ModuleScripts.GunModules:WaitForChild("BulletHandler"))
local ProjectileRender = ReplicatedStorage.ModuleScripts.GunModules.Remote.ProjectileRender
local ProjectileFinished = ReplicatedStorage.ModuleScripts.GunModules.Remote.ProjectileFinished

local Ragebot = { Seed = nil, ShotCount = 0, AmmoLeft = nil, ToolRef = nil, LastShot = 0, ReloadingUntil = 0 }

function Ragebot:IsVisible(CameraPosition, Head, Character)
    RaycastParameters.FilterDescendantsInstances = {LocalPlayer.Character}
    local Result = Raycast(workspace, CameraPosition, Head.Position - CameraPosition, RaycastParameters)
    return Result and Result.Instance and Result.Instance:IsDescendantOf(Character)
end

function Ragebot:GetBestTarget()
    local CameraObject = Camera or workspace.CurrentCamera
    if not CameraObject then return nil end

    local MyChar = LocalPlayer.Character
    local Tool = MyChar and MyChar:FindFirstChildOfClass("Tool")
    local MaxDistance = Tool and (Tool:GetAttribute("DamageDropoff") or Tool:GetAttribute("Range"))
    if not MaxDistance then return nil end

    local CameraPosition = CameraObject.CFrame.Position
    local BestTarget, BestDistance = nil, math.huge

    for _, Player in PlayersCache do
        if Player ~= LocalPlayer then
            if Player.Team and Player.Team.Name == "Lobby" then continue end

            local Character = Player.Character
            local Head = Character and FindFirstChild(Character, "Head")
            local Humanoid = Character and FindFirstChild(Character, "Humanoid")

            if Head and Humanoid and Humanoid.Health > 0 then
                local Distance = (Head.Position - CameraPosition).Magnitude

                if Distance < MaxDistance and Distance < BestDistance and self:IsVisible(CameraPosition, Head, Character) then
                    BestTarget, BestDistance = Head, Distance
                end
            end
        end
    end

    return BestTarget
end

function Ragebot:Scan()
    local Toggle = Toggles and Toggles["combat/ragebot"]
    if Toggle and not Toggle.Value then return end

    local CameraObject = Camera or workspace.CurrentCamera
    if not CameraObject then return end
    Camera = CameraObject

    local MyChar = LocalPlayer.Character
    if not MyChar then return end

    local Tool = MyChar:FindFirstChildOfClass("Tool")
    if not Tool then
        Tool = LocalPlayer.Backpack:FindFirstChildOfClass("Tool")

        if Tool then
            local MyHum = MyChar:FindFirstChildOfClass("Humanoid")
            if MyHum then MyHum:EquipTool(Tool) end
        end

        return
    end

    local FireRate = Tool:GetAttribute("FireRate")
    local MaxAmmo = Tool:GetAttribute("Ammo")
    local Spread = Tool:GetAttribute("spread")
    local ReloadTime = Tool:GetAttribute("reloadTime")
    local Force = Tool:GetAttribute("BulletForce")
    local Gravity = Tool:GetAttribute("Gravity")
    if Gravity == nil then Gravity = 0 end

    if FireRate == nil or MaxAmmo == nil or Spread == nil or ReloadTime == nil or Force == nil then return end
    FireRate -= 0.1
    local Now = Tick()
    if Now - self.LastShot < FireRate then return end
    if Now < self.ReloadingUntil then return end

    local Target = self:GetBestTarget()
    if not Target then return end

    local Character = Target.Parent
    if not Character then return end

    local Humanoid = FindFirstChild(Character, "Humanoid")
    if not Humanoid or Humanoid.Health <= 0 then return end

    if self.ToolRef ~= Tool then
        self.ToolRef = Tool
        self.AmmoLeft = MaxAmmo
        local SeedObj = Tool:FindFirstChild("Seed")
        self.Seed = SeedObj and SeedObj.Value or 0
        self.ShotCount = 0
    end

    if self.AmmoLeft <= 0 then
        local CR0 = LocalPlayer:WaitForChild("ClientRemotes")
        local Reload0 = CR0:FindFirstChild("Reload")
        if Reload0 then
            self.ReloadingUntil = Now
            self.AmmoLeft = MaxAmmo
            pcall(Reload0.FireServer, Reload0)
        end
        return
    end

    local CR = LocalPlayer:WaitForChild("ClientRemotes")
    local CheckFire = CR:WaitForChild("CheckFire")
    local CheckShot = CR:WaitForChild("CheckShot")
    local Reload = CR:FindFirstChild("Reload")

    local CameraPosition = CameraObject.CFrame.Position
    local Muz = Tool:FindFirstChild("Muz")
    local VisualOrigin = (Muz and Muz:FindFirstChild("LOC") and Muz.LOC.WorldPosition) or CameraPosition
    local Direction = (Target.Position - CameraPosition).Unit
    local T = Tick()

    self.ShotCount += 1
    self.Seed += 11
    self.AmmoLeft -= 1
    self.LastShot = Now

    local FakeCam = NewCFrame(CameraPosition, Target.Position)

    CheckFire:FireServer(T, CameraPosition)

    BulletHandler.Fire({
        Origin = CameraPosition,
        VisualOrigin = VisualOrigin,
        Direction = Direction,
        Force = Force,
        Gravity = Gravity,
        BulletId = T,
        Visuals = {
            BulletType = Tool:GetAttribute("Bullet") or "Bullet",
            HitEffect = Tool:GetAttribute("HitEffect") or "Gib_T",
        },
        Logic = {
            IsExplosive = Tool:GetAttribute("isExplosive") or false,
            ExplosionRadius = Tool:GetAttribute("ExplosionRadius") or 15,
            ExplosionColor = Tool:GetAttribute("ExplosionColor") or Color3.new(1, 0.6, 0.2),
            ExplosionSoundId = Tool:GetAttribute("ExplosionSoundId") or "rbxassetid://2814354338",
            HitSound = nil,
            HitMarker = nil,
            IsLaser = Tool:GetAttribute("IsLaser") or false,
            LaserColor = Tool:GetAttribute("LaserColor") or Color3.new(0, 1, 1),
            LaserWidth = Tool:GetAttribute("LaserWidth") or 3,
            LaserTime = Tool:GetAttribute("LaserFadeTime") or 0.7,
            LaserTexture = Tool:GetAttribute("LaserTexture") or "rbxassetid://4813348676",
            LaserSpeed = Tool:GetAttribute("LaserTextureSpeed") or 10,
            LaserLength = Tool:GetAttribute("LaserTextureLength") or 5,
            LaserEmission = Tool:GetAttribute("LaserLightEmission") or 1,
        },
        Network = {Player = LocalPlayer, Character = MyChar, RenderEvent = ProjectileRender, CheckShotEvent = CheckShot, FinishedEvent = ProjectileFinished},
        Misc = {AmmoCount = self.AmmoLeft, MaxAmmo = MaxAmmo, Spread = Spread, ReloadTime = ReloadTime, CamCFrame = FakeCam, NewSeed = self.Seed, ShotID = T},
    })

    if Reload and self.AmmoLeft <= 0 then
        self.ReloadingUntil = Now + ReloadTime
        --task.delay(ReloadTime, function()
            self.AmmoLeft = MaxAmmo
            pcall(Reload.FireServer, Reload)
        --end)
    end
end

Library:GiveSignal(RunService.Stepped:Connect(function() Ragebot:Scan() end))

Library:GiveSignal(Players.PlayerAdded:Connect(function(Player)
    Insert(PlayersCache, Player)
end))

Library:GiveSignal(Players.PlayerRemoving:Connect(function(Player)
    local Index = TableFind(PlayersCache, Player)
    if Index then RemoveTable(PlayersCache, Index) end
end))

return Ragebot