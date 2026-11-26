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

local NetClient = require(ReplicatedFirst.Client.Utility.NetClient)
local Events = require(ReplicatedStorage.Modules.Events)
local State = require(ReplicatedFirst.Client.Utility.State)
local Bridge = require(ReplicatedFirst.Client.Utility.Bridge)
local Particles = require(ReplicatedFirst.Client.Game.Particles)
local HumanoidInstanceWrapper = require(ReplicatedStorage.Modules.HumanoidInstanceWrapper)
local General = require(ReplicatedFirst.Client.Utility.General)
local GeneralFunctions = require(ReplicatedStorage.Modules.GeneralFunctions)

local PlayersCache = Players:GetPlayers()

--# Custom Modules

local Combat = moehack.load_module("moehack.net/modules/combat.luau")
local Utility = moehack.load_module("moehack.net/modules/utility.luau")

--# Cache

local Wkspc = ReplicatedStorage:WaitForChild("wkspc")
local Status = Wkspc:WaitForChild("Status")
local StatusPreparation = Status.Preparation

local KnifebotOverlapParams = OverlapParams.new()
KnifebotOverlapParams.FilterType = Enum.RaycastFilterType.Exclude
KnifebotOverlapParams.FilterDescendantsInstances = { LocalPlayer.Character }

local VisibilityParams = RaycastParams.new()
VisibilityParams.FilterType = Enum.RaycastFilterType.Exclude
VisibilityParams.IgnoreWater = true

local OriginParams = RaycastParams.new()
OriginParams.FilterType = Enum.RaycastFilterType.Exclude
OriginParams.FilterDescendantsInstances = { LocalPlayer.Character }
OriginParams.IgnoreWater = true

local LastRootPos: Vector3? = nil
local LastRootTick = 0

local CanHitFXPls = false

local CachedNow = 0
local CachedCamCFrame: CFrame = Camera.CFrame
local CachedCamPos: Vector3 = CachedCamCFrame.Position
local CachedOrigin: Vector3 = CachedCamPos
local CachedHitList: {Instance} = {}
local CachedCharacter: Model? = nil
local CachedRootPart: BasePart? = nil

--# Main

local Ragebot = { LastTimeFired = 0 }
Ragebot.__index = Ragebot

function Ragebot:UpdateFrameCache()
    if StatusPreparation.Value then return end

    CachedNow = Tick()
    CachedCamCFrame = Camera.CFrame
    CachedCamPos = CachedCamCFrame.Position
    CachedCharacter = LocalPlayer.Character
    CachedRootPart = CachedCharacter and CachedCharacter.PrimaryPart or nil
    CachedHitList = GeneralFunctions.gethitlist()

    KnifebotOverlapParams.FilterDescendantsInstances = { CachedCharacter }
    OriginParams.FilterDescendantsInstances = { CachedCharacter }
    VisibilityParams.FilterDescendantsInstances = CachedHitList
end

function Ragebot:ComputeOrigin()
    local Root = CachedRootPart or (CachedCharacter and FindFirstChild(CachedCharacter, "HumanoidRootPart"))
    local Origin = CachedCamPos

    if Root then
        local Now = CachedNow
        local Delta = Now - LastRootTick
        local Vel = Root.AssemblyLinearVelocity

        if LastRootPos and Delta > 0 and Delta < 1 then
            local RootPos = Root.Position
            local Measured = (RootPos - LastRootPos) / Delta

            if Measured.Magnitude > Vel.Magnitude then
                Vel = Measured
            end

            LastRootPos = RootPos
        else
            LastRootPos = Root.Position
        end

        LastRootTick = Now

        local VelMag = Vel.Magnitude

        if VelMag > 50 then
            local Ping = LocalPlayer:GetNetworkPing()

            if not Ping then
                Ping = 0
            end

            local Comp = Ping + 0.03
            if Comp < 0.03 then Comp = 0.03 end
            if Comp > 0.25 then Comp = 0.25 end

            Origin = CachedCamPos + Vel * Comp
        end
    end

    CachedOrigin = Origin
    return Origin
end

