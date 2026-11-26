local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local LocalPlayer = Players.LocalPlayer

local PlayerData = require(ReplicatedFirst:WaitForChild("Client"):WaitForChild("Utility"):WaitForChild("PlayerData"))
local Bridge = require(ReplicatedFirst:WaitForChild("Client"):WaitForChild("Utility"):WaitForChild("Bridge"))
local ItemUtil = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("ItemUtil"))
local GetIcon = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("GetIcon"))
local State = require(ReplicatedFirst:WaitForChild("Client"):WaitForChild("Utility"):WaitForChild("State"))

local UnlockAll = {}
UnlockAll.__index = UnlockAll

function UnlockAll.new()
	local self = setmetatable({
		Player = LocalPlayer,
		PlayerData = PlayerData,
		Bridge = Bridge,
		ItemUtil = ItemUtil,
		GetIcon = GetIcon,
		State = State,
		Disabled = true,
		RealState = nil,
		RebuildPending = false,
		WrappedFunctions = {},
		Skin = nil,
		Announcer = nil,
		KillEffect = nil,
		WeaponSkin = nil,
		MeleeSkin = nil,
		MeleeMetaCache = {},
		SoundHooked = false,
		OrigPlaysound = nil,
		OrigRplaysound = nil,
		Categories = {
			"Skins",
			"Melees",
			"Emotes",
			"KillEffects",
			"Cards",
			"Announcers",
			"WeaponSkins",
			"Themes",
			"Kits"
		}
	}, UnlockAll)

	PlayerData.Wait()

	self:BackfillMeleeAnimations()
	self:HookViewmodel()
	self:HookCharacterUpdates()
	self:HookInventoryUpdates()
	self:HookInventoryIcon()
	self:HookEquipped()
	self:HookDataValues()
	self:HookRagdoll()
	self:HookCharacterAdded()
	self:HookMeleeMeta()
	self:HookMeleeSounds()

	if not self.Disabled then
		self:UnlockAll()
		self:AdoptLoadout()
		self:PushAll()
		self:PaintMeleeIcon()
	end

	return self
end

function UnlockAll:GetImages()
	local ItemData = ReplicatedStorage:FindFirstChild("ItemData")
	return ItemData and ItemData:FindFirstChild("Images")
end

function UnlockAll:IsValidImage(Category, Name)
	if type(Name) ~= "string" or Name == "" then
		return false
	end

	if Name == "None" or Name == "Default" or Name == "Shuffle" then
		return true
	end

	local Images = self:GetImages()
	local CategoryFolder = Images and Images:FindFirstChild(Category)

	return CategoryFolder and CategoryFolder:FindFirstChild(Name) ~= nil
end

function UnlockAll:IsValidSkin(Name)
	if Name == "curr" or Name == "none" or Name == "del" then
		return false
	end

	return self:IsValidImage("Skins", Name)
end

function UnlockAll:IsValidMelee(Name)
	if type(Name) ~= "string" or Name == "" then
		return false
	end

	if Name == "None" or Name == "Default" or Name == "Shuffle" then
		return false
	end

	local Viewmodels = ReplicatedStorage:FindFirstChild("Viewmodels")

	if not Viewmodels or not Viewmodels:FindFirstChild("v_" .. Name) then
		return false
	end

	return self:IsValidImage("Melees", Name)
end

function UnlockAll:UnlockAll()
	if self.Disabled then
		return 0
	end

	local Images = self:GetImages()
	local Items = self.PlayerData.Data.Items

	if not Images or type(Items) ~= "table" then
		return 0
	end

	local UnlockedCount = 0

	for _, Category in self.Categories do
		local SourceFolder = Images:FindFirstChild(Category)
		local DestinationItems = Items[Category]

		if SourceFolder and type(DestinationItems) == "table" then
			for _, Item in SourceFolder:GetChildren() do
				if DestinationItems[Item.Name] == nil then
					DestinationItems[Item.Name] = 1
					UnlockedCount += 1
				end
			end
		end
	end

	return UnlockedCount
end

