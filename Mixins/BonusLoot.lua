-- List globals here for Mikk's FindGlobals script.
--
-- Alert Frame frames
-- GLOBALS: AlertFrame, BonusRollLootWonFrame, GroupLootContainer
--
-- Alert Frame functions
-- GLOBALS: GroupLootContainer_AddFrame, GroupLootContainer_RemoveFrame, GroupLootContainer_Update, LootWonAlertFrame_SetUp
--
-- FrameXML functions:
-- GLOBALS: CreateFromMixins
--
-- WoW API functions:
-- GLOBALS: hooksecurefunc

local addon, ns = ...

local unpack = unpack

local pack, debugprint = ns.pack, ns.debugprint

local SingleFrame_HookManagerMixin = ns.SingleFrame_HookManagerMixin

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

function ns.CreateAlertFrameBonusLoot_HookManager(sampleArgumentsFunction, moverTextFunction)
	local hookManager = CreateFromMixins(AlertFrameBonusLoot_HookManager)
	hookManager:OnLoad(sampleArgumentsFunction, moverTextFunction)
	return hookManager
end