function Ragebot:IsVisible(Target: BasePart, Origin: Vector3?): boolean
    if not Target or not Target.Parent then return false end

    Origin = Origin or CachedCamPos

    local Character = Target:FindFirstAncestorOfClass("Model")
    if not Character then return false end

    local Direction = Target.Position - Origin
    local Result = Raycast(workspace, Origin, Direction, VisibilityParams)

    if not Result then
        return true
    end

    return Result.Instance:IsDescendantOf(Character)
end

function Ragebot:HitFX(Head: BasePart, Origin: Vector3, HeadBits: number)
    if not CanHitFXPls then return end
    if not Head or not Origin then return end

    local Gun = State.gun
    if not Gun then return end

    local HeadPos = Head.Position
    local Normal = (HeadPos - Origin).Unit

    Bridge.HitObject:Fire(Head, HeadPos, Normal, Gun, HeadBits or 1, false, false, false)

    local Override = GeneralFunctions.getTrailColorOverride(LocalPlayer, Gun)
    Particles.CreateTrail(Origin, HeadPos, Override)

    CanHitFXPls = false
end

function Ragebot:OriginScan(TargetCharacter, Hitbox)
    local RootPart = CachedRootPart

    if not RootPart or not TargetCharacter or not Hitbox or not Hitbox.Parent then
        return nil
    end

    local MaxOrigins = Minimum(Options["combat/originscan/maxorigin"].Value, 24)
    local MaxDist = Options["combat/originscan/maxdist"].Value

    if MaxOrigins < 1 or MaxDist <= 0 then
        return nil
    end

    local RootPosition = RootPart.Position
    local TargetPosition = Hitbox.Position
    local ToTarget = TargetPosition - RootPosition
    local Distance = ToTarget.Magnitude

    if Distance <= 0.001 then
        return RootPosition
    end

    if Distance > MaxDist then
        return nil
    end

    local Direction = ToTarget / Distance
    local Right = Direction:Cross(Vector3.yAxis)

    if Right.Magnitude <= 0.001 then
        Right = Direction:Cross(Vector3.xAxis)
    end

    Right = Right.Unit

    local Up = Right:Cross(Direction).Unit

    local Candidates = {
        RootPosition,
        RootPosition + Up * 1.5,
        RootPosition - Up * 1.5,
        RootPosition + Right * 1.5,
        RootPosition - Right * 1.5
    }

    for Index = 1, #Candidates do
        local Origin = Candidates[Index]
        local Result = Raycast(workspace, Origin, TargetPosition - Origin, OriginParams)

        if Result and Result.Instance and Result.Instance:IsDescendantOf(TargetCharacter) then
            return Origin
        end
    end

    local StepDistance = Distance / MaxOrigins

    for Index = 1, MaxOrigins do
        local Forward = StepDistance * Index
        local Spread = ((Index % 3) - 1) * 1.5
        local Height = ((Index % 5) - 2) * 1

        local Origin = RootPosition + Direction * Forward + Right * Spread + Up * Height

        if (Origin - RootPosition).Magnitude > MaxDist then
            continue
        end

        local Result = Raycast(workspace, Origin, TargetPosition - Origin, OriginParams)

        if Result and Result.Instance and Result.Instance:IsDescendantOf(TargetCharacter) then
            return Origin
        end
    end

    return nil
end

function Ragebot:GetOrigin(TargetCharacter, Hitbox)
    if Toggles["combat/originscan"] and Toggles["combat/originscan"].Value and TargetCharacter and Hitbox then
        local Scanned = self:OriginScan(TargetCharacter, Hitbox)

        if Scanned then
            return Scanned
        end
    end

    return CachedOrigin
end