function UnlockAll:DeepCopy(Value, Depth)
	if Depth > 6 or type(Value) ~= "table" then
		return Value
	end

	local Result = {}

	for Key, Item in Value do
		Result[Key] = self:DeepCopy(Item, Depth + 1)
	end

	return Result
end

function UnlockAll:Disable()
	self.Disabled = true

	local Success, FreshData = pcall(function()
		return ReplicatedStorage:WaitForChild("Events"):WaitForChild("GetInventory"):InvokeServer({"GetData"})
	end)

	if not Success or type(FreshData) ~= "table" then
		return false
	end

	self.RealState = self:DeepCopy(FreshData, 0)
	self.PlayerData.Data = FreshData

	self.Skin = nil
	self.Announcer = nil
	self.KillEffect = nil
	self.WeaponSkin = nil
	self.MeleeSkin = nil

	return true
end

function UnlockAll:Enable()
	self.Disabled = false
	self:UnlockAll()
	self:AdoptLoadout()
	self:PushAll()
	self:PaintMeleeIcon()
end

function UnlockAll:BackfillMeleeAnimations()
	local Melees = ReplicatedStorage:FindFirstChild("Melees")
	local Dagger = Melees and Melees:FindFirstChild("Dagger")
	local WalkAnimation = Dagger and Dagger:FindFirstChild("Walk")
	local BackwardsWalkAnimation = Dagger and Dagger:FindFirstChild("BWalk")

	if not WalkAnimation or not BackwardsWalkAnimation then
		return
	end

	for _, Melee in Melees:GetChildren() do
		if not Melee:FindFirstChild("Walk") then
			WalkAnimation:Clone().Parent = Melee
		end

		if not Melee:FindFirstChild("BWalk") then
			BackwardsWalkAnimation:Clone().Parent = Melee
		end
	end
end

function UnlockAll:PushAll()
	if self.Disabled then
		return
	end

	local PlayerDataFolder = self.Player:FindFirstChild("Data")

	if not PlayerDataFolder then
		return
	end

	if self.Skin and self:IsValidSkin(self.Skin) then
		local SkinValue = PlayerDataFolder:FindFirstChild("Skin")

		if SkinValue then
			SkinValue.Value = self.Skin

			local SleeveValue = SkinValue:FindFirstChild("Sleeve")

			if SleeveValue then
				SleeveValue.Value = self.Skin
			end
		end

		self.Player:SetAttribute("ForceSleeves", self.Skin)
	end

	if self.Announcer and self:IsValidImage("Announcers", self.Announcer) then
		local AnnouncerValue = PlayerDataFolder:FindFirstChild("Announcer")

		if AnnouncerValue then
			AnnouncerValue.Value = self.Announcer
		end
	end

	if self.KillEffect and self:IsValidImage("KillEffects", self.KillEffect) then
		local KillEffectValue = PlayerDataFolder:FindFirstChild("KillEffect")

		if KillEffectValue then
			KillEffectValue.Value = self.KillEffect
		end
	end

	if self.WeaponSkin then
		local EquippedValue = self.Player:FindFirstChild("Equipped")

		if EquippedValue and EquippedValue.Value ~= self.WeaponSkin then
			EquippedValue.Value = self.WeaponSkin
		end
	end
end

function UnlockAll:ScheduleWeaponSkinRebuild()
	if self.RebuildPending then
		return
	end

	self.RebuildPending = true

	task.delay(0.35, function()
		self.RebuildPending = false
		self:PushAll()

		pcall(function()
			self.Bridge.GiveTools:Fire()
		end)
	end)
end

