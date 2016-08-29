local SAMPLE_ITEMID = 127857 -- Aluneth
local SAMPLE_MONEY = 13370000 -- 1337g

-------------------
-- END OF CONFIG --
-------------------
-- Do not change anything below here!

-- List globals here for Mikk's FindGlobals script.
--
-- Slash commands:
-- GLOBALS: SLASH_LOOTWON_TOGGLELOCK1, SLASH_LOOTWON_TOGGLELOCK2 , SLASH_LOOTWON_SHOW1, SLASH_LOOTWON_SHOW2, SLASH_LOOTWON_HIDE1, SLASH_LOOTWON_HIDE2, SLASH_LOOTWON_RESET1, SLASH_LOOTWON_RESET2
--
-- Exports:
-- GLOBALS: LootWonAlert_HiderMover_HookManagers
--
-- Alert Frame frames, functions and systems:
-- GLOBALS: AlertFrame, AlertFrame_ResumeOutAnimation, AlertFrame_StopOutAnimation, LootAlertSystem, MoneyWonAlertSystem, LootUpgradeAlertSystem, GarrisonMissionAlertSystem, GarrisonShipMissionAlertSystem, LootWonAlertFrame_SetUp, BonusRollLootWonFrame, GroupLootContainer, GroupLootContainer_AddFrame, GroupLootContainer_RemoveFrame
--
-- Saved Variables:
-- GLOBALS: LOOTWON_HIDE, LOOTWON_SAVED_POSITIONS
--
-- FrameXML functions:
-- GLOBALS: CreateFromMixins
--
-- WoW API functions:
-- GLOBALS: GetItemInfo, CreateFrame, GetSpecializationInfo, C_Garrison, hooksecurefunc, UnitLevel, GetExpansionLevel
--
-- Constants:
-- GLOBALS: LOOT_ROLL_TYPE_NEED, LE_ITEM_QUALITY_EPIC, LE_FOLLOWER_TYPE_GARRISON_6_0, LE_FOLLOWER_TYPE_SHIPYARD_6_2, LE_FOLLOWER_TYPE_GARRISON_7_0, LE_EXPANSION_WARLORDS_OF_DRAENOR

local addon, ns = ...

local UNLOCKED = false

local HookManagers = {}
LootWonAlert_HiderMover_HookManagers = HookManagers

local pairs, unpack, setmetatable, wipe = pairs, unpack, setmetatable, wipe
local select, print = select, print
local debugstack = debugstack

-- table.pack from Lua 5.2+
local function pack(...)
	return { n = select("#", ...), ... }
end


--@alpha@
local function debugprint(name, ...)
	if not name:find("BonusLoot", 1, true) then return end
	print(name, ...)
end
--@end-alpha@

--[===[@non-alpha@
local function debugprint() end
--@end-non-alpha@]===]

------------------
-- Slash Commands --
------------------

local function ShowAlertsAndMovers(hookManager)
	local success = hookManager:ShowAlerts()
	if success then
		hookManager:ShowMovers()
	else
		local alertType = hookManager:GetAlertType()
		
		-- Don't warn players about Garrison alerts if they're lower than 90 or don't have WoD.
		if (alertType ~= "GarrisonMission" and alertType ~= "GarrisonShipMission") or (UnitLevel("player") >= 90 and GetExpansionLevel() >= LE_EXPANSION_WARLORDS_OF_DRAENOR) then
			print(("Failed to show alerts of type %s. Try locking and unlocking again."):format(alertType))
		end
	end
end

SLASH_LOOTWON_TOGGLELOCK1, SLASH_LOOTWON_TOGGLELOCK2 = "/lootwonlock", "/lwl"
SlashCmdList.LOOTWON_TOGGLELOCK = function()
	UNLOCKED = not UNLOCKED
	
	if UNLOCKED then
		if LOOTWON_HIDE then
			print("Loow Won Alerts are hidden. Use /lootwonshow or /lws to show them before using /lootwonlock again.")
		else
			for alertType, hookManager in pairs(HookManagers) do
				ShowAlertsAndMovers(hookManager)
			end
			
			print("Loot Won Alerts unlocked.")
		end
	else
		for alertType, hookManager in pairs(HookManagers) do
			hookManager:HideMovers()
		end
		
		print("Loot Won Alerts locked.")
	end	
