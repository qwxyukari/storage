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

--# Main

local function StartsWithBytes(Data: string, Bytes: {number}): boolean
	if #Data < #Bytes then
		return false
	end

	for Index, ExpectedByte in ipairs(Bytes) do
		if string.byte(Data, Index) ~= ExpectedByte then
			return false
		end
	end

	return true
end

local function ReadUInt16BE(Data: string, Position: number): number
	local A, B = string.byte(Data, Position, Position + 1)
	return A * 256 + B
end

local function ReadUInt16LE(Data: string, Position: number): number
	local A, B = string.byte(Data, Position, Position + 1)
	return A + B * 256
end

local function ReadUInt32LE(Data: string, Position: number): number
	local A, B, C, D = string.byte(Data, Position, Position + 3)

	return A
		+ B * 256
		+ C * 65536
		+ D * 16777216
end

local function ReadUInt24LE(Data: string, Position: number): number
	local A, B, C = string.byte(Data, Position, Position + 2)

	return A
		+ B * 256
		+ C * 65536
end

local function IsPng(Data: string): boolean
	return string.sub(Data, 1, 8) == "\137PNG\r\n\26\n"
end

local function IsJpeg(Data: string): boolean
	local A, B = string.byte(Data, 1, 2)
	return A == 0xFF and B == 0xD8
end

local function IsGif(Data: string): boolean
	local Header = string.sub(Data, 1, 6)
	return Header == "GIF87a" or Header == "GIF89a"
end

local function IsBmp(Data: string): boolean
	return string.sub(Data, 1, 2) == "BM"
end

local function IsWebp(Data: string): boolean
	return string.sub(Data, 1, 4) == "RIFF"
		and string.sub(Data, 9, 12) == "WEBP"
end

local function GetJpegResolution(Data: string)
	local Position = 3
	local DataLength = #Data

	while Position <= DataLength do
		while Position <= DataLength and string.byte(Data, Position) ~= 0xFF do
			Position += 1
		end

		while Position <= DataLength and string.byte(Data, Position) == 0xFF do
			Position += 1
		end

		if Position > DataLength then
			break
		end

		local Marker = string.byte(Data, Position)
		Position += 1

		if Marker == 0xD9 or Marker == 0xDA then
			break
		end

		if Marker ~= 0x01 and not (Marker >= 0xD0 and Marker <= 0xD7) then
			if Position + 1 > DataLength then
				break
			end

			local SegmentLength = ReadUInt16BE(Data, Position)

			local IsStartOfFrame =
				(Marker >= 0xC0 and Marker <= 0xC3)
				or (Marker >= 0xC5 and Marker <= 0xC7)
				or (Marker >= 0xC9 and Marker <= 0xCB)
				or (Marker >= 0xCD and Marker <= 0xCF)

			if IsStartOfFrame then
				local Height = ReadUInt16BE(Data, Position + 3)
				local Width = ReadUInt16BE(Data, Position + 5)

				return Width, Height
			end

			Position += SegmentLength
		end
	end

	return nil, nil
end

local Utility = {}

Utility.EasingStyle = {
    Linear = function(t)
        return t
    end,

    Sine = function(t)
        return 1 - math.cos(t * math.pi * 0.5)
    end,

    Quad = function(t)
        return t * t
    end,

    Cubic = function(t)
        return t * t * t
    end,

    Quart = function(t)
        return t * t * t * t
    end,

    Quint = function(t)
        return t * t * t * t * t
    end,

    Exponential = function(t)
        return t == 0 and 0 or 2 ^ (10 * (t - 1))
    end,

    Circular = function(t)
        return 1 - math.sqrt(1 - t * t)
    end,

    SmoothStep = function(t)
        return t * t * (3 - 2 * t)
    end,

    SmootherStep = function(t)
        return t * t * t * (t * (t * 6 - 15) + 10)
    end,

    Back = function(t)
        local s = 1.70158
        return t * t * ((s + 1) * t - s)
    end,

    Elastic = function(t)
        if t == 0 or t == 1 then
            return t
        end

        local c4 = (2 * math.pi) / 3
        return -(2 ^ (10 * t - 10))
            * math.sin((t * 10 - 10.75) * c4)
    end,

    Bounce = function(t)
        local n1 = 7.5625
        local d1 = 2.75

        if t < 1 / d1 then
            return n1 * t * t
        elseif t < 2 / d1 then
            t = t - 1.5 / d1
            return n1 * t * t + 0.75
        elseif t < 2.5 / d1 then
            t = t - 2.25 / d1
            return n1 * t * t + 0.9375
        else
            t = t - 2.625 / d1
            return n1 * t * t + 0.984375
        end
    end,
}

Utility.EasingStylesKey = {
    "Sine",
    "Quad",
    "Cubic",
    "Quart",
    "Quint",
    "Exponential",
    "Circular",
    "Linear",
    "SmoothStep",
    "SmootherStep",
    "Back",
    "Elastic",
    "Bounce",
}

Utility.EasingDirection = {
    In = function(EasingFunction, t)
        return EasingFunction(t)
    end,

    Out = function(EasingFunction, t)
        return 1 - EasingFunction(1 - t)
    end,

    InOut = function(EasingFunction, t)
        if t < 0.5 then
            return EasingFunction(t * 2) * 0.5
        end
        return 1 - EasingFunction((1 - t) * 2) * 0.5
    end,
}

Utility.EasingDirectionsKey = {
    "In",
    "Out",
    "InOut",
}

