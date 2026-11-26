--!native
--!optimize 2

--# Aliases

local FromOffset, FromScale, UDim2New = UDim2.fromOffset, UDim2.fromScale, UDim2.new
local Atan2, Rad, Pi, Abs, Minimum, Maximum, Floor, Clamp = math.atan2, math.rad, math.pi, math.abs, math.min, math.max, math.floor, math.clamp
local NewVector, NewVector3, NewCFrame = vector.create, Vector3.new, CFrame.new
local Create = Instance.new
local Spawn, Wait = task.spawn, task.wait
local Insert, RemoveTable, Clear = table.insert, table.remove, table.clear
local GetService = Game.GetService

--# Services

local MarketplaceService = GetService(Game, "MarketplaceService")
local ReplicatedStorage = GetService(Game, "ReplicatedStorage")
local RunService = GetService(Game, "RunService")
local Lighting = GetService(Game, "Lighting")
local Players = GetService(Game, "Players")
local TweenService = GetService(Game, "TweenService")
local LocalPlayer = Players.LocalPlayer

local FadeInfo = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--# Modules

local Fonts = moehack.load_module("globals/fonts.luau", true)
local Utility = moehack.load_module("moehack.net/modules/utility.luau", true)
local CustomFontRenderer = moehack.load_module("globals/custom_font_renderer.luau", true)

--# Variables

local Library = getgenv().Library
local Toggles, Options = getgenv().Toggles, getgenv().Options

local ScreenGui = Create("ScreenGui")
ScreenGui.Parent = gethui()
ScreenGui.ResetOnSpawn = true
ScreenGui.IgnoreGuiInset = true
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local CurrentCamera = workspace.CurrentCamera
local ChamsPartBuffer = table.create(32)
local ChamsCFrameBuffer = table.create(32)
local EnumFireCFChange = Enum.BulkMoveMode.FireCFrameChanged

local Corners = {
    {1, 1, 1},
    {-1, 1, 1},
    {1, 1, -1},
    {-1, 1, -1},
    {1, -1, 1},
    {-1, -1, 1},
    {1, -1, -1},
    {-1, -1, -1}
}

local CornerBoxes = {
    {"TopLeft", 0},
    {"TopRight", 90},
    {"BottomLeft", -90},
    {"BottomRight", 180}
}

local StrokeNames = {
    "BoundingBoxStroke",
    "BoundingBoxInline",
    "HealthBarOutline",
    "HealthTextStroke",
    "NameStroke",
    "DistStroke",
    "ToolStroke"
}

local LastHz = 0
local PlayersCache = {}

for _, Player in Players:GetPlayers() do
    PlayersCache[Player] = Player
end

if moehack.data.game_name == "Operation One" then
    StateObject = require(ReplicatedStorage.Modules.StateObject)
end

local ESP = {
    Entities = {}
}

Library:GiveSignal(Players.PlayerAdded:Connect(function(Player)
    PlayersCache[Player] = Player
end))

Library:GiveSignal(Players.PlayerRemoving:Connect(function(Player)
    PlayersCache[Player] = nil

    local Entity = ESP.Entities[Player]

    if Entity then
        ESP.RemoveTarget(Entity)
    end
end))

--# Main

local Viewport = Create("ViewportFrame")
Viewport.Parent = ScreenGui
Viewport.Size = UDim2New(1, 0, 1, 0)
Viewport.BackgroundTransparency = 1
Viewport.CurrentCamera = CurrentCamera
Viewport.BorderSizePixel = 0
Viewport.BackgroundColor3 = Color3.fromRGB(-5000, -5000, -5000)

