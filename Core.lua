local AngryAssign = LibStub("AceAddon-3.0"):NewAddon("AngryAssignments", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0")
local AceGUI = LibStub("AceGUI-3.0")
local libS = LibStub("AceSerializer-3.0")
local libC = LibStub("LibCompress")
local libCE = libC:GetAddonEncodeTable()

local AngryAssign_Version = '@project-version@'
local AngryAssign_Hash = '@project-abbreviated-hash@'

local default_channel = "GUILD"
local protocolVersion = 1
local comPrefix = "AnAss"..protocolVersion

-- Used for version tracking
local warnedOOD = false
local versionList = {} 

-- Pages Saved Variable Format 
-- 	{
-- 		[Id] = { Id = "1231", Updated = now(), Name = "Name", Contents = "..." },
--		...
-- 	},
--
-- Format for our addon communication
--
-- { "PAGE", [Id], [Last Update Timestamp], [Name], [Contents] }
-- Sent when a page is updated. Id is a random unique value. Checks that sender is Officer or Promoted. Uses GUILD.
--
-- { "REQUEST_PAGE", [Id] }
-- Asks to be sent PAGE with give Id. Response is a throttled PAGE. Uses WHISPER to raid leader.
--
-- { "DISPLAY", [Id], [Last Update Timestamp] }
-- Raid leader / promoted sends out when new page is to be displayed. Checks that sender is Officer or Promoted. Uses RAId.
--
-- { "REQUEST_DISPLAY" }
-- Asks to be sent DISPLAY. Response is a throttled DISPLAY. Uses WHISPER to raid leader.
--
-- { "VER_QUERY" }
-- { "VERSION", [Version], [GIT Revision Hash] }

-- Constants for dealing with our addon communication
local COMMAND = 1

local PAGE_Id = 1
local PAGE_Timestamp = 2
local PAGE_Name = 3

local REQUEST_PAGE_Id = 1

local DISPLAY_Id = 1
local DISPLAY_Timestamp = 2

local VERSION_Version = 2
local VERSION_GIT_Hash = 3


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
		if AngryAssign_Hash:sub(1,1) == "@" then hashToSend = "dev" else hashToSend = AngryAssign_Hash end
		self:SendMessage({ "VERSION", verToSend, hashToSend })
	elseif cmd == "VERSION" then
		local localHash, ver, hash
		
		if AngryAssign_Hash:sub(1,1) == "@" then localHash = nil else localHash = AngryAssign_Hash end
		ver = data[VERSION_Version]
		hash = data[VERSION_GIT_Hash]
			
		if localHash ~= nil and hash ~= "dev" and hash ~= localHash and not warnedOOD then 
			self:Print("Your version of Angrry Assignments is out of date! Download the latest version from www.wowace.com.")
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

function AngryAssign:CreateWindow()
	local window = AceGUI:Create("Frame")
	window:SetTitle("Angry Assignments")
	window:SetStatusText("")
	window:SetLayout("Flow")
	window:SetStatusTable(AngryAssign_State.window)
	AngryAssign.window = window

	-- tree code from http://www.wowace.com/addons/ace3/pages/ace-gui-3-0-widgets/
	local treecontents = {
		{ value = 1, text = "Thok", },
		{ value = 2, text = "Spoils of Pandaria", },
		{ value = 3, text = "Sha of Anger", },
	}

	local tree = AceGUI:Create("TreeGroup")
	tree:SetTree(treecontents)
	tree:SelectByValue(1)
	tree:SetStatusTable(AngryAssign_State.tree)
	tree:SetFullWidth(true)
	tree:SetFullHeight(true)
	tree:SetLayout("Flow")
	window:AddChild(tree)
	AngryAssign.tree = tree

	local text = AceGUI:Create("MultiLineEditBox")
	text:SetLabel(nil)
	text:SetFullWidth(true)
	text:SetFullHeight(true)
	tree:AddChild(text)

	tree:PauseLayout()
	local button_display = AceGUI:Create("Button")
	button_display:SetText("Display")
	button_display:SetWidth(80)
	button_display:SetHeight(22)
	button_display:ClearAllPoints()
	button_display:SetPoint("BOTTOMRIGHT", text.frame, "BOTTOMRIGHT", 0, 0)
	tree:AddChild(button_display)

	local button_revert = AceGUI:Create("Button")
	button_revert:SetText("Revert")
	button_revert:SetWidth(65)
	button_revert:SetHeight(22)
	button_revert:ClearAllPoints()
	button_revert:SetDisabled(true)
	button_revert:SetPoint("BOTTOMLEFT", text.button, "BOTTOMRIGHT", 6, 0)
	tree:AddChild(button_revert)

	window:PauseLayout()
	local button_add = AceGUI:Create("Button")
	button_add:SetText("Add")
	button_add:SetWidth(70)
	button_add:SetHeight(19)
	button_add:ClearAllPoints()
	button_add:SetPoint("BOTTOMLEFT", window.frame, "BOTTOMLEFT", 17, 18)
	window:AddChild(button_add)

	local button_rename = AceGUI:Create("Button")
	button_rename:SetText("Rename")
	button_rename:SetWidth(70)
	button_rename:SetHeight(19)
	button_rename:ClearAllPoints()
	button_rename:SetPoint("BOTTOMLEFT", button_add.frame, "BOTTOMRIGHT", 5, 0)
	window:AddChild(button_rename)

	local button_delete = AceGUI:Create("Button")
	button_delete:SetText("Delete")
	button_delete:SetWidth(70)
	button_delete:SetHeight(19)
	button_delete:ClearAllPoints()
	button_delete:SetPoint("BOTTOMLEFT", button_rename.frame, "BOTTOMRIGHT", 5, 0)
	window:AddChild(button_delete)

	local button_lock = AceGUI:Create("Button")
	button_lock:SetText("Unlock")
	button_lock:SetWidth(70)
	button_lock:SetHeight(19)
	button_lock:ClearAllPoints()
	button_lock:SetPoint("BOTTOMRIGHT", window.frame, "BOTTOMRIGHT", -135, 18)
	window:AddChild(button_lock)
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
	
	self:CreateWindow()
end

function AngryAssign:OnEnable()
	self:RegisterComm(comPrefix, "ReceiveMessage")
	
	self:ScheduleTimer("AfterEnable", 5)
end

function AngryAssign:AfterEnable()
	self:SendMessage({ "VER_QUERY" })
	self:SendMessage({ "REQUEST_DISPLAY" })
end
