--!native
--!optimize 2

--# Aliases

local Spawn = task.spawn
local FromOffset, FromScale, UDim2New = UDim2.fromOffset, UDim2.fromScale, UDim2.new
local Create, IsA = Instance.new, workspace.IsA
local GetService = game.GetService

--# Services

local RunService = GetService(Game, "RunService")

--# Helper


--# Modules

local Fonts = moehack.load_module("globals/fonts.luau")

--# Main

local Intro = {
    Messages = {
        { Text = "This cheat is not suitable for children or those that are easily beatable", Weight = 80 },
        -- { Text = "This cheat is not suitable for children that are easily breedable?", Weight = 50 },
        { Text = "Moehack is a yuri.love revival", Weight = 15 },
        { Text = "Fuck you", Weight = 50 },
    }
}

function Intro.GetRandomMessages()
    local TotalWeight = 0

    for _, Message in Intro.Messages do
        TotalWeight += Message.Weight
    end
    
    local Roll = math.random() * TotalWeight

    for _, Message in Intro.Messages do
        Roll -= Message.Weight

        if Roll <= 0 then
            return Message.Text
        end
    end
end

function Intro.Create()
    -- Интро полностью отключено
    return {
        FadeIn  = function() end,
        FadeOut = function() end,
    }
end

    function MyFuckingIntro:FadeOut(Duration)
        Duration = Duration or 0.5

        local Start = os.clock()

        Spawn(function()
            while true do
                local Alpha = math.clamp((os.clock() - Start) / Duration, 0, 1)

                Background.BackgroundTransparency = Alpha
                WarningText.TextTransparency = Alpha
                Sound.Volume = 1 - Alpha

                if Alpha >= 1 then
                    Sound:Stop()
                    ScreenGui:Destroy()
                    break
                end

                RunService.RenderStepped:Wait()
            end
        end)
    end

    return MyFuckingIntro
end

return Intro