function ESP.CreateElements(Entity: table)
    local Objects = {}

    Objects.Holder = Create("Frame")
    Objects.Holder.Parent = ScreenGui
    Objects.Holder.BackgroundTransparency = 1

    Objects.BoundingBox = Create("CanvasGroup")
    Objects.BoundingBox.Parent = Objects.Holder
    Objects.BoundingBox.Size = FromScale(1, 1)
    Objects.BoundingBox.BackgroundTransparency = 1
    Objects.BoundingBox.GroupTransparency = 0

    Objects.BoundingBoxStroke = Create("UIStroke")
    Objects.BoundingBoxStroke.LineJoinMode = Enum.LineJoinMode.Miter
    Objects.BoundingBoxStroke.Thickness = 3
    Objects.BoundingBoxStroke.Parent = Objects.BoundingBox

    Objects.BoundingBoxInline = Create("UIStroke")
    Objects.BoundingBoxInline.LineJoinMode = Enum.LineJoinMode.Miter
    Objects.BoundingBoxInline.BorderOffset = UDim.new(0, 1)
    Objects.BoundingBoxInline.Color = Options["esp/box/color"].Value
    Objects.BoundingBoxInline.Thickness = 1
    Objects.BoundingBoxInline.ZIndex = 2
    Objects.BoundingBoxInline.Parent = Objects.BoundingBox

    Objects.BoundingBoxFill = Create("Frame")
    Objects.BoundingBoxFill.Parent = Objects.BoundingBox
    Objects.BoundingBoxFill.Size = FromScale(1, 1)
    Objects.BoundingBoxFill.BackgroundColor3 = Options["esp/box/fillcolor"].Value
    Objects.BoundingBoxFill.BackgroundTransparency = Options["esp/box/fillcolor"].Transparency
    Objects.BoundingBoxFill.BorderSizePixel = 0
    Objects.BoundingBoxFill.ZIndex = 1

    Objects.CornerBox = Create("CanvasGroup")
    Objects.CornerBox.BackgroundTransparency = 1
    Objects.CornerBox.Size = UDim2New(1, 6, 1, 6)
    Objects.CornerBox.Position = UDim2New(0, -3, 0, -3)
    Objects.CornerBox.BorderSizePixel = 0
    Objects.CornerBox.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Objects.CornerBox.Visible = false
    Objects.CornerBox.Parent = Objects.Holder

    for _, Corner in CornerBoxes do
        local Name, Rotation = Corner[1], Corner[2]
        local IsBottom = Name:find("Bottom") ~= nil
        local IsRight = Name:find("Right") ~= nil

        local CornerPart = Create("Frame")
        CornerPart.Name = Name
        CornerPart.Rotation = Rotation
        CornerPart.BackgroundTransparency = 1
        CornerPart.BorderColor3 = Color3.fromRGB(0, 0, 0)
        CornerPart.BorderSizePixel = 0
        CornerPart.Size = UDim2New(0, 10, 0, 10)
        CornerPart.AnchorPoint = Vector2.new(IsRight and 1 or 0, IsBottom and 1 or 0)
        CornerPart.Position = UDim2New(IsRight and 1 or 0, IsRight and -1 or 1, IsBottom and 1 or 0, IsBottom and -1 or 1)
        CornerPart.Parent = Objects.CornerBox
        Objects[Name] = CornerPart

        local InlineHorizontal = Create("Frame")
        InlineHorizontal.Name = "InlineHorizontal"
        InlineHorizontal.Size = UDim2New(1, 0, 0, 1)
        InlineHorizontal.BorderSizePixel = 0
        InlineHorizontal.BackgroundColor3 = Options["esp/box/color"].Value
        InlineHorizontal.ZIndex = 2
        InlineHorizontal.Parent = CornerPart
        Objects[Name .. "InlineHorizontal"] = InlineHorizontal

        local InlineVertical = Create("Frame")
        InlineVertical.Name = "InlineVertical"
        InlineVertical.Size = UDim2New(0, 1, 1, 0)
        InlineVertical.BorderSizePixel = 0
        InlineVertical.BackgroundColor3 = Options["esp/box/color"].Value
        InlineVertical.ZIndex = 5
        InlineVertical.Parent = CornerPart
        Objects[Name .. "InlineVertical"] = InlineVertical

        local OutlineHorizontal = Create("Frame")
        OutlineHorizontal.Name = "OutlineHorizontal"
        OutlineHorizontal.Position = UDim2New(0, 0, 0, -1)
        OutlineHorizontal.Size = UDim2New(1, 1, 0, 3)
        OutlineHorizontal.BorderSizePixel = 0
        OutlineHorizontal.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        OutlineHorizontal.Parent = CornerPart
        Objects[Name .. "OutlineHorizontal"] = OutlineHorizontal

        local OutlineVertical = Create("Frame")
        OutlineVertical.Name = "OutlineVertical"
        OutlineVertical.Position = UDim2New(0, -1, 0, -1)
        OutlineVertical.Size = UDim2New(0, 3, 1, 2)
        OutlineVertical.BorderSizePixel = 0
        OutlineVertical.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
        OutlineVertical.Parent = CornerPart
        Objects[Name .. "OutlineVertical"] = OutlineVertical
    end

    Objects.GlowHolder = Create("CanvasGroup")
    Objects.GlowHolder.Parent = Objects.Holder
    Objects.GlowHolder.Size = UDim2New(1, 47, 1, 47)
    Objects.GlowHolder.BackgroundTransparency = 1
    Objects.GlowHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    Objects.GlowHolder.Position = UDim2New(0.5, -1, 0.5, -1)

    Objects.BoundingBoxGlow = Utility.Create("ImageLabel", {
        Parent = Objects.GlowHolder,
        ImageColor3 = Options["esp/box/glowcolor"].Value,
        ScaleType = Enum.ScaleType.Slice,
        BorderColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        Image = getcustomasset("glow.png"),
        BackgroundTransparency = 1,
        ImageTransparency = Options["esp/box/glowcolor"].Transparency,
        Size = UDim2New(1, 0, 1, 0),
        ZIndex = -10,
        BorderSizePixel = 0,
        SliceCenter = Rect.new(Vector2.new(21, 21), Vector2.new(79, 79))
    })

    Objects.HealthBar = Create("CanvasGroup")
    Objects.HealthBar.Parent = Objects.Holder
    Objects.HealthBar.Size = UDim2New(0, Options["esp/healthbar/thickness"].Value, 1, 4)
    Objects.HealthBar.Position = UDim2New(0, -5 - Options["esp/healthbar/thickness"].Value, 0, -2)
    Objects.HealthBar.BackgroundTransparency = 1
    Objects.HealthBar.BorderSizePixel = 0

    Objects.HealthBarOutline = Create("UIStroke")
    Objects.HealthBarOutline.LineJoinMode = Enum.LineJoinMode.Miter
    Objects.HealthBarOutline.Thickness = 1
    Objects.HealthBarOutline.ZIndex = 4
    Objects.HealthBarOutline.Color = Color3.fromRGB(0, 0, 0)
    Objects.HealthBarOutline.Parent = Objects.HealthBar

    Objects.HealthBarBackground = Create("Frame")
    Objects.HealthBarBackground.Parent = Objects.HealthBar
    Objects.HealthBarBackground.Size = FromScale(1, 1)
    Objects.HealthBarBackground.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Objects.HealthBarBackground.BorderSizePixel = 0
    Objects.HealthBarBackground.ZIndex = 1

    Objects.HealthBarCover = Create("Frame")
    Objects.HealthBarCover.Parent = Objects.HealthBar
    Objects.HealthBarCover.Size = UDim2New(1, 0, 0, 0)
    Objects.HealthBarCover.BorderSizePixel = 0
    Objects.HealthBarCover.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    Objects.HealthBarCover.ZIndex = 3

    Objects.HealthBarFill = Create("Frame")
    Objects.HealthBarFill.Parent = Objects.HealthBar
    Objects.HealthBarFill.Size = UDim2New(1, 0, 1, 0)
    Objects.HealthBarFill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Objects.HealthBarFill.BorderSizePixel = 0
    Objects.HealthBarFill.ZIndex = 2

    Objects.HealthBarGradient = Create("UIGradient")
    Objects.HealthBarGradient.Parent = Objects.HealthBarFill
    Objects.HealthBarGradient.Rotation = 90
    Objects.HealthBarGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Options["esp/healthbar/colora"].Value),
        ColorSequenceKeypoint.new(1, Options["esp/healthbar/colorb"].Value)
    })

    Objects.HealthTextHolder = Create("CanvasGroup")
    Objects.HealthTextHolder.Parent = Objects.Holder
    Objects.HealthTextHolder.Size = FromOffset(11, 10)
    Objects.HealthTextHolder.BackgroundTransparency = 1
    Objects.HealthTextHolder.AnchorPoint = Vector2.new(0, 0.5)

    Objects.HealthText = Create("TextLabel")
    Objects.HealthText.Parent = Objects.HealthTextHolder
    Objects.HealthText.Size = FromOffset(9, 9)
    Objects.HealthText.BackgroundTransparency = 1
    Objects.HealthText.Position = FromOffset(1, 0)
    Objects.HealthText.Text = "100"
    Objects.HealthText.TextXAlignment = Enum.TextXAlignment.Center
    Objects.HealthText.FontFace = Fonts.SmallestPixel7
    Objects.HealthText.TextColor3 = Options["esp/healthtext/color"].Value
    Objects.HealthText.TextSize = 9
    Objects.HealthText.ZIndex = 5

    Objects.HealthTextStroke = Create("UIStroke")
    Objects.HealthTextStroke.Parent = Objects.HealthText
    Objects.HealthTextStroke.LineJoinMode = Enum.LineJoinMode.Miter
    Objects.HealthTextStroke.Thickness = 1
    Objects.HealthTextStroke.Color = Color3.new(0, 0, 0)

    Objects.NameHolder = Create("CanvasGroup")
    Objects.NameHolder.Parent = Objects.Holder
    Objects.NameHolder.BackgroundTransparency = 1
    Objects.NameHolder.Size = FromOffset(500, 15)
    Objects.NameHolder.AnchorPoint = Vector2.new(0.5, 1)
    Objects.NameHolder.Position = UDim2New(0.5, 0, 0, -2)
    Objects.NameHolder.Visible = false
    Objects.NameHolder.ZIndex = 6

    Objects.Name = Create("TextLabel")
    Objects.Name.Parent = Objects.NameHolder
    Objects.Name.Size = FromScale(1, 1)
    Objects.Name.BackgroundTransparency = 1
    Objects.Name.Text = "Player"
    Objects.Name.TextColor3 = Options["esp/name/color"].Value
    Objects.Name.TextSize = 12
    Objects.Name.Visible = false
    Objects.Name.TextXAlignment = Enum.TextXAlignment.Center
    Objects.Name.TextYAlignment = Enum.TextYAlignment.Center
    Objects.Name.FontFace = Fonts.Tahoma
    Objects.Name.ZIndex = 6

    Objects.RealName = CustomFontRenderer.CreateText(
        Objects.NameHolder,
        Entity.Player and Entity.Player.Name or Entity.Name,
        {
            Font = "HudDefault",
            Size = 12,
            Color = Options["esp/name/color"].Value,
            AnchorPoint = Vector2.new(0.5, 0.5),
            XScalePos = 0.5,
            YScalePos = 0.5,
            Shadow = true,
            Y = 0,
            ShadowColor = Color3.fromRGB(0, 0, 0),
            ShadowX = 1,
            ShadowY = 1,
            ZIndex = 10
        }
    )

    Objects.NameStroke = Create("UIStroke")
    Objects.NameStroke.Parent = Objects.Name
    Objects.NameStroke.LineJoinMode = Enum.LineJoinMode.Miter
    Objects.NameStroke.Thickness = 1
    Objects.NameStroke.Color = Color3.new(0, 0, 0)

    Objects.Bottom = Create("CanvasGroup")
    Objects.Bottom.Size = UDim2New(0, 500, 0, 500)
    Objects.Bottom.BackgroundTransparency = 1
    Objects.Bottom.Parent = Objects.Holder
    Objects.Bottom.AnchorPoint = Vector2.new(0.5, 0)
    Objects.Bottom.Position = UDim2New(0.5, 0, 1, 0)

    local Padding = Create("UIPadding")
    Padding.PaddingTop = UDim.new(0, 2)
    Padding.Parent = Objects.Bottom

    local Layout = Create("UIListLayout")
    Layout.SortOrder = Enum.SortOrder.LayoutOrder
    Layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    Layout.Padding = UDim.new(0, -1)
    Layout.Parent = Objects.Bottom

    Objects.Distance = Create("TextLabel")
    Objects.Distance.Parent = Objects.Bottom
    Objects.Distance.Size = FromOffset(9, 9)
    Objects.Distance.BackgroundTransparency = 1
    Objects.Distance.Position = FromOffset(1, 0)
    Objects.Distance.Text = "100st"
    Objects.Distance.TextXAlignment = Enum.TextXAlignment.Center
    Objects.Distance.FontFace = Fonts.SmallestPixel7
    Objects.Distance.TextColor3 = Options["esp/distance/color"].Value
    Objects.Distance.TextSize = 9
    Objects.Distance.ZIndex = 5

    Objects.DistStroke = Create("UIStroke")
    Objects.DistStroke.Parent = Objects.Distance
    Objects.DistStroke.LineJoinMode = Enum.LineJoinMode.Miter
    Objects.DistStroke.Thickness = 1
    Objects.DistStroke.Color = Color3.new(0, 0, 0)

    Objects.Tool = Create("TextLabel")
    Objects.Tool.Parent = Objects.Bottom
    Objects.Tool.Size = FromOffset(9, 9)
    Objects.Tool.BackgroundTransparency = 1
    Objects.Tool.Position = FromOffset(1, 0)
    Objects.Tool.Text = "none"
    Objects.Tool.TextXAlignment = Enum.TextXAlignment.Center
    Objects.Tool.FontFace = Fonts.SmallestPixel7
    Objects.Tool.TextColor3 = Options["esp/tool/color"].Value
    Objects.Tool.TextSize = 9
    Objects.Tool.ZIndex = 5

    Objects.ToolStroke = Create("UIStroke")
    Objects.ToolStroke.Parent = Objects.Tool
    Objects.ToolStroke.LineJoinMode = Enum.LineJoinMode.Miter
    Objects.ToolStroke.Thickness = 1
    Objects.ToolStroke.Color = Color3.new(0, 0, 0)

    Objects.FadeGroups = {
        Objects.BoundingBox,
        Objects.CornerBox,
        Objects.GlowHolder,
        Objects.HealthBar,
        Objects.HealthTextHolder,
        Objects.NameHolder,
        Objects.Bottom
    }

    Objects.FadeValue = Create("NumberValue")
    Objects.FadeValue.Value = 1

    for _, Group in Objects.FadeGroups do
        Group.GroupTransparency = 1
    end

    for _, Name in StrokeNames do
        Objects[Name].Transparency = 1
    end

    Objects.FadeValue.Changed:Connect(function(Value)
        Entity.ChamsFade = Value

        for _, Group in Objects.FadeGroups do
            if Group.Parent then
                Group.GroupTransparency = Value
            end
        end

        for _, Name in StrokeNames do
            local Stroke = Objects[Name]

            if Stroke and Stroke.Parent then
                Stroke.Transparency = Value
            end
        end

        local Base = Options["esp/chams/color"].Transparency

        for _, ChamsPart in Entity.ChamsParts do
            if ChamsPart.Parent then
                ChamsPart.Transparency = Base + (1 - Base) * Value
            end
        end
    end)

    return Objects
