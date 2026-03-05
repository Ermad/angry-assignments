local _, ns = ...
local AngryAssign = LibStub("AceAddon-3.0"):GetAddon("AngryAssignments")

local libS = LibStub("AceSerializer-3.0")
local LibDeflate = LibStub("LibDeflate")

local EnsureUnitFullName = ns.EnsureUnitFullName
local PlayerFullName = ns.PlayerFullName

local comPrefix = ns.comPrefix

-- Protocol message field indices
local COMMAND = 1

local PAGE_Id = 2
local PAGE_Updated = 3
local PAGE_Name = 4
local PAGE_Contents = 5
local PAGE_UpdateId = 6
local PAGE_Variables = 7

local REQUEST_PAGE_Id = 2

local DISPLAY_Id = 2
local DISPLAY_Updated = 3
local DISPLAY_UpdateId = 4

local VERSION_Version = 2
local VERSION_Timestamp = 3
local VERSION_ValidRaid = 4

local SHARE_Name = 2
local SHARE_Contents = 3
local SHARE_Variables = 4

-- Throttling state
local updateFrequency = 2
local pageLastUpdate = {}
local pageTimerId = {}
local displayLastUpdate = nil
local displayTimerId = nil
local versionLastUpdate = nil
local versionTimerId = nil

local warnedOOD = false

-------------------------
-- Addon Communication --
-------------------------

function AngryAssign:ReceiveMessage(prefix, data, channel, sender)
	if prefix ~= comPrefix then return end

	local one = LibDeflate:DecodeForWoWAddonChannel(data)
	if not one then error("Error decoding message"); return end

	local two = LibDeflate:DecompressDeflate(one)
	if not two then error("Error decompressing"); return end

	local success, final = libS:Deserialize(two)
	if not success then error("Error deserializing " .. final); return end

	self:ProcessMessage( sender, final )
end

function AngryAssign:SendOutMessage(data, channel, target)
	local one = libS:Serialize( data )
	local two = LibDeflate:CompressDeflate(one)
	local final = LibDeflate:EncodeForWoWAddonChannel(two)
	if not channel then
		if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
			channel = "INSTANCE_CHAT"
		elseif IsInRaid(LE_PARTY_CATEGORY_HOME) then
			channel = "RAID"
		elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
			channel = "PARTY"
		end
	end

	if not channel then return end

	-- self:Print("Sending "..data[COMMAND].." over "..channel.." to "..tostring(target))
	self:SendCommMessage(comPrefix, final, channel, target, "NORMAL")
	return true
end

