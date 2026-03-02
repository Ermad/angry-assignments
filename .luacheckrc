std = "lua51"
max_line_length = false
allow_defined_top = true
exclude_files = { "libs/", "dist/" }

-- Suppress common WoW addon patterns
ignore = {
	"212", -- unused argument (WoW callback pattern: widget, event, value)
	"211/self", -- unused self argument
	"431", -- shadowing upvalue (intentional in menu/callback closures)
	"432", -- shadowing upvalue argument (same pattern — dropdown/gsub callbacks)
	"131", -- unused global variable (keybinding globals read by WoW XML)
	"311", -- value assigned but mutated before use (WoW API multi-return)
	"542", -- empty if branch (upstream code pattern)
}

-- WoW globals that this addon reads
read_globals = {
	-- Lua 5.1 extensions provided by WoW
	"time", "date", "format", "floor",
	"strsplit", "strsub", "strmatch", "strfind", "strlen", "strtrim",
	"tinsert", "tremove", "wipe", "sort",
	"select", "pairs", "ipairs", "type", "tonumber", "tostring",
	"math", "string", "table", "bit",
	"hooksecurefunc",

	-- WoW Frame/UI
	"CreateFrame", "UIParent",
	"BackdropTemplateMixin",
	"SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP",
	"SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM",
	"GameTooltip",
	"FONT_COLOR_CODE_CLOSE",

	-- WoW API functions
	"IsInRaid", "IsInGroup", "IsInGuild", "GetNumGroupMembers", "GetRaidRosterInfo",
	"GetNumGuildMembers", "GetGuildRosterInfo",
	"UnitName", "UnitFullName", "UnitIsGroupLeader", "UnitIsGroupAssistant",
	"SendChatMessage", "Ambiguate",
	"GetSpellLink", "GetSpellInfo", "GetItemInfo", "GetMacroIcons",
	"GetBuildInfo",
	"PlaySound",
	"GuildRoster",
	"EJ_GetEncounterInfo",

	-- WoW namespaces
	"C_Spell", "C_Item", "C_Club", "C_GuildInfo",
	"C_EncounterJournal",
	"CommunitiesUtil", "Enum",

	-- WoW constants
	"LE_PARTY_CATEGORY_INSTANCE", "LE_PARTY_CATEGORY_HOME",
	"OKAY", "CANCEL",
	"RED_FONT_COLOR_CODE", "LIGHTYELLOW_FONT_COLOR_CODE",
	"LOCALIZED_CLASS_NAMES_MALE", "RAID_CLASS_COLORS",
	"WOW_PROJECT_ID", "WOW_PROJECT_MAINLINE", "WOW_PROJECT_CLASSIC",
	"WOW_PROJECT_BURNING_CRUSADE_CLASSIC", "WOW_PROJECT_WRATH_CLASSIC",
	"WOW_PROJECT_CATACLYSM_CLASSIC", "WOW_PROJECT_MISTS_CLASSIC",

	-- WoW StaticPopup system
	"StaticPopup_Show",

	-- WoW Dropdown system
	"UIDropDownMenu_Initialize", "UIDropDownMenu_AddButton",
	"ToggleDropDownMenu", "HideDropDownMenu",
	"EasyMenu",

	-- WoW Settings / Options
	"Settings", "InterfaceOptionsFrame_OpenToCategory",

	-- Libraries (loaded before Core.lua via embeds.xml)
	"LibStub",
}

-- WoW globals that this addon writes/mutates
globals = {
	-- SavedVariables (set by WoW, mutated by addon)
	"AngryAssign_Pages",
	"AngryAssign_Categories",
	"AngryAssign_State",
	"AngryAssign_Config",

	-- StaticPopup dialog registration
	"StaticPopupDialogs",

	-- Keybinding strings (read by WoW keybinding system from XML)
	"BINDING_HEADER_AngryAssign",
	"BINDING_NAME_AngryAssign_WINDOW",
	"BINDING_NAME_AngryAssign_LOCK",
	"BINDING_NAME_AngryAssign_DISPLAY",
	"BINDING_NAME_AngryAssign_SHOW_DISPLAY",
	"BINDING_NAME_AngryAssign_HIDE_DISPLAY",
	"BINDING_NAME_AngryAssign_OUTPUT",

	-- Global functions called from bindings.xml
	"AngryAssign_ToggleDisplay",
	"AngryAssign_ShowDisplay",
	"AngryAssign_HideDisplay",
	"AngryAssign_ToggleLock",
	"AngryAssign_ToggleWindow",
	"AngryAssign_OutputDisplayed",

	-- Addon frame globals
	"AngryAssign_Window",
	"AngryAssign_DropDown",

	-- Global addon reference (PR #9)
	"AngryAssign",

	-- Icon browser global
	"icon",
}
