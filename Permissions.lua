local _, ns = ...
local AngryAssign = LibStub("AceAddon-3.0"):GetAddon("AngryAssignments")

local EnsureUnitFullName = ns.EnsureUnitFullName
local EnsureUnitShortName = ns.EnsureUnitShortName
local PlayerFullName = ns.PlayerFullName

local guildOfficerNames = nil

function AngryAssign:IsGuildOfficer(player)
	if not player then return false end
	local fullplayer = EnsureUnitFullName(player)

	if guildOfficerNames == nil then
		self:UpdateOfficerRank()
	end

	return guildOfficerNames[fullplayer]
end

function AngryAssign:ResetOfficerRank()
	guildOfficerNames = nil
end

function AngryAssign:UpdateOfficerRank()
	guildOfficerNames = {}

	if C_Club and C_Club.GetGuildClubId then
		local clubId, streamId = C_Club.GetGuildClubId(), nil
		local memberIds = CommunitiesUtil.GetMemberIdsSortedByName(clubId, streamId)
		local allMemberList = CommunitiesUtil.GetMemberInfo(clubId, memberIds)

		for _, memberInfo in ipairs(allMemberList) do
			if memberInfo.name and (memberInfo.role == Enum.ClubRoleIdentifier.Owner or memberInfo.role == Enum.ClubRoleIdentifier.Leader or memberInfo.role == Enum.ClubRoleIdentifier.Moderator) then
				guildOfficerNames[EnsureUnitFullName(memberInfo.name)] = true
			end
		end
	end

	return guildOfficerNames
end

function AngryAssign:IsPlayerRaidLeader()
	local leader = self:GetRaidLeader()
	return leader and PlayerFullName() == EnsureUnitFullName(leader)
end

function AngryAssign:IsGuildRaid()
	local leader = self:GetRaidLeader()

	if self:IsGuildOfficer(leader) then
		return true
	end

	return false
end


function AngryAssign:IsValidRaid()
	if self:GetConfig('allowall') then
		return true
	end

	local leader = self:GetRaidLeader()

	if self:GetConfig('allowOfficers') and self:IsGuildOfficer(leader) then
		return true
	end

	for token in string.gmatch( AngryAssign:GetConfig('allowplayers') , "[^%s!#$%%&()*+,./:;<=>?@\\^_{|}~%[%]]+") do
		if leader and EnsureUnitFullName(token):lower() == EnsureUnitFullName(leader):lower() then
			return true
		end
	end

	if self:IsPlayerRaidLeader() then
		return true
	end

	return false
end

function AngryAssign:PermissionCheck(sender)
	if not sender then sender = PlayerFullName() end

	if not (IsInRaid() or IsInGroup()) then
		return sender == PlayerFullName()
	end

	local shortName = EnsureUnitShortName(sender)
	local isLeader = UnitIsGroupLeader(shortName) == true
	local isAssistant = UnitIsGroupAssistant(shortName) == true

	if not isLeader and not isAssistant then
		return false
	end

	-- Valid raid: all leaders and assistants are trusted
	if self:IsValidRaid() then
		return true
	end

	-- Role-specific overrides (for non-valid raids)
	if self:GetConfig('allowRaidLeader') and isLeader then
		return true
	end
	if self:GetConfig('allowRaidAssistants') and isAssistant then
		return true
	end

	return false
end


function AngryAssign:PermissionsUpdated()
	self:UpdateSelected()
	if ns.comStarted then
		self:SendRequestDisplay()
	end
	if (IsInRaid() or IsInGroup()) and not self:IsValidRaid()
		and not self:GetConfig('allowRaidLeader')
		and not self:GetConfig('allowRaidAssistants') then
		self:ClearDisplayed()
	end
end
