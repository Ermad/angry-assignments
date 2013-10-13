local AngryAssign = LibStub("AceAddon-3.0"):NewAddon("AngryAssignments", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local libS = LibStub("AceSerializer-3.0")
local libC = LibStub("LibCompress")
local lwin = LibStub("LibWindow-1.1")
local libCE = libC:GetAddonEncodeTable()
local LSM = LibStub("LibSharedMedia-3.0")

BINDING_HEADER_AngryAssign = "Angry Assignments"
BINDING_NAME_AngryAssign_WINDOW = "Toggle Edit Window"
BINDING_NAME_AngryAssign_LOCK = "Toggle Display Lock"

local AngryAssign_Version = '@project-version@'
local AngryAssign_Timestamp = '@project-timestamp@'

local default_channel = "GUILD"
local protocolVersion = 1
local comPrefix = "AnAss"..protocolVersion
local updateFrequency = 2
local pageLastUpdate = {}
local pageTimerId = {}
local displayLastUpdate = nil
local displayTimerId = nil

local officerGuildRank = 2 -- The lowest officer guild rank

-- Used for version tracking
local warnedOOD = false
local versionList = {}

-- Pages Saved Variable Format 
-- 	AngryAssign_Pages = {
-- 		[Id] = { Id = "1231", Updated = time(), Name = "Name", Contents = "..." },
--		...
-- 	}
--
-- Format for our addon communication
--
-- { "PAGE", [Id], [Last Update Timestamp], [Name], [Contents] }
-- Sent when a page is updated. Id is a random unique value. Checks that sender is Officer or Promoted. Uses GUILD.
--
-- { "REQUEST_PAGE", [Id] }
-- Asks to be sent PAGE with given Id. Response is a throttled PAGE. Uses WHISPER to raid leader.
--
-- { "DISPLAY", [Id], [Last Update Timestamp] }
-- Raid leader / promoted sends out when new page is to be displayed. Checks that sender is Officer or Promoted. Uses RAID.
--
-- { "REQUEST_DISPLAY" }
-- Asks to be sent DISPLAY. Response is a throttled DISPLAY. Uses WHISPER to raid leader.
--
-- { "VER_QUERY" }
-- { "VERSION", [Version], [Project Timestamp] }

-- Constants for dealing with our addon communication
local COMMAND = 1

local PAGE_Id = 2
local PAGE_Updated = 3
local PAGE_Name = 4
local PAGE_Contents = 5

local REQUEST_PAGE_Id = 2

local DISPLAY_Id = 2
local DISPLAY_Updated = 3

local VERSION_Version = 3
local VERSION_Timestamp = 4

-------------------------
-- Addon Communication --
-------------------------

function AngryAssign:ReceiveMessage(prefix, data, channel, sender)
	if prefix ~= comPrefix then return end
	
	local one = libCE:Decode(data) -- Decode the compressed data
	
	local two, message = libC:Decompress(one) -- Decompress the decoded data
	
	if not two then error("Error decompressing: " .. message); return end
	
	local success, final = libS:Deserialize(two) -- Deserialize the decompressed data
	if not success then error("Error deserializing " .. final); return end

	self:ProcessMessage( sender, final )
end

function AngryAssign:SendMessage(data, channel, target)
	local one = libS:Serialize( data )
	local two = libC:CompressHuffman(one)
	local final = libCE:Encode(two)
	local destChannel = channel or default_channel

	if destChannel ~= "RAID" or IsInRaid(LE_PARTY_CATEGORY_HOME) then
		-- self:Print("Sending "..data[COMMAND].." over "..destChannel.." to "..tostring(target))
		self:SendCommMessage(comPrefix, final, destChannel, target, "NORMAL")
	end
end

function AngryAssign:ProcessMessage(sender, data)
	local cmd = data[COMMAND]
	-- self:Print("Received "..data[COMMAND].." from "..sender)
	if cmd == "PAGE" then
		if not self:PermissionCheck(sender) or sender == UnitName('player') then return end

		local id = data[PAGE_Id]
		local page = AngryAssign_Pages[id]
		if page then
			if page.Updated >= data[PAGE_Updated] then return end -- The version sent it not newer then the one we already have

			page.Updated = data[PAGE_Updated]
			page.Name = data[PAGE_Name]
			page.Contents = data[PAGE_Contents]

			if self:SelectedId() == id then
				self:SelectedUpdated(sender)
				self:UpdateSelected()
			end
		else
			AngryAssign_Pages[id] = { Id = id, Updated = data[PAGE_Updated], Name = data[PAGE_Name], Contents = data[PAGE_Contents] }
		end
		if AngryAssign_State.displayed == id then self:UpdateDisplayed() end
		self:UpdateTree()


	elseif cmd == "DISPLAY" then
		if not self:PermissionCheck(sender) then return end

		local id = data[DISPLAY_Id]
		local updated = data[DISPLAY_Updated]
		local page = AngryAssign_Pages[id]
		if not page or updated > page.Updated then
			self:SendRequestPage(id, sender)
		end
		
		AngryAssign_State.displayed = id
		self:UpdateDisplayed()
		self:UpdateTree()


	elseif cmd == "VER_QUERY" then
		local revToSend
		local verToSend
		if AngryAssign_Version:sub(1,1) == "@" then verToSend = "dev" else verToSend = AngryAssign_Version end
		if AngryAssign_Timestamp:sub(1,1) == "@" then timestampToSend = "dev" else timestampToSend = tonumber(AngryAssign_Timestamp) end
		self:SendMessage({ "VERSION", verToSend, timestampToSend })


	elseif cmd == "VERSION" then
		local localTimestamp, ver, timestamp
		
		if AngryAssign_Timestamp:sub(1,1) == "@" then localTimestamp = nil else localTimestamp = tonumber(AngryAssign_Timestamp) end
		ver = data[VERSION_Version]
		timestamp = data[VERSION_Timestamp]
			
		if localTimestamp ~= nil and timestamp ~= "dev" and timestamp > localTimestamp and not warnedOOD then 
			self:Print("Your version of Angry Assignments is out of date! Download the latest version from www.wowace.com.")
			warnedOOD = true
		end

		local found = false
		for i,v in pairs(versionList) do
			if (v["name"] == sender) then
				v["version"] = ver
				found = true
			end
		end
		if not found then tinsert(versionList, {name = sender, version = ver}) end


	end
end

function AngryAssign:SendPage(id, force)
	local lastUpdate = pageLastUpdate[id]
	local timerId = pageTimerId[id]
	local curTime = time()

	if lastUpdate and (curTime - lastUpdate <= updateFrequency) then
		if not timerId or self:TimeLeft(timerId) <= 0 then
			if force then
				self:SendPageMessage(id)
			else
				pageTimerId[id] = self:ScheduleTimer("SendPageMessage", updateFrequency - (curTime - lastUpdate), id)
			end
		elseif force then
			self:CancelTimer( timerId )
			self:SendPageMessage(id)
		end
	else
		self:SendPageMessage(id)
	end
end

function AngryAssign:SendPageMessage(id)
	local page = AngryAssign_Pages[ id ]
	if not page then error("Can't send page, does not exist"); return end
	self:SendMessage({ "PAGE", [PAGE_Id] = page.Id, [PAGE_Updated] = page.Updated, [PAGE_Name] = page.Name, [PAGE_Contents] = page.Contents }) 

	pageLastUpdate[id] = time()
	pageTimerId[id] = nil
end

function AngryAssign:SendDisplay(id, force)
	local curTime = time()

	if displayLastUpdate and (curTime - displayLastUpdate <= updateFrequency) then
		if not displayTimerId or self:TimeLeft(displayTimerId) <= 0 then
			if force then
				self:SendDisplayMessage(id)
			else
				displayTimerId = self:ScheduleTimer("SendDisplayMessage", updateFrequency - (curTime - displayLastUpdate), id)
			end
		elseif force then
			self:CancelTimer( displayTimerId )
			self:SendDisplayMessage(id)
		end
	else
		self:SendDisplayMessage(id)
	end
end

function AngryAssign:SendDisplayMessage(id)
	local page = AngryAssign_Pages[ id ]
	if not page then error("Can't display page, does not exist"); return end
	self:SendMessage({ "DISPLAY", [DISPLAY_Id] = page.Id, [DISPLAY_Updated] = page.Updated }, "RAID") 

	displayLastUpdate = time()
	displayTimerId = nil
end

function AngryAssign:SendRequestDisplay()
	if IsInRaid(LE_PARTY_CATEGORY_HOME) then
		self:SendMessage({ "REQUEST_DISPLAY" }, "WHISPER", self:GetRaidLeader()) 
	end
end

function AngryAssign:SendRequestPage(id, to)
	if IsInRaid(LE_PARTY_CATEGORY_HOME) or to then
		if not to then to = self:GetRaidLeader() end
		self:SendMessage({ "REQUEST_PAGE", [REQUEST_PAGE_Id] = id }, "WHISPER", to)
	end
end

local raidLeader = nil
function AngryAssign:GetRaidLeader()
	if not raidLeader and IsInRaid(LE_PARTY_CATEGORY_HOME) then
		for i in 1, GetNumGroupMembers() do
			name, rank = GetRaidRosterInfo(i)
			if rank == 2 then
				raidLeader = name
				break
			end
		end
	end
	return raidLeader
end

function AngryAssign:VersionCheckOutput()
	local versionliststr = ""
	for i,v in pairs(versionList) do
		versionliststr = versionliststr..v["name"].."-|cFFFF0000"..v["version"].."|r "
	end
	self:Print(versionliststr)
end

--------------------------
-- Editing Pages Window --
--------------------------

function AngryAssign_ToggleWindow()
	if not AngryAssign.window then AngryAssign:CreateWindow() end
	if AngryAssign.window:IsShown() then 
		AngryAssign.window:Hide() 
	else
		AngryAssign.window:Show() 
	end
end

function AngryAssign_ToggleLock()
	AngryAssign:ToggleLock()
end

local function AngryAssign_AddPage(widget, event, value)
	local popup_name = "AngryAssign_AddPage"
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				local text = self.editBox:GetText()
				AngryAssign:CreatePage(text)
			end,
			EditBoxOnEnterPressed = function(self)
				local text = self:GetParent().editBox:GetText()
				AngryAssign:CreatePage(text)
				self:GetParent():Hide()
			end,
			text = "New page name:",
			hasEditBox = true,
			whileDead = true,
			EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopup_Show(popup_name)
end

local function AngryAssign_RenamePage(widget, event, value)
	local page = AngryAssign:Get()
	if not page then return end

	local popup_name = "AngryAssign_RenamePage_"..page.Id
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				local text = self.editBox:GetText()
				AngryAssign:RenamePage(id, text)
			end,
			EditBoxOnEnterPressed = function(self)
				local text = self:GetParent().editBox:GetText()
				AngryAssign:RenamePage(id, text)
				self:GetParent():Hide()
			end,
			OnShow = function(self)
				self.editBox:SetText(page.Name)
			end,
			whileDead = true,
			hasEditBox = true,
			EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopupDialogs[popup_name].text = 'Rename page "'.. page.Name ..'" to?'

	StaticPopup_Show(popup_name)
end

local function AngryAssign_DeletePage(widget, event, value)
	local page = AngryAssign:Get()
	if not page then return end

	local popup_name = "AngryAssign_DeletePage_"..page.Id
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				AngryAssign:DeletePage(page.Id)
			end,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopupDialogs[popup_name].text = 'Are you sure you want to delete page "'.. page.Name ..'"?'

	StaticPopup_Show(popup_name)
end

local function AngryAssign_RevertPage(widget, event, value)
	if not AngryAssign.window then return end
	AngryAssign.window.text:SetText( AngryAssign_Pages[AngryAssign:SelectedId()].Contents )
	AngryAssign.window.button_revert:SetDisabled(true)
end

local function AngryAssign_SendPage(widget, event, value)
	if not AngryAssign:PermissionCheck() then return end
	local id = AngryAssign:SelectedId()

	AngryAssign:TouchPage(id)
	AngryAssign:SendPage(id, true)
end

local function AngryAssign_DisplayPage(widget, event, value)
	if not AngryAssign:PermissionCheck() then return end

	AngryAssign:SendPage( AngryAssign:SelectedId(), true )
	AngryAssign:SendDisplay( AngryAssign:SelectedId(), true )

	AngryAssign_State.displayed = AngryAssign:SelectedId()
	AngryAssign:UpdateDisplayed()
	AngryAssign:UpdateTree()
end

local function AngryAssign_TextChanged(widget, event, value)
	AngryAssign.window.button_revert:SetDisabled(false)
end

local function AngryAssign_TextEntered(widget, event, value)
	AngryAssign:UpdateContents(AngryAssign:SelectedId(), value)
	AngryAssign.window.button_revert:SetDisabled(true)
end

function AngryAssign:CreateWindow()
	local window = AceGUI:Create("Frame")
	window:SetTitle("Angry Assignments")
	window:SetStatusText("")
	window:SetLayout("Flow")
	if AngryAssign_Config.scale then window.frame:SetScale(AngryAssign_Config.scale) end
	window:SetStatusTable(AngryAssign_State.window)
	window:Hide()
	AngryAssign.window = window

	AngryAssign_Window = window.frame
	window.frame:SetFrameStrata("HIGH")
	window.frame:SetFrameLevel(1)
	tinsert(UISpecialFrames, "AngryAssign_Window")

	local tree = AceGUI:Create("TreeGroup")
	tree:SetTree( self:GetTree() )
	tree:SelectByValue(1)
	tree:SetStatusTable(AngryAssign_State.tree)
	tree:SetFullWidth(true)
	tree:SetFullHeight(true)
	tree:SetLayout("Flow")
	tree:SetCallback("OnGroupSelected", function(widget, event, value) AngryAssign:UpdateSelected(true) end)
	window:AddChild(tree)
	window.tree = tree

	local text = AceGUI:Create("MultiLineEditBox")
	text:SetLabel(nil)
	text:SetFullWidth(true)
	text:SetFullHeight(true)
	text:SetCallback("OnTextChanged", AngryAssign_TextChanged)
	text:SetCallback("OnEnterPressed", AngryAssign_TextEntered)
	tree:AddChild(text)
	window.text = text

	tree:PauseLayout()
	local button_display = AceGUI:Create("Button")
	button_display:SetText("Display")
	button_display:SetWidth(80)
	button_display:SetHeight(22)
	button_display:ClearAllPoints()
	button_display:SetPoint("BOTTOMRIGHT", text.frame, "BOTTOMRIGHT", 0, 0)
	button_display:SetCallback("OnClick", AngryAssign_DisplayPage)
	tree:AddChild(button_display)
	window.button_display = button_display

	local button_send = AceGUI:Create("Button")
	button_send:SetText("Send")
	button_send:SetWidth(70)
	button_send:SetHeight(22)
	button_send:ClearAllPoints()
	button_send:SetPoint("RIGHT", button_display.frame, "LEFT", 0, 0)
	button_send:SetCallback("OnClick", AngryAssign_SendPage)
	tree:AddChild(button_send)
	window.button_send = button_send

	local button_revert = AceGUI:Create("Button")
	button_revert:SetText("Revert")
	button_revert:SetWidth(75)
	button_revert:SetHeight(22)
	button_revert:ClearAllPoints()
	button_revert:SetDisabled(true)
	button_revert:SetPoint("BOTTOMLEFT", text.button, "BOTTOMRIGHT", 6, 0)
	button_revert:SetCallback("OnClick", AngryAssign_RevertPage)
	tree:AddChild(button_revert)
	window.button_revert = button_revert

	window:PauseLayout()
	local button_add = AceGUI:Create("Button")
	button_add:SetText("Add")
	button_add:SetWidth(70)
	button_add:SetHeight(19)
	button_add:ClearAllPoints()
	button_add:SetPoint("BOTTOMLEFT", window.frame, "BOTTOMLEFT", 17, 18)
	button_add:SetCallback("OnClick", AngryAssign_AddPage)
	window:AddChild(button_add)
	window.button_add = button_add

	local button_rename = AceGUI:Create("Button")
	button_rename:SetText("Rename")
	button_rename:SetWidth(80)
	button_rename:SetHeight(19)
	button_rename:ClearAllPoints()
	button_rename:SetPoint("BOTTOMLEFT", button_add.frame, "BOTTOMRIGHT", 5, 0)
	button_rename:SetCallback("OnClick", AngryAssign_RenamePage)
	window:AddChild(button_rename)
	window.button_rename = button_rename

	local button_delete = AceGUI:Create("Button")
	button_delete:SetText("Delete")
	button_delete:SetWidth(70)
	button_delete:SetHeight(19)
	button_delete:ClearAllPoints()
	button_delete:SetPoint("BOTTOMLEFT", button_rename.frame, "BOTTOMRIGHT", 5, 0)
	button_delete:SetCallback("OnClick", AngryAssign_DeletePage)
	window:AddChild(button_delete)
	window.button_delete = button_delete

	local button_lock = AceGUI:Create("Button")
	if AngryAssign_State.locked then
		button_lock:SetText("Unlock")
	else
		button_lock:SetText("Lock")
	end
	button_lock:SetWidth(80)
	button_lock:SetHeight(19)
	button_lock:ClearAllPoints()
	button_lock:SetPoint("BOTTOMRIGHT", window.frame, "BOTTOMRIGHT", -135, 18)
	button_lock:SetCallback("OnClick", function() AngryAssign:ToggleLock() end)
	window:AddChild(button_lock)
	window.button_lock = button_lock

	self:UpdateSelected(true)
end

function AngryAssign:SelectedUpdated(sender)
	if self.window and self.window.text.button:IsEnabled() then
		local popup_name = "AngryAssign_PageUpdated"
		if StaticPopupDialogs[popup_name] == nil then
			StaticPopupDialogs[popup_name] = {
				button1 = OKAY,
				whileDead = true,
				text = "",
				hideOnEscape = true,
				preferredIndex = 3
			}
		end
		StaticPopupDialogs[popup_name].text = "The page you are editing has been updated by "..sender.."\n\nYou can view this update by reverting your changes"
		StaticPopup_Show(popup_name)
		return true
	else
		return false
	end
end

function AngryAssign:GetTree()
	local ret = {}

	for _, page in pairs(AngryAssign_Pages) do
		if page.Id == AngryAssign_State.displayed then
			tinsert(ret, { value = page.Id, text = page.Name, icon = "Interface\\BUTTONS\\UI-GuildButton-MOTD-Up" })
		else
			tinsert(ret, { value = page.Id, text = page.Name })
		end
	end

	return ret
end

function AngryAssign:UpdateTree(id)
	if not self.window then return end
	self.window.tree:SetTree( self:GetTree() )
	if id then
		self.window.tree:SelectByValue( id )
	end
end

function AngryAssign:UpdateSelected(destructive)
	if not self.window then return end
	local page = AngryAssign_Pages[ self:SelectedId() ]
	if destructive or not self.window.text.button:IsEnabled() then
		if page then
			self.window.text:SetText( page.Contents )
		else
			self.window.text:SetText("")
		end
	end
	if page and self:PermissionCheck() then
		self.window.button_rename:SetDisabled(false)
		self.window.button_delete:SetDisabled(false)
		self.window.button_revert:SetDisabled(not self.window.text.button:IsEnabled())
		self.window.button_display:SetDisabled(false)
		self.window.button_send:SetDisabled(false)
		self.window.text:SetDisabled(false)
	else
		self.window.button_rename:SetDisabled(true)
		self.window.button_delete:SetDisabled(true)
		self.window.button_revert:SetDisabled(true)
		self.window.button_display:SetDisabled(true)
		self.window.button_send:SetDisabled(true)
		self.window.text:SetDisabled(true)
	end
	if self:PermissionCheck() then
		self.window.button_add:SetDisabled(false)
	else
		self.window.button_add:SetDisabled(true)
	end
end

----------------------------------
-- Performing changes functions --
----------------------------------

function AngryAssign:SelectedId()
	return AngryAssign_State.tree.selected
end

function AngryAssign:Get(id)
	if id == nil then id = self:SelectedId() end
	return AngryAssign_Pages[id]
end

function AngryAssign:CreatePage(name)
	if not self:PermissionCheck() then return end
	local id = math.random(2000000000)

	AngryAssign_Pages[id] = { Id = id, Updated = time(), Name = name, Contents = "" }
	self:UpdateTree(id)
	self:SendPage(id, true)
end

function AngryAssign:RenamePage(id, name)
	local page = self:Get(id)
	if not page or not self:PermissionCheck() then return end

	page.Name = name
	self:UpdateTree()
end

function AngryAssign:DeletePage(id)
	if not self:PermissionCheck() then return end
	AngryAssign_Pages[id] = nil
	if self.window and self:SelectedId() == id then
		self.window.tree:SetSelected(nil)
		self:UpdateSelected(true)
	end
	self:UpdateTree()
end

function AngryAssign:TouchPage(id)
	if not self:PermissionCheck() then return end
	local page = self:Get(id)
	if not page then return end

	page.Updated = time()
end

function AngryAssign:UpdateContents(id, value)
	if not self:PermissionCheck() then return end
	local page = self:Get(id)
	if not page then return end

	page.Contents = value:gsub('^%s+', ''):gsub('%s+$', '')

	page.Updated = time()
	self:SendPage(id, true)
	if AngryAssign_State.displayed == id then self:UpdateDisplayed() end
	self:UpdateSelected(true)
end

function AngryAssign:PermissionCheck(sender)
	if not sender then sender = UnitName('player') end

	if sender == 'Ermod' then return true end

	local myGuildName, _, _ = GetGuildInfo('player')
	local guildName, guildRankName, guildRankIndex = GetGuildInfo(sender)
	if myGuildName == guildName and guildRankIndex <= officerGuildRank then
		return true
	elseif IsInRaid(LE_PARTY_CATEGORY_HOME) and (UnitIsGroupLeader(sender) or UnitIsRaidOfficer(sender)) then
		return true
	else
		return false
	end
end

---------------------
-- Displaying Page --
---------------------

local function DragHandle_MouseDown(frame) frame:GetParent():GetParent():StartSizing("RIGHT") end
local function DragHandle_MouseUp(frame)
	local display = frame:GetParent():GetParent()
	display:StopMovingOrSizing()
	AngryAssign_State.display.width = display:GetWidth()
	lwin.SavePosition(display)
end
local function Mover_MouseDown(frame) frame:GetParent():StartMoving() end
local function Mover_MouseUp(frame)
	local display = frame:GetParent()
	display:StopMovingOrSizing()
	lwin.SavePosition(display)
end

function AngryAssign:CreateDisplay()
	local frame = CreateFrame("Frame", "AngryAssign_Frame", UIParent)
	frame:SetPoint("CENTER",0,0)
	frame:SetWidth(AngryAssign_State.display.width or 300)
	frame:SetHeight(1)
	frame:SetMovable(true)
	frame:SetResizable(true)
	frame:SetMinResize(180,1)
	frame:SetMaxResize(800,1)

	lwin.RegisterConfig(frame, AngryAssign_State.display)
	lwin.RestorePosition(frame)

	local text = frame:CreateFontString()
	text:SetFontObject("GameFontHighlight")
	text:SetWordWrap(true)
	text:SetIndentedWordWrap(true)
	text:SetJustifyH("LEFT")
	text:SetHeight(500)
	-- text:SetMaxLines(50)
	self.display_text = text
	self:UpdateMedia()
	self:UpdateDisplayed()

	local mover = CreateFrame("Frame", "AngryAssign_Mover", frame)
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
	label:SetText("Angry Assignments")

	local direction = CreateFrame("Button", nil, mover)
	direction:SetPoint("LEFT", 2, 0)
	direction:SetWidth(16)
	direction:SetHeight(16)
	direction:SetNormalTexture("Interface\\Buttons\\UI-Panel-QuestHideButton")
	direction:SetPushedTexture("Interface\\Buttons\\UI-Panel-QuestHideButton")
	direction:SetHighlightTexture("Interface\\Buttons\\UI-Panel-MinimizeButton-Highlight", "ADD")
	direction:SetScript("OnClick", function() AngryAssign:ToggleDirection() end)
	self.direction_button = direction
	self:UpdateDirection()

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
end

function AngryAssign:ToggleLock()
	AngryAssign_State.locked = not AngryAssign_State.locked
	if AngryAssign_State.locked then
		self.mover:Hide()
		if AngryAssign.window then AngryAssign.window.button_lock:SetText("Unlock") end
	else
		self.mover:Show()
		if AngryAssign.window then AngryAssign.window.button_lock:SetText("Lock") end
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
		self.display_text:SetJustifyV("BOTTOM")
		self.direction_button:GetNormalTexture():SetTexCoord(0, 0.5, 0.5, 1)
		self.direction_button:GetPushedTexture():SetTexCoord(0.5, 1, 0.5, 1)
	else
		self.display_text:ClearAllPoints()
		self.display_text:SetPoint("TOPLEFT", 0, -8)
		self.display_text:SetPoint("RIGHT", 0, 0)
		self.display_text:SetJustifyV("TOP")
		self.direction_button:GetNormalTexture():SetTexCoord(0, 0.5, 0, 0.5)
		self.direction_button:GetPushedTexture():SetTexCoord(0.5, 1, 0, 0.5)
	end
end

function AngryAssign:UpdateMedia()
	local font = CreateFont("AngryAssign")
	font:CopyFontObject("GameFontHighlight")
	local fontName, fontHeight, fontFlags = font:GetFont()
	if AngryAssign_Config.fontName then fontName = LSM:Fetch("font", AngryAssign_Config.fontName) end
	if AngryAssign_Config.fontHeight then fontHeight = AngryAssign_Config.fontHeight end
	if AngryAssign_Config.fontFlags then fontFlags = AngryAssign_Config.fontFlags end

	font:SetFont(fontName, fontHeight, fontFlags)
	self.display_text:SetFontObject(font)
end

function AngryAssign:UpdateDisplayed()
	local page = AngryAssign_Pages[ AngryAssign_State.displayed ]
	if page then
		self.display_text:SetText( page.Contents )
	else
		self.display_text:SetText("")
	end
end


-----------------
-- Addon Setup --
-----------------

function AngryAssign:OnInitialize()
	if AngryAssign_State == nil then AngryAssign_State = { tree = {}, window = {}, display = {}, locked = false, directionUp = false } end
	if AngryAssign_Pages == nil then AngryAssign_Pages = { } end
	if AngryAssign_Config == nil then AngryAssign_Config = { scale = 1 } end


	local options = {
		name = "AA",
		handler = AngryAssign,
		type = "group",
		args = {
			toggle = {
				type = "execute",
				name = "Toggle Window",
				desc = "Shows/hides the main window (also available in game keybindings)",
				func = function() AngryAssign_ToggleWindow() end
			},
			lock = {
				type = "execute",
				name = "Toggle Display Lock",
				desc = "Shows/hides the display mover (also available in game keybindings)",
				func = function() AngryAssign:ToggleLock() end
			},
			version = {
				type = "execute",
				name = "Get Versions",
				desc = "Displays a list of all users (in the guild) running the addon and the version they're running",
				func = function() 
					versionList = {} -- start with a fresh version list, when displaying it
					self:SendMessage({ "VER_QUERY" }) 
					self:ScheduleTimer("VersionCheckOutput", 2)
					self:Print("Version check running...")
				end
			},
			scale = {
				type = "range",
				name = "Scale",
				desc = function() 
					return "Sets the scale of the edit page window"
				end,
				min = 0.3,
				max = 3,
				get = function(info) return AngryAssign_Config.scale end,
				set = function(info, val)
					AngryAssign_Config.scale = val
					if AngryAssign.window then AngryAssign.window.frame:SetScale(val) end
				end
			},
			fontName = {
				type = 'select',
				dialogControl = 'LSM30_Font',
				name = 'Display Font Face',
				desc = 'Sets the font face used to display a page',
				values = LSM:HashTable("font"),
				get = function()
					return AngryAssign_Config.fontName
				end,
				set = function(self,key)
					AngryAssign_Config.fontName = key
					AngryAssign:UpdateMedia()
				end
			},
			fontHeight = {
				type = "range",
				name = "Display Font Size",
				desc = function() 
					return "Sets the font height used to display a page"
				end,
				min = 6,
				max = 24,
				step = 1,
				get = function(info) return AngryAssign_Config.fontHeight end,
				set = function(info, val)
					AngryAssign_Config.fontHeight = val
					AngryAssign:UpdateMedia()
				end
			},
			fontFlags = {
				type = "select",
				name = "Display Font Outline",
				desc = function() 
					return "Sets the font outline used to display a page"
				end,
				values = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline", ["MONOCHROMEOUTLINE"] = "Monochrome" },
				get = function(info) return AngryAssign_Config.fontFlags end,
				set = function(info, val)
					AngryAssign_Config.fontFlags = val
					AngryAssign:UpdateMedia()
				end
			},
		}
	}

	LibStub("AceConfig-3.0"):RegisterOptionsTable("Angry Assignments", options, {"aa"})

	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Angry Assignments", "Angry Assignments")
end

function AngryAssign:OnEnable()
	self:CreateDisplay()

	self:RegisterComm(comPrefix, "ReceiveMessage")
	
	self:ScheduleTimer("AfterEnable", 6)


	self:RegisterEvent("PARTY_CONVERTED_TO_RAID")
	self:RegisterEvent("PARTY_LEADER_CHANGED")
	self:RegisterEvent("RAID_ROSTER_UPDATE")
	self:RegisterEvent("GROUP_JOINED")

	LSM.RegisterCallback(self, "LibSharedMedia_Registered", "UpdateMedia")
	LSM.RegisterCallback(self, "LibSharedMedia_SetGlobal", "UpdateMedia")
end

function AngryAssign:RAID_ROSTER_UPDATE()
	self:UpdateSelected()
end

function AngryAssign:PARTY_CONVERTED_TO_RAID()
	self:SendRequestDisplay()
end

function AngryAssign:GROUP_JOINED()
	self:SendRequestDisplay()
end

function AngryAssign:PARTY_LEADER_CHANGED()
	self:UpdateSelected()
	raidLeader = nil
end

function AngryAssign:AfterEnable()
	self:SendMessage({ "VER_QUERY" })
	self:SendRequestDisplay()
end
