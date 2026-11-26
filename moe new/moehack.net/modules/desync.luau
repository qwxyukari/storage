--!native
--!optimize 2

--# Aliases

local FromOffset, FromScale, UDim2New = UDim2.fromOffset, UDim2.fromScale, UDim2.new
local Atan2, Rad, Pi, Abs, Minimum, Maximum, Floor, Clamp = math.atan2, math.rad, math.pi, math.abs, math.min, math.max, math.floor, math.clamp
local NewVector, NewVector3, NewCFrame = vector.create, Vector3.new, CFrame.new
local Create, IsA = Instance.new, workspace.IsA
local Spawn, Wait = task.spawn, task.wait
local ForEach, Insert, RemoveTable = table.foreach, table.insert, table.remove
local FindFirstChild, WaitForChild, FindFirstChildOfClass = workspace.FindFirstChild, workspace.WaitForChild, workspace.FindFirstChildOfClass
local WorldToViewportPoint = workspace.CurrentCamera.WorldToViewportPoint
local GetService = Game.GetService

--# Services

local MarketplaceService = GetService(Game, "MarketplaceService")
local ReplicatedStorage  = GetService(Game, "ReplicatedStorage")
local RunService         = GetService(Game, "RunService")
local Stats              = GetService(Game, "Stats")
local DataPing           = Stats.Network.ServerStatsItem["Data Ping"]
local Players            = GetService(Game, "Players")

local LocalPlayer        = Players.LocalPlayer

--# Helper Funcs


--# Variables

local LastPositionCFrame = NewCFrame()
local TargetCFrame = NewCFrame()

local PosThingly = Rad(0.0005)
local FlipWhen = false

--# Modules

local Utility = moehack.load_module("moehack.net/modules/utility.luau")
local Handler = moehack.load_module("globals/desync_handler.luau")

--# Main

local Desync = {}