function UnlockAll:AdoptLoadout(Loadout)
	if self.Disabled then
		return
	end

	Loadout = Loadout or self.PlayerData.Data.Loadout

	if type(Loadout) ~= "table" then
		return
	end

	if self:IsValidSkin(Loadout.Skin) and Loadout.Skin ~= self.Skin then
		self.Skin = Loadout.Skin
	end

	if self:IsValidImage("Announcers", Loadout.Announcer) and Loadout.Announcer ~= self.Announcer then
		self.Announcer = Loadout.Announcer
	end

	if self:IsValidImage("KillEffects", Loadout.KillEffect) and Loadout.KillEffect ~= self.KillEffect then
		self.KillEffect = Loadout.KillEffect
	end

	if type(Loadout.WeaponSkins) == "string"
		and Loadout.WeaponSkins ~= ""
		and Loadout.WeaponSkins ~= self.WeaponSkin
		and self:IsValidImage("WeaponSkins", Loadout.WeaponSkins) then
		self.WeaponSkin = Loadout.WeaponSkins
		self:ScheduleWeaponSkinRebuild()
	end

	if type(Loadout.Melee) == "string"
		and Loadout.Melee ~= self.MeleeSkin
		and self:IsValidMelee(Loadout.Melee) then
		self.MeleeSkin = Loadout.Melee

		task.defer(function()
			self:PaintMeleeIcon()
		end)
	end

	self:PushAll()
end

function UnlockAll:PaintMeleeIcon()
	if self.Disabled then
		return
	end

	if not self:IsValidMelee(self.MeleeSkin) then
		return
	end

	local Image

	pcall(function()
		Image = self.GetIcon.getWeaponOfKiller(self.MeleeSkin)
	end)

	if type(Image) ~= "string" or Image == "" then
		pcall(function()
			Image = self.ItemUtil.GetInfo(self.MeleeSkin, "Melees"):unwrapOr(self.ItemUtil.FALLBACK_ITEM).Image
		end)
	end

	if type(Image) ~= "string" or Image == "" then
		return
	end

	local PlayerGui = self.Player:FindFirstChild("PlayerGui")
	local MainGui = PlayerGui and PlayerGui:FindFirstChild("GUI")
	local Inventory = MainGui and MainGui:FindFirstChild("Inventory")
	local InventoryItem = Inventory and Inventory:FindFirstChild("Item3")

	if not InventoryItem then
		return
	end

	local WeaponImage = InventoryItem:FindFirstChild("Weapon")

	if WeaponImage then
		WeaponImage.Image = Image
	end

	local ToolName = InventoryItem:FindFirstChild("ToolName")

	if ToolName then
		ToolName.Text = self.MeleeSkin
	end
end

function UnlockAll:Equip(Type, Name)
	if self.Disabled then
		return
	end

	if Type == "Skin" and self:IsValidSkin(Name) then
		self.Skin = Name
		self.PlayerData.Data.Loadout.Skin = Name
		self:PushAll()
	elseif Type == "Announcer" and self:IsValidImage("Announcers", Name) then
		self.Announcer = Name
		self.PlayerData.Data.Loadout.Announcer = Name
		self:PushAll()
	elseif Type == "KillEffect" and self:IsValidImage("KillEffects", Name) then
		self.KillEffect = Name
		self.PlayerData.Data.Loadout.KillEffect = Name
		self:PushAll()
	elseif Type == "WeaponSkin" and self:IsValidImage("WeaponSkins", Name) then
		self.WeaponSkin = Name
		self.PlayerData.Data.Loadout.WeaponSkins = Name
		self:PushAll()
		self:ScheduleWeaponSkinRebuild()
	elseif Type == "MeleeSkin" and self:IsValidMelee(Name) then
		self.MeleeSkin = Name
		self.PlayerData.Data.Loadout.Melee = Name

		task.defer(function()
			self:PaintMeleeIcon()
		end)
	end
end

function UnlockAll:GetMeleeMeta(Name)
	if type(Name) ~= "string" or Name == "" then
		return nil
	end

	local Cached = self.MeleeMetaCache[Name]

	if Cached ~= nil then
		if Cached == false then
			return nil
		end

		return Cached
	end

	local Melees = ReplicatedStorage:FindFirstChild("Melees")
	local Folder = Melees and Melees:FindFirstChild(Name)
	local Meta = Folder and Folder:FindFirstChild("Meta")

	if not Meta then
		self.MeleeMetaCache[Name] = false
		return nil
	end

	local Ok, Mod = pcall(require, Meta)

	if not Ok or type(Mod) ~= "table" then
		self.MeleeMetaCache[Name] = false
		return nil
	end

	self.MeleeMetaCache[Name] = Mod
	return Mod