end

local function DisconnectTarget(Entity)
    for _, Connection in Entity.TargetConnections do
        Connection:Disconnect()
    end

    Clear(Entity.TargetConnections)
end

local function HasBodyPart(Entity, Part)
    for _, ExistingPart in Entity.BodyParts do
        if ExistingPart == Part then
            return true
        end
    end

    return false
end

local function AddBodyPart(Entity, Part)
    if not Part:IsA("BasePart") or HasBodyPart(Entity, Part) then
        return
    end

    Insert(Entity.BodyParts, Part)
end

local function RemoveBodyPart(Entity, Part)
    for Index = #Entity.BodyParts, 1, -1 do
        if Entity.BodyParts[Index] == Part then
            RemoveTable(Entity.BodyParts, Index)
            break
        end
    end

    local ChamsPart = Entity.ChamsParts[Part]

    if ChamsPart then
        ChamsPart:Destroy()
        Entity.ChamsParts[Part] = nil
    end
end

local function ResolveHumanoid(Target)
    if not Target then
        return nil
    end

    if Target:IsA("Humanoid") then
        return Target
    end

    return Target:FindFirstChildWhichIsA("Humanoid", true)
end

local function GetTargetRoot(Target, BodyParts)
    if not Target then
        return nil
    end

    if Target:IsA("BasePart") then
        return Target
    end

    if Target:IsA("Model") then
        local PrimaryPart = Target.PrimaryPart

        if PrimaryPart and PrimaryPart.Parent then
            return PrimaryPart
        end

        local RootPart = Target:FindFirstChild("HumanoidRootPart")

        if RootPart and RootPart:IsA("BasePart") then
            return RootPart
        end
    end

    for _, Part in BodyParts do
        if Part.Parent then
            return Part
        end
    end

    return nil
