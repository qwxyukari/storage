--!native
--!optimize 2

--# Aliases

local FromOffset, FromScale, UDim2New = UDim2.fromOffset, UDim2.fromScale, UDim2.new
local Atan2, Rad, Pi, Abs, Minimum, Maximum, Floor, Clamp = math.atan2, math.rad, math.pi, math.abs, math.min, math.max, math.floor, math.clamp
local NewVector, NewVector3, NewCFrame = vector.create, Vector3.new, CFrame.new
local Create, IsA = Instance.new, workspace.IsA
local Spawn, Wait = task.spawn, task.wait
local ForEach, Insert, RemoveTable, TableFind = table.foreach, table.insert, table.remove, table.find
local FindFirstChild, WaitForChild = workspace.FindFirstChild, workspace.WaitForChild
local WorldToViewportPoint = workspace.CurrentCamera.WorldToViewportPoint
local Lower = string.lower
local GetService = Game.GetService

local GetThreadIdentity = getthreadidentity or get_thread_identity
local SetThreadIdentity = setthreadidentity or set_thread_identity

--# Services

local MarketplaceService = GetService(Game, "MarketplaceService")
local ReplicatedStorage  = GetService(Game, "ReplicatedStorage")
local RunService         = GetService(Game, "RunService")
local Stats              = GetService(Game, "Stats")
local Players            = GetService(Game, "Players")

--# Main

local Storage = {}

Storage.Sounds = {
	AmongUs             = "5700183626",
	AR2Body             = "2062015952",
	AR2Head             = "2062016772",
	AR2Limb             = "6659353525",
	Bag                 = "364942410",
	Baimware            = "3124331820",
	Bambi               = "8437203821",
	BameWare            = "7898991882",
	Bamboo              = "3769434519",
	Bat                 = "3333907347",
	BBHitM               = "4645745735",
	BBKill               = "2636743632",
	Bell                = "6534947240",
	BitchBot            = "5709456554",
	BitchBotBody        = "3744371342",
	BitchBotHead        = "5043539486",
	Body                = "3213738472",
	Bonk                = "3765689841",
	Bop                 = "8829676038",
	Bubble              = "6534947588",
	BruH                = "4275842574",
	Bamboo              = "3769434519",
	CarrierKill         = "7139067012",
	Click               = "8053704437",
	Clink               = "711751971",
	CoD                 = "160432334",
	Crit                = "296102734",
	Crickets            = "2101148",
	Csgo                = "7269900245",
	Ding                = "7149516994",
	DoubleKill          = "6818527307",
	Doublekill1         = "1950547222",
	Doublekill2         = "130819307",
	Elevator            = "8322227967",
	EmptyGun            = "203691822",
	Fart                = "131314452",
	Fart2               = "6367774932",
	Fatality            = "7347423703",
	FatalityMKX         = "6721975770",
	FatalityOriginal    = "158012252",
	FortniteGuns        = "3008769599",
	Gamesense           = "4817809188",
	GrenadeHit          = "5684745272",
	Headshot            = "8418469749",
	HLCrowbar           = "546410481",
	HLDoor              = "4996094887",
	HLElevator          = "237877850",
	HLMedKit            = "4720445506",
	HLRevolver          = "1678424590",
	HitMarker           = "8543972310",
	KillingFrenzy       = "6822465319",
	KillingSpree        = "6822465178",
	KillingSpree1       = "723054723",
	KillingSpree2       = "937898383",
	KillImanjaro        = "6818527258",
	KillIonaire         = "6818527200",
	KillPocalypse       = "6818527144",
	KillTacular         = "6818527070",
	KillTastrophe       = "6818526916",
	KillTrocity         = "6818544945",
	Kombat              = "8527433497",
	LaserSlash          = "199145497",
	LazerBeam           = "130791043",
	Mario               = "2815207981",
	Minecraft           = "6361963422",
	MinecraftExperience = "1053296915",
	Neverlose           = "8726881116",
	Osu                 = "7149919358",
	OsuCombobreak       = "3547118594",
	OverKill            = "6818526995",
	PDBody              = "4585364605",
	PDHead              = "4585351098",
	Pick                = "1347140027",
	Pop                 = "198598793",
	QuakeHitsound       = "4868633804",
	RailGunF            = "199145534",
	Rust                = "1255040462",
	Saber               = "8415678813",
	Skeet               = "4753603610",
	SitDog              = "7349055654",
	Slime               = "6916371803",
	Snow                = "6455527632",
	Splat               = "12222152",
	Steve               = "4965083997",
	Stone               = "3581383408",
	TacoBell            = "5689199277",
	TF2Beepo            = "3466987025",
	TF2HitSound         = "3455144981",
	TF2Pow              = "679798995",
	TF2Retro            = "3466984142",
	TF2Space            = "3466982899",
	TF2Squasher         = "3466981613",
	TF2Vortex           = "3466980212",
	TF2YouSuck          = "1058417264",
	TripleKill          = "6818526855",
	WindowsXPError      = "160715357",
	WindowsXPDing       = "489390072",
	YouSuck              = "1058417264",
}
Storage.SoundsKey = {}

Storage.BulletTracers = {
    ["Supremacy"] = "rbxassetid://446111271",
    ["Coolant Laser"] = "rbxassetid://7136858729",
    ["Lightning Bolt"] = "rbxassetid://12781806168",
    ["Lightning Bolt2"] = "rbxassetid://7151778302",
    ["Laser"] = "rbxassetid://5864341017",
    ["Red Laser"] = "rbxassetid://6333823534",
    ["DNA"] = "rbxassetid://6511613786"
}
Storage.BulletTracersKey = {
}

do 
    for i,v in Storage.Sounds do
        Insert(Storage.SoundsKey, i)
    end

    for i,v in Storage.BulletTracers do
        Insert(Storage.BulletTracersKey, i)
    end
end

function Storage.Preload(Names)
    Spawn(function()
        for _, Name in Names or Storage.SoundsKey do
            local Id = Storage.Sounds[Name]
            if not Id then continue end

            local Sound = Instance.new("Sound")
            Sound.SoundId = "rbxassetid://" .. Id
            Sound.Volume = 0
            Sound.PlayOnRemove = true
            Sound.Parent = HiddenUI
            Sound:Destroy()
        end
    end)
end

return Storage