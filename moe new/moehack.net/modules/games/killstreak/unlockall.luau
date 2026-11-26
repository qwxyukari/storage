-- messi messi messi messi

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkinRegistry = require(Shared:WaitForChild("SkinRegistry"))
local WeaponRegistry = require(Shared:WaitForChild("WeaponRegistry"))
local UtilityRegistry = require(Shared:WaitForChild("UtilityRegistry"))

local UnlockAll = {}
UnlockAll.__index = UnlockAll

local ScriptVersion = 6

function UnlockAll.new()
    local self = setmetatable({}, UnlockAll)

    self.FakePrefix = "FAKE_"
    self.SlotNames = { "Primary", "Secondary", "Melee" }
    self.SlotFallbackName = { Primary = "Rebel", Secondary = "Compact", Melee = "Knife" }
    self.BestVariantOrder = {
        "Sapphire",
        "FireIce",
        "FireIceFade",
        "Gold",
        "Rainbow",
        "RainbowFade",
        "Ocean",
        "Blue",
        "Red",
        "Purple",
        "Pink",
        "Green",
        "Cyan",
        "Silver",
        "Amethyst",
        "Electro",
        "Pyro",
        "Myst",
        "Arctic",
        "SharkFade",
        "PoisonFade",
        "PurpleFade",
        "RedFade",
        "GreenFade",
        "Greyscale",
        "Corrupted",
        "Dark",
        "V3",
        "V2",
    }
    self.DefaultOwnedWeapons = { "Rebel", "Compact", "Knife", "FragGrenade" }
    self.LastOwnershipRefresh = 0
    self.OwnershipRefreshInterval = 180

    self.PlayerDataClient = nil
    self.MenuLoadout = nil
    self.WeaponClient = nil
    self.Network = nil
    self.SharedState = nil

    self.OriginalGet = nil
    self.OriginalIsItemUnlocked = nil
    self.OriginalUpdateSlot = nil
    self.OriginalApplySkin = nil
    self.OriginalOnSync = nil
    self.OriginalOnPatch = nil
    self.OriginalOnSyncAll = nil
    self.OriginalSendEquipState = nil
    self.OriginalGetAuthorityMetadata = nil

    self.ServerOwnedWeapons = {}
    self.ServerWeaponNames = {
        Rebel = true,
        Compact = true,
        Knife = true
    }
    self.ServerUtilityNames = {
        FragGrenade = true
    }

    self.ServerEquipped = {}
    self.ServerSkins = {}
    self.DesiredEquipped = {}
    self.DesiredSkins = {}
    self.DesiredObserver = nil

    self.ExcludedSkins = {
        ["Bayonet_GunGame_Gold"] = true,
    }

    return self
end

function UnlockAll:GetPlayerDataClient()
    local Candidates = filtergc("table", {
        Keys = { "Data", "DataReady" }
    })

    for _, Candidate in Candidates do
        if Candidate.DataReady == true then
            return Candidate
        end
    end

    return nil
end

function UnlockAll:GetMenuLoadout()
    return filtergc("table", {
        Keys = { "OwnedWeaponSkins", "CurrentSlot" }
    }, true)
end

function UnlockAll:GetWeaponClient()
    local Single = filtergc("table", {
        Keys = { "Inventory", "sendEquipState" }
    }, true)

    if Single then
        return Single
    end

    local Candidates = filtergc("table", {
        Keys = { "Inventory" }
    })

    for _, Candidate in Candidates do
        if type(Candidate.sendEquipState) == "function" and type(Candidate.getAuthorityMetadata) == "function" then
            return Candidate
        end
    end

    return nil
end

function UnlockAll:GetNetwork()
    local Candidates = filtergc("table", {
        Keys = { "FireServer", "InvokeServer" }
    })

    for _, Candidate in Candidates do
        if type(Candidate.FireServer) == "function" and type(Candidate.InvokeServer) == "function" then
            return Candidate
        end
    end

    return nil
end

function UnlockAll:GetSharedState()
    if type(getgenv) ~= "function" then
        return nil
    end

    local Env = getgenv()
    Env.KillstreakUnlockAll = Env.KillstreakUnlockAll or {}
    return Env.KillstreakUnlockAll
end

function UnlockAll:AdoptSharedState()
    local State = self.SharedState

    if not State or State.Enabled ~= true then
        return
    end

    if State.JobId and State.JobId ~= game.JobId then
        return
    end

    self.OriginalGet = State.OriginalGet or self.OriginalGet
    self.OriginalOnSync = State.OriginalOnSync or self.OriginalOnSync
    self.OriginalOnPatch = State.OriginalOnPatch or self.OriginalOnPatch
    self.OriginalOnSyncAll = State.OriginalOnSyncAll or self.OriginalOnSyncAll
    self.OriginalSendEquipState = State.OriginalSendEquipState or self.OriginalSendEquipState
    self.OriginalGetAuthorityMetadata = State.OriginalGetAuthorityMetadata or self.OriginalGetAuthorityMetadata
    self.OriginalIsItemUnlocked = State.OriginalIsItemUnlocked or self.OriginalIsItemUnlocked
    self.OriginalUpdateSlot = State.OriginalUpdateSlot or self.OriginalUpdateSlot
    self.OriginalApplySkin = State.OriginalApplySkin or self.OriginalApplySkin
    self.DesiredObserver = State.DesiredObserver or self.DesiredObserver
    self.DesiredEquipped = State.DesiredEquipped or self.DesiredEquipped
    self.DesiredSkins = State.DesiredSkins or self.DesiredSkins
