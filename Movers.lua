local addon, ns = ...

local debugprint = ns.debugprint

------------
-- Movers --
------------

local MoverScripts = {}
ns.MoverScripts = MoverScripts

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
