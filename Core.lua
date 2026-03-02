local _, ns = ...
local AngryAssign = LibStub("AceAddon-3.0"):NewAddon("AngryAssignments", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

BINDING_HEADER_AngryAssign = "Angry Assignments+"
BINDING_NAME_AngryAssign_WINDOW = "Toggle Window"
BINDING_NAME_AngryAssign_LOCK = "Toggle Lock"
BINDING_NAME_AngryAssign_DISPLAY = "Toggle Display"
BINDING_NAME_AngryAssign_SHOW_DISPLAY = "Show Display"
BINDING_NAME_AngryAssign_HIDE_DISPLAY = "Hide Display"
BINDING_NAME_AngryAssign_OUTPUT = "Output Assignment to Chat"

ns.AngryAssign_Version = '2.0.1'
ns.AngryAssign_Timestamp = '20260302'

-- Expansion detection
ns.isClassicVanilla = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
ns.isClassicTBC = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
ns.isClassicWrath = WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC
ns.isClassicCata = WOW_PROJECT_ID == (WOW_PROJECT_CATACLYSM_CLASSIC or 14)
ns.isClassicMoP = WOW_PROJECT_ID == (WOW_PROJECT_MISTS_CLASSIC or 19)
ns.isClassic = ns.isClassicVanilla or ns.isClassicTBC or ns.isClassicWrath or ns.isClassicCata or ns.isClassicMoP
ns.isRetail = WOW_PROJECT_ID == (WOW_PROJECT_MAINLINE or 1)

-- Communication shared state
ns.comPrefix = "AnAss2"
ns.comStarted = false
ns.warnedPermission = false
ns.versionList = {}

-- Virtual category sentinels
ns.SHARED_CATEGORY_ID   = "__shared__"
ns.DISPLAYED_TREE_VALUE = -2147483647
ns.SHARED_TREE_VALUE    = -2147483646

-----------------------
-- Polyfills         --
-----------------------

ns.EasyMenu = EasyMenu
if not ns.EasyMenu then
	local function EasyMenu_Initialize( frame, level, menuList )
		for index = 1, #menuList do
			local value = menuList[index]
			if (value.text) then
				value.index = index
				UIDropDownMenu_AddButton( value, level )
			end
		end
	end
	ns.EasyMenu = function(menuList, menuFrame, anchor, x, y, displayMode, autoHideDelay )
		if ( displayMode == "MENU" ) then
			menuFrame.displayMode = displayMode
		end
		UIDropDownMenu_Initialize(menuFrame, EasyMenu_Initialize, displayMode, nil, menuList)
		ToggleDropDownMenu(1, nil, menuFrame, anchor, x, y, menuList, nil, autoHideDelay)
	end
end

ns.GetSpellLink = C_Spell and C_Spell.GetSpellLink or GetSpellLink;
ns.GetItemInfo = GetItemInfo or C_Item.GetItemInfo
ns.GetSpellInfo = GetSpellInfo or function(spellID)
	if not spellID then
		return nil
	end
	local spellInfo = C_Spell.GetSpellInfo(spellID)
	if spellInfo then
		return spellInfo.name, nil, spellInfo.iconID, spellInfo.castTime, spellInfo.minRange, spellInfo.maxRange, spellInfo.spellID, spellInfo.originalIconID
	end
end

-----------------------
-- Utility Functions --
-----------------------

function ns.selectedLastValue(input)
	local a = select(-1, strsplit("\001", input or ""))
	return tonumber(a)
end

function ns.tReverse(tbl)
	for i=1, math.floor(#tbl / 2) do
		tbl[i], tbl[#tbl - i + 1] = tbl[#tbl - i + 1], tbl[i]
	end
end

local _player_realm = nil
function ns.EnsureUnitFullName(unit)
	if not _player_realm then _player_realm = select(2, UnitFullName('player')) end
	if unit and not unit:find('-') then
		unit = unit..'-'.._player_realm
	end
	return unit
end

function ns.EnsureUnitShortName(unit)
	if not _player_realm then _player_realm = select(2, UnitFullName('player')) end
	local name, realm = strsplit("-", unit, 2)
	if not realm or realm == _player_realm then
		return name
	else
		return unit
	end
end

function ns.PlayerFullName()
	if not _player_realm then _player_realm = select(2, UnitFullName('player')) end
	return UnitName('player')..'-'.._player_realm
end

function ns.RGBToHex(r, g, b, a)
	r = math.ceil(255 * r)
	g = math.ceil(255 * g)
	b = math.ceil(255 * b)
	if a == nil then
		return string.format("%02x%02x%02x", r, g, b)
	else
		a = math.ceil(255 * a)
		return string.format("%02x%02x%02x%02x", r, g, b, a)
	end
end

function ns.HexToRGB(hex)
	if string.len(hex) == 8 then
		return tonumber("0x"..hex:sub(1,2)) / 255, tonumber("0x"..hex:sub(3,4)) / 255, tonumber("0x"..hex:sub(5,6)) / 255, tonumber("0x"..hex:sub(7,8)) / 255
	else
		return tonumber("0x"..hex:sub(1,2)) / 255, tonumber("0x"..hex:sub(3,4)) / 255, tonumber("0x"..hex:sub(5,6)) / 255
	end
end

-----------------
-- Config      --
-----------------

local configDefaults = {
	scale = 1,
	hideoncombat = false,
	showaftercombat = true,
	updateSound = false,
	fontName = "Friz Quadrata TT",
	fontHeight = 12,
	fontFlags = "",
	highlight = "",
	highlightColor = "ffd200",
	color = "ffffff",
	allowall = false,
	allowOfficers = true,
	allowRaidLeader = false,
	allowRaidAssistants = false,
	lineSpacing = 0,
	allowplayers = "",
	backdropShow = false,
	backdropColor = "00000080",
	glowColor = "FF0000",
	displayMaxLines = 70,
	showMinimapButton = true,
}

function AngryAssign:GetConfig(key)
	if AngryAssign_Config[key] == nil then
		return configDefaults[key]
	else
		return AngryAssign_Config[key]
	end
end

function AngryAssign:SetConfig(key, value)
	if configDefaults[key] == value then
		AngryAssign_Config[key] = nil
	else
		AngryAssign_Config[key] = value
	end
end

function AngryAssign:RestoreDefaults()
	local minimapIcon = AngryAssign_Config.minimapIcon
	AngryAssign_Config = {}
	AngryAssign_Config.minimapIcon = minimapIcon or {}
	self:UpdateMedia()
	self:UpdateDisplayed()
	self:UpdateMinimapButton()
	LibStub("AceConfigRegistry-3.0"):NotifyChange("AngryAssign")
end

-----------------
-- Addon Setup --
-----------------

function AngryAssign:OnInitialize()
	if AngryAssign_State == nil then
		AngryAssign_State = { tree = {}, window = {}, display = {}, displayed = nil, locked = false, directionUp = false }
	end
	if AngryAssign_Pages == nil then AngryAssign_Pages = { } end
	if AngryAssign_Config == nil then AngryAssign_Config = { } end
	if AngryAssign_Categories == nil then
		AngryAssign_Categories = { }
	else
		for _, cat in pairs(AngryAssign_Categories) do
			if cat.Children then
				for _, pageId in ipairs(cat.Children) do
					local page = AngryAssign_Pages[pageId]
					if page then
						page.CategoryId = cat.Id
					end
				end
				cat.Children = nil
			end
		end
	end

	self:InitOptions()
end

function AngryAssign:ChatCommand(input)
  local cmd = input and input:trim():lower() or ""
  if cmd == "" then
    AngryAssign_ToggleWindow()
  elseif cmd == "config" or cmd == "options" or cmd == "opt" then
    if Settings and Settings.OpenToCategory then
      Settings.OpenToCategory("Angry Assignments+")
    elseif InterfaceOptionsFrame_OpenToCategory then
      InterfaceOptionsFrame_OpenToCategory("Angry Assignments+")
      InterfaceOptionsFrame_OpenToCategory("Angry Assignments+") -- called twice, WoW bug
    end
  else
    LibStub("AceConfigCmd-3.0").HandleCommand(self, "aa", "AngryAssign", input)
  end
end

function AngryAssign:OnEnable()
	self:ResetOfficerRank()
	self:CreateDisplay()

	self:ScheduleTimer("AfterEnable", 4)

	self:RegisterEvent("PLAYER_REGEN_DISABLED")
	self:RegisterEvent("PLAYER_REGEN_ENABLED")
	self:RegisterEvent("PLAYER_GUILD_UPDATE")
	self:RegisterEvent("GUILD_ROSTER_UPDATE")

	if GuildRoster then
		GuildRoster()
	elseif C_GuildInfo and C_GuildInfo.GuildRoster then
		C_GuildInfo.GuildRoster()
	end

	LSM.RegisterCallback(self, "LibSharedMedia_Registered", "UpdateMedia")
	LSM.RegisterCallback(self, "LibSharedMedia_SetGlobal", "UpdateMedia")
end


function AngryAssign:PARTY_LEADER_CHANGED()
	self:PermissionsUpdated()
	if AngryAssign_State.displayed and not (self:IsGuildRaid() or self:IsValidRaid()) then self:ClearDisplayed() end
end

function AngryAssign:PARTY_CONVERTED_TO_RAID()
	self:SendRequestDisplay()
	self:SendVerQuery()
	self:UpdateDisplayedIfNewGroup()
end

function AngryAssign:GROUP_JOINED()
	self:SendVerQuery()
	self:UpdateDisplayedIfNewGroup()
	self:ScheduleTimer("SendRequestDisplay", 0.5)
end

function AngryAssign:PLAYER_REGEN_DISABLED()
	if AngryAssign:GetConfig('hideoncombat') then
		self:HideDisplay()
	end
end

function AngryAssign:PLAYER_REGEN_ENABLED()
	if self:GetConfig('showaftercombat') and AngryAssign_State.displayed and AngryAssign_State.display.hidden then
		self:ShowDisplay()
	end
end

function AngryAssign:GROUP_ROSTER_UPDATE()
	self:UpdateSelected()
	if not (IsInRaid() or IsInGroup()) then
		if AngryAssign_State.displayed then self:ClearDisplayed() end
		self:ResetCurrentGroup()
		ns.warnedPermission = false
	else
		self:UpdateDisplayedIfNewGroup()
	end
	self:RefreshTokenPanelRoster()
end

function AngryAssign:PLAYER_GUILD_UPDATE()
	self:ResetOfficerRank()
	self:PermissionsUpdated()
end

function AngryAssign:GUILD_ROSTER_UPDATE(...)
	local canRequestRosterUpdate = ...
	self:ResetOfficerRank()
	if canRequestRosterUpdate then
		if GuildRoster then
			GuildRoster()
		elseif C_GuildInfo and C_GuildInfo.GuildRoster then
			C_GuildInfo.GuildRoster()
		end
	end
end

function AngryAssign:AfterEnable()
	self:RegisterComm(ns.comPrefix, "ReceiveMessage")
	ns.comStarted = true

	if not (IsInRaid() or IsInGroup()) then
		self:ClearDisplayed()
	end

	--self:RegisterEvent("PARTY_CONVERTED_TO_RAID")
	self:RegisterEvent("PARTY_LEADER_CHANGED")
	self:RegisterEvent("GROUP_JOINED")
	self:RegisterEvent("GROUP_ROSTER_UPDATE")

	self:InitMinimapButton()
	self:SendRequestDisplay()
	self:ScheduleTimer("SendRequestDisplayFallback", 5)
	self:UpdateDisplayedIfNewGroup()
	self:SendVerQuery()
end

_G.AngryAssign = AngryAssign
