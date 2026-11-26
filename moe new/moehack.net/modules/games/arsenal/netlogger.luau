-- ai lord

local Logger = {}
Logger.__index = Logger

function Logger.New()
	local Self = setmetatable({}, Logger)
	Self.Enabled = true
	Self.LogOutgoing = true
	Self.LogIncoming = true
	Self.MaxLogs = 300
	Self.Ignore = {
		ControlCharacterLook = true,
		ControlCharacterTurn = true,
		UpdatePing = true,
	}
	Self.Only = nil
	Self.ShowRaw = false
	Self.ShowHex = false
	Self.ShowStack = false
	Self.MaxString = 120
	Self.CollapseRepeats = true
	Self.CollapseWindow = 0.5
	Self.ShooterTags = true
	Self.CopyFriendly = true
	Self.Logs = {}
	Self.Census = {}
	Self.Subscriptions = { Outgoing = {}, Incoming = {} }
	Self.Connections = {}
	Self.Originals = {}
	Self.IncomingHooks = {}
	Self.WritersInstalled = false
	Self.Frames = {}
	Self.AutoCapture = nil
	Self.AutoGeneration = 0
	Self.Depth = 0
	Self.SessionId = game.JobId
	return Self
end

local Generation = 1

local TracerEvents = {
	HitPart = true,
	TrailBounce = true,
	MuzzleParticleBounce = true,
	BulletHoleBounce = true,
	ImpactParticleBounce = true,
	ExplosionParticleBounce = true,
	CreateProjectile = true,
	ReplicateProjectile = true,
}

local GameHookedEvents = {
	TrailBounce = true,
	MuzzleParticleBounce = true,
	BulletHoleBounce = true,
	ExplosionParticleBounce = true,
	ImpactParticleBounce = true,
	ReplicateProjectile = true,
	DoFlames = true,
	DoKillcam = true,
	ReplicateSound = true,
	StopReplicatedSound = true,
	ThrowBall = true,
	ApplyGun = true,
	SpawnMe = true,
	JoinTeam = true,
	HitDebug = true,
}

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local NetClient = require(ReplicatedFirst.Client.Utility.NetClient)
local GameEvents = require(ReplicatedStorage.Modules.Events)

if not NetClient then
	return nil
end
if not GameEvents then
	return nil
end

local NetLogger = Logger.New()

local _getgenv = getgenv or (function()
	return _G
end)
-- Re-execute safe: restore NetClient/Particles wrappers from previous run
-- so lock/unlock/u16 don't stack and hook retry just warns.
do
	local prev = _getgenv()._EventLoggerState
	if prev and prev.NetClient == NetClient and type(prev.Originals) == "table" then
		for K, Orig in prev.Originals do
			pcall(function()
				NetClient[K] = Orig
			end)
		end
		pcall(function()
			if prev.Particles and prev.OriginalsCreateTrail then
				prev.Particles.CreateTrail = prev.OriginalsCreateTrail
			end
			if prev.Particles and prev.OriginalsMuzzle then
				prev.Particles.CreateMuzzleFlash = prev.OriginalsMuzzle
			end
		end)
	end
end

local Shims = { SessionId = game.JobId, Installed = {}, Handlers = {} }

local Particles = require(ReplicatedFirst.Client.Game.Particles)

local IdToName = {}
for Name, Id in GameEvents do
	if type(Id) == "number" and type(Name) == "string" then
		IdToName[Id] = Name
	end
end

local function SafeFullName(Inst)
	local Name = Inst:GetFullName()
	if type(Name) == "string" then
		return Name
	end
	return tostring(Inst.Name)
end

local function FmtNumber(X)
	if X ~= X then
		return "nan"
	end
	if X == math.huge then
		return "inf"
	end
	if X == -math.huge then
		return "-inf"
	end
	if math.abs(X - math.floor(X + 0.5)) < 1e-4 and math.abs(X) < 1e7 then
		return tostring(math.floor(X + 0.5))
	end
	return ("%.3f"):format(X)
end