function Desync.Tick(DeltaTime)
    local Character = Utility.GetCharacter(LocalPlayer)
    
    if Toggles["misc/desync"].Value then
        if not Handler.IsDesyncing then
            Handler.Activate()

            if Character then
                LastPositionCFrame = Character.PrimaryPart.CFrame
            end

            TargetCFrame = Handler.Real.CFrame
        end

        local EasingStyle = Options["misc/desync/easingstyle"].Value
        local EasingDirection = Options["misc/desync/easingdirection"].Value
        local EasingStyleFunction = Utility.EasingStyle[EasingStyle]
        local EasingDirectionFunction = Utility.EasingDirection[EasingDirection]
        local CurrentCFrame = Character.PrimaryPart.CFrame

        if Toggles["misc/desync/freezepos"].Value and Options["misc/desync/freezepos/key"]:GetState() then
            CurrentCFrame = LastPositionCFrame
        end

        if Toggles["misc/desync/randompos"].Value and Options["misc/desync/randompos/key"]:GetState() then
            local X, Y, Z = Options["misc/desync/randompos/x"].Value, Options["misc/desync/randompos/y"].Value, Options["misc/desync/randompos/z"].Value

            CurrentCFrame *= NewCFrame(
                math.random() * (X * 2) - X,
                math.random() * (Y * 2) - Y,
                math.random() * (Z * 2) - Z
            )
        end

        if Toggles["misc/desync/offset"].Value then
            local X = Options["misc/desync/offset/x"].Value
            local Y = Options["misc/desync/offset/y"].Value
            local Z = Options["misc/desync/offset/z"].Value
            local Speed = Options["misc/desync/offset/speed"].Value
            local Animation = Options["misc/desync/offset/animation"].Value

            local Time = os.clock() * Speed
            local OffsetX, OffsetY, OffsetZ = X, Y, Z

            if Animation == "Sine" then
                OffsetX = math.sin(Time) * X
                OffsetY = math.sin(Time * 1.17) * Y
                OffsetZ = math.sin(Time * 0.83) * Z

            elseif Animation == "Cosine" then
                OffsetX = math.cos(Time) * X
                OffsetY = math.cos(Time * 1.17) * Y
                OffsetZ = math.cos(Time * 0.83) * Z

            elseif Animation == "Triangle" then
                local Function = function(Value)
                    return 2 * math.abs(2 * (Value - math.floor(Value + 0.5))) - 1
                end

                OffsetX = Function(Time / (2 * Pi)) * X
                OffsetY = Function(Time / (2 * Pi) + 0.17) * Y
                OffsetZ = Function(Time / (2 * Pi) + 0.33) * Z

            elseif Animation == "Square" then
                local Function = function(Value)
                    return math.sin(Value) >= 0 and 1 or -1
                end

                OffsetX = Function(Time) * X
                OffsetY = Function(Time * 1.17) * Y
                OffsetZ = Function(Time * 0.83) * Z

            elseif Animation == "Sawtooth" then
                local Function = function(Value)
                    return (Value % (2 * Pi)) / Pi - 1
                end

                OffsetX = Function(Time) * X
                OffsetY = Function(Time * 1.17) * Y
                OffsetZ = Function(Time * 0.83) * Z

            elseif Animation == "SmoothStep" then
                local Function = function(Value)
                    local Alpha = (math.sin(Value) + 1) * 0.5
                    return Alpha * Alpha * (3 - 2 * Alpha) * 2 - 1
                end

                OffsetX = Function(Time) * X
                OffsetY = Function(Time * 1.17) * Y
                OffsetZ = Function(Time * 0.83) * Z

            elseif Animation == "Circle" then
                OffsetX = math.cos(Time) * X
                OffsetY = math.sin(Time) * Y
                OffsetZ = math.cos(Time) * Z

            elseif Animation == "Figure8" then
                OffsetX = math.sin(Time) * X
                OffsetY = math.sin(Time * 2) * Y
                OffsetZ = math.cos(Time) * Z

            elseif Animation == "Spiral" then
                local Radius = (math.sin(Time) + 1) * 0.5

                OffsetX = math.cos(Time) * X * Radius
                OffsetY = math.sin(Time * 2) * Y * Radius
                OffsetZ = math.sin(Time) * Z * Radius
            end

            CurrentCFrame *= NewCFrame(
                OffsetX,
                OffsetY,
                OffsetZ
            )
        end

        if Toggles["misc/desync/jitter"].Value then
            local X = Options["misc/desync/jitter/x"].Value
            local Y = Options["misc/desync/jitter/y"].Value
            local Z = Options["misc/desync/jitter/z"].Value
            local Speed = Options["misc/desync/jitter/speed"].Value

            local Time = os.clock() * Speed

            CurrentCFrame *= NewCFrame(
                math.sin(Time) * X,
                math.sin(Time * 1.17) * Y,
                math.sin(Time * 0.83) * Z
            )
        end

        if Toggles["misc/desync/rotation"].Value then
            local Pitch = Options["misc/desync/rotation/x"].Value
            local Yaw = Options["misc/desync/rotation/y"].Value
            local Roll = Options["misc/desync/rotation/z"].Value
            local Speed = Options["misc/desync/rotation/speed"].Value
            local Animation = Options["misc/desync/rotation/animation"].Value
            local Time = os.clock() * Speed

            local Multiplier = 1

            if Animation == "Sine" then
                Multiplier = math.sin(Time)

            elseif Animation == "Cosine" then
                Multiplier = math.cos(Time)

            elseif Animation == "Triangle" then
                Multiplier = 2 * math.abs(2 * ((Time / (2 * Pi)) - math.floor((Time / (2 * Pi)) + 0.5))) - 1

            elseif Animation == "Square" then
                Multiplier = math.sin(Time) >= 0 and 1 or -1

            elseif Animation == "Sawtooth" then
                Multiplier = ((Time % (2 * Pi)) / Pi) - 1

            elseif Animation == "SmoothStep" then
                local Alpha = (math.sin(Time) + 1) * 0.5
                Multiplier = Alpha * Alpha * (3 - 2 * Alpha) * 2 - 1

            elseif Animation == "None" then
                Multiplier = 1
            end

            CurrentCFrame *= CFrame.Angles(
                Rad(Pitch) * Multiplier,
                Rad(Yaw) * Multiplier,
                Rad(Roll) * Multiplier
            )
        end

        if EasingStyleFunction and EasingDirectionFunction and Toggles["misc/desync/useeasingstyle"].Value then
            local Speed = Options["misc/desync/speed"].Value
            local Alpha = Clamp(DeltaTime * Speed, 0, 1)

            Alpha = EasingDirectionFunction(EasingStyleFunction, Alpha)

            TargetCFrame = TargetCFrame:Lerp(CurrentCFrame, Alpha)
            CurrentCFrame = TargetCFrame
        else
            TargetCFrame = CurrentCFrame
        end

        Handler.ChangePosition(CurrentCFrame)
        FlipWhen = not FlipWhen

        Character.PrimaryPart.CFrame *= CFrame.new(0, FlipWhen and PosThingly or -PosThingly, 0)
        return
    end

    if Handler.IsDesyncing then
        Handler.Deactivate()
    end

end

return Desync