function Ragebot:Hit(Character, PenIndex, SharedCFrame, ForcedOrigin)
    if not Character then return end

    local Self = self
    local Head = FindFirstChild(Character, "HeadHB") or FindFirstChild(Character, "Head")

    if not Head then return end

    local Gun = State.gun

    if not Gun then return end
    if FindFirstChild(Gun, "Melee") ~= nil then return end
    if FindFirstChild(Gun, "DK") ~= nil then return end
    if FindFirstChild(Gun, "Lunchbox") ~= nil then return end
    if State.ammocount ~= nil and State.ammocount <= 0 then return end
    if State.DISABLED == true then return end
    if State.equipping == true then return end

    local GunName = Gun.Name
    local ProjectileHolder = FindFirstChild(Gun, "Projectile")

    if ProjectileHolder then
        local ProjectileName

        if FindFirstChild(ProjectileHolder, "Arrow") then
            ProjectileName = "Arrow"
        elseif FindFirstChild(ProjectileHolder, "Rocket") then
            ProjectileName = "Rocket"
        elseif FindFirstChild(ProjectileHolder, "Grenade") then
            ProjectileName = "Grenade"
        elseif FindFirstChild(ProjectileHolder, "Baseball") then
            ProjectileName = "Baseball"
        elseif #ProjectileHolder:GetChildren() > 0 then
            ProjectileName = ProjectileHolder:GetChildren()[1].Name
        end

        if not ProjectileName then return end
        if FindFirstChild(ProjectileHolder, "Rocket") and LocalPlayer:FindFirstChild("RocketDebounce") then return end

        local GunId = Gun:GetAttribute("Id") or 4
        local Speed = FindFirstChild(Gun, "Speed") and Gun.Speed.Value * 0.07 or 100

        if Speed == 0 then
            Speed = 0.01
        end

        Speed *= Options["combat/ragebot/projectilespeedmult"].Value

        local Origin = ForcedOrigin or self:GetOrigin(Character, Head)
        local HeadPos = Head.Position
        local Aim = HeadPos
        local LegitTarget = CachedCamPos + CachedCamCFrame.LookVector * 1000
        local Muzzle = (CachedCamCFrame * NewCFrame(1.5, -0.65, 0)).Position

        NetClient.lock()
        NetClient.u16(Events.ReplicateProjectile)
        NetClient.str(ProjectileName)
        NetClient.f32(Speed)
        NetClient.f32(LegitTarget.X)
        NetClient.f32(LegitTarget.Y)
        NetClient.f32(LegitTarget.Z)
        NetClient.f32(Muzzle.X)
        NetClient.f32(Muzzle.Y)
        NetClient.f32(Muzzle.Z)
        NetClient.str(GunName)
        NetClient.f32(0)
        NetClient.u8(State.currentSpell or 1)
        NetClient.u8(bit32.bor(State.jumping and 1 or 0, State.ads and 2 or 0))
        NetClient.unlock()

        local Travel = (Aim - Origin).Magnitude / Speed
        local FireAds = State.ads
        local FireJump = State.jumping
        local FireSpell = State.currentSpell or 1

        task.delay(Travel, function()
            if Head.Parent == nil then return end

            local HeadPos2 = Head.Position
            local Spoofed = NewCFrame(Origin, HeadPos2)
            local Cx, Cy, Cz, R00, R01, R02, R10, R11, R12, R20, R21, R22 = Spoofed:GetComponents()
            local HeadBits = ProjectileName == "Arrow" and 2 or 0
            local Flags = bit32.replace(bit32.replace(bit32.bor(0, FireAds and 2 or 0, FireJump and 4 or 0), FireSpell, 3, 3), HeadBits, 6, 2)
            local N = (HeadPos2 - Origin).Unit

            NetClient.lock()
            NetClient.u16(Events.HitPart)
            NetClient.inst(Head)
            NetClient.u8(GunId)
            NetClient.u8(Flags)
            NetClient.u8(0)
            NetClient.f32(Cx)
            NetClient.f32(Cy)
            NetClient.f32(Cz)
            NetClient.f32(R00)
            NetClient.f32(R01)
            NetClient.f32(R02)
            NetClient.f32(R10)
            NetClient.f32(R11)
            NetClient.f32(R12)
            NetClient.f32(R20)
            NetClient.f32(R21)
            NetClient.f32(R22)
            NetClient.f32(HeadPos2.X)
            NetClient.f32(HeadPos2.Y)
            NetClient.f32(HeadPos2.Z)
            NetClient.f32(0)
            NetClient.unlock()

            NetClient.lock()
            NetClient.u16(Events.ImpactParticleBounce)
            NetClient.u8(GunId)
            NetClient.inst(Head)
            NetClient.f32(HeadPos2.X)
            NetClient.f32(HeadPos2.Y)
            NetClient.f32(HeadPos2.Z)
            NetClient.f32(N.X)
            NetClient.f32(N.Y)
            NetClient.f32(N.Z)
            NetClient.unlock()

            Self:HitFX(Head, Origin, HeadBits)
        end)

        return
    end

    local GunId = Gun:GetAttribute("Id") or 4
    local Origin = ForcedOrigin or self:GetOrigin(Character, Head)
    local HeadPos = Head.Position
    local Spoofed = SharedCFrame or NewCFrame(Origin, HeadPos)
    local Cx, Cy, Cz, R00, R01, R02, R10, R11, R12, R20, R21, R22 = Spoofed:GetComponents()
    local IsCrit = FindFirstChild(Gun, "Scoped") or FindFirstChild(Gun, "Crit")
    local HeadBits = IsCrit and 2 or 1
    local Flags = bit32.replace(bit32.replace(bit32.bor(0, State.ads and 2 or 0, State.jumping and 4 or 0), State.currentSpell or 1, 3, 3), HeadBits, 6, 2)
    local DeltaTime = State.btick == 0 and 0 or CachedNow - State.btick
    local Bullets = FindFirstChild(Gun, "Bullets") and Gun.Bullets.Value or 1

    if Bullets < 1 then
        Bullets = 1
    elseif Bullets > 10 then
        Bullets = 10
    end

    local Pen = PenIndex or 1

    if Pen < 1 then
        Pen = 1
    elseif Pen > 3 then
        Pen = 3
    end

    for _ = 1, Bullets do
        NetClient.lock()
        NetClient.u16(Events.HitPart)
        NetClient.inst(Head)
        NetClient.u8(GunId)
        NetClient.u8(Flags)
        NetClient.u8(Pen)
        NetClient.f32(Cx)
        NetClient.f32(Cy)
        NetClient.f32(Cz)
        NetClient.f32(R00)
        NetClient.f32(R01)
        NetClient.f32(R02)
        NetClient.f32(R10)
        NetClient.f32(R11)
        NetClient.f32(R12)
        NetClient.f32(R20)
        NetClient.f32(R21)
        NetClient.f32(R22)
        NetClient.f32(HeadPos.X)
        NetClient.f32(HeadPos.Y)
        NetClient.f32(HeadPos.Z)
        NetClient.f32(DeltaTime)
        NetClient.unlock()

        self:HitFX(Head, Origin, HeadBits)
    end

    if FindFirstChild(Gun, "ThrowWeapon") then
        local TSpeed = FindFirstChild(Gun, "Speed") and Gun.Speed.Value * 0.07 or 100

        if TSpeed == 0 then
            TSpeed = 0.01
        end

        local LegitTarget = CachedCamPos + CachedCamCFrame.LookVector * 1000
        local Muzzle = (CachedCamCFrame * NewCFrame(1.5, -0.65, 0)).Position

        NetClient.lock()
        NetClient.u16(Events.ReplicateProjectile)
        NetClient.str("Baseball")
        NetClient.f32(TSpeed)
        NetClient.f32(LegitTarget.X)
        NetClient.f32(LegitTarget.Y)
        NetClient.f32(LegitTarget.Z)
        NetClient.f32(Muzzle.X)
        NetClient.f32(Muzzle.Y)
        NetClient.f32(Muzzle.Z)
        NetClient.str(GunName)
        NetClient.f32(0)
        NetClient.u8(State.currentSpell or 1)
        NetClient.u8(bit32.bor(State.jumping and 1 or 0, State.ads and 2 or 0))
        NetClient.unlock()
    end
