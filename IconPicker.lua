local _, ns = ...
local AngryAssign = LibStub("AceAddon-3.0"):GetAddon("AngryAssignments")

local AceGUI = LibStub("AceGUI-3.0")

local GetSpellInfo = ns.GetSpellInfo
local GetItemInfo = ns.GetItemInfo

local function AngryAssign_TextChanged()
	AngryAssign.window.button_revert:SetDisabled(false)
	AngryAssign.window.button_restore:SetDisabled(false)
	AngryAssign.window.button_display:SetDisabled(true)
	AngryAssign.window.button_output:SetDisabled(true)
end

local function AngryAssign_IconPicker_Clicked(widget, event)
	local icon
	if widget:GetUserData('name') then
		icon = widget:GetUserData('name')
	else
		icon = '{icon '..strmatch(widget.image:GetTexture():lower(), "^interface\\icons\\([-_%w]+)$")..'}'
	end

	local editBox = AngryAssign.window.text.editBox
	editBox:SetFocus()
	editBox:Insert(icon)
	AngryAssign.window.text.button:Enable()
	AngryAssign_TextChanged()
end

local iconCache = nil
local function AngryAssign_IconPicker_TextChanged(widget, event, value)
	AngryAssign.iconpicker_scroll:ReleaseChildren()

	local names = {}

	local spellID = strmatch(value, '|Hspell:(%d+)|')
	local itemID = strmatch(value, '|Hitem:(%d+):')

	if spellID then
		local path = select(3, GetSpellInfo(tonumber(spellID)))
		tinsert(names, path)
	elseif itemID then
		local path = select(10, GetItemInfo(tonumber(itemID)))
		tinsert(names, path)
	elseif value ~= "" then
		if not iconCache then iconCache = GetMacroIcons() end
		local iconsFound = 0
		local subname = value:lower()
		for _, path in ipairs(iconCache) do
			if path:lower():find(subname) then
				tinsert(names, "Interface\\Icons\\"..path)
				iconsFound = iconsFound + 1
			end

			if iconsFound >= 60 then
				break
			end
		end
	end

	for _, path in ipairs(names) do
		if path then
			local icon = AceGUI:Create("Icon")
			icon:SetImage(path)
			icon:SetImageSize(32, 32)
			icon:SetWidth(36)
			icon:SetHeight(36)
			icon:SetCallback('OnClick', AngryAssign_IconPicker_Clicked)
			AngryAssign.iconpicker_scroll:AddChild(icon)
		end
	end
end

function AngryAssign:CreateIconButton(name, texture)
	local icon = AceGUI:Create("Icon")
	icon:SetImage(texture)
	icon:SetImageSize(20, 20)
	icon:SetWidth(21)
	icon:SetHeight(24)
	icon:SetUserData('name', name)
	icon:SetCallback('OnClick', AngryAssign_IconPicker_Clicked)
	return icon
end

function AngryAssign:CreateIconPicker()
	local window = AceGUI:Create("Window")
	window:SetTitle("Insert an Icon")
	window:SetLayout("List")
	window:SetWidth(240)
	window:SetHeight(320)
	window.frame:SetParent(self.window.frame)
	window.frame:ClearAllPoints()
	window.frame:SetPoint("TOPLEFT", self.window.frame, "TOPRIGHT", 4, -4)
	window.frame:SetMovable(false)
	window.title:SetScript("OnMouseDown", nil)
	window.title:SetScript("OnMouseUp", nil)
	window:EnableResize(false)
	self.iconpicker = window

	local group = AceGUI:Create("SimpleGroup")
	group:SetLayout("Flow")
	group:SetFullWidth(true)
	for i = 8, 1, -1 do
		group:AddChild( self:CreateIconButton("{rt"..i.."}", "Interface\\TargetingFrame\\UI-RaidTargetingIcon_"..i) )
	end
	group:AddChild( self:CreateIconButton("{bl}", "Interface\\Icons\\SPELL_Nature_Bloodlust") )
	group:AddChild( self:CreateIconButton("{hs}", "Interface\\Icons\\INV_Stone_04") )
	window:AddChild(group)

	local heading = AceGUI:Create("Heading")
	heading:SetFullWidth(true)
	window:AddChild(heading)

	local text = AceGUI:Create("EditBox")
	text:SetFullWidth(true)
	text:DisableButton(true)
	text:SetCallback("OnTextChanged", AngryAssign_IconPicker_TextChanged)
	window:AddChild(text)

	local scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("Flow")
	scroll:SetFullWidth(true)
	scroll:SetFullHeight(true)
	window:AddChild(scroll)
	self.iconpicker_scroll = scroll
end
