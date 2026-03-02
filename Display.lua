local _, ns = ...
local AngryAssign = LibStub("AceAddon-3.0"):GetAddon("AngryAssignments")

local lwin = LibStub("LibWindow-1.1")
local LSM = LibStub("LibSharedMedia-3.0")

local HexToRGB = ns.HexToRGB
local GetSpellLink = ns.GetSpellLink
local GetSpellInfo = ns.GetSpellInfo

local isClassicVanilla = ns.isClassicVanilla
local isClassicTBC = ns.isClassicTBC
local isClassicWrath = ns.isClassicWrath
local isClassicCata = ns.isClassicCata
local isClassicMoP = ns.isClassicMoP
local isClassic = ns.isClassic

local currentGroup = nil

---------------------
-- Displaying Page --
---------------------

local function DragHandle_MouseDown(frame) frame:GetParent():GetParent():StartSizing("RIGHT") end
local function DragHandle_MouseUp(frame)
	local display = frame:GetParent():GetParent()
	display:StopMovingOrSizing()
	AngryAssign_State.display.width = display:GetWidth()
	lwin.SavePosition(display)
	AngryAssign:UpdateBackdrop()
end
local function Mover_MouseDown(frame) frame:GetParent():StartMoving() end
local function Mover_MouseUp(frame)
	local display = frame:GetParent()
	display:StopMovingOrSizing()
	lwin.SavePosition(display)
end

function AngryAssign:ResetPosition()
	AngryAssign_State.display = {}
	AngryAssign_State.directionUp = false
	AngryAssign_State.locked = false

	self.frame:Show()
	self.mover:Show()
	self.frame:SetWidth(300)

	lwin.RegisterConfig(self.frame, AngryAssign_State.display)
	lwin.RestorePosition(self.frame)

	self:UpdateDirection()
end

function AngryAssign_ToggleDisplay()
	AngryAssign:ToggleDisplay()
end

function AngryAssign_ShowDisplay()
	AngryAssign:ShowDisplay()
end

function AngryAssign_HideDisplay()
	AngryAssign:HideDisplay()
end

function AngryAssign:ShowDisplay()
	self.frame:Show()
	self:UpdateBackdrop()
	AngryAssign_State.display.hidden = false
end

function AngryAssign:HideDisplay()
	self.frame:Hide()
	AngryAssign_State.display.hidden = true
end

function AngryAssign:ToggleDisplay()
	if self.frame:IsShown() then
		self:HideDisplay()
	else
		self:ShowDisplay()
	end
end


