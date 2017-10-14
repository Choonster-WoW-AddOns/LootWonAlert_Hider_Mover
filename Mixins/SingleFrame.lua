-- List globals here for Mikk's FindGlobals script.
--
-- FrameXML functions:
-- GLOBALS: CreateFromMixins

local addon, ns = ...

local pairs = pairs

local Base_HookManagerMixin = ns.Base_HookManagerMixin

------------------------
-- Single Frame Mixin --
------------------------

local SingleFrame_HookManagerMixin = CreateFromMixins(Base_HookManagerMixin)
ns.SingleFrame_HookManagerMixin = SingleFrame_HookManagerMixin

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
