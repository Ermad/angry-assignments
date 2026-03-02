local _, ns = ...
local AngryAssign = LibStub("AceAddon-3.0"):GetAddon("AngryAssignments")

local AceGUI = LibStub("AceGUI-3.0")

local EnsureUnitShortName = ns.EnsureUnitShortName

-- Marker token names used for Clear Names matching
local MARKER_TOKENS = {
	"{rt1}", "{rt2}", "{rt3}", "{rt4}", "{rt5}", "{rt6}", "{rt7}", "{rt8}",
	"{skull}", "{cross}", "{x}", "{star}", "{circle}", "{diamond}", "{triangle}", "{moon}", "{square}",
	"{tank}", "{healer}", "{dps}", "{damage}",
}

local function MarkDirty()
	AngryAssign.window.button_revert:SetDisabled(false)
	AngryAssign.window.button_restore:SetDisabled(false)
	AngryAssign.window.button_display:SetDisabled(true)
	AngryAssign.window.button_output:SetDisabled(true)
end

local function InsertTextAtCursor(token)
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

local function EscapePattern(str)
	return str:gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
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
		-- Request guild data in retail (Classic uses GuildRoster() in Core.lua)
		if not ns.isClassic and C_GuildInfo and C_GuildInfo.GuildRoster then
			C_GuildInfo.GuildRoster()
		end
		for i = 1, GetNumGuildMembers() do
			local name, _, _, _, _, _, _, _, isOnline, _, classFileName = GetGuildRosterInfo(i)
			if name then
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

	local roster = GetRaidRoster()
	if #roster == 0 then return end

	for _, info in ipairs(roster) do
		local escaped = EscapePattern(info.name)
		for _, marker in ipairs(MARKER_TOKENS) do
			local escapedMarker = EscapePattern(marker)
			text = text:gsub("(" .. escapedMarker .. ")(%s+)" .. escaped, "%1%2")
		end
		text = text:gsub("([:%-])(%s+)" .. escaped, "%1%2")
	end

	AngryAssign.window.text:SetText(text)
	AngryAssign.window.text.button:Enable()
	MarkDirty()
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
			label:SetUserData('token', info.name)
			label:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight")
			label:SetCallback('OnClick', TokenClicked)
			scroll:AddChild(label)
		end
	end
end


function AngryAssign:CreateTokenPanel()
	local window = AceGUI:Create("Window")
	window:SetTitle("Tokens & Roster")
	window:SetLayout("List")
	window:SetWidth(240)
	window:SetHeight(500)
	window.frame:SetParent(self.window.frame)
	window.frame:ClearAllPoints()
	window.frame:SetPoint("TOPLEFT", self.window.frame, "TOPRIGHT", 4, -4)
	window.frame:SetMovable(false)
	window.title:SetScript("OnMouseDown", nil)
	window.title:SetScript("OnMouseUp", nil)
	window:EnableResize(false)
	self.tokenpanel = window

	-------------------------------------------------
	-- Section 1: Raid Icons
	-------------------------------------------------
	local iconHeading = AceGUI:Create("Heading")
	iconHeading:SetText("Raid Icons")
	iconHeading:SetFullWidth(true)
	window:AddChild(iconHeading)

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
	window:AddChild(iconGroup)

	-------------------------------------------------
	-- Section 2: Roles & Buffs
	-------------------------------------------------
	local roleHeading = AceGUI:Create("Heading")
	roleHeading:SetText("Roles & Buffs")
	roleHeading:SetFullWidth(true)
	window:AddChild(roleHeading)

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
	window:AddChild(roleGroup)

	-------------------------------------------------
	-- Section 3: Color Codes Reference
	-------------------------------------------------
	local colorHeading = AceGUI:Create("Heading")
	colorHeading:SetText("Color Codes")
	colorHeading:SetFullWidth(true)
	window:AddChild(colorHeading)

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
	window:AddChild(colorGroup)

	-------------------------------------------------
	-- Section 4: Players
	-------------------------------------------------
	local rosterHeading = AceGUI:Create("Heading")
	rosterHeading:SetText("Players")
	rosterHeading:SetFullWidth(true)
	window:AddChild(rosterHeading)

	local clearBtn = AceGUI:Create("Button")
	clearBtn:SetText("Clear Names")
	clearBtn:SetFullWidth(true)
	clearBtn:SetHeight(20)
	clearBtn:SetCallback("OnClick", function() ClearNamesFromText() end)
	window:AddChild(clearBtn)

	local searchBox = AceGUI:Create("EditBox")
	searchBox:SetFullWidth(true)
	searchBox:DisableButton(true)
	searchBox:SetLabel("Search")
	window:AddChild(searchBox)
	self.tokenpanel_searchbox = searchBox

	local rosterScroll = AceGUI:Create("ScrollFrame")
	rosterScroll:SetLayout("List")
	rosterScroll:SetFullWidth(true)
	rosterScroll:SetHeight(180)
	window:AddChild(rosterScroll)
	self.tokenpanel_scroll = rosterScroll

	searchBox:SetCallback("OnTextChanged", function(widget, event, value)
		RefreshRosterList(rosterScroll, value)
	end)

	RefreshRosterList(rosterScroll)
end

function AngryAssign:RefreshTokenPanelRoster()
	if self.tokenpanel and self.tokenpanel_scroll then
		local filter
		if self.tokenpanel_searchbox then
			filter = self.tokenpanel_searchbox:GetText()
		end
		RefreshRosterList(self.tokenpanel_scroll, filter)
	end
end
