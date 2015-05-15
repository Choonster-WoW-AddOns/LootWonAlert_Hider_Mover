local NUM_SAMPLE_FRAMES = 5 -- 5 alert frames just about fill the screen
local SAMPLE_ITEMID = 80211 -- Enchanting Test Sword
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
-- Exported functions:
-- GLOBALS: LootWon_ShowFrames, LootWon_HideFrames
--
-- AlertFrame functions:
-- GLOBALS: AlertFrame_ResumeOutAnimation, AlertFrame_StopOutAnimation, LootWonAlertFrame_ShowAlert, GarrisonMissionAlertFrame_ShowAlert, LootUpgradeFrame_ShowAlert
--
-- SavedVariables:
-- GLOBALS: LOOTWON_HIDE, LOOTWON_SAVED_POSITIONS
--
-- WoW API functions:
-- GLOBALS: GetItemInfo, CreateFrame, GetSpecializationInfo, C_Garrison
--
-- Constants:
-- GLOBALS: LOOT_ROLL_TYPE_NEED, LE_ITEM_QUALITY_EPIC

local addon, ns = ...

local UNLOCKED = false
local originalScripts = {}
local hookedFrames = {}
local allMovers = { wonAlerts = {}, moneyAlerts = {}, upgradeAlerts = {}, specialAlerts = {} }
-- LW_MOVERS = movers
-- LW_HOOKED = hookedFrames

local wonAlerts = LOOT_WON_ALERT_FRAMES
local moneyAlerts = MONEY_WON_ALERT_FRAMES
local upgradeAlerts = LOOT_UPGRADE_ALERT_FRAMES
local bonusAlert = BonusRollLootWonFrame
local garrisonMissionAlert = GarrisonMissionAlertFrame

local rawget, rawset, pairs, unpack, setmetatable, wipe = rawget, rawset, pairs, unpack, setmetatable, wipe
local select, print = select, print

------------
-- Movers --
------------

local SAMPLE_ITEMLINK

local function GetLink()
	if not SAMPLE_ITEMLINK then
		SAMPLE_ITEMLINK = select(2, GetItemInfo(SAMPLE_ITEMID))
	end
end

GetLink() -- We probably won't get the data this time around, but this should let the next query receive it

local Mover = {}

function Mover:OnShow()
	-- print("Mover OnShow!", self:GetName())
	AlertFrame_StopOutAnimation(self.parent)
end

function Mover:OnHide()
	AlertFrame_ResumeOutAnimation(self.parent)
end

function Mover:OnEnter()
	AlertFrame_StopOutAnimation(self.parent)
end

function Mover:OnLeave()
	AlertFrame_StopOutAnimation(self.parent)
end

function Mover:OnDragStart()
	self.parent:ClearAllPoints()
	self.parent:StartMoving()
end

function Mover:OnDragStop()
	self.parent:StopMovingOrSizing()

	LOOTWON_SAVED_POSITIONS[self.alertType](self.alertIndex, self.parent:GetPoint()) -- Store the position using the __call metamethod

	local savedPos = LOOTWON_SAVED_POSITIONS[self.alertType][self.alertIndex]
	local anchor = savedPos[2]
	if anchor then
		if anchor.GetName then
			savedPos[2] = anchor:GetName()
		end
	else
		savedPos[2] = "UIParent"
	end
end

local function CreateMover(frame)
	-- print("CreateMover!", frame, frame:GetName())
	frame:SetMovable(true)

	local mover = CreateFrame("Frame", "$parentMoverFrame", frame)
	mover.parent = frame
	mover.alertType = frame.LW_alertType
	mover.alertIndex = frame.LW_alertIndex
	mover:SetAllPoints()
	mover:RegisterForDrag("LeftButton")
	mover:Hide()

	for script, func in pairs(Mover) do
		mover:SetScript(script, func)
	end

	frame.LW_moverFrame = mover

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

	local alertType, alertIndex = mover.alertType, mover.alertIndex
	local displayText

	if alertType == "wonAlerts" then
		displayText = ("Loot Won Alert #%d"):format(alertIndex)
	elseif alertType == "moneyAlerts" then
		displayText = ("Money Won Alert #%d"):format(alertIndex)
	elseif alertType == "upgradeAlerts" then
		displayText = ("Loot Upgrade Alert #%d"):format(alertIndex)
	elseif alertIndex == 2 then
		displayText = "Garrison Mission Alert"
	elseif alertIndex == 1 then
		displayText = "Bonus Loot Alert"
	end

	text:SetText(displayText .. "\n\nClick and drag to move this frame.")

	allMovers[mover.alertType][mover.alertIndex] = mover
