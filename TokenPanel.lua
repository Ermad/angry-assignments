local _, ns = ...
local AngryAssign = LibStub("AceAddon-3.0"):GetAddon("AngryAssignments")

local AceGUI = LibStub("AceGUI-3.0")

local EnsureUnitShortName = ns.EnsureUnitShortName
local isClassicVanilla = ns.isClassicVanilla
local isClassicTBC = ns.isClassicTBC

local function MarkDirty()
	AngryAssign.window.button_revert:SetDisabled(false)
	AngryAssign.window.button_restore:SetDisabled(false)
	AngryAssign.window.button_display:SetDisabled(true)
	AngryAssign.window.button_output:SetDisabled(true)
end

local function InsertTextAtCursor(token)
	local id = AngryAssign:SelectedId()
	if not id or id < 0 then return end
	local editBox = AngryAssign.window.text.editBox
	editBox:SetFocus()
	editBox:Insert(token)
	AngryAssign.window.text.button:Enable()
	MarkDirty()
end

local function TokenClicked(widget)
	local token = widget:GetUserData('token')
	if token then
		InsertTextAtCursor(token)
	end
end

local function ShowTooltip(widget, tooltip)
	return function()
		GameTooltip:SetOwner(widget.frame or widget, "ANCHOR_RIGHT")
		GameTooltip:SetText(tooltip, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end
end

local function HideTooltip()
	GameTooltip:Hide()
end

local function CreateTokenIcon(token, texture, tooltip, coords)
	local icon = AceGUI:Create("Icon")
	if coords then
		icon:SetImage(texture, coords.l, coords.r, coords.t, coords.b)
	else
		icon:SetImage(texture)
	end
	icon:SetImageSize(20, 20)
	icon:SetWidth(21)
	icon:SetHeight(24)
	icon:SetUserData('token', token)
	icon:SetCallback('OnClick', TokenClicked)
	icon.frame:SetScript("OnEnter", ShowTooltip(icon, tooltip))
	icon.frame:SetScript("OnLeave", HideTooltip)
	return icon
end

local function GetRaidRoster()
	local roster = {}
	if IsInRaid() or IsInGroup() then
		for i = 1, GetNumGroupMembers() do
			local name, _, subgroup, _, _, fileName, _, online = GetRaidRosterInfo(i)
			if name then
				tinsert(roster, {
					name = EnsureUnitShortName(name),
					class = fileName,
					subgroup = subgroup,
					online = online,
				})
			end
		end
	elseif IsInGuild() and GetGuildRosterInfo then
		for i = 1, GetNumGuildMembers() do
			local name, _, _, _, _, _, _, _, isOnline, _, classFileName = GetGuildRosterInfo(i)
			if name and isOnline then
				tinsert(roster, {
					name = EnsureUnitShortName(name),
					class = classFileName,
					online = isOnline,
				})
			end
		end
	end
	table.sort(roster, function(a, b) return a.name < b.name end)
	return roster
end

local function ClearNamesFromText()
	if not AngryAssign.window then return end
	local text = AngryAssign.window.text:GetText()
	if not text or text == "" then return end

	-- Strip {name ...} tokens first
	local newText = text:gsub("{[Nn][Aa][Mm][Ee]%s+%S+%s+%u+}", "___")

	-- Fallback: also strip plain roster names (for manually typed names)
	local roster = GetRaidRoster()
	for _, info in ipairs(roster) do
		newText = newText:gsub(info.name, "___")
	end

	if newText == text then return end

	local id = AngryAssign:SelectedId()
	if id then
		AngryAssign:UpdateContents(id, newText)
	end
end

local function RefreshRosterList(scroll, filter)
	scroll:ReleaseChildren()
	local roster = GetRaidRoster()

	if #roster == 0 then
		local label = AceGUI:Create("Label")
		label:SetText("|cff808080Not in a group or guild|r")
		label:SetFullWidth(true)
		label:SetHeight(20)
		scroll:AddChild(label)
		return
	end

	local filterLower = filter and filter ~= "" and filter:lower() or nil

	for _, info in ipairs(roster) do
		if not filterLower or info.name:lower():find(filterLower, 1, true) then
			local label = AceGUI:Create("InteractiveLabel")
			local color = RAID_CLASS_COLORS[info.class]
			if color then
				label:SetText(format("|cff%02x%02x%02x%s|r",
					color.r * 255, color.g * 255, color.b * 255,
					info.name))
			else
				label:SetText(info.name)
			end
			label:SetFullWidth(true)
			label:SetUserData('token', '{name ' .. info.name .. ' ' .. (info.class or 'UNKNOWN') .. '}')
			label:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			label:SetCallback('OnClick', TokenClicked)
			scroll:AddChild(label)
		end
	end
end


function AngryAssign:CreateSidePanel()
	local window = AceGUI:Create("Window")
	window:SetTitle("Tokens & Variables")
	window:SetLayout("Fill")
	window:SetWidth(360)
	window:SetHeight(500)
	window.frame:SetParent(self.window.frame)
	window.frame:ClearAllPoints()
	window.frame:SetPoint("TOPLEFT", self.window.frame, "TOPRIGHT", 4, -4)
	window.frame:SetMovable(false)
	window.title:SetScript("OnMouseDown", nil)
	window.title:SetScript("OnMouseUp", nil)
	window:EnableResize(false)
	window:Hide()
	self.sidepanel = window

	local scroll = AceGUI:Create("ScrollFrame")
	scroll:SetLayout("List")
	scroll:SetFullWidth(true)
	scroll:SetFullHeight(true)
	window:AddChild(scroll)
	self.sidepanel_scroll = scroll

	-------------------------------------------------
	-- Section 1: Raid Icons
	-------------------------------------------------
	local iconHeading = AceGUI:Create("Heading")
	iconHeading:SetText("Raid Icons")
	iconHeading:SetFullWidth(true)
	scroll:AddChild(iconHeading)

	local iconGroup = AceGUI:Create("SimpleGroup")
	iconGroup:SetLayout("Flow")
	iconGroup:SetFullWidth(true)
	local raidIcons = {
		{ token = "{skull}",    texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", tip = "{skull} or {rt8}" },
		{ token = "{cross}",    texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", tip = "{cross} or {x} or {rt7}" },
		{ token = "{square}",   texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6", tip = "{square} or {rt6}" },
		{ token = "{moon}",     texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5", tip = "{moon} or {rt5}" },
		{ token = "{triangle}", texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4", tip = "{triangle} or {rt4}" },
		{ token = "{diamond}",  texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", tip = "{diamond} or {rt3}" },
		{ token = "{circle}",   texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2", tip = "{circle} or {rt2}" },
		{ token = "{star}",     texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", tip = "{star} or {rt1}" },
	}
	for _, ri in ipairs(raidIcons) do
		iconGroup:AddChild(CreateTokenIcon(ri.token, ri.texture, ri.tip))
	end
	scroll:AddChild(iconGroup)

	-------------------------------------------------
	-- Section 2: Roles & Buffs
	-------------------------------------------------
	local roleHeading = AceGUI:Create("Heading")
	roleHeading:SetText("Roles & Buffs")
	roleHeading:SetFullWidth(true)
	scroll:AddChild(roleHeading)

	local roleGroup = AceGUI:Create("SimpleGroup")
	roleGroup:SetLayout("Flow")
	roleGroup:SetFullWidth(true)
	local roles = {
		{ token = "{tank}",   texture = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES", tip = "{tank}", coords = { l = 0, r = 0.296875, t = 0.34375, b = 0.640625 } },
		{ token = "{healer}", texture = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES", tip = "{healer}", coords = { l = 0.3125, r = 0.609375, t = 0.015625, b = 0.3125 } },
		{ token = "{dps}",    texture = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES", tip = "{dps} or {damage}", coords = { l = 0.3125, r = 0.609375, t = 0.34375, b = 0.640625 } },
	}
	for _, role in ipairs(roles) do
		roleGroup:AddChild(CreateTokenIcon(role.token, role.texture, role.tip, role.coords))
	end
	roleGroup:AddChild(CreateTokenIcon("{bl}", "Interface\\Icons\\SPELL_Nature_Bloodlust", "{bl} or {bloodlust}"))
	roleGroup:AddChild(CreateTokenIcon("{hs}", "Interface\\Icons\\INV_Stone_04", "{hs} or {healthstone}"))
	scroll:AddChild(roleGroup)

	-------------------------------------------------
	-- Section: CC & Dispels
	-------------------------------------------------
	local ccHeading = AceGUI:Create("Heading")
	ccHeading:SetText("CC & Dispels")
	ccHeading:SetFullWidth(true)
	scroll:AddChild(ccHeading)

	local ccGroup = AceGUI:Create("SimpleGroup")
	ccGroup:SetLayout("Flow")
	ccGroup:SetFullWidth(true)

	-- Interrupt
	ccGroup:AddChild(CreateTokenIcon("{icon Ability_Kick}", "Interface\\Icons\\Ability_Kick", "Kick (Rogue)\nInserts: {icon Ability_Kick}"))

	-- CC (all versions)
	ccGroup:AddChild(CreateTokenIcon("{icon Spell_Nature_Polymorph}", "Interface\\Icons\\Spell_Nature_Polymorph", "Polymorph (Mage)\nInserts: {icon Spell_Nature_Polymorph}"))
	ccGroup:AddChild(CreateTokenIcon("{icon Spell_Shadow_Possession}", "Interface\\Icons\\Spell_Shadow_Possession", "Fear (Warlock)\nInserts: {icon Spell_Shadow_Possession}"))
	ccGroup:AddChild(CreateTokenIcon("{icon Spell_Shadow_Cripple}", "Interface\\Icons\\Spell_Shadow_Cripple", "Banish (Warlock)\nInserts: {icon Spell_Shadow_Cripple}"))
	ccGroup:AddChild(CreateTokenIcon("{icon Spell_Nature_Slow}", "Interface\\Icons\\Spell_Nature_Slow", "Shackle Undead (Priest)\nInserts: {icon Spell_Nature_Slow}"))
	ccGroup:AddChild(CreateTokenIcon("{icon Spell_Nature_Sleep}", "Interface\\Icons\\Spell_Nature_Sleep", "Hibernate (Druid)\nInserts: {icon Spell_Nature_Sleep}"))
	ccGroup:AddChild(CreateTokenIcon("{icon Spell_Holy_PrayerOfHealing}", "Interface\\Icons\\Spell_Holy_PrayerOfHealing", "Repentance (Paladin)\nInserts: {icon Spell_Holy_PrayerOfHealing}"))

	-- Dispels (all versions)
	ccGroup:AddChild(CreateTokenIcon("{icon Spell_Nature_Purge}", "Interface\\Icons\\Spell_Nature_Purge", "Purge (Shaman)\nInserts: {icon Spell_Nature_Purge}"))
	ccGroup:AddChild(CreateTokenIcon("{icon Ability_Hunter_BeastSoothe}", "Interface\\Icons\\Ability_Hunter_BeastSoothe", "Soothe (Druid)\nInserts: {icon Ability_Hunter_BeastSoothe}"))
	ccGroup:AddChild(CreateTokenIcon("{icon Spell_Nature_Drowsy}", "Interface\\Icons\\Spell_Nature_Drowsy", "Tranquilizing Shot (Hunter)\nInserts: {icon Spell_Nature_Drowsy}"))

	-- TBC+ abilities
	if not isClassicVanilla then
		ccGroup:AddChild(CreateTokenIcon("{icon Spell_Arcane_Arcane02}", "Interface\\Icons\\Spell_Arcane_Arcane02", "Spellsteal (Mage)\nInserts: {icon Spell_Arcane_Arcane02}"))
		ccGroup:AddChild(CreateTokenIcon("{icon Spell_Arcane_MassDispel}", "Interface\\Icons\\Spell_Arcane_MassDispel", "Mass Dispel (Priest)\nInserts: {icon Spell_Arcane_MassDispel}"))

		-- Wrath+ abilities
		if not isClassicTBC then
			ccGroup:AddChild(CreateTokenIcon("{icon Spell_Shaman_Hex}", "Interface\\Icons\\Spell_Shaman_Hex", "Hex (Shaman)\nInserts: {icon Spell_Shaman_Hex}"))
		end
	end

	scroll:AddChild(ccGroup)

	-------------------------------------------------
	-- Section: Page Break
	-------------------------------------------------
	local pageBreakHeading = AceGUI:Create("Heading")
	pageBreakHeading:SetText("Layout")
	pageBreakHeading:SetFullWidth(true)
	scroll:AddChild(pageBreakHeading)

	local pageBreakLabel = AceGUI:Create("InteractiveLabel")
	pageBreakLabel:SetText("|cff808080{page}|r  Page break")
	pageBreakLabel:SetFullWidth(true)
	pageBreakLabel:SetUserData('token', '{page}')
	pageBreakLabel:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	pageBreakLabel:SetCallback('OnClick', TokenClicked)
	pageBreakLabel.frame:SetScript("OnEnter", ShowTooltip(pageBreakLabel, "{page}\nSplits content into clickable pages.\nLeft-click display to go forward, right-click to go back."))
	pageBreakLabel.frame:SetScript("OnLeave", HideTooltip)
	scroll:AddChild(pageBreakLabel)

	-------------------------------------------------
	-- Section 3: Color Codes Reference
	-------------------------------------------------
	local colorHeading = AceGUI:Create("Heading")
	colorHeading:SetText("Color Codes")
	colorHeading:SetFullWidth(true)
	scroll:AddChild(colorHeading)

	local colorGroup = AceGUI:Create("SimpleGroup")
	colorGroup:SetLayout("Flow")
	colorGroup:SetFullWidth(true)
	local colorCodes = {
		{ token = "|cblue",    color = "00cbf4", tip = "|cblue ... |" },
		{ token = "|cgreen",   color = "0adc00", tip = "|cgreen ... |" },
		{ token = "|cred",     color = "eb310c", tip = "|cred ... |" },
		{ token = "|cyellow",  color = "faf318", tip = "|cyellow ... |" },
		{ token = "|corange",  color = "ff9d00", tip = "|corange ... |" },
		{ token = "|cpink",    color = "f64c97", tip = "|cpink ... |" },
		{ token = "|cpurple",  color = "dc44eb", tip = "|cpurple ... |" },
	}
	local classColors = {
		{ token = "|cwarrior",  color = "c79c6e", tip = "|cwarrior ... |" },
		{ token = "|cpaladin",  color = "f58cba", tip = "|cpaladin ... |" },
		{ token = "|chunter",   color = "abd473", tip = "|chunter ... |" },
		{ token = "|crogue",    color = "fff569", tip = "|crogue ... |" },
		{ token = "|cpriest",   color = "ffffff", tip = "|cpriest ... |" },
		{ token = "|cshaman",   color = "0070de", tip = "|cshaman ... |" },
		{ token = "|cmage",     color = "40c7eb", tip = "|cmage ... |" },
		{ token = "|cwarlock",  color = "8787ed", tip = "|cwarlock ... |" },
		{ token = "|cdruid",    color = "ff7d0a", tip = "|cdruid ... |" },
		{ token = "|cdk",       color = "c41f3b", tip = "|cdk or |cdeathknight ... |" },
	}

	for _, cc in ipairs(colorCodes) do
		local label = AceGUI:Create("InteractiveLabel")
		label:SetText(format("|cff%s%s|r", cc.color, cc.token))
		label:SetWidth(70)
		label:SetUserData('token', cc.token)
		label:SetCallback('OnClick', TokenClicked)
		label.frame:SetScript("OnEnter", ShowTooltip(label, cc.tip .. "\nInserts: " .. cc.token))
		label.frame:SetScript("OnLeave", HideTooltip)
		colorGroup:AddChild(label)
	end
	for _, cc in ipairs(classColors) do
		local label = AceGUI:Create("InteractiveLabel")
		label:SetText(format("|cff%s%s|r", cc.color, cc.token))
		label:SetWidth(70)
		label:SetUserData('token', cc.token)
		label:SetCallback('OnClick', TokenClicked)
		label.frame:SetScript("OnEnter", ShowTooltip(label, cc.tip .. "\nInserts: " .. cc.token))
		label.frame:SetScript("OnLeave", HideTooltip)
		colorGroup:AddChild(label)
	end
	scroll:AddChild(colorGroup)

	-------------------------------------------------
	-- Section 4: Variables (dynamic, rebuilt on selection change)
	-------------------------------------------------
	local varsContainer = AceGUI:Create("SimpleGroup")
	varsContainer:SetLayout("List")
	varsContainer:SetFullWidth(true)
	scroll:AddChild(varsContainer)
	self.sidepanel_vars = varsContainer

	-------------------------------------------------
	-- Section 5: Players
	-------------------------------------------------
	local rosterHeading = AceGUI:Create("Heading")
	rosterHeading:SetText("Players")
	rosterHeading:SetFullWidth(true)
	scroll:AddChild(rosterHeading)

	local clearBtn = AceGUI:Create("Button")
	clearBtn:SetText("Clear Names")
	clearBtn:SetFullWidth(true)
	clearBtn:SetHeight(20)
	clearBtn:SetCallback("OnClick", function() ClearNamesFromText() end)
	scroll:AddChild(clearBtn)

	local searchBox = AceGUI:Create("EditBox")
	searchBox:SetFullWidth(true)
	searchBox:DisableButton(true)
	searchBox:SetLabel("Search")
	scroll:AddChild(searchBox)
	self.sidepanel_searchbox = searchBox

	local rosterScroll = AceGUI:Create("ScrollFrame")
	rosterScroll:SetLayout("List")
	rosterScroll:SetFullWidth(true)
	rosterScroll:SetHeight(180)
	scroll:AddChild(rosterScroll)
	self.sidepanel_roster = rosterScroll

	searchBox:SetCallback("OnTextChanged", function(_, _, value)
		RefreshRosterList(rosterScroll, value)
	end)

	self:ScheduleTimer(function() RefreshRosterList(rosterScroll) end, 0)
end

function AngryAssign:RefreshSidePanel()
	if not self.sidepanel or not self.sidepanel.frame:IsShown() then return end

	-- Refresh variables section
	if self.sidepanel_vars then
		self.sidepanel_vars:ReleaseChildren()
		self:BuildVariablesSection(self.sidepanel_vars)
	end

	-- Recalculate scroll content height so scrollbar updates
	if self.sidepanel_scroll then
		self.sidepanel_scroll:DoLayout()
	end
end

function AngryAssign:RefreshSidePanelRoster()
	if self.sidepanel and self.sidepanel_roster then
		local filter
		if self.sidepanel_searchbox then
			filter = self.sidepanel_searchbox:GetText()
		end
		RefreshRosterList(self.sidepanel_roster, filter)
	end
end
