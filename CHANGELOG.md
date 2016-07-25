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
- Hook AlertFrame_FixAnchors directly instead of AlertFrame_SetLootWonAnchors/AlertFrame_SetGarrisonMissionAlertFrameAnchors
- Add slash command to reset alert frames to their default positions

## 1.04.00
- Add support for GarrisonMissionAlertFrame

## 1.03.00
- Bump TOC Interface version

## 1.02.00
- Add .pkgmeta for CurseForge packager
- Add FindGlobals comment to core.lua and tools-used entry to .pkgmeta