end

local function ForAllMovers(func)
	for alertType, movers in pairs(allMovers) do
		for alertIndex, mover in pairs(movers) do
			func(mover)
		end
	end
end

local function ReanchorFrame(mover)
	local savedPos = rawget(LOOTWON_SAVED_POSITIONS[mover.alertType], mover.alertIndex)
	local parent = mover.parent
	if savedPos then
		parent:ClearAllPoints()
		parent:SetPoint(unpack(savedPos))
	elseif parent:GetNumPoints() > 1 then
		-- Alerts that get pushed off the screen seem to have their TOP point set to a positive y-offset from the TOP of the screen
		-- This causes them to stretch when the alert that they're anchored to is moved instead of moving with it
		-- To fix this, we find the real anchor point, clear all points and then restore the real one
		print("Found alert with incorrect anchor.", "alertType", mover.alertType, "alertIndex", mover.alertIndex, "name", parent:GetName() or "<unnamed>")
		
		local point, relativeTo, relativePoint, xOffset, yOffset
		for i = 1, parent:GetNumPoints() do
			point, relativeTo, relativePoint, xOffset, yOffset = parent:GetPoint(i)
			if point == "BOTTOM" then -- This is the real anchor point, use it
				break
			end
		end
		
		parent:ClearAllPoints()
		parent:SetPoint(point, relativeTo, relativePoint, xOffset, yOffset)
	end
end

local function ReanchorFrames()
	-- print("ReanchorFrames")
	ForAllMovers(ReanchorFrame)
end

local function ShowFrames(numFrames)
	GetLink()
	
	numFrames = numFrames or NUM_SAMPLE_FRAMES

	for i = 1, numFrames do
		LootWonAlertFrame_ShowAlert(SAMPLE_ITEMLINK, 1, LOOT_ROLL_TYPE_NEED, 42)
	end

	for i = 1, numFrames do
		MoneyWonAlertFrame_ShowAlert(SAMPLE_MONEY)
	end
	
	for i = 1, numFrames do
		LootUpgradeFrame_ShowAlert(SAMPLE_ITEMLINK, 1, GetSpecializationInfo(1), LE_ITEM_QUALITY_EPIC)
	end	

	local firstMission = C_Garrison.GetCompleteMissions()[1] or C_Garrison.GetAvailableMissions()[1]
	if firstMission then
		GarrisonMissionAlertFrame_ShowAlert(firstMission.missionID)
	end
end

local function HideFrames()
	for i = 1, #wonAlerts do
		wonAlerts[i]:Hide()
	end
	
	for i = 1, #moneyAlerts do
		moneyAlerts[i]:Hide()
	end

	for i = 1, #upgradeAlerts do
		upgradeAlerts[i]:Hide()
	end

	garrisonMissionAlert:Hide()
end

LootWon_ShowFrames = ShowFrames
LootWon_HideFrames = HideFrames

local function ShowMover(mover)
	mover:Show()
end

local function ShowMovers()
	-- print"ShowMovers"
	UNLOCKED = true

	ShowFrames()

	ForAllMovers(ShowMover)

	ReanchorFrames()
end

local function HideMover(mover)
	mover:Hide()
end

local function HideMovers()
	-- print"HideMovers"
	UNLOCKED = false

	ForAllMovers(HideMover)
end

local function ResetPosition(mover)
	local alertType = mover.alertType
	local alertIndex = mover.alertIndex

	local savedPos = rawget(LOOTWON_SAVED_POSITIONS[alertType], alertIndex)
	if savedPos then
		mover.parent:ClearAllPoints()
	end

	LOOTWON_SAVED_POSITIONS[alertType][alertIndex] = nil
end

local function ResetPositions()
	HideFrames()
	HideMovers()
	ForAllMovers(ResetPosition)
	ShowMovers()
end

local function AlertFrame_FixAnchors_Hook()
	ReanchorFrames()
end

hooksecurefunc("AlertFrame_FixAnchors", AlertFrame_FixAnchors_Hook)

SLASH_LOOTWON_TOGGLELOCK1, SLASH_LOOTWON_TOGGLELOCK2 = "/lootwonlock", "/lwl"
SlashCmdList.LOOTWON_TOGGLELOCK = function()
	if UNLOCKED then
		HideMovers()
		print("Loot Won Alerts locked.")
	else
		if LOOTWON_HIDE then
			print("Loow Won Alerts are hidden. Use /lootwonshow or /lws to show them before using /lootwonlock again.")
		else
			ShowMovers()
			print("Loot Won Alerts unlocked.")
		end
	end