end

local function PopulateBodyParts(Entity, Target)
    Clear(Entity.BodyParts)

    if Target:IsA("BasePart") then
        AddBodyPart(Entity, Target)
        return
    end

    for _, Object in Target:GetDescendants() do
        if Object:IsA("BasePart") then
            AddBodyPart(Entity, Object)
        end
    end
end

local function ConnectTarget(Target, Entity)
    DisconnectTarget(Entity)
    Clear(Entity.BodyParts)

    Entity.Target = Target

    if not Target or not Target.Parent then
        Entity.Humanoid = nil
        return false
    end

    PopulateBodyParts(Entity, Target)

    if not Entity.Humanoid or not Entity.Humanoid.Parent or not Entity.Humanoid:IsDescendantOf(Target) then
        Entity.Humanoid = ResolveHumanoid(Target)
    end

    if Target:IsA("BasePart") then
        Insert(Entity.TargetConnections, Target.AncestryChanged:Connect(function(_, Parent)
            if not Parent then
                ESP.RemoveTarget(Entity)
            end
        end))

        return true
    end

    Insert(Entity.TargetConnections, Target.DescendantAdded:Connect(function(Object)
        if Object:IsA("BasePart") then
            AddBodyPart(Entity, Object)
            return
        end

        if Object:IsA("Humanoid") and not Entity.Humanoid then
            Entity.Humanoid = Object
        end
    end))

    Insert(Entity.TargetConnections, Target.DescendantRemoving:Connect(function(Object)
        if Object:IsA("BasePart") then
            RemoveBodyPart(Entity, Object)
            return
        end

        if Object == Entity.Humanoid then
            Entity.Humanoid = ResolveHumanoid(Target)
        end
    end))

    Insert(Entity.TargetConnections, Target.AncestryChanged:Connect(function(_, Parent)
        if not Parent then
            ESP.RemoveTarget(Entity)
        end
    end))

    return true
end

