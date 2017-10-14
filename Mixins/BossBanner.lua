-- List globals here for Mikk's FindGlobals script.
--
-- Alert Frame frames
-- GLOBALS: BossBanner
--
-- Alert Frame functions
-- GLOBALS: BossBanner_OnEvent, BossBanner_SetAnimState, BossBanner_OnAnimOutFinished
--
-- FrameXML functions:
-- GLOBALS: CreateFromMixins

local addon, ns = ...

local unpack = unpack

local pack, debugprint = ns.pack, ns.debugprint

local SingleFrame_HookManagerMixin = ns.SingleFrame_HookManagerMixin

-----------------------
-- Boss Banner Mixin --
-----------------------

local BB_STATE_BANNER_OUT = 6

local BossBanner_HookManagerMixin = CreateFromMixins(SingleFrame_HookManagerMixin)

function BossBanner_HookManagerMixin:OnLoad(sampleArgumentsFunction, moverTextFunction)
	SingleFrame_HookManagerMixin.OnLoad(self, BossBanner, "BossBanner", sampleArgumentsFunction, moverTextFunction)
	
	self.frame:HookScript("OnShow", function(frame)
		self:ReanchorAlert(frame)
	end)
end

function BossBanner_HookManagerMixin:CreateNewOnShowScript(frame)
	debugprint("BossBanner:CreateNewOnShowScript")
	return function(frame)
		debugprint("BossBanner:OnShow hook")
		BossBanner_OnAnimOutFinished(frame.AnimOut)
	end
end

function BossBanner_HookManagerMixin:StopOutAnimation(frame)
	debugprint("BossBanner:StopOutAnimation")
	BossBanner_SetAnimState(frame, nil)
end

function BossBanner_HookManagerMixin:ResumeOutAnimation(frame)
	debugprint("BossBanner:ResumeOutAnimation")
	BossBanner_SetAnimState(frame, BB_STATE_BANNER_OUT)
end

function BossBanner_HookManagerMixin:ShowAlerts()
	local arguments = pack(self.sampleArgumentsFunction())
	
	debugprint("BossBanner:ShowAlerts", "Args:", unpack(arguments, 1, arguments.n))
	
	BossBanner_OnEvent(self.frame, "BOSS_KILL", unpack(arguments, 1, arguments.n))
	
	return true
end

function ns.CreateBossBanner_HookManager(sampleArgumentsFunction, moverTextFunction)
	local hookManager = CreateFromMixins(BossBanner_HookManagerMixin)
	hookManager:OnLoad(sampleArgumentsFunction, moverTextFunction)
	return hookManager
end
