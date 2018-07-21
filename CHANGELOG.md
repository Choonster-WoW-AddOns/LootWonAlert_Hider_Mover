## 1.15.00
- Update to 8.0 (80000)
- Add .travis.yml file and TOC properties for the BigWigs packager script
	- https://www.wowinterface.com/forums/showthread.php?t=55801

## 1.14.02
- Disable non-alpha comments
	- The CurseForge packager isn't replacing them properly
	- Should fix "LootWonAlert\_Hider\_Mover\core.lua:57: attempt to call upvalue 'debugprint' (a nil value)"

## 1.14.01
- Dummy version to try and fix the CurseForge packager.

## 1.14.00
- Update to 7.3 (70300)
- Add support for the New Pet and New Mount alerts
- Add support for the Boss Banner
- Add indexes to the Garrison Mission and Ship Mission alert mover text
- Allow individual alertTypes to be locked, unlocked, shown and hidden
- Split each section of the AddOn into its own file
- Clean up globals list and add missing entries

## 1.13.00
- Fix error "FrameXML\AlertFrameSystems.lua:715: attempt to index local 'missionInfo' (a number value)"
	- The Garrison Mission/Ship Mission Alerts now take the entire missionInfo table as an argument instead of just the mission ID

## 1.12.00
- Update to 7.1 (70100)
- Fix error "LootWonAlert\_Hider\_Mover\core.lua:384: table index is nil"
	- Remove the simple subsystem hook manager (used for Garrison Mission/Ship Mission Alerts) and replace it with the queue subsystem hook manager
	- The previous implementation of the simple subsystem has been replaced with the queue subsystem limited to one alert

## 1.11.00
- Update to 7.0 (70000)
- Rewrite for the new alert frame system
- Add support for the Garrison Ship Mission Alert
- Change the sample item from Enchanting Test Sword to Aluneth
  - The item data for Enchanting Test Sword is no longer available in-game

## 1.10.00
- Update to 6.2 (60200)
- Stop loot sound from being played at login

## 1.09.00
- Update to 6.1 (60100)
- Add support for the Money Won Alerts

## 1.08.00
- Fix Garrison Mission Alert being stretched when the alert(s) it's anchored to are moved
- Fix /lootwonreset command

## 1.07.00
- Fix error 'FrameXML\AlertFrames.lua:885: Usage: GetItemInfo(itemID|"name"|"itemlink")'
- Add support for the Loot Upgrade Alerts
- Any existing saved positions will be reset due to restructuring of the saved positions data

## 1.06.00
- Fix alert frames not being moved to saved positions (properly this time)

## 1.05.00
- Fix alert frames not being moved to saved positions
- Hook AlertFrame\_FixAnchors directly instead of AlertFrame\_SetLootWonAnchors/AlertFrame\_SetGarrisonMissionAlertFrameAnchors
- Add slash command to reset alert frames to their default positions

## 1.04.00
- Add support for GarrisonMissionAlertFrame

## 1.03.00
- Bump TOC Interface version

## 1.02.00
- Add .pkgmeta for CurseForge packager
- Add FindGlobals comment to core.lua and tools-used entry to .pkgmeta