function AngryAssign:CreateDisplay()
	local frame = CreateFrame("Frame", nil, UIParent)
	frame:SetPoint("CENTER",0,0)
	frame:SetWidth(AngryAssign_State.display.width or 300)
	frame:SetHeight(1)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetClampedToScreen(true)
	if frame.SetResizeBounds then -- WoW 10.0+
		frame:SetResizeBounds(180, 1, 830, 1)
	elseif frame.SetMinResize then
		frame:SetMinResize(180,1)
		if frame.SetMaxResize then frame:SetMaxResize(830,1) end
	end
	frame:SetFrameStrata("MEDIUM")
	self.frame = frame

	lwin.RegisterConfig(frame, AngryAssign_State.display)
	lwin.RestorePosition(frame)

	local text = CreateFrame("ScrollingMessageFrame", nil, frame)
	text:SetIndentedWordWrap(true)
	text:SetJustifyH("LEFT")
	text:SetFading(false)
	text:SetMaxLines(AngryAssign:GetConfig('displayMaxLines'))
	text:SetHeight(AngryAssign:GetConfig('displayMaxLines') * 10)
	text:SetHyperlinksEnabled(true)
	text:SetScript("OnHyperlinkEnter", function(_, link)
		GameTooltip:SetOwner(text, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(link)
		GameTooltip:Show()
	end)
	text:SetScript("OnHyperlinkLeave", function()
		GameTooltip:Hide()
	end)
	self.display_text = text

	local backdrop = text:CreateTexture()
	backdrop:SetDrawLayer("BACKGROUND")
	self.backdrop = backdrop

	local mover = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	mover:SetPoint("LEFT",0,0)
	mover:SetPoint("RIGHT",0,0)
	mover:SetHeight(16)
	mover:EnableMouse(true)
	mover:SetBackdrop({ bgFile = "Interface\\Tooltips\\UI-Tooltip-Background" })
	mover:SetBackdropColor( 0.616, 0.149, 0.114, 0.9)
	mover:SetScript("OnMouseDown", Mover_MouseDown)
	mover:SetScript("OnMouseUp", Mover_MouseUp)
	self.mover = mover
	if AngryAssign_State.locked then mover:Hide() end

	local label = mover:CreateFontString()
	label:SetFontObject("GameFontNormal")
	label:SetJustifyH("CENTER")
	label:SetPoint("LEFT", 38, 0)
	label:SetPoint("RIGHT", -38, 0)
	label:SetText("Angry Assignments+")

	local direction = CreateFrame("Button", nil, mover)
	direction:SetPoint("LEFT", 2, 0)
	direction:SetWidth(16)
	direction:SetHeight(16)
	direction:SetNormalTexture("Interface\\Buttons\\UI-Panel-QuestHideButton")
	direction:SetPushedTexture("Interface\\Buttons\\UI-Panel-QuestHideButton")
	direction:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
	direction:SetScript("OnClick", function() AngryAssign:ToggleDirection() end)
	self.direction_button = direction

	local lock = CreateFrame("Button", nil, mover)
	lock:SetNormalTexture("Interface\\LFGFRAME\\UI-LFG-ICON-LOCK")
	lock:GetNormalTexture():SetTexCoord(0, 0.71875, 0, 0.875)
	lock:SetPoint("LEFT", direction, "RIGHT", 4, 0)
	lock:SetWidth(12)
	lock:SetHeight(14)
	lock:SetScript("OnClick", function() AngryAssign:ToggleLock() end)

	local drag = CreateFrame("Frame", nil, mover)
	drag:SetFrameLevel(mover:GetFrameLevel() + 10)
	drag:SetWidth(16)
	drag:SetHeight(16)
	drag:SetPoint("BOTTOMRIGHT", 0, 0)
	drag:EnableMouse(true)
	drag:SetScript("OnMouseDown", DragHandle_MouseDown)
	drag:SetScript("OnMouseUp", DragHandle_MouseUp)
	drag:SetAlpha(0.5)
	local dragtex = drag:CreateTexture(nil, "OVERLAY")
	dragtex:SetTexture("Interface\\AddOns\\AngryAssignments\\Textures\\draghandle")
	dragtex:SetWidth(16)
	dragtex:SetHeight(16)
	dragtex:SetBlendMode("ADD")
	dragtex:SetPoint("CENTER", drag)

	local glow = text:CreateTexture()
	glow:SetDrawLayer("BORDER")
	glow:SetTexture("Interface\\AddOns\\AngryAssignments\\Textures\\LevelUpTex")
	glow:SetSize(223, 115)
	glow:SetTexCoord(0.56054688, 0.99609375, 0.24218750, 0.46679688)
	glow:SetVertexColor( HexToRGB(self:GetConfig('glowColor')) )
	glow:SetAlpha(0)
	self.display_glow = glow

	local glow2 = text:CreateTexture()
	glow2:SetDrawLayer("BORDER")
	glow2:SetTexture("Interface\\AddOns\\AngryAssignments\\Textures\\LevelUpTex")
	glow2:SetSize(418, 7)
	glow2:SetTexCoord(0.00195313, 0.81835938, 0.01953125, 0.03320313)
	glow2:SetVertexColor( HexToRGB(self:GetConfig('glowColor')) )
	glow2:SetAlpha(0)
	self.display_glow2 = glow2

	if AngryAssign_State.display.hidden then frame:Hide() end
	self:UpdateMedia()
	self:UpdateDirection()
end

function AngryAssign:ToggleLock()
	AngryAssign_State.locked = not AngryAssign_State.locked
	if AngryAssign_State.locked then
		self.mover:Hide()
	else
		self.mover:Show()
	end
end

function AngryAssign:ToggleDirection()
	AngryAssign_State.directionUp = not AngryAssign_State.directionUp
	self:UpdateDirection()
end

function AngryAssign:UpdateDirection()
	if AngryAssign_State.directionUp then
		self.display_text:ClearAllPoints()
		self.display_text:SetPoint("BOTTOMLEFT", 0, 8)
		self.display_text:SetPoint("RIGHT", 0, 0)
		self.direction_button:GetNormalTexture():SetTexCoord(0, 0.5, 0.5, 1)
		self.direction_button:GetPushedTexture():SetTexCoord(0.5, 1, 0.5, 1)
		if self.display_text.SetInsertMode and SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM then
			self.display_text:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_BOTTOM)
		end

		self.display_glow:ClearAllPoints()
		self.display_glow:SetPoint("BOTTOM", 0, -4)
		self.display_glow:SetTexCoord(0.56054688, 0.99609375, 0.24218750, 0.46679688)
		self.display_glow2:ClearAllPoints()
		self.display_glow2:SetPoint("TOP", self.display_glow, "BOTTOM", 0, 6)
	else
		self.display_text:ClearAllPoints()
		self.display_text:SetPoint("TOPLEFT", 0, -8)
		self.display_text:SetPoint("RIGHT", 0, 0)
		self.direction_button:GetNormalTexture():SetTexCoord(0, 0.5, 0, 0.5)
		self.direction_button:GetPushedTexture():SetTexCoord(0.5, 1, 0, 0.5)
		if self.display_text.SetInsertMode and SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP then
			self.display_text:SetInsertMode(SCROLLING_MESSAGE_FRAME_INSERT_MODE_TOP)
		end

		self.display_glow:ClearAllPoints()
		self.display_glow:SetPoint("TOP", 0, 4)
		self.display_glow:SetTexCoord(0.56054688, 0.99609375, 0.46679688, 0.24218750)
		self.display_glow2:ClearAllPoints()
		self.display_glow2:SetPoint("BOTTOM", self.display_glow, "TOP", 0, 0)
	end
	if self.display_text:IsShown() then
		self.display_text:Hide()
		self.display_text:Show()
	end
	self:UpdateDisplayed()