function AngryAssign:ProcessMessage(sender, data)
	local cmd = data[COMMAND]
	sender = EnsureUnitFullName(sender)

	-- self:Print("Received "..data[COMMAND].." from "..sender)
	if cmd == "PAGE" then
		if sender == PlayerFullName() then return end
		if not self:PermissionCheck(sender) then
			self:PermissionCheckFailError(sender)
			return
		end

		local contents_updated = true
		local id = data[PAGE_Id]
		local page = AngryAssign_Pages[id]
		if page then
			if data[PAGE_UpdateId] and page.UpdateId == data[PAGE_UpdateId] then return end -- The version received is same as the one we already have

			contents_updated = page.Contents ~= data[PAGE_Contents]
			page.Name = data[PAGE_Name]
			page.Contents = data[PAGE_Contents]
			page.Updated = data[PAGE_Updated]
			page.UpdateId = data[PAGE_UpdateId] or self:Hash(page.Name, page.Contents)

			if self:SelectedId() == id then
				self:SelectedUpdated(sender)
				self:UpdateSelected()
			end
		else
			AngryAssign_Pages[id] = { Id = id, Updated = data[PAGE_Updated], UpdateId = data[PAGE_UpdateId], Name = data[PAGE_Name], Contents = data[PAGE_Contents] }
		end
		-- Store received variables if present
		if data[PAGE_Variables] then
			AngryAssign_Variables.pages[id] = data[PAGE_Variables]
		end
		if AngryAssign_State.displayed == id then
			if contents_updated then AngryAssign_State.currentPage = 1 end
			self:UpdateDisplayed()
			self:ShowDisplay()
			if contents_updated then self:DisplayUpdateNotification() end
		end
		self:UpdateTree()

	elseif cmd == "DISPLAY" then
		if sender == PlayerFullName() then return end
		if not self:PermissionCheck(sender) then
			if data[DISPLAY_Id] then self:PermissionCheckFailError(sender) end
			return
		end

		local id = data[DISPLAY_Id]
		local updated = data[DISPLAY_Updated]
		local updateId = data[DISPLAY_UpdateId]
		local page = AngryAssign_Pages[id]
		local sameVersion = (updateId and page and updateId == page.UpdateId) or (not updateId and page and updated == page.Updated)
		if id and not sameVersion then
			self:SendRequestPage(id, sender)
		end

		if AngryAssign_State.displayed ~= id then
			AngryAssign_State.displayed = id
			AngryAssign_State.currentPage = 1
			self:UpdateTree()
			self:UpdateDisplayed()
			self:ShowDisplay()
			if id then self:DisplayUpdateNotification() end
			self:SendMessage("ANGRY_ASSIGNMENTS_UPDATE")
		end

	elseif cmd == "REQUEST_DISPLAY" then
		if sender == PlayerFullName() then return end
		if AngryAssign_State.displayed then
			self:SendDisplay( AngryAssign_State.displayed )
		end

	elseif cmd == "REQUEST_PAGE" then
		if sender == PlayerFullName() then return end

		self:SendPage( data[REQUEST_PAGE_Id] )


	elseif cmd == "VER_QUERY" then

		self:SendVersion()


	elseif cmd == "VERSION" then
		local ver, timestamp
		ver = tostring(data[VERSION_Version])
		timestamp = tonumber(data[VERSION_Timestamp])

		local localTimestamp = "dev"
		local localIsClassic = 0
		if ns.AngryAssign_Timestamp:sub(1,1) ~= "@" then
			localTimestamp = tonumber(ns.AngryAssign_Timestamp)
			if ns.AngryAssign_Version:sub(-3) == "tbc" then
				localIsClassic = 2
			elseif ns.AngryAssign_Version:sub(-1) == "c" then
				localIsClassic = 1
			end
		end

		local remoteIsClassic = 0
		if ver:sub(-3) == "tbc" then
			remoteIsClassic = 2
		elseif ver:sub(-1) == "c" then
			remoteIsClassic = 1
		end

		local localStr = tostring(localTimestamp)
		local remoteStr = tostring(timestamp)

		if (localStr ~= "dev" and localStr:len() ~= 14) or (remoteStr ~= "dev" and remoteStr:len() ~= 14) then
			if localStr ~= "dev" then localTimestamp = tonumber(localStr:sub(1,8)) end
			if remoteStr ~= "dev" then timestamp = tonumber(remoteStr:sub(1,8)) end
		end

		if localTimestamp ~= "dev" and timestamp ~= "dev" and timestamp > localTimestamp and localIsClassic == remoteIsClassic and not warnedOOD then
			self:Print("Your version of Angry Assignments+ is out of date!")
			warnedOOD = true
		end

		ns.versionList[ sender ] = { valid = data[VERSION_ValidRaid], version = ver }

	elseif cmd == "SHARE" then
		if sender == PlayerFullName() then return end
		if not self:PermissionCheck(sender) then
			self:PermissionCheckFailError(sender)
			return
		end

		local name = data[SHARE_Name]
		local contents = data[SHARE_Contents]
		if not name or not contents then return end

		if self:HasContentHash(contents) then return end

		local senderShort = Ambiguate(sender, "none")
		local sharedName = "[" .. senderShort .. "] " .. name

		local id = self:Hash("share", math.random(2000000000))
		AngryAssign_Pages[id] = {
			Id = id,
			Updated = time(),
			UpdateId = self:Hash(sharedName, contents),
			Name = sharedName,
			Contents = contents,
			ContentHash = LibDeflate:Adler32(contents),
			CategoryId = ns.SHARED_CATEGORY_ID,
			SharedFrom = sender,
		}
		-- Store received variables if present
		if data[SHARE_Variables] then
			AngryAssign_Variables.pages[id] = data[SHARE_Variables]
		end
		self:UpdateTree()
		self:Print("Received shared page: " .. sharedName)
	end