local function ConnectCharacter(Player, Entity)
    local Character = Utility.GetCharacter(Player)

    if not Character then
        DisconnectTarget(Entity)

        Entity.Target = nil
        Entity.Humanoid = nil

        Clear(Entity.BodyParts)

        ESP.ChamsRemove(Entity)

        return
    end

    Entity.Humanoid = nil
    ConnectTarget(Character, Entity)
end

function ESP.AddTarget(Target, Settings)
    Settings = Settings or {}

    if not Target or not Target:IsA("Instance") then
        return nil
    end

    local Humanoid = Settings.Humanoid

    if Target:IsA("Humanoid") then
        Humanoid = Target
        Target = Target.Parent

        if not Target then
            return nil
        end
    end

    if not Target:IsDescendantOf(workspace) then
        return nil
    end

    local Existing = ESP.Entities[Target]

    if Existing then
        ESP.RemoveTarget(Existing)
    end

    local Entity = {
        Target = nil,
        Player = Settings.Player,
        Name = Settings.Name or Target.Name,
        Humanoid = Humanoid,
        BodyParts = {},
        TargetConnections = {},
        ChamsModel = nil,
        ChamsParts = {},
        ChamsFade = 1,
        IsCustom = true,
        LastPosition = nil,
        LastRect = nil,
        Shown = false,
        FadeTween = nil
    }

    Entity.Objects = ESP.CreateElements(Entity)
    ESP.Entities[Target] = Entity

    if not ConnectTarget(Target, Entity) then
        ESP.Entities[Target] = nil

        if Entity.Objects.FadeValue then
            Entity.Objects.FadeValue:Destroy()
        end

        if Entity.Objects.Holder then
            Entity.Objects.Holder:Destroy()
        end

        return nil
    end

    return Entity
end

function ESP.RemoveTarget(TargetOrEntity)
    local Entity = ESP.Entities[TargetOrEntity] or TargetOrEntity

    if not Entity then
        return
    end

    for Key, Value in ESP.Entities do
        if Value == Entity then
            ESP.Entities[Key] = nil
            break
        end
    end

    DisconnectTarget(Entity)

    if Entity.FadeTween then
        Entity.FadeTween:Cancel()
        Entity.FadeTween = nil
    end

    if Entity.ChamsModel then
        Entity.ChamsModel:Destroy()
        Entity.ChamsModel = nil
    end

    Clear(Entity.ChamsParts)
    Clear(Entity.BodyParts)

    if Entity.Objects then
        if Entity.Objects.FadeValue then
            Entity.Objects.FadeValue:Destroy()
        end

        if Entity.Objects.Holder then
            Entity.Objects.Holder:Destroy()
        end
    end

    Entity.Target = nil
    Entity.Humanoid = nil
end

function ESP.ApplyAllPlayer()
    if moehack.data.game_name == "Operation One" then
        return
    end

    for _, Player in PlayersCache do
        if Player == LocalPlayer or ESP.Entities[Player] then
            continue
        end

        local Entity = {
            Player = Player,
            Humanoid = nil,
            ChamsModel = nil,
            ChamsParts = {},
            BodyParts = {},
            TargetConnections = {},
            ChamsFade = 1,
            IsCustom = false,
            LastRect = nil,
            LastPosition = nil,
            Shown = false,
            FadeTween = nil
        }

        Entity.Objects = ESP.CreateElements(Entity)
        ESP.Entities[Player] = Entity

        if Player.Character then
            ConnectCharacter(Player, Entity)
        end

        Library:GiveSignal(Player.CharacterAdded:Connect(function()
            if ESP.Entities[Player] ~= Entity then
                return
            end

            ConnectCharacter(Player, Entity)
        end))

        Library:GiveSignal(Player.CharacterRemoving:Connect(function()
            if ESP.Entities[Player] ~= Entity then
                return
            end

            DisconnectTarget(Entity)

            Entity.Target = nil
            Entity.Humanoid = nil

            Clear(Entity.BodyParts)

            ESP.ChamsRemove(Entity)
        end))
    end
end

--# Bounding Box

function ESP.GetBoundingBox(Model: {}, Character)
    local LowestX, HighestX = 1e6, -1e6
    local LowestY, HighestY = 1e6, -1e6
    local OnScreen = false

    if Toggles["esp/settings/custombound"].Value then
        local Root

        if Character and Character:IsA("BasePart") then
            Root = Character
        elseif Character and Character:IsA("Model") then
            Root = Character.PrimaryPart

            if not Root then
                local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")

                if HumanoidRootPart and HumanoidRootPart:IsA("BasePart") then
                    Root = HumanoidRootPart
                end
            end
        end

        if not Root then
            for _, Part in Model do
                if Part.Parent then
                    Root = Part
                    break
                end
            end
        end

        if Root and Root.Parent then
            local Width = Options["esp/settings/custombound/width"].Value
            local Height = Options["esp/settings/custombound/height"].Value
            local OffsetX = Options["esp/settings/custombound/offsetx"].Value
            local OffsetY = Options["esp/settings/custombound/offsety"].Value

            local HalfSize = NewVector3(Width, Height, Width) * 0.5
            local RootCFrame = Root.CFrame * NewCFrame(OffsetX, OffsetY, 0)

            for _, Signs in Corners do
                local ScreenPoint, Visible = CurrentCamera:WorldToViewportPoint(
                    RootCFrame * NewVector3(
                        HalfSize.X * Signs[1],
                        HalfSize.Y * Signs[2],
                        HalfSize.Z * Signs[3]
                    )
                )

                OnScreen = OnScreen or Visible

                LowestX = Minimum(LowestX, ScreenPoint.X)
                HighestX = Maximum(HighestX, ScreenPoint.X)
                LowestY = Minimum(LowestY, ScreenPoint.Y)
                HighestY = Maximum(HighestY, ScreenPoint.Y)
            end

            return LowestX, HighestX, LowestY, HighestY, OnScreen
        end
    end

    for _, Part in Model do
        if Part.Parent and Part.Transparency < 0.99 then
            local PartCFrame = Part.CFrame
            local HalfSize = Part.Size * 0.5

            for _, Signs in Corners do
                local ScreenPoint, Visible = CurrentCamera:WorldToViewportPoint(
                    PartCFrame * NewVector3(
                        HalfSize.X * Signs[1],
                        HalfSize.Y * Signs[2],
                        HalfSize.Z * Signs[3]
                    )
                )

                OnScreen = OnScreen or Visible

                LowestX = Minimum(LowestX, ScreenPoint.X)
                HighestX = Maximum(HighestX, ScreenPoint.X)
                LowestY = Minimum(LowestY, ScreenPoint.Y)
                HighestY = Maximum(HighestY, ScreenPoint.Y)
            end
        end
    end

    return LowestX, HighestX, LowestY, HighestY, OnScreen