end

function Ragebot:ReplicateShoot()
    local Character = CachedCharacter
    if Character == nil then return end

    local Gun = HumanoidInstanceWrapper.Get(Character, "Gun")
    if Gun == nil then return end

    local Anims = State.anims
    local FireTrack = Anims.fireani or Anims.afireani or Anims.gfireani or Anims.efireani or Anims.cfireani or Anims.fire2ani or Anims.fire

    if FireTrack ~= nil then
        FireTrack:Play()
    end

    local Arms = FindFirstChild(Camera, "Arms")

    if Arms ~= nil then
        local Flash = FindFirstChild(Arms, "Flash")

        if Flash ~= nil then
            Particles.CreateMuzzleFlash(Flash)
        end

        local SecondFlash = FindFirstChild(Arms, "2Flash")

        if SecondFlash ~= nil then
            Particles.CreateMuzzleFlash(SecondFlash)
        end
    end

    local ViewGun = State.gun

    if ViewGun then
        local Model = FindFirstChild(ViewGun, "Model")
        local ShootVal = Model and FindFirstChild(Model, "Shoot") or FindFirstChild(ViewGun, "Shoot")

        if ShootVal then
            General.PlayLocalSound(ShootVal)
        end
    end
end

function Ragebot:Stab(Character, ForcedOrigin)
    if not Character then return end

    local Head = FindFirstChild(Character, "HeadHB") or FindFirstChild(Character, "Head") or FindFirstChild(Character, "Hitbox")

    if not Head then return end

    local Gun = State.gun

    if not Gun then return end
    if FindFirstChild(Gun, "Melee") == nil then return end
    if State.DISABLED == true then return end
    if State.equipping == true then return end

    local Range = FindFirstChild(Gun, "Range") and Gun.Range.Value + 1 or 7
    local RealOrigin = CachedOrigin
    local HeadPos = Head.Position

    if (HeadPos - RealOrigin).Magnitude > Range + 1 then
        return
    end

    local Origin = ForcedOrigin or self:GetOrigin(Character, Head)
    local FakeOrigin = Origin
    local Root = Character.PrimaryPart

    if Root then
        FakeOrigin = HeadPos - Root.CFrame.LookVector * 4
    end

    local GunId = Gun:GetAttribute("Id") or 125
    local Spoofed = NewCFrame(FakeOrigin, HeadPos)
    local Cx, Cy, Cz, R00, R01, R02, R10, R11, R12, R20, R21, R22 = Spoofed:GetComponents()
    local Flags = bit32.replace(bit32.replace(bit32.bor(1, State.ads and 2 or 0, State.jumping and 4 or 0), State.currentSpell or 1, 3, 3), 0, 6, 2)
    local DeltaTime = State.btick == 0 and 0 or CachedNow - State.btick

    NetClient.lock()
    NetClient.u16(Events.HitPart)
    NetClient.inst(Head)
    NetClient.u8(GunId)
    NetClient.u8(Flags)
    NetClient.u8(0)
    NetClient.f32(Cx)
    NetClient.f32(Cy)
    NetClient.f32(Cz)
    NetClient.f32(R00)
    NetClient.f32(R01)
    NetClient.f32(R02)
    NetClient.f32(R10)
    NetClient.f32(R11)
    NetClient.f32(R12)
    NetClient.f32(R20)
    NetClient.f32(R21)
    NetClient.f32(R22)
    NetClient.f32(HeadPos.X)
    NetClient.f32(HeadPos.Y)
    NetClient.f32(HeadPos.Z)
    NetClient.f32(DeltaTime)
    NetClient.unlock()

    self:HitFX(Head, Origin, 0)
