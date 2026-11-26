--!optimize 2

--# Aliases

local FromOffset, FromScale, UDim2New = UDim2.fromOffset, UDim2.fromScale, UDim2.new
local Atan2, Rad, Pi, Abs, Minimum, Maximum, Floor, Clamp = math.atan2, math.rad, math.pi, math.abs, math.min, math.max, math.floor, math.clamp
local NewVector, NewVector3, NewCFrame = vector.create, Vector3.new, CFrame.new
local Create, IsA, QueryDescendants = Instance.new, workspace.IsA, workspace.QueryDescendants
local Spawn, Wait = task.spawn, task.wait
local ForEach, Insert, RemoveTable = table.foreach, table.insert, table.remove
local FindFirstChild, WaitForChild, FindFirstChildOfClass, Raycast  = workspace.FindFirstChild, workspace.WaitForChild, workspace.FindFirstChildOfClass, workspace.Raycast
local WorldToViewportPoint = workspace.CurrentCamera.WorldToViewportPoint
local GetService, IsKeyDown = Game.GetService, cloneref(Game:GetService("UserInputService")).IsKeyDown

--# Services

local MarketplaceService = GetService(Game, "MarketplaceService")
local ReplicatedStorage  = GetService(Game, "ReplicatedStorage")
local RunService         = GetService(Game, "RunService")
local InputService       = GetService(Game, "UserInputService")
local Stats              = GetService(Game, "Stats")
local DataPing           = Stats.Network.ServerStatsItem["Data Ping"]
local FrameRateManager   = Stats:FindFirstChild("FrameRateManager")
local RenderAverage      = FrameRateManager:FindFirstChild("RenderAverage")
local Players            = GetService(Game, "Players")
local StarterPlayer      = GetService(Game, "StarterPlayer")

local LocalPlayer        = Players.LocalPlayer

--# Variables

local Params = RaycastParams.new()
Params.FilterType = Enum.RaycastFilterType.Exclude
Params.IgnoreWater = true
local Toggles, Options = getgenv().Toggles, getgenv().Options
local Camera = workspace.CurrentCamera

local PlayersCache = Players:GetPlayers()
Library:GiveSignal(Players.PlayerAdded:Connect(function()
    PlayersCache = Players:GetPlayers()
end))
Library:GiveSignal(Players.PlayerRemoving:Connect(function()
    PlayersCache = Players:GetPlayers()
end))

local EmptyVec3 = NewVector3()
local EmptyPhysicProp = PhysicalProperties.new(0,0,0,0,0)

local OriginalCollisions = {

}

--# Main

local Misc = {}