end

--# Animations

function ESP.RenderLastPosition(Entity: {})
    local Position = Entity.LastPosition
    local Rect = Entity.LastRect

    if not Position or not Rect then
        Entity.Objects.Holder.Visible = false
        return false
    end

    local ScreenPoint, Visible = CurrentCamera:WorldToViewportPoint(Position)

    if not Visible or ScreenPoint.Z <= 0 then
        Entity.Objects.Holder.Visible = false
        return false
    end

    local Scale = Rect.Depth / ScreenPoint.Z

    Entity.Objects.Holder.Position = FromOffset(
        ScreenPoint.X + Rect.OffsetX * Scale,
        ScreenPoint.Y + Rect.OffsetY * Scale
    )

    Entity.Objects.Holder.Size = FromOffset(
        Rect.Width * Scale,
        Rect.Height * Scale
    )

    return true
end

local function TweenFade(Entity: {}, Target: number)
    if Entity.FadeTween then
        Entity.FadeTween:Cancel()
    end

    local Tween = TweenService:Create(
        Entity.Objects.FadeValue,
        FadeInfo,
        {Value = Target}
    )

    Entity.FadeTween = Tween

    Tween.Completed:Connect(function(State)
        if State ~= Enum.PlaybackState.Completed or Entity.Shown then
            return
        end

        local Holder = Entity.Objects.Holder

        if Holder and Holder.Parent then
            Holder.Visible = false
        end
    end)

    Tween:Play()
end

function ESP.FadeIn(Entity: {}, DeltaTime: number)
    Entity.Objects.Holder.Visible = true

    if Entity.Shown then
        return
    end

    Entity.Shown = true

    TweenFade(Entity, 0)
end

function ESP.FadeOut(Entity: {}, DeltaTime: number)
    if Entity.Shown then
        Entity.Shown = false
        TweenFade(Entity, 1)
    end

    if Entity.Objects.FadeValue.Value < 1 then
        if ESP.RenderLastPosition(Entity) then
            Entity.Objects.Holder.Visible = true
        end
    else
        Entity.Objects.Holder.Visible = false
    end
end

--# Chams

function ESP.ChamsRemove(Entity: {})
    if Entity.ChamsModel then
        Entity.ChamsModel:Destroy()
        Entity.ChamsModel = nil
    end

    Clear(Entity.ChamsParts)
end

function ESP.ChamsRender(Entity: {})
    if not Toggles["esp/chams"].Value then
        ESP.ChamsRemove(Entity)
        Viewport.Visible = false
        return
    end

    Viewport.Visible = true

    local Model = Entity.ChamsModel

    if not Model then
        Model = Create("Model")
        Model.Name = "\0"
        Model.Parent = Viewport

        Entity.ChamsModel = Model
        Entity.ChamsParts = {}

        Create("Humanoid", Model)
    end

    local ChamsParts = Entity.ChamsParts

    Clear(ChamsPartBuffer)
    Clear(ChamsCFrameBuffer)

    local Count = 0
    local Material = Enum.Material[Options["esp/chams/material"].Value]
    local Picker = Options["esp/chams/color"]
    local Color = Picker.Value

    for _, Value in Entity.BodyParts do
        if not Value.Parent then
            continue
        end

        local Part = ChamsParts[Value]

        if not Part then
            if Value.Transparency >= 1 then
                continue
            end

            Part = Value:Clone()

            if Part:IsA("MeshPart") then
                Part.TextureID = ""
            end

            for _, Object in Part:GetDescendants() do
                if Object:IsA("Decal")
                    or Object:IsA("Texture")
                    or Object:IsA("SurfaceAppearance") then
                    Object:Destroy()
                elseif Object:IsA("SpecialMesh") then
                    Object.TextureId = ""
                end
            end

            Part.Parent = Model
            ChamsParts[Value] = Part
        end

        local TargetCFrame = Value.CFrame

        if Part.CFrame ~= TargetCFrame then
            Count += 1
            ChamsPartBuffer[Count] = Part
            ChamsCFrameBuffer[Count] = TargetCFrame
        end
    end

    if Count > 0 then
        workspace:BulkMoveTo(
            ChamsPartBuffer,
            ChamsCFrameBuffer,
            EnumFireCFChange
        )
    end

    for RealPart, ChamsPart in ChamsParts do
        if not RealPart.Parent then
            ChamsPart:Destroy()
            ChamsParts[RealPart] = nil
            continue
        end

        if ChamsPart.Color ~= Color then
            ChamsPart.Color = Color
        end

        if ChamsPart.Material ~= Material then
            ChamsPart.Material = Material
        end

        local Transparency =
            Picker.Transparency
            + (1 - Picker.Transparency) * (Entity.ChamsFade or 0)

        if ChamsPart.Transparency ~= Transparency
            and RealPart.Transparency < 1 then
            ChamsPart.Transparency = Transparency
        end
    end

    if Viewport.BackgroundColor3 ~= Color then
        Viewport.BackgroundColor3 = Color
    end