end

function AngryAssign:UpdateBackdrop()
	local first, last
	for _, visibleLine in ipairs(self.display_text.visibleLines) do
		if visibleLine:IsShown() then
			if not first then first = visibleLine end
			last = visibleLine
		end
	end

	if first and last and self:GetConfig('backdropShow') then
		self.backdrop:ClearAllPoints()
		if AngryAssign_State.directionUp then
			self.backdrop:SetPoint("TOPLEFT", last, "TOPLEFT", -4, 4)
			self.backdrop:SetPoint("BOTTOMRIGHT", first, "BOTTOMRIGHT", 4, -4)
		else
			self.backdrop:SetPoint("TOPLEFT", first, "TOPLEFT", -4, 4)
			self.backdrop:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT", 4, -4)
		end
		self.backdrop:SetColorTexture( HexToRGB(self:GetConfig('backdropColor')) )
		self.backdrop:Show()
	else
		self.backdrop:Hide()
	end
end

function AngryAssign:UpdateMedia()
	local fontName = LSM:Fetch("font", AngryAssign:GetConfig('fontName'))
	local fontHeight = AngryAssign:GetConfig('fontHeight')
	local fontFlags = AngryAssign:GetConfig('fontFlags')
	if fontFlags == "NONE" or fontFlags == "" then fontFlags = nil end

	self.display_text:SetTextColor( HexToRGB(self:GetConfig('color')) )
	self.display_text:SetFont(fontName, fontHeight, fontFlags)
	self.display_text:SetSpacing( AngryAssign:GetConfig('lineSpacing') )
	self.display_text:SetMaxLines( AngryAssign:GetConfig('displayMaxLines') )
	self.display_text:SetHeight( AngryAssign:GetConfig('displayMaxLines') * 10 )

	self:UpdateBackdrop()
end