end

SLASH_LOOTWON_RESET1, SLASH_LOOTWON_RESET2 = "/lootwonreset", "/lwr"
SlashCmdList.LOOTWON_RESET = function()
	for alertType, hookManager in pairs(HookManagers) do
		hookManager:HideAlerts()
		hookManager:HideMovers()
		hookManager:ResetPositions()
		ShowAlertsAndMovers(hookManager)
	end
	
	print("Loot Won Alert positions have been reset")
end

SLASH_LOOTWON_SHOW1, SLASH_LOOTWON_SHOW2 = "/lootwonshow", "/lws"
SlashCmdList.LOOTWON_SHOW = function()
	LOOTWON_HIDE = false
	
	for alertType, hookManager in pairs(HookManagers) do
		hookManager:RemoveHooks()
	end
	
	print("Loot Won Alerts shown.")
end

SLASH_LOOTWON_HIDE1, SLASH_LOOTWON_HIDE2 = "/lootwonhide", "/lwh"
SlashCmdList.LOOTWON_HIDE = function()
	LOOTWON_HIDE = true
	
	for alertType, hookManager in pairs(HookManagers) do
		hookManager:HookAlertFrames()
	end
	
	print("Loot Won Alerts hidden.")
end

------------
-- Movers --
------------

local MoverScripts = {}

function MoverScripts:OnShow()
	local hookManager = self.hookManager
	local parent = self:GetParent()
	local alertIndex = hookManager:GetAlertIndex(parent)
	
	debugprint("MoverScripts:OnShow", "AlertType", hookManager:GetAlertType(), "Index", alertIndex)
	
	self.text:SetText(hookManager.moverTextFunction(alertIndex) .. "\n\nClick and drag to move this frame.")
	
	parent:EnableMouse(false)
	hookManager:StopOutAnimation(parent)
end

function MoverScripts:OnHide()
	local parent = self:GetParent()
	
	parent:EnableMouse(true)
	self.hookManager:ResumeOutAnimation(parent)
end

function MoverScripts:OnMouseDown()
	local parent = self:GetParent()
	
	debugprint("MoverScripts:OnMouseDown", "AlertType", self.hookManager:GetAlertType(), "Index", self.hookManager:GetAlertIndex(parent))
	
	parent:ClearAllPoints()
	parent:StartMoving()
end

function MoverScripts:OnMouseUp()
	local parent = self:GetParent()
	
	debugprint("MoverScripts:OnMouseUp", "AlertType", self.hookManager:GetAlertType(), "Index", self.hookManager:GetAlertIndex(self:GetParent()))
	
	parent:StopMovingOrSizing()
	self.hookManager:SaveAlertPosition(parent)
end

--------------------------
-- Base Mixin --
--------------------------

local Base_HookManagerMixin = {}

function Base_HookManagerMixin:OnLoad(alertType, sampleArgumentsFunction, moverTextFunction)
	self.alertType = alertType
	self.sampleArgumentsFunction = sampleArgumentsFunction
	self.moverTextFunction = moverTextFunction
	
	self.hookedFrames = {} -- [alertFrame] = true
	self.originalScripts = {} -- [alertFrame] = scriptFunction
	self.movers = {} -- [alertFrame] = mover
	self.numMovers = 0
	
	LOOTWON_SAVED_POSITIONS[alertType] = LOOTWON_SAVED_POSITIONS[alertType] or {}
	self.savedPositions = LOOTWON_SAVED_POSITIONS[alertType]
end

function Base_HookManagerMixin:GetAlertType()
	return self.alertType
end

function Base_HookManagerMixin:HookAlertFrames()
	local moverOnly = not LOOTWON_HIDE
	
	debugprint("Base:HookAlertFrames", "AlertType", self:GetAlertType(), "moverOnly", moverOnly)
	
	for frame, _ in self:EnumerateActiveAlerts() do
		self:HookAlertFrame(frame, moverOnly)
	end