end

function UnlockAll:GetEffectColor()
	if self.State.meleeslot == "Golden Knife" then
		return Color3.fromRGB(245, 205, 48)
	end

	local Color = nil

	pcall(function()
		Color = self.Player.TeamColor.Color
	end)

	local Wkspc = ReplicatedStorage:FindFirstChild("wkspc")
	local FFA = Wkspc and Wkspc:FindFirstChild("FFA")
	local Gametype = Wkspc and Wkspc:FindFirstChild("gametype")
	local IsFFA = false

	pcall(function()
		IsFFA = FFA.Value == true or Gametype.Value == "Juggernaut"
	end)

	if IsFFA then
		pcall(function()
			Color = self.Player.DesignColor.Value.Color
		end)
	end

	return Color
end

function UnlockAll:ApplySpoofedMetaToArms()
	if self.Disabled then
		return
	end

	local MeleeName = self.MeleeSkin

	if not self:IsValidMelee(MeleeName) then
		return
	end

	local IsMeleeView = false

	pcall(function()
		IsMeleeView = self.State.equipped == "melee"
			and (self.State.meleeslot == "Knife" or self.State.meleeslot == "Golden Knife")
	end)

	if not IsMeleeView then
		return
	end

	local Arms = nil

	pcall(function()
		local Camera = workspace.CurrentCamera
		Arms = Camera and Camera:FindFirstChild("Arms")
	end)

	if typeof(Arms) ~= "Instance" then
		return
	end

	local Meta = self:GetMeleeMeta(MeleeName)

	if not Meta then
		return
	end

	local Color = nil

	pcall(function()
		Color = self:GetEffectColor()
	end)

	if typeof(Color) ~= "Color3" then
		pcall(function()
			Color = self.Player.TeamColor.Color
		end)
	end

	if Meta.VM_INIT and typeof(Color) == "Color3" then
		pcall(function()
			Meta.VM_INIT(Arms, Color)
		end)
	end

	if Meta.POST_EQUIP then
		task.spawn(function()
			pcall(function()
				Meta.POST_EQUIP(Arms)
			end)
		end)
	end

	if Meta.ANIM_KEYFRAME_REACHED then
		pcall(function()
			Meta.ANIM_KEYFRAME_REACHED(Arms, "Equip")
		end)

		local CapturedArms = Arms
		local CapturedName = MeleeName

		task.delay(0.35, function()
			if self.Disabled then
				return
			end

			if self.MeleeSkin ~= CapturedName then
				return
			end

			local Current = nil

			pcall(function()
				local Camera = workspace.CurrentCamera
				Current = Camera and Camera:FindFirstChild("Arms")
			end)

			if Current ~= CapturedArms then
				return
			end

			pcall(function()
				Meta.ANIM_KEYFRAME_REACHED(CapturedArms, "Equip")
			end)
		end)
	end
end

function UnlockAll:HookMeleeMeta()
	local Ok, Fn = pcall(function()
		return filtergc("function", {
			IgnoreExecutor = true,
			Name = "CreateViewmodel"
		}, true)
	end)

	if not Ok or type(Fn) ~= "function" then
		return
	end

	local Old
	Old = hookfunction(Fn, function(Gun, Speed)
		local Results = {pcall(Old, Gun, Speed)}

		pcall(function()
			self:ApplySpoofedMetaToArms()
		end)

		local CallOk = table.remove(Results, 1)

		if not CallOk then
			error(Results[1], 2)
		end

		return table.unpack(Results)
	end)
end

