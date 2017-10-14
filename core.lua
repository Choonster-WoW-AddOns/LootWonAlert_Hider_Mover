-- List globals here for Mikk's FindGlobals script.
--
-- Exports:
-- GLOBALS: LootWonAlert_HiderMover_HookManagers
--
-- Alert Frame systems
-- GLOBALS: LootAlertSystem, MoneyWonAlertSystem, LootUpgradeAlertSystem, GarrisonMissionAlertSystem, GarrisonShipMissionAlertSystem, NewPetAlertSystem, NewMountAlertSystem
--
-- Saved Variables:
-- GLOBALS: LOOTWON_HIDE, LOOTWON_SAVED_POSITIONS, LOOTWON_HIDDEN_ALERTS
--
-- WoW API functions:
-- GLOBALS: GetItemInfo, CreateFrame, GetSpecializationInfo, C_Garrison, C_PetJournal, C_MountJournal, EJ_GetEncounterInfo
--
-- Constants:
-- GLOBALS: LOOT_ROLL_TYPE_NEED, LE_ITEM_QUALITY_EPIC, LE_FOLLOWER_TYPE_GARRISON_6_0, LE_FOLLOWER_TYPE_SHIPYARD_6_2, LE_FOLLOWER_TYPE_GARRISON_7_0, LE_GARRISON_TYPE_6_0, LE_GARRISON_TYPE_7_0, LE_PET_JOURNAL_FILTER_COLLECTED, LE_PET_JOURNAL_FILTER_NOT_COLLECTED

local addon, ns = ...

ns.AlertTypes = {}
ns.HookManagers = {}
local AlertTypes, HookManagers = ns.AlertTypes, ns.HookManagers
LootWonAlert_HiderMover_HookManagers = HookManagers

local pairs, select, print = pairs, select, print
local random = math.random

-- table.pack from Lua 5.2+
function ns.pack(...)
	return { n = select("#", ...), ... }
end

--@alpha@
function ns.debugprint(name, ...)
	-- if not name:find("Pet", 1, true) then return end
	print(name, ...)
end
--@end-alpha@

--[===[@non-alpha@
function ns.debugprint() end
--@end-non-alpha@]===]

local pack, debugprint = ns.pack, ns.debugprint

local SAMPLE_ITEMID, SAMPLE_MONEY, SAMPLE_ENCOUNTERID = ns.SAMPLE_ITEMID, ns.SAMPLE_MONEY, ns.SAMPLE_ENCOUNTERID

---------------------
-- Initialisation --
---------------------

local SAMPLE_ITEMLINK

local function GetLink()
	-- if not SAMPLE_ITEMLINK then
		local _, itemLink = GetItemInfo(SAMPLE_ITEMID) -- Call GetItemInfo once with the item ID
		debugprint("GetLink", "itemLink1", itemLink)
		
		if itemLink then -- If the item link was returned,
			_, SAMPLE_ITEMLINK = GetItemInfo(itemLink) -- Call GetItemInfo a second time with the item link to ensure that the alert system can do the same and get valid results
			debugprint("GetLink", "itemLink2", SAMPLE_ITEMLINK)
		end
	-- end
end

GetLink() -- We probably won't get the data this time around, but this should let the next query receive it

local function GetFirstGarrisonMission(...)
	local missions = {}
	
	for i = 1, select("#", ...) do
		local followerType = select(i, ...)
		
		C_Garrison.GetCompleteMissions(missions, followerType)
		
		if missions[1] then
			return missions[1]
		end
		
		C_Garrison.GetAvailableMissions(missions, followerType)
		
		if missions[1] then
			return missions[1]
		end
	end
end

local function GetFirstPetID()
	-- Store the current filters
	local checkedSources = {}
	for i = 1, C_PetJournal.GetNumPetSources() do
		checkedSources[i] = C_PetJournal.IsPetSourceChecked(i)
	end
	
	local checkedTypes = {}
	for i = 1, C_PetJournal.GetNumPetTypes() do
		checkedTypes[i] = C_PetJournal.IsPetTypeChecked(i)
	end
	
	local collectedChecked = C_PetJournal.IsFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED)
	local notCollectedChecked = C_PetJournal.IsFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED)
	
	-- Clear all filters
	C_PetJournal.ClearSearchFilter()
	C_PetJournal.SetAllPetSourcesChecked(true)
	C_PetJournal.SetAllPetTypesChecked(true)
	
	-- Get the GUID of the first pet in the journal
	local petID = C_PetJournal.GetPetInfoByIndex(1)
	
	-- Restore the previous filters
	for i = 1, #checkedSources do
		C_PetJournal.SetPetSourceChecked(i, checkedSources[i])
	end
	
	for i = 1, #checkedTypes do
		C_PetJournal.SetPetTypeFilter(i, checkedTypes[i])
	end
	
	C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_COLLECTED, collectedChecked)
	C_PetJournal.SetFilterChecked(LE_PET_JOURNAL_FILTER_NOT_COLLECTED, notCollectedChecked)
	
	return petID
end

