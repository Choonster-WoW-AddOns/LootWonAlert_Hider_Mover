-- List globals here for Mikk's FindGlobals script.
--
-- Alert Frame functions
-- GLOBALS: AlertFrame_ResumeOutAnimation, AlertFrame_StopOutAnimation
--
-- Saved Variables:
-- GLOBALS: LOOTWON_SAVED_POSITIONS, LOOTWON_HIDDEN_ALERTS
--
-- WoW API functions:
-- GLOBALS: CreateFrame

local addon, ns = ...

local pairs, unpack, select, wipe = pairs, unpack, select, wipe
local tinsert = table.insert
local debugstack = debugstack

local pack, debugprint = ns.pack, ns.debugprint
local AlertTypes, MoverScripts = ns.AlertTypes, ns.MoverScripts

--------------------------
-- Base Mixin --
--------------------------

local Base_HookManagerMixin = {}
ns.Base_HookManagerMixin = Base_HookManagerMixin

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
	
	tinsert(AlertTypes, alertType)
end

function Base_HookManagerMixin:GetAlertType()
	return self.alertType
end

function Base_HookManagerMixin:AreAlertsHidden()
	return LOOTWON_HIDDEN_ALERTS[self:GetAlertType()]
end

function Base_HookManagerMixin:SetAlertsHidden(hidden)
	LOOTWON_HIDDEN_ALERTS[self:GetAlertType()] = hidden
end

function Base_HookManagerMixin:HookAlertFrames()
	local moverOnly = not self:AreAlertsHidden()
	
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

	local onShow = self:CreateNewOnShowScript(frame)
	frame:HookScript("OnShow", onShow)
	onShow(frame)
end

function Base_HookManagerMixin:CreateNewOnShowScript(frame)
	return frame.Hide
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