end

function Base_HookManagerMixin:HookAlertFrame(frame, moverOnly)
	debugprint("Base:HookAlertFrame", "AlertType", self:GetAlertType(), "moverOnly", moverOnly)
	
	if moverOnly == nil then
		debugprint("Base:HookAlertFrame", debugstack())
	end

	if self.hookedFrames[frame] then return end

	if not self.movers[frame] then
		self.movers[frame] = self:CreateMover(frame)
	end

	if moverOnly then return end

	self.hookedFrames[frame] = true
	self.originalScripts[frame] = frame:GetScript("OnShow")

	frame:HookScript("OnShow", frame.Hide)
	frame:Hide()
end

function Base_HookManagerMixin:CreateMover(frame)
	debugprint("Base:CreateMover")
	
	frame:SetMovable(true)

	self.numMovers = self.numMovers + 1
	
	local mover = CreateFrame("Frame", "LootWonAlert_HiderMover_" .. self:GetAlertType() .. "_MoverFrame" .. self.numMovers, frame)
	mover.hookManager = self
	mover:SetAllPoints()
	mover:RegisterForDrag("LeftButton")
	mover:Hide()

	for script, func in pairs(MoverScripts) do
		mover:SetScript(script, func)
	end

	local overlay = mover:CreateTexture("$parentOverlay")
	overlay:SetDrawLayer("OVERLAY", 6)
	overlay:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
	overlay:SetVertexColor(0, 1, 0, 0.8)
	overlay:SetBlendMode("BLEND")
	overlay:SetAllPoints()
	mover.overlay = overlay

	local text = mover:CreateFontString("$parentText", "OVERLAY", "GameFontNormal")
	text:SetDrawLayer("OVERLAY", 7)
	text:SetPoint("CENTER")
	mover.text = text
	
	return mover
end
	
function Base_HookManagerMixin:ReanchorAlerts()
	for frame, _ in self:EnumerateActiveAlerts() do
		self:ReanchorAlert(frame)
	end
end

function Base_HookManagerMixin:ReanchorAlert(frame)
	local alertIndex = self:GetAlertIndex(frame)
	debugprint("Base:ReanchorAlert", "AlertType", self:GetAlertType(), "alertIndex", alertIndex)

	local position = self.savedPositions[alertIndex]
	
	if position then
		frame:ClearAllPoints()
		frame:SetPoint(unpack(position, 1, position.n))
	elseif frame:GetNumPoints() > 1 then
		-- Alerts that get pushed off the screen seem to have their TOP point set to a positive y-offset from the TOP of the screen
		-- This causes them to stretch when the alert that they're anchored to is moved instead of moving with it
		-- To fix this, we find the real anchor point, clear all points and then restore the real one
		debugprint("Found alert with incorrect anchor.", "AlertType", self:GetAlertType(), "alertIndex", alertIndex, "name", frame:GetName() or "<unnamed>")
		
		local point, relativeTo, relativePoint, xOffset, yOffset
		for i = 1, frame:GetNumPoints() do
			point, relativeTo, relativePoint, xOffset, yOffset = frame:GetPoint(i)
			if point == "BOTTOM" then -- This is the real anchor point, use it
				break
			end
		end
		
		frame:ClearAllPoints()
		frame:SetPoint(point, relativeTo, relativePoint, xOffset, yOffset)
	end
end

function Base_HookManagerMixin:RemoveHooks()
	debugprint("Base:RemoveHooks", "AlertType", self:GetAlertType())
	
	for frame, _ in pairs(self.hookedFrames) do
		frame:SetScript("OnShow", self.originalScripts[frame])
		self.hookedFrames[frame] = nil
	end
end

function Base_HookManagerMixin:HideAlerts()
	debugprint("Base:HideAlerts", "AlertType", self:GetAlertType())
	
	for frame, _ in self:EnumerateActiveAlerts() do
		frame:Hide()
	end