local function CreateHookManagers()
	local CreateAlertFrameQueueSystem_HookManager = ns.CreateAlertFrameQueueSystem_HookManager
	local CreateAlertFrameBonusLoot_HookManager = ns.CreateAlertFrameBonusLoot_HookManager
	local CreateBossBanner_HookManager = ns.CreateBossBanner_HookManager

	HookManagers.Loot = CreateAlertFrameQueueSystem_HookManager(LootAlertSystem, "Loot",
		function()
			GetLink()
			return SAMPLE_ITEMLINK, 1, LOOT_ROLL_TYPE_NEED, 42
		end,
		function(alertIndex)
			return ("Loot Alert #%d"):format(alertIndex)
		end
	)
	
	HookManagers.Money = CreateAlertFrameQueueSystem_HookManager(MoneyWonAlertSystem, "Money",
		function()
			return SAMPLE_MONEY
		end,
		function(alertIndex)
			return ("Money Won Alert #%d"):format(alertIndex)
		end
	)
	
	HookManagers.LootUpgrade = CreateAlertFrameQueueSystem_HookManager(LootUpgradeAlertSystem, "LootUpgrade",
		function()
			GetLink()
			return SAMPLE_ITEMLINK, 1, GetSpecializationInfo(1), LE_ITEM_QUALITY_EPIC
		end,
		function(alertIndex)
			return ("Loot Upgrade Alert #%d"):format(alertIndex)
		end
	)
	
	HookManagers.BonusLoot = CreateAlertFrameBonusLoot_HookManager(
		function()
			GetLink()
			return SAMPLE_ITEMLINK, 1, nil, nil, (GetSpecializationInfo(1))
		end,
		function(alertIndex)
			return "Bonus Loot Alert"
		end
	)
	
	HookManagers.GarrisonMission = CreateAlertFrameQueueSystem_HookManager(GarrisonMissionAlertSystem, "GarrisonMission",
		function()
			return GetFirstGarrisonMission(LE_FOLLOWER_TYPE_GARRISON_7_0, LE_FOLLOWER_TYPE_GARRISON_6_0)
		end,
		function(alertIndex)
			return ("Garrison Mission Alert #%d"):format(alertIndex)
		end
	)
	
	HookManagers.GarrisonShipMission = CreateAlertFrameQueueSystem_HookManager(GarrisonShipMissionAlertSystem, "GarrisonShipMission",
		function()
			return GetFirstGarrisonMission(LE_FOLLOWER_TYPE_SHIPYARD_6_2)
		end,
		function(alertIndex)
			return ("Garrison Ship Mission Alert #%d"):format(alertIndex)
		end
	)
	
	HookManagers.NewPet = CreateAlertFrameQueueSystem_HookManager(NewPetAlertSystem, "NewPet",
		function()
			return GetFirstPetID()
		end,
		function(alertIndex)
			return ("New Pet Alert %d"):format(alertIndex)
		end
	)
	
	HookManagers.NewMount = CreateAlertFrameQueueSystem_HookManager(NewMountAlertSystem, "NewMount",
		function()
			local mountIDs = C_MountJournal.GetMountIDs()
			return mountIDs[random(1, #mountIDs)]
		end,
		function(alertIndex)
			return ("New Mount Alert %d"):format(alertIndex)
		end
	)
	
	HookManagers.BossBanner = CreateBossBanner_HookManager(
		function()
			local name, description, encounterID, rootSectionID, link = EJ_GetEncounterInfo(SAMPLE_ENCOUNTERID)
			return SAMPLE_ENCOUNTERID, name
		end,
		function(alertIndex)
			return "Boss Banner"
		end
	)
end

local function ConvertSavedPositions(savedPositions)
	if not savedPositions then
		return {}
	end
	
	if savedPositions.specialAlerts then
		savedPositions.BonusLoot = { savedPositions.specialAlerts[1] }
		savedPositions.GarrisonMission = { savedPositions.specialAlerts[2] }
		savedPositions.specialAlerts = nil
	end
	
	if savedPositions.wonAlerts then
		savedPositions.Loot = savedPositions.wonAlerts
		savedPositions.wonAlerts = nil
	end
	
	if savedPositions.moneyAlerts then
		savedPositions.Money = savedPositions.moneyAlerts
		savedPositions.moneyAlerts = nil
	end
	
	if savedPositions.upgradeAlerts then
		savedPositions.LootUpgrade = savedPositions.upgradeAlerts
		savedPositions.upgradeAlerts = nil
	end
	
	return savedPositions
end

local function ConvertHiddenState(hiddenAlerts, hidden)
	hiddenAlerts = hiddenAlerts or {}
	
	if hidden == nil then
		hidden = true
	end
	
	for alertType, hookManager in pairs(HookManagers) do
		if hiddenAlerts[alertType] == nil then
			hiddenAlerts[alertType] = hidden
		end
	end
	
	return hiddenAlerts
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

function f:ADDON_LOADED(name)
	if name == addon then
		LOOTWON_SAVED_POSITIONS = ConvertSavedPositions(LOOTWON_SAVED_POSITIONS)
			
		CreateHookManagers()
		
		LOOTWON_HIDDEN_ALERTS = ConvertHiddenState(LOOTWON_HIDDEN_ALERTS, LOOTWON_HIDE)
		
		self:UnregisterEvent("ADDON_LOADED")
	end
end

function f:PLAYER_ENTERING_WORLD()
	GetLink() -- Try to get the link again
	
	debugprint("PLAYER_ENTERING_WORLD", "Link", SAMPLE_ITEMLINK)
	
	if not SAMPLE_ITEMLINK then -- If we don't have it, wait for GET_ITEM_INFO_RECEIVED
		f:RegisterEvent("GET_ITEM_INFO_RECEIVED")
	end
	
	f:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

function f:GET_ITEM_INFO_RECEIVED(itemID)
	if itemID == SAMPLE_ITEMID then
		GetLink() -- We should get the link now
		
		debugprint("GET_ITEM_INFO_RECEIVED", "Link", SAMPLE_ITEMLINK)
		
		if SAMPLE_ITEMLINK then -- If we have it, unregister the event
			f:UnregisterEvent("GET_ITEM_INFO_RECEIVED")
		end
	end
end