function UnlockAll:RemapMeleeSound(SoundVal)
	if self.Disabled then
		return SoundVal
	end

	local OkInst, IsInst = pcall(function()
		return typeof(SoundVal) == "Instance"
	end)

	if not OkInst or not IsInst then
		return SoundVal
	end

	local OkClass, IsStr = pcall(function()
		return SoundVal:IsA("StringValue")
	end)

	if not OkClass or not IsStr then
		return SoundVal
	end

	local Slot = nil

	pcall(function()
		Slot = SoundVal.Name
	end)

	if type(Slot) ~= "string" then
		return SoundVal
	end

	local Allowed = {
		Hit1 = true,
		Hit2 = true,
		Hit3 = true,
		Hit4 = true,
		Hit5 = true,
		Shoot = true,
		Shoot2 = true,
		On = true,
		Idle = true,
		World1 = true,
		World2 = true,
		Taunt = true,
		Equip = true,
	}

	if not Allowed[Slot] then
		return SoundVal
	end

	local IsMeleeView = false

	pcall(function()
		IsMeleeView = self.State.equipped == "melee"
			and (self.State.meleeslot == "Knife" or self.State.meleeslot == "Golden Knife")
	end)

	if not IsMeleeView then
		return SoundVal
	end

	local RealName = nil

	pcall(function()
		local Folder = self.Player:FindFirstChild("Data")
		local MeleeValue = Folder and Folder:FindFirstChild("Melee")
		RealName = MeleeValue and string.split(MeleeValue.Value or "", "_")[1]
	end)

	local Spoof = self.MeleeSkin

	if not self:IsValidMelee(Spoof) then
		return SoundVal
	end

	if type(RealName) ~= "string" or RealName == "" or RealName == Spoof then
		return SoundVal
	end

	local Model = nil

	pcall(function()
		Model = SoundVal.Parent
	end)

	if typeof(Model) ~= "Instance" or Model.Name ~= "Model" then
		return SoundVal
	end

	local HolderName = nil

	pcall(function()
		HolderName = Model.Parent and Model.Parent.Name
	end)

	local Melees = ReplicatedStorage:FindFirstChild("Melees")

	if not Melees then
		return SoundVal
	end

	if HolderName == RealName then
		local SpoofModel = nil

		pcall(function()
			local SpoofFolder = Melees:FindFirstChild(Spoof)
			SpoofModel = SpoofFolder and SpoofFolder:FindFirstChild("Model")
		end)

		local SpoofSlot = SpoofModel and SpoofModel:FindFirstChild(Slot)

		if SpoofSlot then
			return SpoofSlot
		end

		return SoundVal
	end

	local RealValue, CurValue = nil, nil

	pcall(function()
		local RealFolder = Melees:FindFirstChild(RealName)
		local RealModel = RealFolder and RealFolder:FindFirstChild("Model")
		local RealSlot = RealModel and RealModel:FindFirstChild(Slot)
		RealValue = RealSlot and RealSlot.Value
	end)

	pcall(function()
		CurValue = SoundVal.Value
	end)

	if RealValue ~= nil and CurValue ~= nil and RealValue == CurValue then
		local SpoofSlot = nil

		pcall(function()
			local SpoofFolder = Melees:FindFirstChild(Spoof)
			local SpoofModel = SpoofFolder and SpoofFolder:FindFirstChild("Model")
			SpoofSlot = SpoofModel and SpoofModel:FindFirstChild(Slot)
		end)

		if SpoofSlot then
			return SpoofSlot
		end
	end

	return SoundVal
end

function UnlockAll:HookMeleeSounds()
	if self.SoundHooked then
		return
	end

	local Ok, SoundTable = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Sound"))
	end)

	if not Ok or type(SoundTable) ~= "table" then
		return
	end

	local OrigPlay, OrigRPlay = nil, nil

	pcall(function()
		OrigPlay = SoundTable.playsound
	end)

	pcall(function()
		OrigRPlay = SoundTable.rplaysound
	end)

	if type(OrigPlay) ~= "function" then
		return
	end

	self.OrigPlaysound = OrigPlay
	self.OrigRplaysound = OrigRPlay
	self.SoundHooked = true

	SoundTable.playsound = function(A, B, ...)
		if A == SoundTable then
			local Remapped = self:RemapMeleeSound(B)
			return OrigPlay(A, Remapped, ...)
		end

		local Remapped = self:RemapMeleeSound(A)
		return OrigPlay(Remapped, B, ...)
	end

	if type(OrigRPlay) == "function" then
		SoundTable.rplaysound = function(A, B, ...)
			if A == SoundTable then
				local Remapped = self:RemapMeleeSound(B)
				return OrigRPlay(A, Remapped, ...)
			end

			local Remapped = self:RemapMeleeSound(A)
			return OrigRPlay(Remapped, B, ...)
		end
	end
