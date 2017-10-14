-- List globals here for Mikk's FindGlobals script.
--
-- FrameXML functions:
-- GLOBALS: CreateFromMixins
--
-- WoW API functions:
-- GLOBALS: hooksecurefunc

local addon, ns = ...

local unpack = unpack

local pack, debugprint = ns.pack, ns.debugprint

local Base_HookManagerMixin = ns.Base_HookManagerMixin

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
		debugprint("Queue:HookAlertFrame", "AlertType", self:GetAlertType(), "Setting index to", self.subsystem:GetNumVisibleAlerts())
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

function ns.CreateAlertFrameQueueSystem_HookManager(subsystem, alertType, sampleArgumentsFunction, moverTextFunction)
	local hookManager = CreateFromMixins(AlertFrameQueueSystem_HookManagerMixin)
	hookManager:OnLoad(subsystem, alertType, sampleArgumentsFunction, moverTextFunction)
	return hookManager
end