end

function Ragebot:Knifebot()
    if not Toggles["combat/knifebot"].Value then return end
    if Toggles["combat/ragebot/removeextrachecks"].Value then return end

    local Gun = State.gun
    if not Gun then return end
    if FindFirstChild(Gun, "Melee") == nil then return end

    local RootPart = CachedRootPart
    if not RootPart then return end

    local Range = FindFirstChild(Gun, "Range") and Gun.Range.Value + 1 or 7
    local RootPos = RootPart.Position
    local Parts = GetParts(workspace, RootPos, Range, KnifebotOverlapParams)

    local ShouldMulti = Toggles["combat/ragebot/multitarget"].Value

    for _, Part in Parts do
        local TargetCharacter = Part:FindFirstAncestorOfClass("Model")

        if not TargetCharacter then
            continue
        end

        local Player = Players:GetPlayerFromCharacter(TargetCharacter)

        if not Player or Player == LocalPlayer then
            continue
        end

        if Utility.IsTeammate(LocalPlayer, Player) then
            continue
        end

        local MaxHealth, Health = Utility.GetHealth(Player, TargetCharacter)

        if Health <= 0 then
            continue
        end

        if TargetCharacter:FindFirstChildOfClass("ForceField") then
            continue
        end

        self:Stab(TargetCharacter)

        if not ShouldMulti then
            break
        end
    end
end