local updateFlasher, updateFlasher2 = nil, nil
function AngryAssign:DisplayUpdateNotification()
	if updateFlasher == nil then
		updateFlasher = self.display_glow:CreateAnimationGroup()

		-- Flashing in
		local fade1 = updateFlasher:CreateAnimation("Alpha")
		fade1:SetDuration(0.5)
		fade1:SetFromAlpha(0)
		fade1:SetToAlpha(1)
		fade1:SetOrder(1)

		-- Holding it visible for 1 second
		fade1:SetEndDelay(5)

		-- Flashing out
		local fade2 = updateFlasher:CreateAnimation("Alpha")
		fade2:SetDuration(0.5)
		fade2:SetFromAlpha(1)
		fade2:SetToAlpha(0)
		fade2:SetOrder(3)
	end
	if updateFlasher2 == nil then
		updateFlasher2 = self.display_glow2:CreateAnimationGroup()

		-- Flashing in
		local fade1 = updateFlasher2:CreateAnimation("Alpha")
		fade1:SetDuration(0.5)
		fade1:SetFromAlpha(0)
		fade1:SetToAlpha(1)
		fade1:SetOrder(1)

		-- Holding it visible for 1 second
		fade1:SetEndDelay(5)

		-- Flashing out
		local fade2 = updateFlasher2:CreateAnimation("Alpha")
		fade2:SetDuration(0.5)
		fade2:SetFromAlpha(1)
		fade2:SetToAlpha(0)
		fade2:SetOrder(3)
	end

	updateFlasher:Play()
	updateFlasher2:Play()

	if AngryAssign:GetConfig('updateSound') then
		PlaySound(8959)
	end
end

----------------------------
-- Text Formatting        --
----------------------------

local function ci_pattern(pattern)
	local p = pattern:gsub("(%%?)(.)", function(percent, letter)
		if percent ~= "" or not letter:match("%a") then
			return percent .. letter
		else
			return string.format("[%s%s]", letter:lower(), letter:upper())
		end
	end)
	return p
end

function AngryAssign:UpdateDisplayedIfNewGroup()
	local newGroup = self:GetCurrentGroup()
	if newGroup ~= currentGroup then
		currentGroup = newGroup
		self:UpdateDisplayed()
	end
end

-- Also update from event handlers via ns
function AngryAssign:ResetCurrentGroup()
	currentGroup = nil
end