local function HexPreview(Buf, MaxBytes)
	MaxBytes = MaxBytes or 96
	local Len = buffer.len(Buf)
	if type(Len) ~= "number" then
		return nil
	end
	local N = math.min(Len, MaxBytes)
	local Bytes = table.create(N)
	for I = 0, N - 1 do
		Bytes[#Bytes + 1] = ("%02X"):format(buffer.readu8(Buf, I))
	end
	local S = table.concat(Bytes, " ")
	if Len > N then
		S ..= (" ...<%dB>"):format(Len)
	end
	return S
end

local function DecodeFlags(Flags)
	if type(Flags) ~= "number" then
		return tostring(Flags)
	end
	local F = math.floor(Flags)
	local Backstab = bit32.extract(F, 0, 1) == 1
	local Ads = bit32.extract(F, 1, 1) == 1
	local Jumping = bit32.extract(F, 2, 1) == 1
	local Spell = bit32.extract(F, 3, 3)
	local HitType = bit32.extract(F, 6, 2)
	return ("flags=%d[backstab=%s ads=%s jump=%s spell=%d hitType=%d]"):format(F, tostring(Backstab), tostring(Ads), tostring(Jumping), Spell, HitType)
end

local LocalPlayer = Players.LocalPlayer

local function TeamOf(Player)
	if Player == nil then
		return nil
	end
	local Status = Player:FindFirstChild("Status")
	if Status == nil then
		return nil
	end
	local Team = Status:FindFirstChild("Team")
	if Team == nil then
		return nil
	end
	return Team.Value
end

function Logger.Truncate(Self, S, N)
	N = N or (Self.MaxString or 120)
	if #S > N then
		return S:sub(1, N) .. ("...<%d>"):format(#S)
	end
	return S
end

function Logger.FormatValue(Self, V, Depth)
	Depth = Depth or 0
	local T = typeof(V)
	if T == "Instance" then
		return ("%s(%s)"):format(V.ClassName, SafeFullName(V))
	elseif T == "Vector3" then
		return ("V3(%.2f, %.2f, %.2f)"):format(V.X, V.Y, V.Z)
	elseif T == "CFrame" then
		return ("CF(%.1f, %.1f, %.1f)"):format(V.X, V.Y, V.Z)
	elseif T == "Color3" then
		return ("RGB(%d,%d,%d)"):format(math.floor(V.R * 255), math.floor(V.G * 255), math.floor(V.B * 255))
	elseif T == "EnumItem" then
		return tostring(V)
	elseif T == "buffer" then
		return ("<buffer:%d>"):format(buffer.len(V))
	elseif type(V) == "number" then
		return FmtNumber(V)
	elseif type(V) == "string" then
		return ("%q"):format(Self:Truncate(V))
	elseif type(V) == "boolean" or type(V) == "nil" then
		return tostring(V)
	elseif type(V) == "table" then
		if Depth > 1 then
			return "{...}"
		end
		local Parts = {}
		local N = 0
		for K, Val in V do
			N += 1
			if N > 10 then
				table.insert(Parts, "...")
				break
			end
			table.insert(Parts, tostring(K) .. "=" .. Self:FormatValue(Val, Depth + 1))
		end
		return "{" .. table.concat(Parts, ", ") .. "}"
	else
		return Self:Truncate(tostring(V))
	end
end

function Logger.GuessShooter(Self, Pos)
	if typeof(Pos) ~= "Vector3" then
		return nil
	end
	local Best = nil
	local BestDist = 9
	for _, Player in Players:GetPlayers() do
		if Player ~= LocalPlayer and Player.Character then
			local Root = Player.Character:FindFirstChild("HumanoidRootPart")
			local Head = Player.Character:FindFirstChild("Head")
			for _, Part in { Root, Head } do
				if Part then
					local D = (Part.Position - Pos).Magnitude
					if D < BestDist then
						Best = Player
						BestDist = D
					end
				end
			end
		end
	end
	if not Best then
		return nil
	end
	if LocalPlayer and LocalPlayer.Character then
		local Cam = workspace.CurrentCamera
		if Cam and (Cam.CFrame.Position - Pos).Magnitude < 6 then
			return "local"
		end
	end
	local Rel = "enemy"
	if LocalPlayer and TeamOf(Best) ~= nil and TeamOf(Best) == TeamOf(LocalPlayer) then
		Rel = "teammate"
	end
	return ("%s(%s)"):format(Best.Name, Rel)
end

function Logger.TrailMeta(Self, StartPos, EndPos)
	local Len = (EndPos - StartPos).Magnitude
	local Tag = ""
	if Self.ShooterTags and typeof(StartPos) == "Vector3" then
		local Who = Self:GuessShooter(StartPos)
		if Who then
			Tag = (" [from=%s]"):format(Who)
		end
	end
	local Copy = ""
	if Self.CopyFriendly and typeof(StartPos) == "Vector3" and typeof(EndPos) == "Vector3" then
		Copy = (" || Vector3.new(%s), Vector3.new(%s)"):format(
			("%s, %s, %s"):format(FmtNumber(StartPos.X), FmtNumber(StartPos.Y), FmtNumber(StartPos.Z)),
			("%s, %s, %s"):format(FmtNumber(EndPos.X), FmtNumber(EndPos.Y), FmtNumber(EndPos.Z))
		)
	end
	return ("len=%.1f%s%s"):format(Len, Tag, Copy)
end

function Logger.ShouldLog(Self, Name)
	if type(Self.Ignore) == "table" and Self.Ignore[Name] then
		return false
	end
	if type(Self.Only) == "table" then
		return Self.Only[Name] == true
	end
	return true
end

function Logger.ShouldCapture(Self, Name)
	if Self:ShouldLog(Name) then
		return true
	end
	return Self.Subscriptions.Outgoing[Name] ~= nil
end

local function DecodeArgs(Entry)
	local D = Entry.Data
	local N = Entry.Name
	if type(D) == "table" then
		if N == "HitPart" then
			return { D.Target, D.GunId, D.Flags, D.Pen, D.CamPos, D.HitPos, D.Dt, Entry }, 8
		elseif N == "TrailBounce" then
			return { D.StartPos, D.EndPos, Entry }, 3
		elseif N == "BulletHoleBounce" then
			if Entry.Dir == "OUT" then
				return { D.Pos, D.Normal, D.Part, Entry }, 4
			end
			return { D.StartPos, D.EndPos, D.Part, Entry }, 4
		elseif N == "MuzzleParticleBounce" then
			return { D.Flash, Entry }, 2
		elseif N == "ReplicateProjectile" then
			if Entry.Dir == "OUT" then
				return { D.ProjType, D.Speed, D.TargetPos, D.MuzzlePos, D.Gun, D.Spell, D.Flags, Entry }, 8
			end
			return { D.Shooter, D.ProjType, D.Speed, D.TargetPos, D.MuzzlePos, D.Gun, D.Spell, D.Flags, Entry }, 9
		elseif N == "SetServerDevice" then
			-- Stable: DeviceId is always arg1, Entry is always arg2 (even if nil).
			local Out = table.create(2)
			Out[1] = D.DeviceId
			Out[2] = Entry
			return Out, 2
		end
		-- Generic decoded Data: payload args in writer order, Entry last.
		-- Uses ArgN so nils keep positions: (arg1, arg2, ..., Entry).
		if type(D.Args) == "table" then
			local Count = type(D.ArgN) == "number" and D.ArgN or #D.Args
			local Out = table.create(Count + 1)
			for I = 1, Count do
				Out[I] = D.Args[I]
			end
			Out[Count + 1] = Entry
			return Out, Count + 1
		end
	end
	-- Fallback: unpack raw Ops payload (skip leading u16 id), Entry last.
	-- Guarantees same positions every time: arg1 = first writer value.
	if type(Entry.Ops) == "table" and #Entry.Ops >= 1 then
		local StartIdx = 1
		if Entry.Ops[1] and Entry.Ops[1].Op == "u16" then
			StartIdx = 2
		end
		if #Entry.Ops >= StartIdx then
			local Count = #Entry.Ops - StartIdx + 1
			local Out = table.create(Count + 1)
			for I = StartIdx, #Entry.Ops do
				Out[I - StartIdx + 1] = Entry.Ops[I].Val
			end
			Out[Count + 1] = Entry
			return Out, Count + 1
		end
	end
	return { Entry }, 1
end

function Logger.PushLog(Self, Entry)
	Entry.Count = Entry.Count or 1
	Entry.T = Entry.T or os.clock()
	if Self.CollapseRepeats then
		local Last = Self.Logs[#Self.Logs]
		if Last and Last.Dir == Entry.Dir and Last.Name == Entry.Name
			and Last.Text == Entry.Text and (Entry.T - (Last.T or 0)) < (Self.CollapseWindow or 0.5) then
			Last.Count = (Last.Count or 1) + 1
			Last.T = Entry.T
			return Last
		end
	end
	table.insert(Self.Logs, Entry)
	local Max = math.clamp(Self.MaxLogs or 300, 10, 5000)
	while #Self.Logs > Max do
		table.remove(Self.Logs, 1)
	end
	local DirKey = Entry.Dir == "OUT" and "Outgoing" or "Incoming"
	local Subs = Self.Subscriptions[DirKey][Entry.Name]
	if Subs then
		local Args, ArgN = DecodeArgs(Entry)
		ArgN = type(ArgN) == "number" and ArgN or #Args
		for _, Fn in Subs do
			task.spawn(Fn, table.unpack(Args, 1, ArgN))
		end
	end
	return Entry
end

function Logger.DecodeOutgoing(Self, Name, Ops)
	local Payload = {}
	for I = 2, #Ops do
		Payload[#Payload + 1] = Ops[I]
	end
	local function OpAt(I)
		return Payload[I] and Payload[I].Op or nil
	end
	local function ValAt(I)
		return Payload[I] and Payload[I].Val or nil
	end
	if Name == "HitPart" then
		if #Payload >= 19 and OpAt(1) == "inst" then
			local Target = ValAt(1)
			local GunId = ValAt(2)
			local Flags = ValAt(3)
			local Pen = ValAt(4)
			local Cam = {}
			for I = 5, 16 do
				Cam[#Cam + 1] = tonumber(ValAt(I)) or 0
			end
			local Hx, Hy, Hz = ValAt(17), ValAt(18), ValAt(19)
			local Dt = ValAt(20)
			local HitPos = nil
			local HitStr = "?"
			if typeof(Hx) == "number" and typeof(Hy) == "number" and typeof(Hz) == "number" then
				HitPos = Vector3.new(Hx, Hy, Hz)
				HitStr = ("V3(%.2f, %.2f, %.2f)"):format(Hx, Hy, Hz)
			end
			local CamPos = Vector3.new(Cam[1], Cam[2], Cam[3])
			local Summary = ("target=%s gunId=%s %s pen=%s hitPos=%s dt=%s cam=(%.1f,%.1f,%.1f)"):format(
				Self:FormatValue(Target), Self:FormatValue(GunId), DecodeFlags(Flags), Self:FormatValue(Pen), HitStr, Self:FormatValue(Dt), Cam[1], Cam[2], Cam[3]
			)
			if Self.ShooterTags and HitPos then
				local Who = Self:GuessShooter(CamPos)
				if Who then
					Summary ..= (" [from=%s]"):format(Who)
				end
			end
			return Summary, { Target = Target, GunId = GunId, Flags = Flags, Pen = Pen, HitPos = HitPos, CamPos = CamPos, Dt = Dt }
		end
	elseif Name == "TrailBounce" then
		if #Payload >= 6 then
			local X1, Y1, Z1, X2, Y2, Z2 = ValAt(1), ValAt(2), ValAt(3), ValAt(4), ValAt(5), ValAt(6)
			if typeof(X1) == "number" and typeof(X2) == "number" then
				local S, E = Vector3.new(X1, Y1, Z1), Vector3.new(X2, Y2, Z2)
				return (("start=V3(%.1f, %.1f, %.1f) end=V3(%.1f, %.1f, %.1f) %s"):format(X1, Y1, Z1, X2, Y2, Z2, Self:TrailMeta(S, E))), { StartPos = S, EndPos = E }
			end
		end
	elseif Name == "BulletHoleBounce" then
		if #Payload >= 7 then
			local Pos = Vector3.new(tonumber(ValAt(1)) or 0, tonumber(ValAt(2)) or 0, tonumber(ValAt(3)) or 0)
			local Norm = Vector3.new(tonumber(ValAt(4)) or 0, tonumber(ValAt(5)) or 0, tonumber(ValAt(6)) or 0)
			return (("pos=%s normal=%s part=%s"):format(Self:FormatValue(Pos), Self:FormatValue(Norm), Self:FormatValue(ValAt(7)))), { Pos = Pos, Normal = Norm, Part = ValAt(7) }
		end
	elseif Name == "MuzzleParticleBounce" then
		if #Payload >= 1 then
			return "flash=" .. Self:FormatValue(ValAt(1)), { Flash = ValAt(1) }
		end
	elseif Name == "ReplicateProjectile" then
		if #Payload >= 12 and OpAt(1) == "str" then
			local ProjType = ValAt(1)
			local Speed = ValAt(2)
			local Target = Vector3.new(tonumber(ValAt(3)) or 0, tonumber(ValAt(4)) or 0, tonumber(ValAt(5)) or 0)
			local Muzzle = Vector3.new(tonumber(ValAt(6)) or 0, tonumber(ValAt(7)) or 0, tonumber(ValAt(8)) or 0)
			local Gun, X, Spell, Flags = ValAt(9), ValAt(10), ValAt(11), ValAt(12)
			local Jumping, Ads = false, false
			if type(Flags) == "number" then
				Jumping = bit32.extract(math.floor(Flags), 0, 1) == 1
				Ads = bit32.extract(math.floor(Flags), 1, 1) == 1
			end
			local Summary = ("type=%s speed=%s target=%s muzzle=%s gun=%s spell=%s flags=%s[jump=%s ads=%s]"):format(
				Self:FormatValue(ProjType), Self:FormatValue(Speed), Self:FormatValue(Target),
				Self:FormatValue(Muzzle), Self:FormatValue(Gun), Self:FormatValue(Spell),
				Self:FormatValue(Flags), tostring(Jumping), tostring(Ads)
			)
			return Summary, { ProjType = ProjType, Speed = Speed, TargetPos = Target, MuzzlePos = Muzzle, Gun = Gun, Spell = Spell, Flags = Flags }
		end
	end
	local Parts = {}
	for _, O in Payload do
		Parts[#Parts + 1] = ("%s(%s)"):format(O.Op, Self:FormatValue(O.Val))
	end

	local Vals = table.create(#Payload)
	for I, O in Payload do
		Vals[I] = O.Val
	end
	local ArgN = #Payload
	if Name == "SetServerDevice" then
		return table.concat(Parts, " "), { DeviceId = Vals[1], Args = Vals, ArgN = ArgN, Values = Vals, Ops = Payload }
	end
	return table.concat(Parts, " "), { Args = Vals, ArgN = ArgN, Values = Vals, Ops = Payload }
end

local function RawSummary(LoggerSelf, Ops, Limit)
	Limit = Limit or 40
	local Parts = {}
	for I, O in Ops do
		if I > Limit then
			Parts[#Parts + 1] = "..."
			break
		end
		Parts[#Parts + 1] = ("%s(%s)"):format(O.Op, LoggerSelf:FormatValue(O.Val))
	end
	return table.concat(Parts, " ")
end

function Logger.EmitOutgoing(Self, Ops, Trace)
	if #Ops == 0 then
		return
	end
	local Id = Ops[1] and Ops[1].Val
	local Name = (type(Id) == "number" and IdToName[Id]) or ("id_" .. tostring(Id))
	if not Self:ShouldCapture(Name) then
		return
	end
	local Decoded, Data = Self:DecodeOutgoing(Name, Ops)
	local Text = ("%s(%s) | %s"):format(Name, tostring(Id), Decoded)
	if Self.ShowRaw then
		Text ..= " || raw: " .. RawSummary(Self, Ops)
	end
	if Self.ShowStack and type(Trace) == "string" and Trace ~= "" then
		Text ..= "\n  stack: " .. Self:Truncate(Trace:gsub("\n", " <- "), 400)
	end
	Self:PushLog({
		Dir = "OUT",
		Name = Name,
		Id = Id,
		Text = Text,
		Ops = Ops,
		Data = Data,
		T = os.clock(),
	})
end

function Logger.EmitIncoming(Self, Name, Id, Summary, Hex, ExtraOps, Data)
	if not Self:ShouldLog(Name) then
		return
	end
	local Text = ("%s(%s) | %s"):format(Name, tostring(Id), Summary)
	if Self.ShowHex and type(Hex) == "string" and Hex ~= "" then
		Text ..= " || hex: " .. Hex
	end
	Self:PushLog({
		Dir = "IN ",
		Name = Name,
		Id = Id,
		Text = Text,
		Ops = ExtraOps,
		Data = Data,
		T = os.clock(),
	})
end

function Logger.DecodeIncomingTrail(Self, Reader, Buf)
	local X1 = buffer.readf32(Buf, Reader(4))
	local Y1 = buffer.readf32(Buf, Reader(4))
	local Z1 = buffer.readf32(Buf, Reader(4))
	local X2 = buffer.readf32(Buf, Reader(4))
	local Y2 = buffer.readf32(Buf, Reader(4))
	local Z2 = buffer.readf32(Buf, Reader(4))
	local S, E = Vector3.new(X1, Y1, Z1), Vector3.new(X2, Y2, Z2)
	return ("start=V3(%.1f, %.1f, %.1f) end=V3(%.1f, %.1f, %.1f) %s"):format(X1, Y1, Z1, X2, Y2, Z2, Self:TrailMeta(S, E)),
		{
			{ Op = "f32", Val = X1 },
			{ Op = "f32", Val = Y1 },
			{ Op = "f32", Val = Z1 },
			{ Op = "f32", Val = X2 },
			{ Op = "f32", Val = Y2 },
			{ Op = "f32", Val = Z2 },
		},
		{ StartPos = S, EndPos = E }
end

local function LastArg(...)
	local N = select("#", ...)
	if N == 0 then
		return nil
	end
	return select(N, ...)
end

function Logger.ActiveCapture(Self)
	if Self.Depth > 0 then
		local Frame = Self.Frames[#Self.Frames]
		return Frame and Frame.Cap or nil
	end
	return Self.AutoCapture
end

function Logger.BumpCensus(Self, Id)
	local Name = (type(Id) == "number" and IdToName[Id]) or ("id_" .. tostring(Id))
	Self.Census[Name] = (Self.Census[Name] or 0) + 1
end

local WriterSkip = { lock = true, unlock = true, hook = true, unhook = true, u16 = true }

function Logger.DiscoverWriters(Self)
	for K, V in NetClient do
		if type(V) == "function" and not WriterSkip[K] and Self.Originals[K] == nil then
			if K:match("^[a-z][a-z0-9_]*$") ~= nil then
				Self.Originals[K] = V
			end
		end
	end
end

function Logger.InstallWriters(Self)
	if Self.WritersInstalled then
		return
	end
	Self.WritersInstalled = true
	for K, Orig in Self.Originals do
		if not WriterSkip[K] then
			local Op = K
			NetClient[Op] = function(...)
				local Cap = NetLogger:ActiveCapture()
				if Cap then
					table.insert(Cap.Ops, { Op = Op, Val = LastArg(...) })
				end
				return Orig(...)
			end
		end
	end
end

function Logger.UninstallWriters(Self)
	if not Self.WritersInstalled then
		return
	end
	Self.WritersInstalled = false
	for K, Orig in Self.Originals do
		if not WriterSkip[K] then
			NetClient[K] = Orig
		end
	end
end

function Logger.CloseAuto(Self)
	local Cap = Self.AutoCapture
	Self.AutoCapture = nil
	Self:UninstallWriters()
	if not Cap then
		return
	end
	if not Self.Enabled or not Self.LogOutgoing then
		return
	end
	Self:EmitOutgoing(Cap.Ops, Cap.Trace)
end

local function ScheduleAutoFlush(Cap, Gen)
	task.delay(0.08, function()
		if NetLogger.AutoCapture == Cap and Cap.Gen == Gen then
			NetLogger:CloseAuto()
		end
	end)
end

function Logger.OpenBoundary(Self, Val)
	Self:BumpCensus(Val)
	local Name = IdToName[Val]
	if Self.Enabled and Self.LogOutgoing and Self:ShouldCapture(Name) then
		local Trace = ""
		local Traceback = debug and debug.traceback
		if Self.ShowStack and type(Traceback) == "function" then
			Trace = Traceback("", 2) or ""
		end
		return { Ops = {}, Id = Val, Name = Name, Trace = Trace, Gen = 0 }
	end
	return nil
end

do
	for _, K in { "lock", "unlock", "u16" } do
		if NetLogger.Originals[K] == nil then
			NetLogger.Originals[K] = NetClient[K]
		end
	end
	NetLogger:DiscoverWriters()
	local OrigLock = NetLogger.Originals.lock
	local OrigUnlock = NetLogger.Originals.unlock
	local OrigU16 = NetLogger.Originals.u16

	NetClient.lock = function(...)
		if NetLogger.AutoCapture then
			NetLogger:CloseAuto()
		end
		NetLogger.Depth += 1
		table.insert(NetLogger.Frames, { FirstU16 = true, Cap = nil })
		return OrigLock(...)
	end

	NetClient.unlock = function(...)
		local Res = OrigUnlock(...)
		local Frame = table.remove(NetLogger.Frames)
		NetLogger.Depth = math.max(0, NetLogger.Depth - 1)
		if Frame and Frame.Cap then
			local Cap = Frame.Cap
			NetLogger:UninstallWriters()
			if NetLogger.Enabled and NetLogger.LogOutgoing then
				NetLogger:EmitOutgoing(Cap.Ops, Cap.Trace)
			end
		end
		return Res
	end

	NetClient.u16 = function(...)
		local Val = LastArg(...)
		if NetLogger.Depth > 0 then
			local Frame = NetLogger.Frames[#NetLogger.Frames]
			if Frame and Frame.FirstU16 and type(Val) == "number" and IdToName[Val] then
				Frame.FirstU16 = false
				local Cap = NetLogger:OpenBoundary(Val)
				Frame.Cap = Cap
				if Cap then
					table.insert(Cap.Ops, { Op = "u16", Val = Val })
					NetLogger:InstallWriters()
				end
			elseif Frame and Frame.Cap then
				table.insert(Frame.Cap.Ops, { Op = "u16", Val = Val })
			end
			return OrigU16(...)
		end
		if type(Val) == "number" and IdToName[Val] then
			if NetLogger.AutoCapture then
				NetLogger:CloseAuto()
			end
			local Cap = NetLogger:OpenBoundary(Val)
			if Cap then
				NetLogger.AutoGeneration += 1
				Cap.Gen = NetLogger.AutoGeneration
				table.insert(Cap.Ops, { Op = "u16", Val = Val })
				NetLogger.AutoCapture = Cap
				NetLogger:InstallWriters()
				ScheduleAutoFlush(Cap, Cap.Gen)
			end
		elseif NetLogger.AutoCapture then
			table.insert(NetLogger.AutoCapture.Ops, { Op = "u16", Val = Val })
			NetLogger.AutoGeneration += 1
			NetLogger.AutoCapture.Gen = NetLogger.AutoGeneration
			ScheduleAutoFlush(NetLogger.AutoCapture, NetLogger.AutoCapture.Gen)
		end
		return OrigU16(...)
	end
end

local function InstallIncomingHook(EventName, EventId)
	if NetLogger.IncomingHooks[EventId] then
		return
	end
	NetLogger.IncomingHooks[EventId] = true
	if GameHookedEvents[EventName] then
		if EventName == "TrailBounce" and type(Particles.CreateTrail) == "function" then
			if not NetLogger.OriginalsCreateTrail then
				NetLogger.Particles = Particles
				NetLogger.OriginalsCreateTrail = Particles.CreateTrail
				local Orig = Particles.CreateTrail
				Particles.CreateTrail = function(StartPos, EndPos, Color)
					if NetLogger.Enabled and NetLogger.LogIncoming and NetLogger:ShouldLog("TrailBounce") then
						local Meta = ""
						if typeof(StartPos) == "Vector3" and typeof(EndPos) == "Vector3" then
							Meta = " " .. NetLogger:TrailMeta(StartPos, EndPos)
						end
						local Summary = ("start=%s end=%s color=%s%s [via Particles.CreateTrail]"):format(
							NetLogger:FormatValue(StartPos),
							NetLogger:FormatValue(EndPos),
							type(Color) == "table" and NetLogger:FormatValue(Color) or NetLogger:FormatValue(Color),
							Meta
						)
						local Data = nil
						if typeof(StartPos) == "Vector3" and typeof(EndPos) == "Vector3" then
							Data = { StartPos = StartPos, EndPos = EndPos, Color = Color }
						end
						NetLogger:EmitIncoming("TrailBounce", EventId, Summary, nil, nil, Data)
					end
					return Orig(StartPos, EndPos, Color)
				end
				table.insert(NetLogger.Connections, {
					Disconnect = function()
						if NetLogger.Particles and NetLogger.OriginalsCreateTrail then
							NetLogger.Particles.CreateTrail = NetLogger.OriginalsCreateTrail
						end
					end,
				})
			end
		elseif EventName == "MuzzleParticleBounce" and type(Particles.CreateMuzzleFlash) == "function" then
			if not NetLogger.OriginalsMuzzle then
				NetLogger.Particles = Particles
				NetLogger.OriginalsMuzzle = Particles.CreateMuzzleFlash
				local Orig = Particles.CreateMuzzleFlash
				Particles.CreateMuzzleFlash = function(Flash)
					if NetLogger.Enabled and NetLogger.LogIncoming and NetLogger:ShouldLog("MuzzleParticleBounce") then
						NetLogger:EmitIncoming("MuzzleParticleBounce", EventId, "flash=" .. NetLogger:FormatValue(Flash) .. " [via Particles]", nil, nil, { Flash = Flash })
					end
					return Orig(Flash)
				end
			end
		end
		return
	end
	Shims.Handlers[EventId] = function(Reader, Buf, InstTable)
		if not NetLogger.Enabled or not NetLogger.LogIncoming then
			return
		end
		local Consumed = 0
		local Wrapped = function(N)
			Consumed += (N or 0)
			return Reader(N)
		end
		local Summary, Ops, Data
		if EventName == "TrailBounce" then
			Summary, Ops, Data = NetLogger:DecodeIncomingTrail(Wrapped, Buf)
		elseif EventName == "ReplicateProjectile" then
			local Shooter = InstTable and InstTable[buffer.readu8(Buf, Wrapped(1))] or nil
			local Len1 = buffer.readu16(Buf, Wrapped(2))
			local ProjType = buffer.readstring(Buf, Wrapped(Len1), Len1)
			local Speed = buffer.readf32(Buf, Wrapped(4))
			local T = Vector3.new(buffer.readf32(Buf, Wrapped(4)), buffer.readf32(Buf, Wrapped(4)), buffer.readf32(Buf, Wrapped(4)))
			local M = Vector3.new(buffer.readf32(Buf, Wrapped(4)), buffer.readf32(Buf, Wrapped(4)), buffer.readf32(Buf, Wrapped(4)))
			local Len2 = buffer.readu16(Buf, Wrapped(2))
			local Gun = buffer.readstring(Buf, Wrapped(Len2), Len2)
			local X = buffer.readf32(Buf, Wrapped(4))
			local Spell = buffer.readu8(Buf, Wrapped(1))
			local Flags = buffer.readu8(Buf, Wrapped(1))
			local Who = Shooter and NetLogger:FormatValue(Shooter) or "?"
			Summary = (("type=%s speed=%s target=%s muzzle=%s gun=%s [from=%s]"):format(
				NetLogger:FormatValue(ProjType), NetLogger:FormatValue(Speed), NetLogger:FormatValue(T),
				NetLogger:FormatValue(M), NetLogger:FormatValue(Gun), Who
			))
			Ops = nil
			Data = { ProjType = ProjType, Speed = Speed, TargetPos = T, MuzzlePos = M, Gun = Gun, Shooter = Shooter, Spell = Spell, Flags = Flags }
		elseif EventName == "MuzzleParticleBounce" then
			local Idx = buffer.readu8(Buf, Wrapped(1))
			local Target = InstTable and InstTable[Idx] or ("<inst#" .. tostring(Idx) .. ">")
			Summary = "flash=" .. NetLogger:FormatValue(Target)
			Ops = { { Op = "inst", Val = Target } }
			Data = { Flash = Target }
		elseif EventName == "BulletHoleBounce" then
			local S, TrailOps, TrailData = NetLogger:DecodeIncomingTrail(Wrapped, Buf)
			local Idx = buffer.readu8(Buf, Wrapped(1))
			local Target = InstTable and InstTable[Idx] or ("<inst#" .. tostring(Idx) .. ">")
			TrailData = TrailData or {}
			TrailData.Part = Target
			Summary = S .. " part=" .. NetLogger:FormatValue(Target)
			Ops = TrailOps
			Data = TrailData
		else
			Summary = ("<undecoded layout, id=%d>"):format(EventId)
			Ops = nil
			Data = nil
		end
		local Hex = nil
		if NetLogger.ShowHex then
			local Len = buffer.len(Buf)
			local From = math.clamp(Consumed, 0, Len)
			local N = math.min(Len - From, 64)
			if N > 0 then
				local Bytes = table.create(N)
				for I = 0, N - 1 do
					Bytes[#Bytes + 1] = ("%02X"):format(buffer.readu8(Buf, From + I))
				end
				Hex = "consumed=" .. tostring(Consumed) .. "/" .. tostring(Len) .. " rest: " .. table.concat(Bytes, " ")
			else
				local Full = HexPreview(Buf, 64)
				Hex = "consumed=" .. tostring(Consumed) .. "/" .. tostring(Len) .. (Full and (" buf: " .. Full) or "")
			end
		end
		NetLogger:EmitIncoming(EventName, EventId, Summary, Hex, Ops, Data)
	end
	if not Shims.Installed[EventId] then
		local ok, err = pcall(function()
			NetClient.hook(EventId, function(Reader, Buf, InstTable)
				local H = Shims.Handlers[EventId]
				if H then
					H(Reader, Buf, InstTable)
				end
			end)
		end)
		if ok then
			Shims.Installed[EventId] = true
		else
			warn(("[EventLogger] hook(%s=%d) skipped (already hooked?): %s"):format(tostring(EventName), EventId, tostring(err)))
		end
	end
end

for Name, Id in GameEvents do
	if type(Name) == "string" and type(Id) == "number" then
		InstallIncomingHook(Name, Id)
	end
end

function Logger.Clear(Self)
	table.clear(Self.Logs)
	return true
end

function Logger.Dump(Self, N)
	N = math.clamp(math.floor(tonumber(N) or 20), 1, #Self.Logs > 0 and #Self.Logs or 1)
	local From = math.max(1, #Self.Logs - N + 1)
	local Lines = {}
	for I = From, #Self.Logs do
		local E = Self.Logs[I]
		Lines[#Lines + 1] = ("[%d][%s] %s"):format(I, E.Dir, E.Text)
	end
	return Lines
end

function Logger.SetFilter(Self, OnlyOrNil, IgnoreOrNil)
	if OnlyOrNil ~= nil then
		assert(type(OnlyOrNil) == "table", "Only filter must be a table or nil")
	end
	if IgnoreOrNil ~= nil then
		assert(type(IgnoreOrNil) == "table", "Ignore filter must be a table or nil")
	end
	Self.Only = OnlyOrNil
	if IgnoreOrNil ~= nil then
		Self.Ignore = IgnoreOrNil
	end
end

function Logger.ListEvents(Self)
	local Lines = {}
	for Name, Id in GameEvents do
		Lines[#Lines + 1] = ("%s = %d"):format(tostring(Name), tonumber(Id) or -1)
	end
	table.sort(Lines)
	return Lines
end

function Logger.TracerMode(Self)
	Self.Only = table.clone(TracerEvents)
	Self.ShowRaw = false
	Self.ShowHex = false
	return true
end

function Logger.FullMode(Self)
	Self.Only = nil
	return true
end

local function IsTracerEntry(E)
	return TracerEvents[E.Name] == true
end

function Logger.DumpShots(Self, N)
	N = math.clamp(math.floor(tonumber(N) or 20), 1, 500)
	local Shown, Total = 0, 0
	local Lines = {}
	for I = #Self.Logs, 1, -1 do
		local E = Self.Logs[I]
		if IsTracerEntry(E) then
			Total += 1
			if Shown < N then
				Shown += 1
				Lines[#Lines + 1] = ("[%d][%s] %s"):format(I, E.Dir, E.Text)
			end
		end
	end
	return Lines
end

function Logger.Stats(Self)
	local Keys = {}
	for K in Self.Census do
		table.insert(Keys, K)
	end
	table.sort(Keys, function(A, B)
		return Self.Census[A] > Self.Census[B]
	end)
	local Rows = {}
	for _, K in Keys do
		Rows[#Rows + 1] = { Name = K, Count = Self.Census[K] }
	end
	return Rows
end

function Logger.ResetStats(Self)
	table.clear(Self.Census)
	return true
end

local DirectionAliases = {
	outgoing = "Outgoing",
	outcoming = "Outgoing",
	out = "Outgoing",
	send = "Outgoing",
	incoming = "Incoming",
	inc = "Incoming",
	["in"] = "Incoming",
	receive = "Incoming",
	recv = "Incoming",
}

local function NormalizeDirection(Direction)
	assert(type(Direction) == "string", "On needs a direction string")
	local Key = DirectionAliases[Direction:lower()]
	if not Key then
		error(("unknown direction %q (use \"Outgoing\" or \"Incoming\")"):format(tostring(Direction)), 3)
	end
	return Key
end

function Logger.On(Self, Direction, EventName, Fn)
	local DirKey = NormalizeDirection(Direction)
	assert(type(EventName) == "string", "On needs an event name")
	assert(type(Fn) == "function", "On needs a callback function")
	if type(GameEvents[EventName]) ~= "number" then
		error(("unknown event %q"):format(tostring(EventName)), 2)
	end
	local Bucket = Self.Subscriptions[DirKey]
	Bucket[EventName] = Bucket[EventName] or {}
	table.insert(Bucket[EventName], Fn)
	local Conn = { Connected = true }
	function Conn.Disconnect()
		Conn.Connected = false
		local L = Self.Subscriptions[DirKey][EventName]
		if L then
			for I, V in L do
				if V == Fn then
					table.remove(L, I)
					break
				end
			end
			if #L == 0 then
				Self.Subscriptions[DirKey][EventName] = nil
			end
		end
	end
	table.insert(Self.Connections, Conn)
	return Conn
end

function Logger.CopyLast(Self)
	for I = #Self.Logs, 1, -1 do
		local E = Self.Logs[I]
		local D = E.Data
		if D and typeof(D.StartPos) == "Vector3" and typeof(D.EndPos) == "Vector3" then
			local S = ("Vector3.new(%s, %s, %s), Vector3.new(%s, %s, %s)"):format(
				FmtNumber(D.StartPos.X), FmtNumber(D.StartPos.Y), FmtNumber(D.StartPos.Z),
				FmtNumber(D.EndPos.X), FmtNumber(D.EndPos.Y), FmtNumber(D.EndPos.Z)
			)
			setclipboard(S)
			return S
		end
	end
	return nil
end


return NetLogger