end

function AngryAssign:PermissionCheckFailError(sender)
	if not ns.warnedPermission then
		local senderName = Ambiguate(sender, "none")
		self:Print(RED_FONT_COLOR_CODE .. "Rejected page update from " .. senderName .. ". The raid leader is not authorized to send assignments.|r")
		self:Print(LIGHTYELLOW_FONT_COLOR_CODE .. "To accept: enable 'Allow All' in /aa config, or add the raid leader to your 'Allow Players' list.|r")
		ns.warnedPermission = true
	end
end

function AngryAssign:SendPage(id, force)
	local lastUpdate = pageLastUpdate[id]
	local timerId = pageTimerId[id]
	local curTime = time()

	if lastUpdate and (curTime - lastUpdate <= updateFrequency) then
		if not timerId then
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
	pageLastUpdate[id] = time()
	pageTimerId[id] = nil

	local page = AngryAssign_Pages[ id ]
	if not page then error("Can't send page, does not exist"); return end
	if not page.UpdateId then page.UpdateId = self:Hash(page.Name, page.Contents) end
	local vars = self:GetResolvedVarsForPage(id)
	local varsToSend = next(vars) and vars or nil
	self:SendOutMessage({ "PAGE", [PAGE_Id] = page.Id, [PAGE_Updated] = page.Updated, [PAGE_Name] = page.Name, [PAGE_Contents] = page.Contents, [PAGE_UpdateId] = page.UpdateId, [PAGE_Variables] = varsToSend })
end

function AngryAssign:SendDisplay(id, force)
	local curTime = time()

	if displayLastUpdate and (curTime - displayLastUpdate <= updateFrequency) then
		if not displayTimerId then
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
	displayLastUpdate = time()
	displayTimerId = nil

	local page = AngryAssign_Pages[ id ]
	if not page then
		self:SendOutMessage({ "DISPLAY", [DISPLAY_Id] = nil, [DISPLAY_Updated] = nil, [DISPLAY_UpdateId] = nil })
	else
		if not page.UpdateId then page.UpdateId = self:Hash(page.Name, page.Contents) end
		self:SendOutMessage({ "DISPLAY", [DISPLAY_Id] = page.Id, [DISPLAY_Updated] = page.Updated, [DISPLAY_UpdateId] = page.UpdateId })
	end
end

function AngryAssign:SendRequestDisplay()
	if (IsInRaid() or IsInGroup()) then
		local to = self:GetRaidLeader(true)
		if to then self:SendOutMessage({ "REQUEST_DISPLAY" }, "WHISPER", to) end
	end
end

function AngryAssign:SendRequestDisplayFallback()
	if AngryAssign_State.displayed then return end
	if IsInRaid() or IsInGroup() then
		self:SendOutMessage({ "REQUEST_DISPLAY" })
	end
end

function AngryAssign:SendVersion(force)
	local curTime = time()

	if versionLastUpdate and (curTime - versionLastUpdate <= updateFrequency) then
		if not versionTimerId then
			if force then
				self:SendVersionMessage()
			else
				versionTimerId = self:ScheduleTimer("SendVersionMessage", updateFrequency - (curTime - versionLastUpdate))
			end
		elseif force then
			self:CancelTimer( versionTimerId )
			self:SendVersionMessage()
		end
	else
		self:SendVersionMessage()
	end
end