end

SLASH_LOOTWON_RESET1, SLASH_LOOTWON_RESET2 = "/lootwonreset", "/lwr"
SlashCmdList.LOOTWON_RESET = function()
	ResetPositions()
	print("Loot Won Alert positions have been reset")
end

------------------
-- Alert Hiding --
------------------

local function Hook(frame, alertType, alertIndex, moverOnly)
	if hookedFrames[frame] then return end

	frame.LW_alertType = alertType
	frame.LW_alertIndex = alertIndex

	if not frame.LW_moverFrame then
		CreateMover(frame)
	end

	if moverOnly then return end

	hookedFrames[frame] = true
	originalScripts[frame] = frame:GetScript("OnShow")

	frame:HookScript("OnShow", frame.Hide)
	frame:Hide()
end

local function UpdateHooks(moverOnly)
	-- print("UpdateHooks:", moverOnly)
	for i = 1, #wonAlerts do
		Hook(wonAlerts[i], "wonAlerts", i, moverOnly)
	end
	
	for i = 1, #moneyAlerts do
		Hook(moneyAlerts[i], "moneyAlerts", i, moverOnly)
	end

	for i = 1, #upgradeAlerts do
		Hook(upgradeAlerts[i], "upgradeAlerts", i, moverOnly)
	end

	Hook(bonusAlert, "specialAlerts", 1,  moverOnly)
	Hook(garrisonMissionAlert, "specialAlerts", 2, moverOnly)
end

local function RemoveHooks()
	-- print("RemoveHooks")
	for frame in pairs(hookedFrames) do
		frame:SetScript("OnShow", originalScripts[frame])
		hookedFrames[frame] = nil
	end
end

SLASH_LOOTWON_SHOW1, SLASH_LOOTWON_SHOW2 = "/lootwonshow", "/lws"
SlashCmdList.LOOTWON_SHOW = function()
	LOOTWON_HIDE = false
	RemoveHooks()
	print("Loot Won Alerts shown.")
end

SLASH_LOOTWON_HIDE1, SLASH_LOOTWON_HIDE2 = "/lootwonhide", "/lwh"
SlashCmdList.LOOTWON_HIDE = function()
	LOOTWON_HIDE = true
	UpdateHooks()
	print("Loot Won Alerts hidden.")
end

local function LootWonAlertFrame_ShowAlert_Hook(itemLink, quantity, rollType, roll)
	if LOOTWON_HIDE == nil then
		LOOTWON_HIDE = true
	end

	UpdateHooks(not LOOTWON_HIDE)
end

hooksecurefunc("LootWonAlertFrame_ShowAlert", LootWonAlertFrame_ShowAlert_Hook)

local function GarrisonMissionAlertFrame_ShowAlert_Hook(missionID)
	if LOOTWON_HIDE == nil then
		LOOTWON_HIDE = true
	end

	UpdateHooks(not LOOTWON_HIDE)
end

hooksecurefunc("GarrisonMissionAlertFrame_ShowAlert", GarrisonMissionAlertFrame_ShowAlert_Hook)

---------------------
-- Saved Variables --
---------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

local meta = {
	__index = function(self, index) -- Automatically create a table when a non-existent index is accessed
		local t = {}
		rawset(self, index, t)
		return t
	end,
	__call = function(self, index, ...) -- Store the position of a frame when the table is called with an index and the returns of :GetPoint()
		local t = self[index]
		for i = 1, select("#", ...) do
			t[i] = select(i, ...)
		end
	end
}

local function makeTable()
	return setmetatable({}, meta)
end

function f:ADDON_LOADED(name)
	if name == addon then
		local savedPositions = LOOTWON_SAVED_POSITIONS

		if not savedPositions or not savedPositions.wonAlerts then
			savedPositions = { specialAlerts = {}, wonAlerts = {}, upgradeAlerts = {} }
		end
		
		savedPositions.moneyAlerts = savedPositions.moneyAlerts or {}

		setmetatable(savedPositions.specialAlerts, meta)
		setmetatable(savedPositions.wonAlerts, meta)
		setmetatable(savedPositions.moneyAlerts, meta)
		setmetatable(savedPositions.upgradeAlerts, meta)

		LOOTWON_SAVED_POSITIONS = savedPositions

		UpdateHooks(not LOOTWON_HIDE)
		self:UnregisterEvent("ADDON_LOADED")
	end
end

function f:PLAYER_ENTERING_WORLD()
	ShowFrames()
	HideFrames()
end