function Ragebot:Scan()
    if StatusPreparation.Value then return end
    if not Toggles["combat/ragebot"].Value then return end

    local Gun = State.gun
    if not Gun then return end

    local IsMelee = FindFirstChild(Gun, "Melee") ~= nil
    local FireRateObj = FindFirstChild(Gun, "FireRate")
    local FireRate = FireRateObj and FireRateObj.Value or 0

    if not Toggles["combat/ragebot/removeextrachecks"].Value then
        if IsMelee then return end
        if State.ammocount ~= nil and State.ammocount <= 0 then return end
        if State.DISABLED == true then return end
    end

    local HasPen = not IsMelee and FindFirstChild(Gun, "Penetration") ~= nil
    local ShouldMulti = Toggles["combat/ragebot/multitarget"].Value
    local ShouldRapid = Toggles["combat/ragebot/rapidfire"].Value
    local Now = CachedNow

    self:ComputeOrigin()

    local Sorted = {}

    for _, Player in PlayersCache do
        if Player == LocalPlayer then
            continue
        end

        local Character = Player.Character

        if not Character then
            continue
        end

        if Utility.IsTeammate(LocalPlayer, Player) then
            continue
        end

        local MaxHealth, Health = Utility.GetHealth(Player, Character)

        if not Health or Health <= 0 then
            continue
        end

        if Character:FindFirstChildOfClass("ForceField") then
            continue
        end

        local Head = FindFirstChild(Character, "HeadHB") or FindFirstChild(Character, "Head")

        if not Head then
            continue
        end

        local CheckOrigin = self:GetOrigin(Character, Head)

        if self:IsVisible(Head, CheckOrigin) then
            local HeadPos = Head.Position
            local Dx = HeadPos.X - CheckOrigin.X
            local Dy = HeadPos.Y - CheckOrigin.Y
            local Dz = HeadPos.Z - CheckOrigin.Z

            Insert(Sorted, {
                Character = Character,
                Head = Head,
                HeadPos = HeadPos,
                DistSq = Dx * Dx + Dy * Dy + Dz * Dz,
                Origin = CheckOrigin
            })
        end
    end

    table.sort(Sorted, function(A, B)
        return A.DistSq < B.DistSq
    end)

    for _, Entry in Sorted do
        local Target = Entry.Character

        if not Target then
            continue
        end

        if not ShouldRapid and Now - (self.LastTimeFired or 0) < FireRate then
            continue
        end

        if not ShouldRapid then
            self.LastTimeFired = Now
        end

        if HasPen then
            local HitList = table.clone(CachedHitList)
            local Found = { Entry }

            for Index = 2, #Sorted do
                if #Found >= 3 then
                    break
                end

                local Behind = Sorted[Index]
                local BehindHeadPos = Behind.Head.Position
                local Direction = BehindHeadPos - Entry.Origin

                VisibilityParams.FilterDescendantsInstances = HitList

                local Result = Raycast(workspace, Entry.Origin, Direction, VisibilityParams)

                if Result and Result.Instance:IsDescendantOf(Behind.Character) then
                    Insert(Found, Behind)
                    Insert(HitList, Behind.Character)
                end
            end

            VisibilityParams.FilterDescendantsInstances = CachedHitList

            for Pen, Pierce in Found do
                local PierceHeadPos = Pierce.HeadPos or Pierce.Head.Position

                if IsMelee then
                    self:Stab(Pierce.Character, Pierce.Origin)
                else
                    self:Hit(Pierce.Character, Pen, NewCFrame(Pierce.Origin, PierceHeadPos), Pierce.Origin)
                end
            end

            break
        else
            if IsMelee then
                self:Stab(Target, Entry.Origin)
            else
                self:Hit(Target, nil, nil, Entry.Origin)
            end

            if not ShouldMulti then
                break
            end
        end
    end
end

Library:GiveSignal(LocalPlayer.Damage.Changed:Connect(function()
    if not Toggles["combat/ragebot"].Value then return end
    Ragebot:ReplicateShoot()
    CanHitFXPls = true
end))

Library:GiveSignal(RunService.Stepped:Connect(function()
    Ragebot:UpdateFrameCache()
    Ragebot:Scan()
    Ragebot:Knifebot()
end))

Library:GiveSignal(Players.PlayerAdded:Connect(function(Player)
    Insert(PlayersCache, Player)
end))

Library:GiveSignal(Players.PlayerRemoving:Connect(function(Player)
    local Index = TableFind(PlayersCache, Player)

    if Index then
        RemoveTable(PlayersCache, Index)
    end
end))

return Ragebot