function AngryAssign:UpdateDisplayed()
	local page = self:Get( AngryAssign_State.displayed )
	if page then
		local text = page.Contents

		local highlights = { }
		for token in string.gmatch( AngryAssign:GetConfig('highlight') , "[^%s%p]+") do
			token = token:lower()
			if token == 'group'then
				tinsert(highlights, 'g'..(currentGroup or 0))
			else
				tinsert(highlights, token)
			end
		end
		local highlightHex = self:GetConfig('highlightColor')

		text = text:gsub(ci_pattern('|cblue'), "|cff00cbf4")
			:gsub(ci_pattern('|cgreen'), "|cff0adc00")
			:gsub(ci_pattern('|cred'), "|cffeb310c")
			:gsub(ci_pattern('|cyellow'), "|cfffaf318")
			:gsub(ci_pattern('|corange'), "|cffff9d00")
			:gsub(ci_pattern('|cpink'), "|cfff64c97")
			:gsub(ci_pattern('|cpurple'), "|cffdc44eb")
			:gsub(ci_pattern('|cdruid'), "|cffff7d0a")
			:gsub(ci_pattern('|chunter'), "|cffabd473")
			:gsub(ci_pattern('|cmage'), "|cff40C7eb")
			:gsub(ci_pattern('|cpaladin'), "|cfff58cba")
			:gsub(ci_pattern('|cpriest'), "|cffffffff")
			:gsub(ci_pattern('|crogue'), "|cfffff569")
			:gsub(ci_pattern('|cshaman'), "|cff0070de")
			:gsub(ci_pattern('|cwarlock'), "|cff8787ed")
			:gsub(ci_pattern('|cwarrior'), "|cffc79c6e")
			:gsub("|([^|crtTnHhAaKk])", "|r%1")
			:gsub("|$", "|r")
			:gsub("||", "|")
			:gsub("([^%s%p]+)", function(word)
				local word_lower = word:lower()
				for _, token in ipairs(highlights) do
					if token == word_lower then
						return string.format("|cff%s%s|r", highlightHex, word)
					end
				end
				return word
			end)
			:gsub(ci_pattern('{spell%s+(%d+)}'), function(id)
				return GetSpellLink(id)
			end)
			:gsub(ci_pattern('{star}'), "{rt1}")
			:gsub(ci_pattern('{circle}'), "{rt2}")
			:gsub(ci_pattern('{diamond}'), "{rt3}")
			:gsub(ci_pattern('{triangle}'), "{rt4}")
			:gsub(ci_pattern('{moon}'), "{rt5}")
			:gsub(ci_pattern('{square}'), "{rt6}")
			:gsub(ci_pattern('{cross}'), "{rt7}")
			:gsub(ci_pattern('{x}'), "{rt7}")
			:gsub(ci_pattern('{skull}'), "{rt8}")
			:gsub(ci_pattern('{rt([1-8])}'), "|TInterface\\TargetingFrame\\UI-RaidTargetingIcon_%1:0|t" )
			:gsub(ci_pattern('{healthstone}'), "{hs}")
			:gsub(ci_pattern('{hs}'), "|TInterface\\Icons\\INV_Stone_04:0|t")
			:gsub(ci_pattern('{icon%s+(%d+)}'), function(id)
				return format("|T%s:0|t", select(3, GetSpellInfo(tonumber(id))) )
			end)
			:gsub(ci_pattern('{icon%s+([%w_]+)}'), "|TInterface\\Icons\\%1:0|t")
			:gsub(ci_pattern('{damage}'), "{dps}")
			:gsub(ci_pattern('{tank}'), "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:0:19:22:41|t")
			:gsub(ci_pattern('{healer}'), "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:20:39:1:20|t")
			:gsub(ci_pattern('{dps}'), "|TInterface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES:0:0:0:0:64:64:20:39:22:41|t")
			:gsub(ci_pattern('{hunter}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:0:16:16:32|t")
			:gsub(ci_pattern('{warrior}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:0:16:0:16|t")
			:gsub(ci_pattern('{rogue}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:32:48:0:16|t")
			:gsub(ci_pattern('{mage}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:16:32:0:16|t")
			:gsub(ci_pattern('{priest}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:32:48:16:32|t")
			:gsub(ci_pattern('{warlock}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:48:64:16:32|t")
			:gsub(ci_pattern('{paladin}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:0:16:32:48|t")
			:gsub(ci_pattern('{druid}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:48:64:0:16|t")
			:gsub(ci_pattern('{shaman}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:16:32:16:32|t")

		if not isClassicVanilla then
			text = text:gsub(ci_pattern('{hero}'), "{heroism}")
				:gsub(ci_pattern('{heroism}'), "|TInterface\\Icons\\ABILITY_Shaman_Heroism:0|t")
				:gsub(ci_pattern('{bloodlust}'), "{bl}")
				:gsub(ci_pattern('{bl}'), "|TInterface\\Icons\\SPELL_Nature_Bloodlust:0|t")

			if not isClassicTBC then
				text = text:gsub(ci_pattern('|cdk'), "|cdeathknight")
					:gsub(ci_pattern('|cdeathknight'), "|cffc41f3b")
					:gsub(ci_pattern('{dk}'), "{deathknight}")
					:gsub(ci_pattern('{deathknight}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:16:32:32:48|t")

				if not isClassicWrath then
					-- Cata+: Encounter Journal icons
					if EJ_GetEncounterInfo then
						text = text:gsub(ci_pattern('{boss%s+(%d+)}'), function(id)
							return select(5, EJ_GetEncounterInfo(id))
						end)
					end
					if C_EncounterJournal and C_EncounterJournal.GetSectionInfo then
						text = text:gsub(ci_pattern('{journal%s+(%d+)}'), function(id)
							return C_EncounterJournal.GetSectionInfo(id) and C_EncounterJournal.GetSectionInfo(id).link
						end)
					end

					if not isClassicCata then
						-- MoP+: Monk
						text = text:gsub(ci_pattern('|cmonk'), "|cff00ff96")
							:gsub(ci_pattern('{monk}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:32:48:32:48|t")

						if not isClassicMoP then
							-- Retail: Demon Hunter (Legion+), Evoker (Dragonflight+)
							text = text:gsub(ci_pattern('|cdh'), "|cdemonhunter")
								:gsub(ci_pattern('|cdemonhunter'), "|cffa330c9")
								:gsub(ci_pattern('|cevoker'), "|cff33937f")
								:gsub(ci_pattern('{dh}'), "{demonhunter}")
								:gsub(ci_pattern('{demonhunter}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:64:48:32:48|t")
								:gsub(ci_pattern('{evoker}'), "|TInterface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES:0:0:0:0:64:64:0:16:48:64|t")
						end
					end
				end
			end
		end


		self.display_text:Clear()
		local lines = { strsplit("\n", text) }
		local lines_count = #lines
		for i = 1, lines_count do
			local line
			if AngryAssign_State.directionUp then
				line = lines[i]
			else
				line = lines[lines_count - i + 1]
			end
			if line == "" then line = " " end
			self.display_text:AddMessage(line)
		end
	else
		self.display_text:Clear()
		if not AngryAssign_State.display.hidden then
			self.display_text:AddMessage("|cff666666No assignment displayed.|r")
			self.display_text:AddMessage("|cff666666Use /aa window to create and display a page.|r")
		end
	end
	self:UpdateBackdrop()
end

----------------------------
-- Chat Output            --
----------------------------

function AngryAssign_OutputDisplayed()
	return AngryAssign:OutputDisplayed( AngryAssign:SelectedId() )
end
function AngryAssign:OutputDisplayed(id)
	if not self:PermissionCheck() then
		self:Print( RED_FONT_COLOR_CODE .. "You don't have permission to output a page.|r" )
	end
	if not id then id = AngryAssign_State.displayed end
	local page = self:Get( id )
	local channel
	if not isClassic and (IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInRaid(LE_PARTY_CATEGORY_INSTANCE)) then
		channel = "INSTANCE_CHAT"
	elseif IsInRaid() then
		channel = "RAID"
	elseif IsInGroup() then
		channel = "PARTY"
	end
	if channel and page then
		local output = page.Contents

		output = output:gsub(ci_pattern('|cblue'), "")
			:gsub(ci_pattern('|cgreen'), "")
			:gsub(ci_pattern('|cred'), "")
			:gsub(ci_pattern('|cyellow'), "")
			:gsub(ci_pattern('|corange'), "")
			:gsub(ci_pattern('|cpink'), "")
			:gsub(ci_pattern('|cpurple'), "")
			:gsub(ci_pattern('|cdruid'), "")
			:gsub(ci_pattern('|chunter'), "")
			:gsub(ci_pattern('|cmage'), "")
			:gsub(ci_pattern('|cpaladin'), "")
			:gsub(ci_pattern('|cpriest'), "")
			:gsub(ci_pattern('|crogue'), "")
			:gsub(ci_pattern('|cshaman'), "")
			:gsub(ci_pattern('|cwarlock'), "")
			:gsub(ci_pattern('|cwarrior'), "")
			:gsub("|([^|crtTnHhAaKk])", "|r%1")
			:gsub("|$", "|r")
			:gsub("||", "|")
			:gsub(ci_pattern('|r'), "")
			:gsub(ci_pattern('{spell%s+(%d+)}'), function(id)
				return GetSpellLink(id)
			end)
			:gsub(ci_pattern('{star}'), "{rt1}")
			:gsub(ci_pattern('{circle}'), "{rt2}")
			:gsub(ci_pattern('{diamond}'), "{rt3}")
			:gsub(ci_pattern('{triangle}'), "{rt4}")
			:gsub(ci_pattern('{moon}'), "{rt5}")
			:gsub(ci_pattern('{square}'), "{rt6}")
			:gsub(ci_pattern('{cross}'), "{rt7}")
			:gsub(ci_pattern('{x}'), "{rt7}")
			:gsub(ci_pattern('{skull}'), "{rt8}")
			:gsub(ci_pattern('{healthstone}'), "{hs}")
			:gsub(ci_pattern('{hs}'), 'Healthstone')
			:gsub(ci_pattern('{icon%s+([%w_]+)}'), '')
			:gsub(ci_pattern('{damage}'), 'Damage')
			:gsub(ci_pattern('{tank}'), 'Tanks')
			:gsub(ci_pattern('{healer}'), 'Healers')
			:gsub(ci_pattern('{dps}'), 'Damage')
			:gsub(ci_pattern('{hunter}'), LOCALIZED_CLASS_NAMES_MALE["HUNTER"])
			:gsub(ci_pattern('{warrior}'), LOCALIZED_CLASS_NAMES_MALE["WARRIOR"])
			:gsub(ci_pattern('{rogue}'), LOCALIZED_CLASS_NAMES_MALE["ROGUE"])
			:gsub(ci_pattern('{mage}'), LOCALIZED_CLASS_NAMES_MALE["MAGE"])
			:gsub(ci_pattern('{priest}'), LOCALIZED_CLASS_NAMES_MALE["PRIEST"])
			:gsub(ci_pattern('{warlock}'), LOCALIZED_CLASS_NAMES_MALE["WARLOCK"])
			:gsub(ci_pattern('{paladin}'), LOCALIZED_CLASS_NAMES_MALE["PALADIN"])
			:gsub(ci_pattern('{druid}'), LOCALIZED_CLASS_NAMES_MALE["DRUID"])
			:gsub(ci_pattern('{shaman}'), LOCALIZED_CLASS_NAMES_MALE["SHAMAN"])

		if not isClassicVanilla then
			output = output:gsub(ci_pattern('{bloodlust}'), "{bl}")
				:gsub(ci_pattern('{bl}'), 'Bloodlust')
				:gsub(ci_pattern('{hero}'), "{heroism}")
				:gsub(ci_pattern('{heroism}'), 'Heroism')

			if not isClassicTBC then
				output = output:gsub(ci_pattern('|cdk'), "|cdeathknight")
					:gsub(ci_pattern('|cdeathknight'), "")
					:gsub(ci_pattern('{dk}'), "{deathknight}")
					:gsub(ci_pattern('{deathknight}'), LOCALIZED_CLASS_NAMES_MALE["DEATHKNIGHT"])

				if not isClassicWrath then
					-- Cata+: Encounter Journal text output
					if EJ_GetEncounterInfo then
						output = output:gsub(ci_pattern('{boss%s+(%d+)}'), function(id)
							return select(5, EJ_GetEncounterInfo(id))
						end)
					end
					if C_EncounterJournal and C_EncounterJournal.GetSectionInfo then
						output = output:gsub(ci_pattern('{journal%s+(%d+)}'), function(id)
							return C_EncounterJournal.GetSectionInfo(id) and C_EncounterJournal.GetSectionInfo(id).link
						end)
					end

					if not isClassicCata then
						-- MoP+: Monk
						output = output:gsub(ci_pattern('|cmonk'), "")
							:gsub(ci_pattern('{monk}'), LOCALIZED_CLASS_NAMES_MALE["MONK"])

						if not isClassicMoP then
							-- Retail: Demon Hunter (Legion+), Evoker (Dragonflight+)
							output = output:gsub(ci_pattern('|cdh'), "|cdemonhunter")
								:gsub(ci_pattern('|cdemonhunter'), "")
								:gsub(ci_pattern('|cevoker'), "")
								:gsub(ci_pattern('{dh}'), "{demonhunter}")
								:gsub(ci_pattern('{demonhunter}'), LOCALIZED_CLASS_NAMES_MALE["DEMONHUNTER"])
								:gsub(ci_pattern('{evoker}'), LOCALIZED_CLASS_NAMES_MALE["EVOKER"])
						end
					end
				end
			end
		end

		output = output:gsub(ci_pattern('|c%w?%w?%w?%w?%w?%w?%w?%w?'), "")

		local lines = { strsplit("\n", output) }
		for _, line in ipairs(lines) do
			if line ~= "" then
				SendChatMessage(line, channel)
			end
		end
	end
end