end

function Base_HookManagerMixin:SaveAlertPosition(frame)
	local alertIndex = self:GetAlertIndex(frame)
	local position = pack(frame:GetPoint())
	local anchor = position[2]
	
	debugprint("Base:SaveAlertPosition", "AlertType", self:GetAlertType(), "AlertIndex", alertIndex)
	
	if anchor then
		if anchor.GetName then
			position[2] = anchor:GetName()
		else
			position[2] = nil
		end
	end
	
	self.savedPositions[alertIndex] = position
end

function Base_HookManagerMixin:HasSavedAlertPosition(frame)
	return self.savedPositions[self:GetAlertIndex(frame)] ~= nil
end

function Base_HookManagerMixin:ResetPositions()
	debugprint("Base:ResetPositions", "AlertType", self:GetAlertType())
	
	for frame, _ in self:EnumerateActiveAlerts() do
		local alertIndex = self:GetAlertIndex(frame)
		local position = self.savedPositions[alertIndex]
		
		if position then
			frame:ClearAllPoints()
		end
	end
	
	wipe(self.savedPositions)
end

function Base_HookManagerMixin:ShowMovers()
	debugprint("Base:ShowMovers", "AlertType", self:GetAlertType())
	
	for frame, mover in pairs(self.movers) do
		mover:Show()
		debugprint("Base:ShowMovers", "Showing mover", "Index:", self:GetAlertIndex(frame))
	end
end

function Base_HookManagerMixin:HideMovers()
	debugprint("Base:HideMovers", "AlertType", self:GetAlertType())
	
	for frame, mover in pairs(self.movers) do
		mover:Hide()
	end
end

function Base_HookManagerMixin:StopOutAnimation(frame)
	AlertFrame_StopOutAnimation(frame)
end

function Base_HookManagerMixin:ResumeOutAnimation(frame)
	AlertFrame_ResumeOutAnimation(frame)
end

-- Implementations that extend Base_HookManagerMixin must provide the following methods:
-- :GetAlertIndex(frame)
-- :EnumerateActiveAlerts()
-- :ShowAlerts()

------------------------
-- Single Frame Mixin --
------------------------

local SingleFrame_HookManagerMixin = CreateFromMixins(Base_HookManagerMixin)

function SingleFrame_HookManagerMixin:OnLoad(frame, alertType, sampleArgumentsFunction, moverTextFunction)
	Base_HookManagerMixin.OnLoad(self, alertType, sampleArgumentsFunction, moverTextFunction)
	
	self.frame = frame
	self.frameTable = { [frame] = true }
	
	self.frame:HookScript("OnShow", function(frame)
		self:HookAlertFrames()
	end)
end

function SingleFrame_HookManagerMixin:GetAlertIndex(frame)
	return frame == self.frame and 1 or nil
end

function SingleFrame_HookManagerMixin:EnumerateActiveAlerts()
	return pairs(self.frameTable)
end

---------------------------
-- Simple Subystem Mixin --
---------------------------

local AlertFrameSimpleSystem_HookManagerMixin = CreateFromMixins(SingleFrame_HookManagerMixin)

function AlertFrameSimpleSystem_HookManagerMixin:OnLoad(subsystem, alertType, sampleArgumentsFunction, moverTextFunction)
	SingleFrame_HookManagerMixin.OnLoad(self, subsystem.alertFrame, alertType, sampleArgumentsFunction, moverTextFunction)
	
	self.subsystem = subsystem
	
	hooksecurefunc(subsystem, "AdjustAnchors", function(subsystem, relativeFrame)
		self:ReanchorAlerts()
	end)
end

function AlertFrameSimpleSystem_HookManagerMixin:ShowAlerts()
	local arguments = pack(self.sampleArgumentsFunction())
	
	debugprint("Simple:ShowAlerts", "AlertType", self:GetAlertType(), "Args", unpack(arguments, 1, arguments.n))
	
	if arguments[1] then
		self.subsystem:AddAlert(unpack(arguments, 1, arguments.n))
		return true
	else
		return false
	end