end

function UnlockAll:StoreSharedState()
    local State = self.SharedState

    if not State then
        return
    end

    State.Enabled = true
    State.JobId = game.JobId
    State.OriginalGet = self.OriginalGet
    State.OriginalOnSync = self.OriginalOnSync
    State.OriginalOnPatch = self.OriginalOnPatch
    State.OriginalOnSyncAll = self.OriginalOnSyncAll
    State.OriginalSendEquipState = self.OriginalSendEquipState
    State.OriginalGetAuthorityMetadata = self.OriginalGetAuthorityMetadata
    State.OriginalIsItemUnlocked = self.OriginalIsItemUnlocked
    State.OriginalUpdateSlot = self.OriginalUpdateSlot
    State.OriginalApplySkin = self.OriginalApplySkin
    State.DesiredObserver = self.DesiredObserver
    State.DesiredEquipped = self.DesiredEquipped
    State.DesiredSkins = self.DesiredSkins
    State.Version = ScriptVersion
end

function UnlockAll:GetAllWeapons()
    local AllWeapons = {}

    for _, Slot in WeaponRegistry:getSlotTypes() do
        for _, WeaponName in WeaponRegistry:getWeaponsForSlot(Slot) do
            AllWeapons[WeaponName] = true
        end
    end

    return AllWeapons
end

function UnlockAll:GetAllUtility()
    local AllUtility = {}
    local AllEntries = UtilityRegistry:getAll()

    for _, Entry in AllEntries do
        local UtilityName = Entry

        if type(Entry) == "table" then
            UtilityName = Entry.Name or Entry.Id
        end

        if type(UtilityName) == "string" and UtilityName ~= "" then
            AllUtility[UtilityName] = true
        end
    end

    AllUtility["FragGrenade"] = true
    return AllUtility
end

function UnlockAll:MergeServerUnlocks(UnlockedItems)
    if type(UnlockedItems) ~= "table" then
        return 0
    end

    local Added = 0
    local Weapons = UnlockedItems.Weapons

    if type(Weapons) == "table" then
        for WeaponName in Weapons do
            if not self.ServerOwnedWeapons[WeaponName] then
                Added += 1
            end

            self.ServerOwnedWeapons[WeaponName] = true
            self.ServerWeaponNames[WeaponName] = true
        end
    end

    local Utility = UnlockedItems.Utility

    if type(Utility) == "table" then
        for UtilityName in Utility do
            if not self.ServerOwnedWeapons[UtilityName] then
                Added += 1
            end

            self.ServerOwnedWeapons[UtilityName] = true
            self.ServerUtilityNames[UtilityName] = true
        end
    end

    return Added
end

function UnlockAll:MergeUnlockedName(Name)
    if type(Name) ~= "string" or Name == "" then
        return
    end

    self.ServerOwnedWeapons[Name] = true

    if WeaponRegistry:getIdByName(Name) ~= nil then
        self.ServerWeaponNames[Name] = true
    else
        self.ServerUtilityNames[Name] = true
    end
end

function UnlockAll:MergeUnlockedPatch(Patch)
    if type(Patch) ~= "table" then
        return 0
    end

    local Before = 0

    for Name in self.ServerOwnedWeapons do
        Before += 1
    end

    self:MergeServerUnlocks(Patch.Value)

    if type(Patch.Value) == "table" then
        for Name, Flag in Patch.Value do
            if Flag == true and type(Name) == "string" and Name ~= "Weapons" and Name ~= "Utility" then
                self:MergeUnlockedName(Name)
            end
        end
    elseif Patch.Value == true then
        self:MergeUnlockedName(Patch.EntryKey)
    end

    local After = 0

    for Name in self.ServerOwnedWeapons do
        After += 1
    end

    return After - Before
end

function UnlockAll:RefreshUnlockedMenu()
    if not self.MenuLoadout then
        return
    end

    self:Refresh(self.MenuLoadout, "refreshOwnedCosmeticsCache")
    self:Refresh(self.MenuLoadout, "refreshLoadoutData")
    self:Refresh(self.MenuLoadout, "loadoutweapon_init")
end

function UnlockAll:RefreshOwnership()
    if not self.Network then
        self.Network = self:GetNetwork()
    end

    if not self.Network then
        return
    end

    local Success, Data = pcall(function()
        return self.Network:InvokeServer("PlayerData:GetDataFromPlayer", LocalPlayer)
    end)

    if not Success or type(Data) ~= "table" then
        return
    end

    if self:MergeServerUnlocks(Data.UnlockedItems) > 0 then
        self:RefreshUnlockedMenu()
        self:FireUpdated("UnlockedItems")
    end

    self.LastOwnershipRefresh = os.clock()