function Utility.GetCharacter(Player)
    if moehack.data.game_name == "Operation One" then
        if not StateObject then
            StateObject = require(ReplicatedStorage.Modules.StateObject)
        end
        if not Player.Character then return nil end
        local Data = StateObject.get("Character", Player.Character)
        if not Data then return end
        if not Data.values or not Data.values.viewmodels then return end
        return Data.values.viewmodels
    end
    return Player.Character
end

function Utility.IsTeammate(Player1, Player2)
    local Team1, Team2

    if moehack.data.game_name == "Blox Strike" then
        Team1 = Player1:GetAttribute("Team")
        Team2 = Player2:GetAttribute("Team")
    else
        Team1 = Player1.Team
        Team2 = Player2.Team
    end

	if moehack.data.game_name == "Arsenal" then
		if not Wkspc then
			Wkspc = ReplicatedStorage:FindFirstChild("wkspc")
		end
		if Wkspc and FindFirstChild(Wkspc, "FFA") and Wkspc.FFA.Value == true then
			return false
		end
	end

    if Team1 == nil or Team2 == nil then
        return false
    end

	if Team1 == "" or Team2 == "" then return false end


    return Team1 == Team2
end

function Utility.GetHealth(Player, Character)

    if moehack.data.game_name == "Blox Strike" then
        return Character:GetAttribute("MaxHealth"), Character:GetAttribute("Health")
    end

	if moehack.data.game_name == "Arsenal" then
		return Player.NRPBS.MaxHealth.Value, Player.NRPBS.Health.Value
	end

    local MaxHealth, Health = 0, 0
    local Humanoid = FindFirstChildOfClass(Character, "Humanoid")
    if Humanoid then
        MaxHealth = Humanoid.MaxHealth
        Health = Humanoid.Health
    end

    return MaxHealth, Health
end

function Utility.Create(Obj, Prop)
	local Object = Create(Obj)
	for Index, Value in Prop do
		Object[Index] = Value
	end
	return Object
end

function Utility:Hook(Func, Callback)
	if setstackhidden  then
		setstackhidden(Callback, true)
	end
	return hookfunction(Func, Callback)
end

function Utility.GetTool(Player, Character)

    if moehack.data.game_name == "Operation One" then
        if not StateObject then
            StateObject = require(ReplicatedStorage.Modules.StateObject)
        end
        if not Player.Character then return nil end
        local Data = StateObject.get("Character", Player.Character)
        return Data.values.equipped and Data.values.equipped.Name or "NONE"
    end

	if moehack.data.game_name == "Arsenal" then
		return Player.NRPBS.EquippedTool.Value
	end

    local Tool = FindFirstChildOfClass(Character, "Tool")
    if Tool then return Tool.Name end
    return "none"
end

function Utility.GetImageResolution(Data: string)
	if IsPng(Data) then
		return {
			Width = ReadUInt32LE(string.sub(Data, 17, 20):reverse(), 1),
			Height = ReadUInt32LE(string.sub(Data, 21, 24):reverse(), 1),
		}
	end

	if IsGif(Data) then
		return {
			Width = ReadUInt16LE(Data, 7),
			Height = ReadUInt16LE(Data, 9),
		}
	end

	if IsBmp(Data) then
		return {
			Width = ReadUInt32LE(Data, 19),
			Height = ReadUInt32LE(Data, 23),
		}
	end

	if IsJpeg(Data) then
		local Width, Height = GetJpegResolution(Data)

		if Width and Height then
			return {
				Width = Width,
				Height = Height,
			}
		end
	end

	if IsWebp(Data) and string.sub(Data, 13, 16) == "VP8X" then
		local Width = ReadUInt24LE(Data, 25) + 1
		local Height = ReadUInt24LE(Data, 28) + 1

		return {
			Width = Width,
			Height = Height,
		}
	end

	return nil
end


function Utility.DetectFileType(Data: string)
	if StartsWithBytes(Data, {
		0x89, 0x50, 0x4E, 0x47,
		0x0D, 0x0A, 0x1A, 0x0A,
	}) then
		return {
			Extension = "png",
			Mime = "image/png",
		}
	end

	if StartsWithBytes(Data, { 0xFF, 0xD8, 0xFF }) then
		return {
			Extension = "jpg",
			Mime = "image/jpeg",
		}
	end

	local Header = string.sub(Data, 1, 6)

	if Header == "GIF87a" or Header == "GIF89a" then
		return {
			Extension = "gif",
			Mime = "image/gif",
		}
	end

	if string.sub(Data, 1, 4) == "RIFF"
		and string.sub(Data, 9, 12) == "WEBP" then
		return {
			Extension = "webp",
			Mime = "image/webp",
		}
	end

	if string.sub(Data, 1, 2) == "BM" then
		return {
			Extension = "bmp",
			Mime = "image/bmp",
		}
	end

	if string.sub(Data, 1, 4) == "%PDF" then
		return {
			Extension = "pdf",
			Mime = "application/pdf",
		}
	end

	if StartsWithBytes(Data, { 0x50, 0x4B, 0x03, 0x04 }) then
		return {
			Extension = "zip",
			Mime = "application/zip",
		}
	end

	return {
		Extension = nil,
		Mime = "application/octet-stream",
	}
end


function Utility.GetHumanoid(Entity) -- for ESP only
    if Entity.Humanoid and Entity.Humanoid.Parent then
        return Entity.Humanoid
    end

    local Character = Entity.IsCustom and Entity.Target or (Entity.Player and Entity.Player.Character)
    if not Character then
        return nil
    end

    local Humanoid = FindFirstChildOfClass(Character, "Humanoid")
    Entity.Humanoid = Humanoid

    return Humanoid
end

return Utility