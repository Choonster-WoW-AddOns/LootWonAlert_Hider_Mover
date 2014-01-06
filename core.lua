local NUM_SAMPLE_FRAMES = 5 -- 5 alert frames just about fill the screen
local SAMPLE_ITEMID = 80211 -- Enchanting Test Sword
local SAMPLE_ITEMLINK;

-------------------
-- END OF CONFIG --
-------------------
-- Do not change anything below here!

-- List globals here for Mikk's FindGlobals script.
--
-- Slash commands:
-- GLOBALS: SLASH_LOOTWON_TOGGLELOCK1, SLASH_LOOTWON_TOGGLELOCK2 , SLASH_LOOTWON_SHOW1, SLASH_LOOTWON_SHOW2, SLASH_LOOTWON_HIDE1, SLASH_LOOTWON_HIDE2
--
-- AlertFrame functions:
-- GLOBALS: AlertFrame_ResumeOutAnimation, AlertFrame_SetLootWonAnchors, AlertFrame_StopOutAnimation, LootWonAlertFrame_ShowAlert
--
-- SavedVariables:
-- GLOBALS: LOOTWON_HIDE, LOOTWON_SHOW, LOOTWON_SAVED_POSITIONS
--
-- WoW API functions:
-- GLOBALS: GetItemInfo, CreateFrame
--
-- Constants:
-- GLOBALS: LOOT_ROLL_TYPE_NEED

local addon, ns = ...

local UNLOCKED = false
local originalScripts = {}
local hookedFrames = {}
local movers = {}
-- LW_MOVERS = movers
-- LW_HOOKED = hookedFrames

local alerts = LOOT_WON_ALERT_FRAMES
local bonusAlert = BonusRollLootWonFrame

local rawget, rawset, pairs, unpack, setmetatable = rawget, rawset, pairs, unpack, setmetatable
local select, print = select, print

------------
-- Movers --
------------

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
	LOOTWON_SAVED_POSITIONS(self.alertIndex, self.parent:GetPoint()) -- Store the position using the __call metamethod
	
	local savedPos = LOOTWON_SAVED_POSITIONS[self.alertIndex]
	local anchor = savedPos[2]
	if anchor and anchor.GetName then
		savedPos[2] = anchor:GetName()
	end
end

local function CreateMover(frame)
	-- print("CreateMover!", frame, frame:GetName())
	frame:SetMovable(true)
	
	local mover = CreateFrame("Frame", "$parentMoverFrame", frame)
	mover.parent = frame
	mover.alertIndex = frame.alertIndex
	mover:SetAllPoints()
	mover:RegisterForDrag("LeftButton")
	mover:Hide()
	
	for script, func in pairs(Mover) do
		mover:SetScript(script, func)
	end
	
	frame.moverFrame = mover
	
	local overlay = mover:CreateTexture("$parentOverlay")
	overlay:SetDrawLayer("OVERLAY", 6)
	overlay:SetTexture("Interface\\Tooltips\\UI-Tooltip-Background")
	overlay:SetVertexColor(0, 1, 0, 0.8)
	overlay:SetBlendMode("BLEND")
	overlay:SetAllPoints()
	mover.overlay = overlay
	
	local text = mover:CreateFontString("$parentText", "OVERLAY", "GameFontNormal")
	text:SetDrawLayer("OVERLAY", 7)
	text:SetFormattedText("Loot Won Alert #%d\n\nClick and drag to move this frame.", frame.alertIndex)
	text:SetPoint("CENTER")
	mover.text = text
	
	movers[frame.alertIndex] = mover
end

local function Reanchor()
	-- print("Reanchor")
	for _, mover in pairs(movers) do
		local savedPos = rawget(LOOTWON_SAVED_POSITIONS, mover.alertIndex)
		if savedPos then
			mover.parent:ClearAllPoints()
			mover.parent:SetPoint(unpack(savedPos))
		end
	end
end

local function ShowMovers()
	-- print"ShowMovers"
	UNLOCKED = true
	GetLink()
	for i = 1, NUM_SAMPLE_FRAMES do
		LootWonAlertFrame_ShowAlert(SAMPLE_ITEMLINK, 1, LOOT_ROLL_TYPE_NEED, 42)
	end
	
	for _, mover in pairs(movers) do
		mover:Show()
	end
	
	Reanchor()
end

local function HideMovers()
	-- print"HideMovers"
	UNLOCKED = false
	for _, mover in pairs(movers) do
		mover:Hide()
	end
end

local function AlertFrame_SetLootWonAnchors_Hook(alertAnchor)
	-- print("AF_SLWA_Hook")
	Reanchor()
end

hooksecurefunc("AlertFrame_SetLootWonAnchors", AlertFrame_SetLootWonAnchors_Hook)

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

------------------
-- Alert Hiding --
------------------

local function Hook(frame, alertIndex, moverOnly)
	if hookedFrames[frame] then return end
	
	frame.alertIndex = alertIndex
	
	if not frame.moverFrame then
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
	for i = 1, #alerts do
		local frame = alerts[i]
		Hook(frame, i, moverOnly)
	end
	
	Hook(bonusAlert, -1,  moverOnly) -- We give the bonus alert frame the special index -1 because it's not in the LOOT_WON_ALERT_FRAMES table
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

---------------------
-- Saved Variables --
---------------------

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, ...)
	self[event](self, ...)
end)

function f:ADDON_LOADED(name)
	if name == addon then
		LOOTWON_SAVED_POSITIONS = LOOTWON_SAVED_POSITIONS or {}
		setmetatable(LOOTWON_SAVED_POSITIONS, {
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
		})
		UpdateHooks(not LOOTWON_HIDE)
		self:UnregisterEvent("ADDON_LOADED")
	end
end