end

function UnlockAll:PickBestVariant(SkinData)
    if type(SkinData) ~= "table" or type(SkinData.Variants) ~= "table" then
        return nil
    end

    for _, VariantName in self.BestVariantOrder do
        if SkinData.Variants[VariantName] ~= nil then
            return VariantName
        end
    end

    return nil
end

function UnlockAll:FetchServerTruth()
    for _, WeaponName in self.DefaultOwnedWeapons do
        self.ServerOwnedWeapons[WeaponName] = true
    end

    self.Network = self.Network or self:GetNetwork()

    if not self.Network or not self.PlayerDataClient then
        return
    end

    local Success, Data = pcall(function()
        return self.Network:InvokeServer("PlayerData:GetDataFromPlayer", LocalPlayer)
    end)

    if not Success or type(Data) ~= "table" then
        return
    end

    local UnlockedItems = Data.UnlockedItems

    self:MergeServerUnlocks(UnlockedItems)
    self.LastOwnershipRefresh = os.clock()

    local Equipped = Data.Equipped

    if type(Equipped) == "table" then
        for Slot, Value in Equipped do
            self.ServerEquipped[Slot] = Value
        end
    end

    local EquippedCosmetics = Data.EquippedCosmetics

    if type(EquippedCosmetics) == "table" then
        local WeaponSkins = EquippedCosmetics.WeaponSkins

        if type(WeaponSkins) == "table" then
            for WeaponName, SkinUuid in WeaponSkins do
                self.ServerSkins[WeaponName] = SkinUuid
            end
        end
    end
end

function UnlockAll:IsServerOwned(WeaponName)
    return self.ServerOwnedWeapons[WeaponName] == true
end

function UnlockAll:IsExcludedSkinId(CosmeticId)
    if type(CosmeticId) ~= "string" then
        return false
    end

    if self.ExcludedSkins[CosmeticId] == true then
        return true
    end

    return string.find(CosmeticId, "Bayonet_GunGame_Gold", 1, true) ~= nil
end

function UnlockAll:GetCosmeticIdForUuid(Uuid)
    if type(Uuid) ~= "string" then
        return nil
    end

    if self.PlayerDataClient == nil then
        return nil
    end

    local Data = self.PlayerDataClient.Data

    if type(Data) ~= "table" or type(Data.CosmeticInventory) ~= "table" then
        return nil
    end

    local Entry = Data.CosmeticInventory[Uuid]

    if type(Entry) == "table" and type(Entry.CosmeticId) == "string" then
        return Entry.CosmeticId
    end

    return nil
end

function UnlockAll:GetEquippedSkinUuid(WeaponName)
    if type(WeaponName) ~= "string" then
        return nil
    end

    local Uuid = self.DesiredSkins[WeaponName]

    if Uuid ~= nil then
        return Uuid
    end

    if self.PlayerDataClient ~= nil then
        local Data = self.PlayerDataClient.Data

        if type(Data) == "table" and type(Data.EquippedCosmetics) == "table" and type(Data.EquippedCosmetics.WeaponSkins) == "table" then
            Uuid = Data.EquippedCosmetics.WeaponSkins[WeaponName]

            if Uuid ~= nil then
                return Uuid
            end
        end
    end

    if self.MenuLoadout ~= nil and type(self.MenuLoadout.EquippedCosmetics) == "table" then
        Uuid = self.MenuLoadout.EquippedCosmetics[WeaponName]

        if Uuid ~= nil then
            return Uuid
        end
    end

    return self.ServerSkins[WeaponName]
end

function UnlockAll:HasExcludedSkin(Weapon)
    if type(Weapon) ~= "table" or type(Weapon.Name) ~= "string" then
        return false
    end

    for _, Value in pairs(Weapon) do
        if type(Value) == "string" and self:IsExcludedSkinId(Value) then
            return true
        end
    end

    local SkinUuid = self:GetEquippedSkinUuid(Weapon.Name)

    if type(SkinUuid) == "string" then
        if self:IsExcludedSkinId(SkinUuid) then
            return true
        end

        if self:IsExcludedSkinId(self:GetCosmeticIdForUuid(SkinUuid)) then
            return true
        end
    end

    return false
end

function UnlockAll:ResolveReportId(Weapon)
    if type(Weapon) ~= "table" or type(Weapon.Name) ~= "string" then
        return nil
    end

    local RealId = WeaponRegistry:getIdByName(Weapon.Name)

    if Weapon.SlotType ~= "Melee" then
        return RealId
    end

    if self:HasExcludedSkin(Weapon) then
        return RealId
    end

    if self:IsServerOwned(Weapon.Name) then
        return RealId
    end

    local FallbackId = WeaponRegistry:getIdByName(self.SlotFallbackName.Melee)

    if FallbackId ~= nil then
        return FallbackId
    end

    return RealId
end