Misc.Movement = {} do

    function Misc.Movement.GetNearestWall()

        local Character = LocalPlayer.Character
        if not Character then return end

        local RootPart = Character.PrimaryPart
        if not RootPart then return end

        local Origin = RootPart.Position

        local Directions = {
            -RootPart.CFrame.LookVector,
            RootPart.CFrame.RightVector,
            -RootPart.CFrame.RightVector,
        }

        local NearestResult
        local NearestDistance = math.huge
        
        Params.FilterDescendantsInstances = { Character }

        for _, Direction in Directions do
            local Result = Raycast(workspace, Origin, Direction * 5, Params)

            if Result then
                local Distance = (Result.Position - Origin).Magnitude

                if Distance < NearestDistance then
                    NearestDistance = Distance
                    NearestResult = Result
                end
            end
        end

        if not NearestResult then
            return
        end

        return NearestResult.Position, NearestDistance, NearestResult
    end

    function Misc.Movement.Tick()
        local Character = LocalPlayer.Character
        if not Character then return end

        local Humanoid = FindFirstChildOfClass(Character, "Humanoid")
        if not Humanoid then return end

        local RootPart = Character.PrimaryPart
        if not RootPart then return end

        local MoveDir = Humanoid.MoveDirection

        if Toggles["misc/movement/noclip"].Value and Options["misc/movement/noclip/key"]:GetState() then

            for _, Part in QueryDescendants(Character, "BasePart") do
                if OriginalCollisions[Part] == nil then
                    OriginalCollisions[Part] = Part.CanCollide
                end

                if Part.CanCollide then
                    Part.CanCollide = false
                end
            end

        else
            for Part, CanCollide in OriginalCollisions do
                if Part.Parent then
                    Part.CanCollide = CanCollide
                end

                OriginalCollisions[Part] = nil
            end
        end

        if Toggles["misc/movement/speed"].Value then
            local Speed = Options["misc/movement/speed/value"].Value
            local Method = Options["misc/movement/speed/method"].Value
            local MoveDir = Vector3.zero

            if Method == "MoveDir" then
                MoveDir = Humanoid.MoveDirection
            elseif Method == "Directional" or Method == "CFrame" then
                local CameraCFrame = Camera.CFrame
                local LookVector = CameraCFrame.LookVector
                local RightVector = CameraCFrame.RightVector

                if Method == "Directional" then
                    LookVector = NewVector3(LookVector.X, 0, LookVector.Z)
                    RightVector = NewVector3(RightVector.X, 0, RightVector.Z)
                else
                    LookVector = NewVector3(LookVector.X, 0, LookVector.Z)
                    RightVector = NewVector3(RightVector.X, 0, RightVector.Z)
                end

                if IsKeyDown(InputService, "W") then
                    MoveDir += LookVector
                end

                if IsKeyDown(InputService, "S") then
                    MoveDir -= LookVector
                end

                if IsKeyDown(InputService, "D") then
                    MoveDir += RightVector
                end

                if IsKeyDown(InputService, "A") then
                    MoveDir -= RightVector
                end
            end

            if MoveDir.Magnitude > 0 then
                MoveDir = MoveDir.Unit

                if Method == "CFrame" then
                    local DeltaTime = RunService.Heartbeat:Wait()
                    local CurrentY = RootPart.AssemblyLinearVelocity.Y
                    RootPart.CFrame += MoveDir * Speed * DeltaTime
                    RootPart.AssemblyLinearVelocity = NewVector3(0, CurrentY, 0)
                else
                    local CurrentY = RootPart.AssemblyLinearVelocity.Y
                    RootPart.AssemblyLinearVelocity = MoveDir * Speed + NewVector3(0, CurrentY, 0)
                end
            elseif Toggles["misc/movement/speed/instantstop"].Value and Method ~= "CFrame" then
                local Velocity = RootPart.AssemblyLinearVelocity
                RootPart.AssemblyLinearVelocity = NewVector3(0, Velocity.Y, 0)
            end
        end


        if Toggles["misc/movement/moonwalk"].Value and Options["misc/movement/moonwalk/key"]:GetState() then
            if MoveDir.Magnitude > 0 then

                local NegaMoveDir = -MoveDir

                local CurrentY = RootPart.AssemblyLinearVelocity.Y
                local Horizontal = NewVector3(NegaMoveDir.X, 0, NegaMoveDir.Z).Unit * Humanoid.WalkSpeed

                RootPart.AssemblyLinearVelocity = NewVector3(Horizontal.X, CurrentY, Horizontal.Z )
            end
        end

        if Toggles["misc/movement/autojump"].Value and IsKeyDown(InputService, "Space") then
            local Method = Options["misc/movement/autojump/method"].Value

            if Method == "Humanoid" then
                Humanoid.Jump = true
            elseif Method == "Velocity" then
                if Humanoid.FloorMaterial ~= Enum.Material.Air and Humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
                    local JumpVelocity

                    if StarterPlayer.CharacterUseJumpPower then
                        JumpVelocity = StarterPlayer.CharacterJumpPower
                    else
                        JumpVelocity = math.sqrt(2 * workspace.Gravity * StarterPlayer.CharacterJumpHeight)
                    end

                    local Velocity = RootPart.AssemblyLinearVelocity
                    RootPart.AssemblyLinearVelocity = NewVector3(Velocity.X, JumpVelocity, Velocity.Z)
                end
            elseif Method == "States" then
                if Humanoid.FloorMaterial ~= Enum.Material.Air and Humanoid:GetState() ~= Enum.HumanoidStateType.Jumping then
                    Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                end
            end
        end

        if Toggles["misc/movement/pixelsurf"].Value and Options["misc/movement/pixelsurf/key"]:GetState() then

            local WallPos, Dist, Result = Misc.Movement.GetNearestWall()

            if Result and RootPart then
                local WallNormal = Result.Normal
                local FlatNormal = NewVector3(WallNormal.X, 0, WallNormal.Z)

                if FlatNormal.Magnitude > 0 then
                    FlatNormal = FlatNormal.Unit

                    local Velocity = RootPart.AssemblyLinearVelocity
                    local HorizontalVelocity = NewVector3(Velocity.X, 0, Velocity.Z)

                    local SurfVelocity = HorizontalVelocity - FlatNormal * HorizontalVelocity:Dot(FlatNormal)

                    RootPart.AssemblyLinearVelocity = NewVector3(SurfVelocity.X, 0, SurfVelocity.Z)
                end
            end
        end

        if Toggles["misc/movement/fly"].Value and Options["misc/movement/fly/key"]:GetState() then

            local CameraCFrame = Camera.CFrame
            local MoveDirection = EmptyVec3

            if IsKeyDown(InputService, "W") then
                MoveDirection += CameraCFrame.LookVector
            end

            if IsKeyDown(InputService, "S") then
                MoveDirection -= CameraCFrame.LookVector
            end

            if IsKeyDown(InputService, "D") then
                MoveDirection += CameraCFrame.RightVector
            end

            if IsKeyDown(InputService, "A") then
                MoveDirection -= CameraCFrame.RightVector
            end

            if IsKeyDown(InputService, "Space") then
                MoveDirection += NewVector3(0, 1, 0)
            end

            if IsKeyDown(InputService, "LeftControl") then
                MoveDirection -= NewVector3(0, 1, 0)
            end

            local FlySpeed = Options["misc/movement/flyspeed/value"].Value

            if not IsFlying then
                IsFlying = true
                Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
            end

            if MoveDirection.Magnitude > 0 then
                RootPart.AssemblyLinearVelocity = MoveDirection.Unit * FlySpeed
            else
                RootPart.AssemblyLinearVelocity = EmptyVec3
            end

        elseif IsFlying then
            IsFlying = false
            RootPart.AssemblyLinearVelocity = EmptyVec3
            Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
        end

    end
end

Misc.Exploits = {  } do
    function Misc.Exploits.Tick()
        if Toggles["misc/exploits/antifling"].Value then
            for _, Player in PlayersCache do
                if Player == LocalPlayer then continue end
                local Character = Player.Character
                if Character then
                    for _, Part in QueryDescendants(Character, "BasePart") do
                        Part.CustomPhysicalProperties = EmptyPhysicProp
                        Part.Velocity = EmptyVec3
                        Part.RotVelocity = EmptyVec3
                        Part.CanCollide = false
                    end
                end
            end
        end
    end
end

function Misc.Tick(Delta)
    Misc.Movement.Tick(Delta)
    Misc.Exploits.Tick(Delta)
end

return Misc