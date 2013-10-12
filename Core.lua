local AngryAssign = LibStub("AceAddon-3.0"):NewAddon("AngryAssignments", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local libS = LibStub("AceSerializer-3.0")
local libC = LibStub("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local AngryAssign_Version = '@project-version@'
local AngryAssign_Timestamp = '@project-timestamp@'

local default_channel = "GUILD"
local protocolVersion = 1
local comPrefix = "AnAss"..protocolVersion

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
-- { "VERSION", [Version], [Project Revision Timestamp] }

-- Constants for dealing with our addon communication
local COMMAND = 1

local PAGE_Id = 1
local PAGE_Timestamp = 2
local PAGE_Name = 3

local REQUEST_PAGE_Id = 1

local DISPLAY_Id = 1
local DISPLAY_Timestamp = 2

local VERSION_Version = 2
local VERSION_Revision_Timestamp = 3


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
		self:SendCommMessage(comPrefix, final, destChannel, target, "NORMAL")
	end
end

function AngryAssign:ProcessMessage(sender, data)
	local cmd = data[COMMAND]
	if cmd == "" then

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
		timestamp = data[VERSION_Revision_Timestamp]
			
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
			text = "New page name",
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
	AngryAssign.text:SetText( AngryAssign_Pages[AngryAssign:SelectedId()].Contents )
end

local function AngryAssign_TextChanged(widget, event, value)

end

local function AngryAssign_TextEntered(widget, event, value)
	AngryAssign:UpdateContents(AngryAssign:SelectedId(), value)
end

function AngryAssign:CreateWindow()
	local window = AceGUI:Create("Frame")
	window:SetTitle("Angry Assignments")
	window:SetStatusText("")
	window:SetLayout("Flow")
	window:SetStatusTable(AngryAssign_State.window)
	AngryAssign.window = window

	local tree = AceGUI:Create("TreeGroup")
	tree:SetTree( self:GetTree() )
	tree:SelectByValue(1)
	tree:SetStatusTable(AngryAssign_State.tree)
	tree:SetFullWidth(true)
	tree:SetFullHeight(true)
	tree:SetLayout("Flow")
	tree:SetCallback("OnGroupSelected", function(widget, event, value) AngryAssign:UpdateSelected() end)
	window:AddChild(tree)
	AngryAssign.tree = tree

	local text = AceGUI:Create("MultiLineEditBox")
	text:SetLabel(nil)
	text:SetFullWidth(true)
	text:SetFullHeight(true)
	text:SetCallback("OnTextChanged", AngryAssign_TextChanged)
	text:SetCallback("OnEnterPressed", AngryAssign_TextEntered)
	tree:AddChild(text)
	AngryAssign.text = text

	tree:PauseLayout()
	local button_display = AceGUI:Create("Button")
	button_display:SetText("Display")
	button_display:SetWidth(80)
	button_display:SetHeight(22)
	button_display:ClearAllPoints()
	button_display:SetPoint("BOTTOMRIGHT", text.frame, "BOTTOMRIGHT", 0, 0)
	tree:AddChild(button_display)
	AngryAssign.button_display = button_display

	local button_revert = AceGUI:Create("Button")
	button_revert:SetText("Revert")
	button_revert:SetWidth(65)
	button_revert:SetHeight(22)
	button_revert:ClearAllPoints()
	button_revert:SetDisabled(true)
	button_revert:SetPoint("BOTTOMLEFT", text.button, "BOTTOMRIGHT", 6, 0)
	button_revert:SetCallback("OnClick", AngryAssign_RevertPage)
	tree:AddChild(button_revert)
	AngryAssign.button_revert = button_revert

	window:PauseLayout()
	local button_add = AceGUI:Create("Button")
	button_add:SetText("Add")
	button_add:SetWidth(70)
	button_add:SetHeight(19)
	button_add:ClearAllPoints()
	button_add:SetPoint("BOTTOMLEFT", window.frame, "BOTTOMLEFT", 17, 18)
	button_add:SetCallback("OnClick", AngryAssign_AddPage)
	window:AddChild(button_add)
	AngryAssign.button_add = button_add

	local button_rename = AceGUI:Create("Button")
	button_rename:SetText("Rename")
	button_rename:SetWidth(70)
	button_rename:SetHeight(19)
	button_rename:ClearAllPoints()
	button_rename:SetPoint("BOTTOMLEFT", button_add.frame, "BOTTOMRIGHT", 5, 0)
	button_rename:SetCallback("OnClick", AngryAssign_RenamePage)
	window:AddChild(button_rename)
	AngryAssign.button_rename = button_rename

	local button_delete = AceGUI:Create("Button")
	button_delete:SetText("Delete")
	button_delete:SetWidth(70)
	button_delete:SetHeight(19)
	button_delete:ClearAllPoints()
	button_delete:SetPoint("BOTTOMLEFT", button_rename.frame, "BOTTOMRIGHT", 5, 0)
	button_delete:SetCallback("OnClick", AngryAssign_DeletePage)
	window:AddChild(button_delete)
	AngryAssign.button_delete = button_delete

	local button_lock = AceGUI:Create("Button")
	button_lock:SetText("Unlock")
	button_lock:SetWidth(70)
	button_lock:SetHeight(19)
	button_lock:ClearAllPoints()
	button_lock:SetPoint("BOTTOMRIGHT", window.frame, "BOTTOMRIGHT", -135, 18)
	window:AddChild(button_lock)
	AngryAssign.button_lock = button_lock

	self:UpdateSelected()
end

function AngryAssign:GetTree()
	local ret = {}

	for _, page in pairs(AngryAssign_Pages) do
		-- TODO show icon for currently displayed page
		tinsert(ret, { value = page.Id, text = page.Name })

	end

	return ret
end

function AngryAssign:UpdateTree()
	self.tree:SetTree( self:GetTree() )
end

function AngryAssign:SelectedId()
	return AngryAssign_State.tree.selected
end

function AngryAssign:Get(id)
	if id == nil then id = self:SelectedId() end
	return AngryAssign_Pages[id]
end

function AngryAssign:CreatePage(name)
	local id = math.random(2000000000)

	AngryAssign_Pages[id] = { Id = id, Updated = time(), Name = name, Contents = "" }
	self:UpdateTree()
	self.tree:SelectByValue( id )
end

function AngryAssign:RenamePage(id, name)
	local page = self:Get(id)
	if not page then return end

	page.Name = name
	self:UpdateTree()
end

function AngryAssign:DeletePage(id)
	AngryAssign_Pages[id] = nil
	if self:SelectedId() == id then
		self.tree:SetSelected(nil)
		self:UpdateSelected()
	end
	self:UpdateTree()
end

function AngryAssign:UpdateContents(id, value)
	local page = self:Get(id)
	if not page then return end
	page.Contents = value
	page.Updated = time()
end

function AngryAssign:UpdateSelected()
	local page = AngryAssign_Pages[ self:SelectedId() ]
	if page then
		AngryAssign.text:SetText( AngryAssign_Pages[ AngryAssign:SelectedId() ].Contents )

		AngryAssign.button_rename:SetDisabled(false)
		AngryAssign.button_delete:SetDisabled(false)
		AngryAssign.button_revert:SetDisabled(false)
		AngryAssign.button_display:SetDisabled(false)
		AngryAssign.text:SetDisabled(false)
	else
		AngryAssign.text:SetText("")
		AngryAssign.button_rename:SetDisabled(true)
		AngryAssign.button_delete:SetDisabled(true)
		AngryAssign.button_revert:SetDisabled(true)
		AngryAssign.button_display:SetDisabled(true)
		AngryAssign.text:SetDisabled(true)
	end
end

function AngryAssign:VersionCheckOutput()
	local versionliststr = ""
	for i,v in pairs(versionList) do
		versionliststr = versionliststr..v["name"].."-|cFFFF0000"..v["version"].."|r "
	end
	self:Print(versionliststr)
end

function AngryAssign:OnInitialize()
	if AngryAssign_State == nil then AngryAssign_State = { tree = {}, window = {} } end
	if AngryAssign_Pages == nil then AngryAssign_Pages = { } end

	local options = {
		name = "AA",
		handler = AngryAssign,
		type = "group",
		args = {
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
		}
	}

	LibStub("AceConfig-3.0"):RegisterOptionsTable("Angry Assignments", options, {"aa"})
end

function AngryAssign:OnEnable()
	self:CreateWindow()

	self:RegisterComm(comPrefix, "ReceiveMessage")
	
	self:ScheduleTimer("AfterEnable", 5)
end

function AngryAssign:AfterEnable()
	self:SendMessage({ "VER_QUERY" })
	self:SendMessage({ "REQUEST_DISPLAY" })
end