function UnlockAll:EnsureUnlockedItems(Data)
    if type(Data) ~= "table" then
        return
    end

    Data.UnlockedItems = Data.UnlockedItems or {}
    Data.UnlockedItems.Weapons = Data.UnlockedItems.Weapons or {}

    for WeaponName in self:GetAllWeapons() do
        Data.UnlockedItems.Weapons[WeaponName] = true
    end

    Data.UnlockedItems.Utility = Data.UnlockedItems.Utility or {}

    for UtilityName in self:GetAllUtility() do
        Data.UnlockedItems.Utility[UtilityName] = true
    end
end

function UnlockAll:EnsureCosmeticInventory(Data)
    if type(Data) ~= "table" then
        return 0
    end

    Data.CosmeticInventory = Data.CosmeticInventory or {}

    local CosmeticInventory = Data.CosmeticInventory

    local AddedCount = 0

    for Uuid, Entry in CosmeticInventory do
        if type(Uuid) == "string" and string.sub(Uuid, 1, #self.FakePrefix) == self.FakePrefix then
            local CosmeticId = nil

            if type(Entry) == "table" then
                CosmeticId = Entry.CosmeticId
            end

            if self:IsExcludedSkinId(Uuid) or self:IsExcludedSkinId(CosmeticId) then
                CosmeticInventory[Uuid] = nil
            end
        end
    end

    if type(Data.EquippedCosmetics) == "table" and type(Data.EquippedCosmetics.WeaponSkins) == "table" then
        for WeaponName, SkinUuid in Data.EquippedCosmetics.WeaponSkins do
            if type(SkinUuid) == "string" and string.sub(SkinUuid, 1, #self.FakePrefix) == self.FakePrefix and self:IsExcludedSkinId(SkinUuid) then
                Data.EquippedCosmetics.WeaponSkins[WeaponName] = "DEFAULT_" .. WeaponName
            end
        end
    end

    for WeaponName, SkinUuid in self.DesiredSkins do
        if type(SkinUuid) == "string" and string.sub(SkinUuid, 1, #self.FakePrefix) == self.FakePrefix and self:IsExcludedSkinId(SkinUuid) then
            self.DesiredSkins[WeaponName] = "DEFAULT_" .. WeaponName
        end
    end

    if self.MenuLoadout ~= nil and type(self.MenuLoadout.EquippedCosmetics) == "table" then
        for WeaponName, SkinUuid in self.MenuLoadout.EquippedCosmetics do
            if type(SkinUuid) == "string" and string.sub(SkinUuid, 1, #self.FakePrefix) == self.FakePrefix and self:IsExcludedSkinId(SkinUuid) then
                self.MenuLoadout.EquippedCosmetics[WeaponName] = "DEFAULT_" .. WeaponName
            end
        end
    end

    for _, SkinData in SkinRegistry do
        if type(SkinData) ~= "table" then
            continue
        end

        local CosmeticId = SkinData.CosmeticId

        if type(CosmeticId) ~= "string" or CosmeticId == "" then
            continue
        end

        if self:IsExcludedSkinId(CosmeticId) then
            continue
        end

        if CosmeticId == "GunGame_Gold" and type(SkinData.AppliesTo) == "string" and string.find(SkinData.AppliesTo, "Bayonet", 1, true) ~= nil then
            continue
        end

        if type(SkinData.Variants) == "table" then
            local BareUuid = self.FakePrefix .. CosmeticId
            local BareEntry = CosmeticInventory[BareUuid]
            local BareVariant = nil

            if type(BareEntry) == "table" then
                BareVariant = BareEntry.Variant
            end

            CosmeticInventory[BareUuid] = nil

            for VariantName in SkinData.Variants do
                local FakeUuid = BareUuid .. "__" .. tostring(VariantName)

                if CosmeticInventory[FakeUuid] == nil then
                    CosmeticInventory[FakeUuid] = {
                        CosmeticId = CosmeticId,
                        Variant = tostring(VariantName),
                        ObtainedAt = 0,
                        ObtainedFrom = {
                            Type = "UnlockAll"
                        }
                    }

                    AddedCount += 1
                end
            end

            local KeepVariant = BareVariant

            if KeepVariant == nil or SkinData.Variants[KeepVariant] == nil then
                KeepVariant = self:PickBestVariant(SkinData)
            end

            if KeepVariant ~= nil then
                local KeepUuid = BareUuid .. "__" .. KeepVariant

                for WeaponName, SkinUuid in self.DesiredSkins do
                    if SkinUuid == BareUuid then
                        self.DesiredSkins[WeaponName] = KeepUuid
                    end
                end

                if type(Data.EquippedCosmetics) == "table" and type(Data.EquippedCosmetics.WeaponSkins) == "table" then
                    for WeaponName, SkinUuid in Data.EquippedCosmetics.WeaponSkins do
                        if SkinUuid == BareUuid then
                            Data.EquippedCosmetics.WeaponSkins[WeaponName] = KeepUuid
                        end
                    end
                end

                if self.MenuLoadout and type(self.MenuLoadout.EquippedCosmetics) == "table" then
                    for WeaponName, SkinUuid in self.MenuLoadout.EquippedCosmetics do
                        if SkinUuid == BareUuid then
                            self.MenuLoadout.EquippedCosmetics[WeaponName] = KeepUuid
                        end
                    end
                end
            end

            continue
        end

        local FakeUuid = self.FakePrefix .. CosmeticId

        if CosmeticInventory[FakeUuid] == nil then
            CosmeticInventory[FakeUuid] = {
                CosmeticId = CosmeticId,
                ObtainedAt = 0,
                ObtainedFrom = {
                    Type = "UnlockAll"
                }
            }

            AddedCount += 1
        end
    end

    return AddedCount
end

function UnlockAll:NoteDesiredFromLocal()
    if not self.PlayerDataClient then
        return
    end

    local Data = self.PlayerDataClient.Data

    if type(Data) ~= "table" then
        return
    end

    local Equipped = Data.Equipped

    if type(Equipped) == "table" then
        for Slot, Value in Equipped do
            if Value ~= nil and self.ServerEquipped[Slot] ~= Value then
                self.DesiredEquipped[Slot] = Value
            end
        end
    end

    local EquippedCosmetics = Data.EquippedCosmetics

    if type(EquippedCosmetics) == "table" then
        local WeaponSkins = EquippedCosmetics.WeaponSkins

        if type(WeaponSkins) == "table" then
            for WeaponName, SkinUuid in WeaponSkins do
                if SkinUuid ~= nil and self.ServerSkins[WeaponName] ~= SkinUuid then
                    self.DesiredSkins[WeaponName] = SkinUuid
                end
            end
        end
    end
end

function UnlockAll:RestoreDesired()
    if not self.PlayerDataClient then
        return false
    end

    local Data = self.PlayerDataClient.Data

    if type(Data) ~= "table" then
        return false
    end

    self:EnsureUnlockedItems(Data)
    self:EnsureCosmeticInventory(Data)

    local Changed = false

    Data.Equipped = Data.Equipped or {}

    for Slot, Value in self.DesiredEquipped do
        if Data.Equipped[Slot] ~= Value then
            Data.Equipped[Slot] = Value
            Changed = true
        end
    end

    Data.EquippedCosmetics = Data.EquippedCosmetics or {}
    Data.EquippedCosmetics.WeaponSkins = Data.EquippedCosmetics.WeaponSkins or {}

    local WeaponSkins = Data.EquippedCosmetics.WeaponSkins

    for WeaponName, SkinUuid in self.DesiredSkins do
        if WeaponSkins[WeaponName] ~= SkinUuid then
            WeaponSkins[WeaponName] = SkinUuid
            Changed = true
        end
    end

    return Changed
end

function UnlockAll:Refresh(Target, Method, Argument)
    if Target == nil then
        return
    end

    local Refresh = Target[Method]

    if type(Refresh) ~= "function" then
        return
    end

    if Argument ~= nil then
        pcall(Refresh, Target, Argument)
    else
        pcall(Refresh, Target)
    end
end

function UnlockAll:FireUpdated(Key)
    if not self.PlayerDataClient then
        return
    end

    local Updated = self.PlayerDataClient.Updated

    if Updated and Updated.Fire then
        Updated:Fire(Key)
    end
end

function UnlockAll:ApplyWeaponLocal(Slot, WeaponName)
    if not self.PlayerDataClient then
        return
    end

    local Data = self.PlayerDataClient.Data

    if type(Data) ~= "table" then
        return
    end

    Data.Equipped = Data.Equipped or {}
    Data.Equipped[Slot] = WeaponName
    self.DesiredEquipped[Slot] = WeaponName

    if not self.MenuLoadout then
        return
    end

    self.MenuLoadout.Equipped = self.MenuLoadout.Equipped or {}
    self.MenuLoadout.Equipped[Slot] = WeaponName

    local ActiveIndex = self.MenuLoadout.ActiveLoadoutIndex or Data.ActiveLoadoutIndex or 1
    local Loadouts = self.MenuLoadout.Loadouts

    if type(Loadouts) ~= "table" or type(Loadouts[ActiveIndex]) ~= "table" then
        return
    end

    local Loadout = Loadouts[ActiveIndex]
    Loadout[Slot] = WeaponName

    if Slot ~= "Utility" then
        Loadout.WeaponSkins = Loadout.WeaponSkins or {}

        local SkinUuid = nil
        local EquippedCosmetics = self.MenuLoadout.EquippedCosmetics

        if type(EquippedCosmetics) == "table" then
            SkinUuid = EquippedCosmetics[WeaponName]
        end

        Loadout.WeaponSkins[Slot] = SkinUuid or ("DEFAULT_" .. WeaponName)
    end
end

function UnlockAll:ApplySkinLocal(WeaponName, SkinUuid)
    if not self.PlayerDataClient then
        return
    end

    local Data = self.PlayerDataClient.Data

    if type(Data) ~= "table" then
        return
    end

    if SkinUuid == nil or SkinUuid == "" then
        SkinUuid = "DEFAULT_" .. WeaponName
    end

    Data.EquippedCosmetics = Data.EquippedCosmetics or {}
    Data.EquippedCosmetics.WeaponSkins = Data.EquippedCosmetics.WeaponSkins or {}
    Data.EquippedCosmetics.WeaponSkins[WeaponName] = SkinUuid

    self.DesiredSkins[WeaponName] = SkinUuid

    if not self.MenuLoadout then
        return
    end

    if type(self.MenuLoadout.EquippedCosmetics) ~= "table" then
        return
    end

    self.MenuLoadout.EquippedCosmetics[WeaponName] = SkinUuid

    local ActiveIndex = self.MenuLoadout.ActiveLoadoutIndex or Data.ActiveLoadoutIndex or 1
    local Loadouts = self.MenuLoadout.Loadouts

    if type(Loadouts) ~= "table" or type(Loadouts[ActiveIndex]) ~= "table" then
        return
    end

    local Loadout = Loadouts[ActiveIndex]
    Loadout.WeaponSkins = Loadout.WeaponSkins or {}

    for _, Slot in self.SlotNames do
        if Loadout[Slot] == WeaponName then
            Loadout.WeaponSkins[Slot] = SkinUuid
        end
    end
end

function UnlockAll:PatchPlayerDataGet()
    if not self.PlayerDataClient or self.OriginalGet ~= nil then
        return
    end

    self.OriginalGet = self.PlayerDataClient.get

    self.PlayerDataClient.get = function(Client, Key)
        local Result = self.OriginalGet(Client, Key)

        if Key == "UnlockedItems" then
            if type(Result) ~= "table" then
                return Result
            end

            Result.Weapons = Result.Weapons or {}

            for WeaponName in self:GetAllWeapons() do
                Result.Weapons[WeaponName] = true
            end

            Result.Utility = Result.Utility or {}

            for UtilityName in self:GetAllUtility() do
                Result.Utility[UtilityName] = true
            end

            if os.clock() - self.LastOwnershipRefresh > self.OwnershipRefreshInterval then
                self.LastOwnershipRefresh = os.clock()

                task.spawn(function()
                    pcall(function()
                        self:RefreshOwnership()
                    end)
                end)
            end

            return Result
        end

        if Key == "CosmeticInventory" then
            if self.PlayerDataClient and self.PlayerDataClient.Data then
                self:EnsureCosmeticInventory(self.PlayerDataClient.Data)
            end

            return self.OriginalGet(Client, Key)
        end

        return Result
    end
end

function UnlockAll:PatchPlayerDataSync()
    if not self.PlayerDataClient then
        return
    end

    if self.OriginalOnSync == nil and type(self.PlayerDataClient.onSync) == "function" then
        self.OriginalOnSync = self.PlayerDataClient.onSync

        self.PlayerDataClient.onSync = function(Key, Value)
            self.OriginalOnSync(Key, Value)

            if Key == "UnlockedItems" and type(Value) == "table" then
                if self:MergeServerUnlocks(Value) > 0 then
                    self:RefreshUnlockedMenu()
                end
            elseif Key == "Equipped" and type(Value) == "table" then
                for Slot, Incoming in Value do
                    if Incoming ~= self.ServerEquipped[Slot] and self.DesiredEquipped[Slot] ~= Incoming then
                        self.ServerEquipped[Slot] = Incoming

                        if self.DesiredEquipped[Slot] ~= nil and Incoming == self.ServerEquipped[Slot] then
                            self.DesiredEquipped[Slot] = nil
                        end
                    end
                end
            end

            if self:RestoreDesired() then
                self:FireUpdated(Key)
            end
        end
    end

    if self.OriginalOnPatch == nil and type(self.PlayerDataClient.onPatch) == "function" then
        self.OriginalOnPatch = self.PlayerDataClient.onPatch

        self.PlayerDataClient.onPatch = function(Key, Patch)
            self.OriginalOnPatch(Key, Patch)

            if Key == "UnlockedItems" then
                if self:MergeUnlockedPatch(Patch) > 0 then
                    self:RefreshUnlockedMenu()
                end
            end

            if self:RestoreDesired() then
                self:FireUpdated(Key)
            end
        end
    end

    if self.OriginalOnSyncAll == nil and type(self.PlayerDataClient.onSyncAll) == "function" then
        self.OriginalOnSyncAll = self.PlayerDataClient.onSyncAll

        self.PlayerDataClient.onSyncAll = function(NewData)
            self.OriginalOnSyncAll(NewData)

            if type(NewData) == "table" then
                if self:MergeServerUnlocks(NewData.UnlockedItems) > 0 then
                    self:RefreshUnlockedMenu()
                end
            end

            if self:RestoreDesired() then
                self:FireUpdated(nil)
            end
        end
    end
end

function UnlockAll:ObserveDesired()
    if not self.PlayerDataClient or self.DesiredObserver ~= nil then
        return
    end

    local Updated = self.PlayerDataClient.Updated

    if Updated and Updated.Connect then
        self.DesiredObserver = Updated:Connect(function(Key)
            if Key == "Equipped" or Key == "EquippedCosmetics" or Key == nil then
                pcall(function()
                    self:NoteDesiredFromLocal()
                end)
            end
        end)
    end
end

function UnlockAll:PatchWeaponAuthority()
    self.WeaponClient = self.WeaponClient or self:GetWeaponClient()

    if not self.WeaponClient then
        return
    end

    self.Network = self.Network or self:GetNetwork()

    if self.OriginalSendEquipState == nil and type(self.WeaponClient.sendEquipState) == "function" then
        self.OriginalSendEquipState = self.WeaponClient.sendEquipState

        self.WeaponClient.sendEquipState = function(Client, Weapon, SlotId)
            local ReportId = self:ResolveReportId(Weapon)

            if ReportId == nil or self.Network == nil then
                return self.OriginalSendEquipState(Client, Weapon, SlotId)
            end

            local Success, EquipSeq = pcall(function()
                return Client:nextSequence("EquipSeq")
            end)

            if not Success or EquipSeq == nil then
                return self.OriginalSendEquipState(Client, Weapon, SlotId)
            end

            Weapon.AuthorityEquipSeq = EquipSeq
            Weapon.AuthorityWeaponId = ReportId
            Weapon.AuthoritySlotId = SlotId

            local TimeA, TimeB = Client:getServerTimeMs()

            self.Network:FireServer("Weapon:EquipState", EquipSeq, SlotId, ReportId, TimeA, TimeB)
            return nil
        end
    end

    if self.OriginalGetAuthorityMetadata == nil and type(self.WeaponClient.getAuthorityMetadata) == "function" then
        self.OriginalGetAuthorityMetadata = self.WeaponClient.getAuthorityMetadata

        self.WeaponClient.getAuthorityMetadata = function(Client, Weapon)
            local ShotSeq, EquipSeq, RealId, Time = self.OriginalGetAuthorityMetadata(Client, Weapon)
            local ReportId = self:ResolveReportId(Weapon)

            if ReportId == nil then
                return ShotSeq, EquipSeq, RealId, Time
            end

            return ShotSeq, EquipSeq, ReportId, Time
        end
    end
end

function UnlockAll:PatchMenuLoadout()
    self.MenuLoadout = self.MenuLoadout or self:GetMenuLoadout()

    if not self.MenuLoadout then
        return
    end

    if self.OriginalIsItemUnlocked == nil and type(self.MenuLoadout.isItemUnlocked) == "function" then
        self.OriginalIsItemUnlocked = self.MenuLoadout.isItemUnlocked
    end

    self.MenuLoadout.isItemUnlocked = function()
        return true
    end

    if self.OriginalUpdateSlot == nil and type(self.MenuLoadout.updateSlot) == "function" then
        self.OriginalUpdateSlot = self.MenuLoadout.updateSlot

        self.MenuLoadout.updateSlot = function(Menu, Slot, WeaponName, Options)
            self:ApplyWeaponLocal(Slot, WeaponName)
            self:Refresh(Menu, "loadoutweapon_init")

            if Slot == Menu.CurrentSlot then
                if Options and Options.SkipCurrentSlotRefresh then
                    self:FireUpdated("Equipped")
                    return true
                end

                self:Refresh(Menu, "selectSlot", Slot)
            end

            self:FireUpdated("Equipped")

            task.spawn(function()
                pcall(self.OriginalUpdateSlot, Menu, Slot, WeaponName, Options)
            end)

            return true
        end
    end

    if self.OriginalApplySkin == nil and type(self.MenuLoadout.applySkin) == "function" then
        self.OriginalApplySkin = self.MenuLoadout.applySkin

        self.MenuLoadout.applySkin = function(Menu, WeaponName, SkinUuid, Options)
            self:ApplySkinLocal(WeaponName, SkinUuid)
            self:Refresh(Menu, "loadoutweapon_init")

            if WeaponName == Menu.CurrentWeaponName and not (Options and Options.SkipPreviewRefresh) then
                self:Refresh(Menu, "view_weapon", {
                    WeaponName = WeaponName
                })
            end

            self:FireUpdated("EquippedCosmetics")

            task.spawn(function()
                pcall(self.OriginalApplySkin, Menu, WeaponName, SkinUuid, Options)
            end)

            return true, SkinUuid
        end
    end

    self.MenuLoadout._cosmeticCacheDirty = true
end

function UnlockAll:RestorePatchedFunctions()
    if self.OriginalGet ~= nil then
        pcall(function()
            self.PlayerDataClient.get = self.OriginalGet
        end)
    end

    if self.OriginalOnSync ~= nil then
        pcall(function()
            self.PlayerDataClient.onSync = self.OriginalOnSync
        end)
    end

    if self.OriginalOnPatch ~= nil then
        pcall(function()
            self.PlayerDataClient.onPatch = self.OriginalOnPatch
        end)
    end

    if self.OriginalOnSyncAll ~= nil then
        pcall(function()
            self.PlayerDataClient.onSyncAll = self.OriginalOnSyncAll
        end)
    end

    if self.WeaponClient then
        if self.OriginalSendEquipState ~= nil then
            pcall(function()
                self.WeaponClient.sendEquipState = self.OriginalSendEquipState
            end)
        end

        if self.OriginalGetAuthorityMetadata ~= nil then
            pcall(function()
                self.WeaponClient.getAuthorityMetadata = self.OriginalGetAuthorityMetadata
            end)
        end
    end

    if self.MenuLoadout then
        if self.OriginalIsItemUnlocked ~= nil then
            pcall(function()
                self.MenuLoadout.isItemUnlocked = self.OriginalIsItemUnlocked
            end)
        end

        if self.OriginalUpdateSlot ~= nil then
            pcall(function()
                self.MenuLoadout.updateSlot = self.OriginalUpdateSlot
            end)
        end

        if self.OriginalApplySkin ~= nil then
            pcall(function()
                self.MenuLoadout.applySkin = self.OriginalApplySkin
            end)
        end

        self.MenuLoadout._cosmeticCacheDirty = true
    end

    if self.DesiredObserver ~= nil then
        pcall(function()
            self.DesiredObserver:Disconnect()
        end)
    end

    self.OriginalGet = nil
    self.OriginalIsItemUnlocked = nil
    self.OriginalUpdateSlot = nil
    self.OriginalApplySkin = nil
    self.OriginalOnSync = nil
    self.OriginalOnPatch = nil
    self.OriginalOnSyncAll = nil
    self.OriginalSendEquipState = nil
    self.OriginalGetAuthorityMetadata = nil
    self.DesiredObserver = nil
end

function UnlockAll:Disable()
    self.SharedState = self.SharedState or self:GetSharedState()
    self:AdoptSharedState()

    self.PlayerDataClient = self.PlayerDataClient or self:GetPlayerDataClient()

    if not self.PlayerDataClient then
        return false
    end

    self.MenuLoadout = self.MenuLoadout or self:GetMenuLoadout()
    self.WeaponClient = self.WeaponClient or self:GetWeaponClient()

    self:RestorePatchedFunctions()

    self.DesiredEquipped = {}
    self.DesiredSkins = {}
    self.Network = self:GetNetwork()

    if self.Network ~= nil then
        local Success, Fresh = pcall(function()
            return self.Network:InvokeServer("PlayerData:GetDataFromPlayer", LocalPlayer)
        end)

        if Success and type(Fresh) == "table" then
            local Data = self.PlayerDataClient.Data

            if type(Data) == "table" then
                if type(Fresh.UnlockedItems) == "table" then
                    Data.UnlockedItems = Fresh.UnlockedItems
                end

                if type(Fresh.Equipped) == "table" then
                    Data.Equipped = Fresh.Equipped
                end

                if type(Fresh.EquippedCosmetics) == "table" then
                    Data.EquippedCosmetics = Fresh.EquippedCosmetics
                end
            end
        end
    end

    local Data = self.PlayerDataClient.Data

    if type(Data) == "table" and type(Data.CosmeticInventory) == "table" then
        for Uuid in Data.CosmeticInventory do
            if string.sub(tostring(Uuid), 1, #self.FakePrefix) == self.FakePrefix then
                Data.CosmeticInventory[Uuid] = nil
            end
        end
    end

    local State = self.SharedState

    if State then
        State.Enabled = false
        State.OriginalGet = nil
        State.OriginalIsItemUnlocked = nil
        State.OriginalUpdateSlot = nil
        State.OriginalApplySkin = nil
        State.OriginalOnSync = nil
        State.OriginalOnPatch = nil
        State.OriginalOnSyncAll = nil
        State.OriginalSendEquipState = nil
        State.OriginalGetAuthorityMetadata = nil
        State.DesiredObserver = nil
        State.DesiredEquipped = nil
        State.DesiredSkins = nil
    end

    if self.MenuLoadout then
        if type(self.PlayerDataClient.Data) == "table" then
            self.MenuLoadout.Equipped = self.PlayerDataClient.Data.Equipped
        end

        self:Refresh(self.MenuLoadout, "refreshOwnedCosmeticsCache")
        self:Refresh(self.MenuLoadout, "refreshLoadoutData")
    end

    self:FireUpdated(nil)
    return true
end

function UnlockAll:Enable()
    self.PlayerDataClient = self:GetPlayerDataClient()

    if not self.PlayerDataClient then
        return false
    end

    self.SharedState = self.SharedState or self:GetSharedState()
    self:AdoptSharedState()

    if self.SharedState ~= nil and self.SharedState.Enabled == true and self.SharedState.JobId == game.JobId and self.SharedState.Version ~= ScriptVersion then
        self.MenuLoadout = self:GetMenuLoadout()
        self.WeaponClient = self:GetWeaponClient()
        self:RestorePatchedFunctions()
    end

    self:FetchServerTruth()
    self:EnsureUnlockedItems(self.PlayerDataClient.Data)

    local AddedCount = self:EnsureCosmeticInventory(self.PlayerDataClient.Data)

    self:NoteDesiredFromLocal()
    self:PatchPlayerDataGet()
    self:PatchPlayerDataSync()
    self:ObserveDesired()
    self:PatchWeaponAuthority()
    self.MenuLoadout = self:GetMenuLoadout()
    self:PatchMenuLoadout()

    self:Refresh(self.MenuLoadout, "refreshOwnedCosmeticsCache")
    self:Refresh(self.MenuLoadout, "refreshLoadoutData")

    self:FireUpdated("UnlockedItems")
    self:FireUpdated("CosmeticInventory")

    self:StoreSharedState()
    return true
end

return UnlockAll.new()