end

--# Render

function ESP.Render(Entity: {}, DeltaTime: number)
    local Player = Entity.Player
    local Objects = Entity.Objects

    local RealCharacter
    local Character

    if Entity.IsCustom then
        RealCharacter = Entity.Target
        Character = Entity.Target
    else
        RealCharacter = Player and Player.Character
        Character = Player and Utility.GetCharacter(Player)
    end

    if Entity.IsCustom then
        if not RealCharacter or not RealCharacter.Parent then
            ESP.RemoveTarget(Entity)
            return
        end
    elseif not RealCharacter then
        ESP.FadeOut(Entity, DeltaTime)
        return
    end

    local Humanoid = Entity.Humanoid

    if not Humanoid and not Entity.IsCustom then
        Humanoid = Utility.GetHumanoid(Entity)
        Entity.Humanoid = Humanoid
    end

    local MaxHealth = 100
    local Health = 100

    if Humanoid and Entity.IsCustom then
        MaxHealth = Humanoid.MaxHealth
        Health = Humanoid.Health
    elseif Player then
        MaxHealth, Health = Utility.GetHealth(Player, RealCharacter)
    end

    local IsTeammate = Player and Utility.IsTeammate(Player, LocalPlayer) or false

    if Humanoid and moehack.data.game_name == "Blox Strike" then
        ESP.ChamsRemove(Entity)
        ESP.FadeOut(Entity, DeltaTime)
        return
    end

    if IsTeammate and not Toggles["esp/settings/renderteam"].Value then
        ESP.FadeOut(Entity, DeltaTime)
        return
    end

    if Health <= 0 then
        ESP.FadeOut(Entity, DeltaTime)
        return
    end

    local LowX, HighX, LowY, HighY, OnScreen = ESP.GetBoundingBox(Entity.BodyParts, Character)

    if not OnScreen or LowX == 1e6 or HighX == -1e6 then
        Objects.Holder.Visible = false
        return
    end

    local TargetRoot

    if Entity.IsCustom then
        TargetRoot = GetTargetRoot(RealCharacter, Entity.BodyParts)
    elseif RealCharacter:IsA("BasePart") then
        TargetRoot = RealCharacter
    elseif RealCharacter:IsA("Model") then
        TargetRoot = RealCharacter.PrimaryPart or RealCharacter:FindFirstChild("HumanoidRootPart")
    end

    if not TargetRoot and Character and Character:IsA("Model") then
        TargetRoot = Character.PrimaryPart or Character:FindFirstChild("HumanoidRootPart")
    end

    if not TargetRoot then
        TargetRoot = GetTargetRoot(RealCharacter, Entity.BodyParts)
    end

    local Distance = TargetRoot and (CurrentCamera.CFrame.Position - TargetRoot.Position).Magnitude or 0

    if TargetRoot then
        local RootPosition = TargetRoot.Position
        local RootPoint = CurrentCamera:WorldToViewportPoint(RootPosition)

        Entity.LastPosition = RootPosition
        Entity.LastRect = {
            OffsetX = LowX - RootPoint.X,
            OffsetY = LowY - RootPoint.Y,
            Width = HighX - LowX,
            Height = HighY - LowY,
            Depth = Maximum(RootPoint.Z, 0.001)
        }
    end

    if Distance > Options["esp/settings/renderdist"].Value then
        ESP.ChamsRemove(Entity)
        ESP.FadeOut(Entity, DeltaTime)
        return
    end

    --# Box

    if Toggles["esp/box"].Value then
        local BoxType = Options["esp/box/type"].Value
        local BoxColor = Options["esp/box/color"].Value

        if BoxType == "Corner" then
            Objects.BoundingBox.Visible = false
            Objects.CornerBox.Visible = true

            local CornerSize = Clamp(160 / Maximum(Distance, 1), 3.25, 10)
            local CornerUDim = UDim2New(0, CornerSize, 0, CornerSize)

            Objects.TopLeft.Size = CornerUDim
            Objects.TopRight.Size = CornerUDim
            Objects.BottomLeft.Size = CornerUDim
            Objects.BottomRight.Size = CornerUDim
        else
            Objects.CornerBox.Visible = false
            Objects.BoundingBox.Visible = true
        end

        if Objects.BoundingBoxInline.Color ~= BoxColor then
            Objects.BoundingBoxInline.Color = BoxColor

            Objects.TopLeftInlineHorizontal.BackgroundColor3 = BoxColor
            Objects.TopLeftInlineVertical.BackgroundColor3 = BoxColor
            Objects.TopRightInlineHorizontal.BackgroundColor3 = BoxColor
            Objects.TopRightInlineVertical.BackgroundColor3 = BoxColor
            Objects.BottomLeftInlineHorizontal.BackgroundColor3 = BoxColor
            Objects.BottomLeftInlineVertical.BackgroundColor3 = BoxColor
            Objects.BottomRightInlineHorizontal.BackgroundColor3 = BoxColor
            Objects.BottomRightInlineVertical.BackgroundColor3 = BoxColor
        end

        local GlowEnabled = Toggles["esp/box/glow"].Value

        if Objects.GlowHolder.Visible ~= GlowEnabled then
            Objects.GlowHolder.Visible = GlowEnabled
        end

        local GlowColor = Options["esp/box/glowcolor"].Value

        if Objects.BoundingBoxGlow.ImageColor3 ~= GlowColor then
            Objects.BoundingBoxGlow.ImageColor3 = GlowColor
        end

        local GlowTransparency = Options["esp/box/glowcolor"].Transparency

        if Objects.BoundingBoxGlow.ImageTransparency ~= GlowTransparency then
            Objects.BoundingBoxGlow.ImageTransparency = GlowTransparency
        end

        if Toggles["esp/box/fill"].Value then
            Objects.BoundingBoxFill.Visible = true

            local FillColor = Options["esp/box/fillcolor"].Value
            local FillTransparency = Options["esp/box/fillcolor"].Transparency

            if Objects.BoundingBoxFill.BackgroundColor3 ~= FillColor then
                Objects.BoundingBoxFill.BackgroundColor3 = FillColor
            end

            if Objects.BoundingBoxFill.BackgroundTransparency ~= FillTransparency then
                Objects.BoundingBoxFill.BackgroundTransparency = FillTransparency
            end
        else
            Objects.BoundingBoxFill.Visible = false
        end
    else
        Objects.BoundingBox.Visible = false
        Objects.CornerBox.Visible = false
        Objects.GlowHolder.Visible = false
    end

    --# Name

    if Toggles["esp/name"].Value then
        Objects.NameHolder.Visible = true

        local Name = Player and Player.DisplayName or Entity.Name

        if Name == "" then
            Name = Entity.Name
        end

        if Objects.Name.Text ~= Name then
            Objects.Name.Text = Name
        end

        local NameColor = Options["esp/name/color"].Value

        if Objects.Name.TextColor3 ~= NameColor then
            Objects.Name.TextColor3 = NameColor
            Objects.RealName:SetColor(NameColor)
        end
    else
        Objects.NameHolder.Visible = false
    end

    --# Tool

    if Toggles["esp/tool"].Value then
        Objects.Tool.Visible = true

        local ToolName = Player and Utility.GetTool(Player, RealCharacter) or "none"

        if Objects.Tool.Text ~= ToolName then
            Objects.Tool.Text = ToolName
        end

        local ToolColor = Options["esp/tool/color"].Value

        if Objects.Tool.TextColor3 ~= ToolColor then
            Objects.Tool.TextColor3 = ToolColor
        end
    else
        Objects.Tool.Visible = false
    end

    --# Health

    if Toggles["esp/healthbar"].Value and (not Entity.IsCustom or Humanoid) then
        Objects.HealthBar.Visible = true

        local HealthPercent = MaxHealth > 0 and Clamp(Health / MaxHealth, 0, 1) or 1
        local HealthBarThickness = Options["esp/healthbar/thickness"].Value

        if Objects.HealthBar.Size.X.Offset ~= HealthBarThickness then
            Objects.HealthBar.Size = UDim2New(0, HealthBarThickness, 1, 4)
            Objects.HealthBar.Position = UDim2New(0, -5 - HealthBarThickness, 0, -2)
        end

        Objects.HealthBarCover.Size = UDim2New(1, 0, 1 - HealthPercent, 0)

        if Toggles["esp/healthtext"].Value then
            local HealthText = tostring(Floor(Health))
            local HealthColor = Options["esp/healthtext/color"].Value

            if Health == MaxHealth then
                Objects.HealthTextHolder.Visible = false
            else
                Objects.HealthTextHolder.Visible = true
                Objects.HealthTextHolder.Position = UDim2New(0, -10 - HealthBarThickness, 0, (HighY - LowY) * (1 - HealthPercent))
            end

            if Objects.HealthText.Text ~= HealthText then
                Objects.HealthText.Text = HealthText
            end

            if Objects.HealthText.TextColor3 ~= HealthColor then
                Objects.HealthText.TextColor3 = HealthColor
            end
        else
            Objects.HealthTextHolder.Visible = false
        end

        local ColorA = Options["esp/healthbar/colora"].Value
        local ColorB = Options["esp/healthbar/colorb"].Value
        local Keypoints = Objects.HealthBarGradient.Color.Keypoints

        if Keypoints[1].Value ~= ColorA or Keypoints[2].Value ~= ColorB then
            Objects.HealthBarGradient.Color = ColorSequence.new({
                ColorSequenceKeypoint.new(0, ColorA),
                ColorSequenceKeypoint.new(1, ColorB)
            })
        end
    else
        Objects.HealthBar.Visible = false
        Objects.HealthTextHolder.Visible = false
    end

    --# Distance

    if Toggles["esp/distance"].Value then
        Objects.Distance.Visible = true

        local DistanceText = tostring(Floor(Distance)) .. "st"
        local DistanceColor = Options["esp/distance/color"].Value

        if Objects.Distance.Text ~= DistanceText then
            Objects.Distance.Text = DistanceText
        end

        if Objects.Distance.TextColor3 ~= DistanceColor then
            Objects.Distance.TextColor3 = DistanceColor
        end
    else
        Objects.Distance.Visible = false
    end

    --# Chams

    ESP.ChamsRender(Entity)

    Objects.Holder.Position = FromOffset(LowX, LowY)
    Objects.Holder.Size = FromOffset(HighX - LowX, HighY - LowY)

    ESP.FadeIn(Entity, DeltaTime)
end

--# Update

function ESP.Update(DeltaTime)
    if not Toggles["esp/enabled"].Value then
        LastHz = 0

        if ScreenGui.Enabled then
            for _, Entity in ESP.Entities do
                if Entity.FadeTween then
                    Entity.FadeTween:Cancel()
                    Entity.FadeTween = nil
                end

                Entity.Shown = false
                Entity.Objects.FadeValue.Value = 1

                ESP.ChamsRemove(Entity)

                Entity.Objects.Holder.Visible = false
            end

            Viewport.Visible = false
            ScreenGui.Enabled = false
        end

        return
    end

    ScreenGui.Enabled = true

    ESP.ApplyAllPlayer()

    local Hertz = Maximum(1, Options["esp/settings/renderhz"].Value)
    local Interval = 1 / Hertz

    LastHz += DeltaTime

    if LastHz < Interval then
        return
    end

    LastHz -= Interval

    for _, Entity in ESP.Entities do
        ESP.Render(Entity, DeltaTime)
    end
end

return ESP