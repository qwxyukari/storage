--!native
--!optimize 2

local GetService: (string) -> any = clonefunction(game.GetService)

local EmptyVector3 = Vector3.new()
local EmptyCFrame = CFrame.new()

local RunService = cloneref(GetService(game, "RunService"))
local InputService = cloneref(GetService(game, "UserInputService"))
local Players = cloneref(GetService(game, "Players"))
local CurrentCamera = cloneref(workspace.CurrentCamera)

local Client = { -- this is us ;w; looks unnecessary but i dont wanna do a thousand checks..
    Player = Players.LocalPlayer;
    Character = nil; -- metatable will be controlling this!
    Root = nil; -- same goes for the rootpart
    RootPos = EmptyVector3;
}

setmetatable(Client, {
    __index = function(Self, Index)
        local LocalPlayer = Self.Player
        local Character = LocalPlayer.Character

        if Index == "Character" then
            return Character or "doesn't exist"

        elseif Index == "Root" then
            return Character and Character.PrimaryPart or "doesn't exist"

        elseif Index == "RootPos" then
            return Character and Character.PrimaryPart.CFrame.Position or EmptyVector3
        elseif Index == "Humanoid" then
            return Character and Character:FindFirstChildOfClass("Humanoid")
        end
    end;
})

local Desync = {
    IsDesyncing = false;

    Fake = {
        CFrame = EmptyCFrame;
        Velocity = EmptyVector3;
        RotVelocity = EmptyVector3;
    };

    Real = {
        CFrame = EmptyCFrame;
        Velocity = EmptyVector3;
        RotVelocity = EmptyVector3;
    };

    LastPos = CFrame.new();
} do
    Desync.__index = Desync

    Desync.Activate = function()
        Desync.IsDesyncing = true

        Desync.Fake.CFrame = Client.Root.CFrame
        Desync.Fake.Velocity = Client.Root.Velocity
        Desync.Fake.RotVelocity = Client.Root.RotVelocity

        Desync.Real.CFrame = Client.Root.CFrame
        Desync.Real.Velocity = Client.Root.Velocity
        Desync.Real.RotVelocity = Client.Root.RotVelocity

        Desync.LastPos = Client.Root.CFrame
    end

    Desync.Deactivate = function()
        Desync.IsDesyncing = false
    end

    Desync.ChangePosition = function(Position: CFrame)
        local Root = Client.Root

        if Root == "doesn't exist" then
            return
        end

        Desync.Fake.CFrame = Position
        Desync.Fake.Velocity = Vector3.zero
        Desync.Fake.RotVelocity = Vector3.zero
    end

    RunService:BindToRenderStep(
        "ImGoingToDesyncNow",
        Enum.RenderPriority.First.Value,
        function()

            if Toggles and Toggles["misc/desync"] and not Toggles["misc/desync"].Value then return end

            local Root = Client.Root

            if Root == "doesn't exist" then
                return
            end

            Root.CFrame = Desync.Real.CFrame or Root.CFrame
            Root.Velocity = Desync.Real.Velocity or Root.Velocity
            Root.RotVelocity = Desync.Real.RotVelocity or Root.RotVelocity
        end
    )

    RunService.Heartbeat:Connect(function()
        local Root = Client.Root
        local Humanoid = Client.Humanoid

        if Toggles and Toggles["misc/desync"] and not Toggles["misc/desync"].Value then return end

        if Root == "doesn't exist" then
            return
        end

        Desync.Real.CFrame = Root.CFrame
        Desync.Real.Velocity = Root.Velocity
        Desync.Real.RotVelocity = Root.RotVelocity

        if Desync.IsDesyncing == true then
            sethiddenproperty(Root, "NetworkIsSleeping", false)

            Root.CFrame = Desync.Fake.CFrame
            Root.Velocity = Desync.Fake.Velocity
            Root.RotVelocity = Desync.Fake.RotVelocity

            sethiddenproperty(Root, "NetworkIsSleeping", true)
        end
    end)
end

return Desync