end

function UnlockAll:HookViewmodel()
	local ViewmodelFunction = filtergc("function", {
		IgnoreExecutor = true,
		Name = "getmyvmodel"
	}, true)

	assert(type(ViewmodelFunction) == "function", "getmyvmodel not found")

	hookfunction(ViewmodelFunction, function()
		local CurrentViewmodel = self.State.gun and self.State.gun.Name

		if self.State.gun and self.State.gun:FindFirstChild("Viewmodel") then
			CurrentViewmodel = self.State.gun.Viewmodel.Value
		end

		local PlayerDataFolder = self.Player:FindFirstChild("Data")
		local MeleeValue = PlayerDataFolder and PlayerDataFolder:FindFirstChild("Melee")
		local MeleeName = string.split(MeleeValue and MeleeValue.Value or "", "_")[1]

		if (self.State.meleeslot == "Knife" or self.State.meleeslot == "Golden Knife")
			and self.State.equipped == "melee"
			and PlayerDataFolder
			and (ReplicatedStorage.Melees:FindFirstChild(MeleeName) or MeleeName == "Shuffle") then

			if MeleeName ~= "Shuffle" then
				local SelectedMelee = self.MeleeSkin

				if type(SelectedMelee) == "string" and SelectedMelee ~= "" and self.State.equipped == "melee" then
					local Viewmodels = ReplicatedStorage:FindFirstChild("Viewmodels")

					if Viewmodels and Viewmodels:FindFirstChild("v_" .. SelectedMelee) then
						return SelectedMelee
					end
				end

				return MeleeName
			end
		end

		return CurrentViewmodel
	end)
end

function UnlockAll:HookCharacterUpdates()
	self.Bridge.ChangeVisibleCharacter:Connect(function(Skin)
		if self:IsValidSkin(Skin) and Skin ~= self.Skin then
			self.Skin = Skin
			self:PushAll()
		end
	end)

	self.Bridge.LockerPreviewVoiceline:Connect(function(Announcer)
		if self:IsValidImage("Announcers", Announcer) and Announcer ~= self.Announcer then
			self.Announcer = Announcer
			self:PushAll()
		end
	end)

	self.Bridge.UpdateTracker:Connect(function()
		task.defer(function()
			pcall(function()
				self:AdoptLoadout()
			end)

			pcall(function()
				self:PaintMeleeIcon()
			end)
		end)
	end)

	self.PlayerData.Updated:Connect(function(Key)
		if Key == "Items" then
			task.defer(function()
				self:UnlockAll()
			end)
		end
	end)
end

function UnlockAll:HookInventoryIcon()
	self.Bridge.UpdateInventory:Connect(function()
		task.defer(function()
			if not self.Disabled then
				pcall(function()
					self:PaintMeleeIcon()
				end)
			end
		end)
	end)
end

function UnlockAll:HookInventoryUpdates()
	local Events = ReplicatedStorage:WaitForChild("Events")
	local PartialDataUpdate = Events:WaitForChild("PartialDataUpdate")

	PartialDataUpdate.OnClientEvent:Connect(function()
		task.defer(function()
			if self.Disabled then
				if self.RealState then
					self.PlayerData.Data = self:DeepCopy(self.RealState, 0)
				end

				self.Skin = nil
				self.Announcer = nil
				self.KillEffect = nil
				self.WeaponSkin = nil
				self.MeleeSkin = nil

				return
			end

			self:UnlockAll()

			pcall(function()
				self:AdoptLoadout()
			end)

			pcall(function()
				self:PushAll()
			end)
		end)
	end)