function AngryAssign:SendVersionMessage()
	versionLastUpdate = time()
	versionTimerId = nil

	local timestampToSend
	local verToSend
	if ns.AngryAssign_Version:sub(1,1) == "@" then verToSend = "dev" else verToSend = ns.AngryAssign_Version end
	if ns.AngryAssign_Timestamp:sub(1,1) == "@" then timestampToSend = "dev" else timestampToSend = tonumber(ns.AngryAssign_Timestamp) end
	self:SendOutMessage({ "VERSION", [VERSION_Version] = verToSend, [VERSION_Timestamp] = timestampToSend, [VERSION_ValidRaid] = self:IsValidRaid() })
end


function AngryAssign:SendVerQuery()
	self:SendOutMessage({ "VER_QUERY" })
end

function AngryAssign:SendRequestPage(id, to)
	if (IsInRaid() or IsInGroup()) or to then
		if not to then to = self:GetRaidLeader(true) end
		if to then self:SendOutMessage({ "REQUEST_PAGE", [REQUEST_PAGE_Id] = id }, "WHISPER", to) end
	end
end

function AngryAssign:SendSharePage(pageId)
	local page = AngryAssign_Pages[pageId]
	if not page then return end
	local vars = self:GetResolvedVarsForPage(pageId)
	local varsToSend = next(vars) and vars or nil
	self:SendOutMessage({ "SHARE", [SHARE_Name] = page.Name, [SHARE_Contents] = page.Contents, [SHARE_Variables] = varsToSend })
end

function AngryAssign:GetRaidLeader(online_only)
	if (IsInRaid() or IsInGroup()) then
		for i = 1, GetNumGroupMembers() do
			local name, rank, _, _, _, _, _, online = GetRaidRosterInfo(i)
			if rank == 2 then
				if (not online_only) or online then
					return EnsureUnitFullName(name)
				else
					return nil
				end
			end
		end
	end
	return nil
end

function AngryAssign:GetCurrentGroup()
	local player = PlayerFullName()
	if (IsInRaid() or IsInGroup()) then
		for i = 1, GetNumGroupMembers() do
			local name, _, subgroup = GetRaidRosterInfo(i)
			if EnsureUnitFullName(name) == player then
				return subgroup
			end
		end
	end
	return nil
end

function AngryAssign:VersionCheckOutput()
	local missing_addon = {}
	local invalid_raid = {}
	local different_version = {}
	local up_to_date = {}

	local ver = ns.AngryAssign_Version
	if ver:sub(1,1) == "@" then ver = "dev" end

	if (IsInRaid() or IsInGroup()) then
		for i = 1, GetNumGroupMembers() do
			local name, _, _, _, _, _, _, online = GetRaidRosterInfo(i)
			local fullname = EnsureUnitFullName(name)
			if online then
				if not ns.versionList[ fullname ] then
					tinsert(missing_addon, name)
				elseif ns.versionList[ fullname ].valid == false or ns.versionList[ fullname ].valid == nil then
					tinsert(invalid_raid, name)
				elseif ver ~= ns.versionList[ fullname ].version then
					tinsert(different_version, string.format("%s - %s", name, ns.versionList[ fullname ].version)  )
				else
					tinsert(up_to_date, name)
				end
			end
		end
	end

	self:Print("Version check results:")
	if #up_to_date > 0 then
		print(LIGHTYELLOW_FONT_COLOR_CODE.."Same version:|r "..table.concat(up_to_date, ", "))
	end

	if #different_version > 0 then
		print(LIGHTYELLOW_FONT_COLOR_CODE.."Different version:|r "..table.concat(different_version, ", "))
	end

	if #invalid_raid > 0 then
		print(LIGHTYELLOW_FONT_COLOR_CODE.."Not allowing changes:|r "..table.concat(invalid_raid, ", "))
	end

	if #missing_addon > 0 then
		print(LIGHTYELLOW_FONT_COLOR_CODE.."Missing addon:|r "..table.concat(missing_addon, ", "))
	end
end
