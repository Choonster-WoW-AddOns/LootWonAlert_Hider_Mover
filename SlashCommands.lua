-- List globals here for Mikk's FindGlobals script.
--
-- Slash commands:
-- GLOBALS: SLASH_LOOTWON_TOGGLELOCK1, SLASH_LOOTWON_TOGGLELOCK2 , SLASH_LOOTWON_SHOW1, SLASH_LOOTWON_SHOW2, SLASH_LOOTWON_HIDE1, SLASH_LOOTWON_HIDE2, SLASH_LOOTWON_RESET1, SLASH_LOOTWON_RESET2
--
-- WoW API functions:
-- GLOBALS: C_Garrison
--
-- Constants:
-- GLOBALS: LE_GARRISON_TYPE_6_0, LE_GARRISON_TYPE_7_0

local addon, ns = ...
local AlertTypes, HookManagers = ns.AlertTypes, ns.HookManagers

local print, pairs, tconcat = print, pairs, table.concat

local function printf(formatString, ...)
	print(formatString:format(...))
end

--------------------
-- Slash Commands --
--------------------

local UnlockedAlerts = {}

local PrintInvalidAlertTypeMessage
do
	local allAlertTypes
	
	PrintInvalidAlertTypeMessage = function(invalidAlertType)
		if not allAlertTypes then
			allAlertTypes = "all, " .. tconcat(AlertTypes, ", ")
		end
		
		printf("Invalid alertType \"%s\". Valid alertTypes: %s", invalidAlertType, allAlertTypes)
	end
end

local function ShowAlertsAndMovers(hookManager)
	local success = hookManager:ShowAlerts()
	if success then
		hookManager:ShowMovers()
	else
		local alertType = hookManager:GetAlertType()
		
		-- Don't warn players about Garrison alerts if they don't have a Garrison or Shipyard alerts if they don't have a shipyard
		if 
			(alertType == "GarrisonMission" and not C_Garrison.HasGarrison(LE_GARRISON_TYPE_7_0) and not C_Garrison.HasGarrison(LE_GARRISON_TYPE_6_0)) or
			(alertType == "GarrisonShipMission" and not C_Garrison.HasShipyard())
		then return end
		
		print(("Failed to show alerts of type %s. Try locking and unlocking again."):format(alertType))
	end
end

-- Create a slash command function that performs an action for the specified alertType or prints an error message if it isn't.
-- preprocessor - function(inputAlertType)         - Called once at the start of the function with the specified alertType.
-- callback     - function(alertType, hookManager) - If the specified alertType is "all", this is called once for every hookManager.
--                                                     - If it returns false every time, messageFunc won't be called and no message will be printed.
--                                                 - If the specified alertType isn't "all", this is called once for the specified alertType's hookManager.
--                                                     - If it returns false, messageFunc won't be called and no message will be printed.
-- messageFunc  - function(inputAlertType)         - Called once at the end of the function with the specified alertType to get a message to print.
local function CreateSlashCommand(preprocessor, callback, messageFunc)
	return function(input)
		local inputAlertType = input:trim()
		
		if inputAlertType == "all" then
			preprocessor(inputAlertType)
		
			local success = false
			
			for alertType, hookManager in pairs(HookManagers) do
				local ret = callback(inputAlertType, hookManager)
				success = success or ret
			end
			
			if success then
				print(messageFunc("All"))
			end
			
			return
		end
		
		local hookManager = HookManagers[inputAlertType]
		if hookManager then
			preprocessor(inputAlertType)
			
			local success = callback(inputAlertType, hookManager)
			if success then
				print(messageFunc(inputAlertType))
			end
		else
			PrintInvalidAlertTypeMessage(inputAlertType)
		end
	end
end

SLASH_LOOTWON_TOGGLELOCK1, SLASH_LOOTWON_TOGGLELOCK2 = "/lootwonlock", "/lwl"
SlashCmdList.LOOTWON_TOGGLELOCK = CreateSlashCommand(
	function(inputAlertType)
		if UnlockedAlerts[inputAlertType] == nil then
			UnlockedAlerts[inputAlertType] = true
		else
			UnlockedAlerts[inputAlertType] = not UnlockedAlerts[inputAlertType]
		end
	end,
	function(inputAlertType, hookManager)
		if UnlockedAlerts[inputAlertType] then
			if hookManager:AreAlertsHidden() then
				printf("%1$s alerts are hidden. Use /lootwonshow %1$s or /lws %1$s to show them before using /lootwonlock %1$s again.", hookManager:GetAlertType())
				
				return false
			else
				ShowAlertsAndMovers(hookManager)
			end
		else
			hookManager:HideMovers()
		end
		
		return true
	end,
	function(inputAlertType)
		if UnlockedAlerts[inputAlertType] then
			return ("%s alerts unlocked"):format(inputAlertType)
		else
			return ("%s alerts locked"):format(inputAlertType)
		end
	end
)

SLASH_LOOTWON_RESET1, SLASH_LOOTWON_RESET2 = "/lootwonreset", "/lwr"
SlashCmdList.LOOTWON_RESET = CreateSlashCommand(
	function(inputAlertType)
	end,
	function(inputAlertType, hookManager)
		hookManager:HideAlerts()
		hookManager:HideMovers()
		hookManager:ResetPositions()
		ShowAlertsAndMovers(hookManager)
		
		return true
	end,
	function(inputAlertType)
		return ("%s alert positions have been reset."):format(inputAlertType)
	end
)

SLASH_LOOTWON_SHOW1, SLASH_LOOTWON_SHOW2 = "/lootwonshow", "/lws"
SlashCmdList.LOOTWON_SHOW = CreateSlashCommand(
	function(inputAlertType)
	end,
	function(inputAlertType, hookManager)
		hookManager:SetAlertsHidden(false)
		hookManager:RemoveHooks()
		
		return true
	end,
	function(inputAlertType)
		return ("%s alerts shown."):format(inputAlertType)
	end
)

SLASH_LOOTWON_HIDE1, SLASH_LOOTWON_HIDE2 = "/lootwonhide", "/lwh"
SlashCmdList.LOOTWON_HIDE = CreateSlashCommand(
	function(inputAlertType)
	end,
	function(inputAlertType, hookManager)
		hookManager:SetAlertsHidden(true)
		hookManager:HookAlertFrames()
		
		return true
	end,
	function(inputAlertType)
		return ("%s alerts hidden."):format(inputAlertType)
	end
)