end

local function CreateAlertFrameSimpleSystem_HookManager(subsystem, alertType, sampleArgumentsFunction, moverTextFunction)
	local hookManager = CreateFromMixins(AlertFrameSimpleSystem_HookManagerMixin)
	hookManager:OnLoad(subsystem, alertType, sampleArgumentsFunction, moverTextFunction)
	return hookManager
end

--------------------------------
-- Bonus Loot Mixin --
--------------------------------

local AlertFrameBonusLoot_HookManager = CreateFromMixins(SingleFrame_HookManagerMixin)

function AlertFrameBonusLoot_HookManager:OnLoad(sampleArgumentsFunction, moverTextFunction)
	SingleFrame_HookManagerMixin.OnLoad(self, BonusRollLootWonFrame, "BonusLoot", sampleArgumentsFunction, moverTextFunction)
	
	hooksecurefunc("GroupLootContainer_Update", function(container)
		self:OnGroupLootContainerUpdate(container)
	end)
end

function AlertFrameBonusLoot_HookManager:OnGroupLootContainerUpdate(container)
	if self.removing then return end
	
	local frame = self.frame
	
	if self:HasSavedAlertPosition(frame) then
		self.removing = true
		GroupLootContainer_RemoveFrame(container, frame)
		self.removing = false
		
		if self.showing then
			frame:Show()
			container:Show()
		end
	end
	
	SingleFrame_HookManagerMixin.ReanchorAlerts(self)
end

function AlertFrameBonusLoot_HookManager:ShowAlerts()
	local arguments = pack(self.sampleArgumentsFunction())
	
	debugprint("BonusLoot:ShowAlerts", "Args", unpack(arguments, 1, arguments.n))
	
	if arguments[1] then
		self.showing = true
		GroupLootContainer_AddFrame(GroupLootContainer, self.frame)
		self.showing = false
		
		LootWonAlertFrame_SetUp(self.frame, unpack(arguments, 1, arguments.n))
		AlertFrame:AddAlertFrame(self.frame)
		
		return true
	else
		return false
	end	
end

local function CreateAlertFrameBonusLoot_HookManager(sampleArgumentsFunction, moverTextFunction)
	local hookManager = CreateFromMixins(AlertFrameBonusLoot_HookManager)
	hookManager:OnLoad(sampleArgumentsFunction, moverTextFunction)
	return hookManager
end

---------------------------
-- Queue Subsystem Mixin --
---------------------------

local AlertFrameQueueSystem_HookManagerMixin = CreateFromMixins(Base_HookManagerMixin)

function AlertFrameQueueSystem_HookManagerMixin:OnLoad(subsystem, alertType, sampleArgumentsFunction, moverTextFunction)
	Base_HookManagerMixin.OnLoad(self, alertType, sampleArgumentsFunction, moverTextFunction)
	
	self.subsystem = subsystem
	self.alertIndices = {} -- [alertFrame] = index
	
	hooksecurefunc(subsystem, "AdjustAnchors", function(subsystem, relativeFrame)
		self:ReanchorAlerts()
	end)
	
	hooksecurefunc(subsystem, "ShowAlert", function(subsystem, ...)
		self:HookAlertFrames()
	end)
	
	hooksecurefunc(subsystem, "OnFrameHide", function(subsystem, frame)
		debugprint("Queue:OnFrameHide", "AlertType", self:GetAlertType(), "Index", self:GetAlertIndex(frame))
		
		self:SetAlertIndex(frame, nil)
	end)
end

function AlertFrameQueueSystem_HookManagerMixin:GetAlertIndex(frame)
	return self.alertIndices[frame]
end

function AlertFrameQueueSystem_HookManagerMixin:SetAlertIndex(frame, index)
	self.alertIndices[frame] = index
end

function AlertFrameQueueSystem_HookManagerMixin:EnumerateActiveAlerts()
	return self.subsystem.alertFramePool:EnumerateActive()
end

