local _ = ...
local AngryAssign = LibStub("AceAddon-3.0"):GetAddon("AngryAssignments")

local LibDBIcon = LibStub("LibDBIcon-1.0", true)
local LibDataBroker = LibStub("LibDataBroker-1.1", true)

local LDB_NAME = "AngryAssignments"

function AngryAssign:InitMinimapButton()
	if not LibDataBroker or not LibDBIcon then
		if self:GetConfig('showMinimapButton') then
			self:Print("Minimap button requires LibDataBroker-1.1 and LibDBIcon-1.0.")
		end
		return
	end

	if AngryAssign_Config.minimapIcon == nil then
		AngryAssign_Config.minimapIcon = {}
	end

	local object = LibDataBroker:NewDataObject(LDB_NAME, {
		type = "launcher",
		text = "Angry Assignments+",
		icon = "Interface\\Icons\\INV_Misc_Note_06",
		OnClick = function(_, button)
			if button == "LeftButton" then
				AngryAssign_ToggleWindow()
			elseif button == "RightButton" then
				AngryAssign_ToggleDisplay()
			end
		end,
		OnTooltipShow = function(tooltip)
			tooltip:AddLine("Angry Assignments+")
			tooltip:AddLine("Left-click: Toggle window", 1, 1, 1)
			tooltip:AddLine("Right-click: Toggle display", 1, 1, 1)
		end,
	})

	LibDBIcon:Register(LDB_NAME, object, AngryAssign_Config.minimapIcon)
	self:UpdateMinimapButton()
end

function AngryAssign:UpdateMinimapButton()
	if not LibDBIcon or not AngryAssign_Config.minimapIcon then return end
	if self:GetConfig('showMinimapButton') then
		AngryAssign_Config.minimapIcon.hide = false
		LibDBIcon:Show(LDB_NAME)
	else
		AngryAssign_Config.minimapIcon.hide = true
		LibDBIcon:Hide(LDB_NAME)
	end
end