end

function UnlockAll:HookEquipped()
	local EquippedValue = self.Player:FindFirstChild("Equipped") or self.Player:WaitForChild("Equipped", 5)

	if not EquippedValue then
		return
	end

	EquippedValue:GetPropertyChangedSignal("Value"):Connect(function()
		if self.WeaponSkin
			and self:IsValidImage("WeaponSkins", self.WeaponSkin)
			and EquippedValue.Value ~= self.WeaponSkin then
			EquippedValue.Value = self.WeaponSkin
			self:ScheduleWeaponSkinRebuild()
		end
	end)
end

function UnlockAll:HookDataValues()
	for _, ValueName in {"Skin", "Announcer"} do
		local PlayerDataFolder = self.Player:FindFirstChild("Data")
		local DataValue = PlayerDataFolder and PlayerDataFolder:FindFirstChild(ValueName)

		if DataValue then
			DataValue:GetPropertyChangedSignal("Value"):Connect(function()
				task.defer(function()
					self:PushAll()
				end)
			end)
		end
	end
end

function UnlockAll:HookRagdoll()
	local RagdollEvent = ReplicatedStorage:WaitForChild("Events"):WaitForChild("CreateRagdoll")

	for _, Connection in getconnections(RagdollEvent.OnClientEvent) do
		local ConnectedFunction = Connection.Function

		if type(ConnectedFunction) ~= "function" or self.WrappedFunctions[ConnectedFunction] then
			continue
		end

		self.WrappedFunctions[ConnectedFunction] = true

		pcall(function()
			Connection:Disable()
		end)

		RagdollEvent.OnClientEvent:Connect(function(...)
			local ArgumentCount = select("#", ...)
			local Arguments = {...}

			if self.KillEffect and self.KillEffect ~= "None" then
				local Target = Arguments[2]
				local KillerName = Arguments[11]
				if Target ~= self.Player and KillerName == self.Player.Name then
					Arguments[12] = self.KillEffect
				end
			end

			return ConnectedFunction(table.unpack(Arguments, 1, ArgumentCount))
		end)
	end
end

function UnlockAll:HookCharacterAdded()
	self.Player.CharacterAdded:Connect(function()
		for _, Delay in {0.5, 1.5, 3} do
			task.delay(Delay, function()
				self:UnlockAll()
				self:PushAll()
			end)
		end
	end)
end

function UnlockAll:RefreshInventoryUI()
    if self.Disabled then return end
    pcall(function() self:PushAll() end)
    pcall(function() self:PaintMeleeIcon() end)
    if self.WeaponSkin then
        self:ScheduleWeaponSkinRebuild()
    end

    pcall(function() self.Bridge.UpdateInventory:Fire() end)
    pcall(function() self.Bridge.UpdateTracker:Fire() end)
end

function UnlockAll:GetConfig()
	return {
		Disabled = self.Disabled and true or false,
		Skin = self.Skin,
		Announcer = self.Announcer,
		KillEffect = self.KillEffect,
		WeaponSkin = self.WeaponSkin,
		MeleeSkin = self.MeleeSkin,
	}
end

function UnlockAll:LoadConfig(Data)
    if type(Data) ~= "table" then return end
    if Data.Disabled then
        if not self.Disabled then self:Disable() end
        return
    end
    if self.Disabled then self:Enable() end
    if type(Data.Skin) == "string" then self:Equip("Skin", Data.Skin) end
    if type(Data.Announcer) == "string" then self:Equip("Announcer", Data.Announcer) end
    if type(Data.KillEffect) == "string" then self:Equip("KillEffect", Data.KillEffect) end
    if type(Data.WeaponSkin) == "string" then self:Equip("WeaponSkin", Data.WeaponSkin) end
    if type(Data.MeleeSkin) == "string" then self:Equip("MeleeSkin", Data.MeleeSkin) end

    task.defer(function() self:RefreshInventoryUI() end)
    task.delay(0.2, function()
        if not self.Disabled then self:RefreshInventoryUI() end
    end)
end

return UnlockAll.new()