function AlertFrameQueueSystem_HookManagerMixin:HookAlertFrame(frame, moverOnly)
	local alertIndex = self:GetAlertIndex(frame)
	
	debugprint("Queue:HookAlertFrame", "AlertType", self:GetAlertType(), "numVisible", self.subsystem:GetNumVisibleAlerts(), "MoverOnly", moverOnly, "Index", alertIndex)
	
	-- If the frame doens't have an index it must be the one that was just shown, so set its index to the number of visible alerts
	if not alertIndex then
		debugprint("Queue:HookAlertFrame", "Setting index to", self.subsystem:GetNumVisibleAlerts())
		-- debugprint("Queue:HookAlertFrame", debugstack())
		
		self:SetAlertIndex(frame, self.subsystem:GetNumVisibleAlerts())
	end
	
	Base_HookManagerMixin.HookAlertFrame(self, frame, moverOnly)
end

function AlertFrameQueueSystem_HookManagerMixin:ShowAlerts()
	local numAlerts = self.subsystem.maxAlerts

	local arguments = pack(self.sampleArgumentsFunction())
	
	debugprint("Queue:ShowAlerts", "AlertType", self:GetAlertType(), "NumAlerts", numAlerts, "Args:", unpack(arguments, 1, arguments.n))
	
	if arguments[1] then
		for i = 1, numAlerts do
			self.subsystem:AddAlert(unpack(arguments, 1, arguments.n))
		end
		
		return true
	else
		return false
	end
end

local function CreateAlertFrameQueueSystem_HookManager(subsystem, alertType, sampleArgumentsFunction, moverTextFunction)
	local hookManager = CreateFromMixins(AlertFrameQueueSystem_HookManagerMixin)
	hookManager:OnLoad(subsystem, alertType, sampleArgumentsFunction, moverTextFunction)
	return hookManager
end

---------------------
-- Initialisation --
---------------------

local SAMPLE_ITEMLINK

local function GetLink()
	if not SAMPLE_ITEMLINK then
		local _, itemLink = GetItemInfo(SAMPLE_ITEMID) -- Call GetItemInfo once with the item ID
		if itemLink then -- If the item link was returned,
			_, SAMPLE_ITEMLINK = GetItemInfo(itemLink) -- Call GetItemInfo a second time with the item link to ensure that the alert system can do the same and get valid results
		end
	end
end

GetLink() -- We probably won't get the data this time around, but this should let the next query receive it

local function GetFirstGarrisonMission(...)
	local missions = {}
	
	for i = 1, select("#", ...) do
		local followerType = select(i, ...)
		
		C_Garrison.GetCompleteMissions(missions, followerType)
		
		if missions[1] then
			return missions[1].missionID
		end
		
		C_Garrison.GetAvailableMissions(missions, followerType)
		
		if missions[1] then
			return missions[1].missionID
		end
	end
end

local function CreateHookManagers()
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
	
	HookManagers.GarrisonMission = CreateAlertFrameSimpleSystem_HookManager(GarrisonMissionAlertSystem, "GarrisonMission",
		function()
			return GetFirstGarrisonMission(LE_FOLLOWER_TYPE_GARRISON_7_0, LE_FOLLOWER_TYPE_GARRISON_6_0)
		end,
		function(alertIndex)
			return "Garrison Mission Alert"
		end
	)
	
	HookManagers.GarrisonShipMission = CreateAlertFrameSimpleSystem_HookManager(GarrisonShipMissionAlertSystem, "GarrisonShipMission",
		function()
			return GetFirstGarrisonMission(LE_FOLLOWER_TYPE_SHIPYARD_6_2)
		end,
		function(alertIndex)
			return "Garrison Ship Mission Alert"
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

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

function f:ADDON_LOADED(name)
	if name == addon then
		LOOTWON_SAVED_POSITIONS = ConvertSavedPositions(LOOTWON_SAVED_POSITIONS)

		if LOOTWON_HIDE == nil then
			LOOTWON_HIDE = true
		end
		
		CreateHookManagers()
		
		self:UnregisterEvent("ADDON_LOADED")
	end
end
