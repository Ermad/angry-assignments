local _, ns = ...
local AngryAssign = LibStub("AceAddon-3.0"):GetAddon("AngryAssignments")

local SHARED_CATEGORY_ID = ns.SHARED_CATEGORY_ID
local EnsureUnitShortName = ns.EnsureUnitShortName

--------------------------------------
-- Built-in token exclusion list    --
--------------------------------------

local BUILTIN_TOKENS = {
	-- Raid icons
	star = true, circle = true, diamond = true, triangle = true,
	moon = true, square = true, cross = true, x = true, skull = true,
	-- RT aliases
	rt1 = true, rt2 = true, rt3 = true, rt4 = true,
	rt5 = true, rt6 = true, rt7 = true, rt8 = true,
	-- Roles
	tank = true, healer = true, dps = true, damage = true,
	-- Buffs
	bl = true, bloodlust = true, hero = true, heroism = true,
	hs = true, healthstone = true,
	-- Classes
	hunter = true, warrior = true, rogue = true, mage = true,
	priest = true, warlock = true, paladin = true, druid = true,
	shaman = true, dk = true, deathknight = true, monk = true,
	dh = true, demonhunter = true, evoker = true,
	-- Page break
	page = true,
}

local BUILTIN_PATTERNS = {
	"^spell%s+%d+$",
	"^icon%s+%d+$",
	"^icon%s+[%w_]+$",
	"^name%s+%S+%s+%u+$",
	"^boss%s+%d+$",
	"^journal%s+%d+$",
}

function AngryAssign:IsBuiltinToken(token)
	if BUILTIN_TOKENS[token] then return true end
	for _, pattern in ipairs(BUILTIN_PATTERNS) do
		if token:match(pattern) then return true end
	end
	return false
end

--------------------------------------
-- Category variable hierarchy      --
--------------------------------------

-- Walk up the category hierarchy, merge variables root-to-leaf (deeper overrides shallower).
function AngryAssign:GetMergedCategoryVars(catId)
	local result = {}
	local chain = {}

	local id = catId
	while id and id ~= SHARED_CATEGORY_ID do
		table.insert(chain, 1, id) -- prepend (root first)
		local cat = AngryAssign_Categories[id]
		id = cat and cat.CategoryId or nil
	end

	for _, cid in ipairs(chain) do
		local vars = AngryAssign_Variables.categories[cid]
		if vars then
			for k, v in pairs(vars) do
				result[k] = v
			end
		end
	end

	return result
end

-- Returns the fully merged variable table (category + page overrides) for a given page.
function AngryAssign:GetResolvedVarsForPage(pageId)
	local page = AngryAssign_Pages[pageId]
	if not page then return {} end

	local vars = {}

	-- Category variables
	if page.CategoryId and page.CategoryId ~= SHARED_CATEGORY_ID then
		local catVars = self:GetMergedCategoryVars(page.CategoryId)
		for k, v in pairs(catVars) do
			vars[k] = v
		end
	end

	-- Page-level overrides
	local pageVars = AngryAssign_Variables.pages[pageId]
	if pageVars then
		for k, v in pairs(pageVars) do
			vars[k] = v
		end
	end

	return vars
end

--------------------------------------
-- Roster lookup for player names   --
--------------------------------------

-- Build a lookup table: lowercase short name -> uppercase class file name.
-- Used to auto-wrap variable values matching player names in {name X CLASS} tokens.
local rosterCache, rosterCacheTime

local function GetRosterLookup()
	local now = GetTime()
	if rosterCache and rosterCacheTime and (now - rosterCacheTime) < 2 then
		return rosterCache
	end

	local lookup = {}
	if IsInRaid() or IsInGroup() then
		for i = 1, GetNumGroupMembers() do
			local name, _, _, _, _, fileName = GetRaidRosterInfo(i)
			if name and fileName then
				lookup[EnsureUnitShortName(name):lower()] = fileName
			end
		end
	end

	rosterCache = lookup
	rosterCacheTime = now
	return lookup
end

--------------------------------------
-- Variable substitution            --
--------------------------------------

-- Resolve {$varName} tokens in text using the merged variable definitions for a page.
-- If a variable value matches a raid member's name, it is wrapped in a {name X CLASS}
-- token so it gets class-colored by the display pipeline.
function AngryAssign:ResolveVariables(pageId, text)
	if not text or text == "" then return text end

	local vars = self:GetResolvedVarsForPage(pageId)
	if not next(vars) then return text end

	-- Build lowercase lookup for case-insensitive matching
	local lowerVars = {}
	for k, v in pairs(vars) do
		lowerVars[k:lower()] = v
	end

	local roster = GetRosterLookup()

	text = text:gsub("{%$([^}]+)}", function(token)
		local replacement = lowerVars[token:lower()]
		if replacement then
			-- If value matches a player name, emit a {name} token for class coloring
			local className = roster[replacement:lower()]
			if className then
				return "{name " .. replacement .. " " .. className .. "}"
			end
			return replacement
		end
		return nil -- keep original {$token} unchanged
	end)

	return text
end

--------------------------------------
-- Variable token scanning          --
--------------------------------------

-- Scan page contents for {$variableName} tokens.
-- Returns a set (table where keys are lowercase variable names, values are true).
function AngryAssign:ScanPageVariableTokens(pageId)
	local page = self:Get(pageId)
	if not page or not page.Contents then return {} end

	local found = {}
	for token in page.Contents:gmatch("{%$([^}]+)}") do
		found[token:lower()] = true
	end
	return found
end

-- Scan all pages in a category for {$variable} tokens.
-- Returns a set of unique lowercase variable names.
function AngryAssign:ScanCategoryVariableTokens(catId)
	local allVars = {}
	local pages = self:GetCategoryPages(catId)
	for _, page in ipairs(pages) do
		local pageVars = self:ScanPageVariableTokens(page.Id)
		for k in pairs(pageVars) do
			allVars[k] = true
		end
	end
	return allVars
end

-- Quick boolean check: does page contain any {$...} tokens?
function AngryAssign:PageHasVariableTokens(pageId)
	local page = self:Get(pageId)
	if not page or not page.Contents then return false end
	return page.Contents:find("{%$[^}]+}") ~= nil
end

-- Strip all {$key} tokens from a list of page tables.
-- Used by the delete button to fully remove a variable and its references.
function AngryAssign:StripVariableToken(key, pages)
	local pattern = "{%$" .. key:gsub("([%%%.])", "%%%1") .. "}"
	for _, page in ipairs(pages) do
		if page.Contents and page.Contents:find(pattern) then
			page.Contents = page.Contents:gsub(pattern, "")
			page.Updated = time()
			if self.window and self:SelectedId() == page.Id then
				self:UpdateSelected(true)
			end
		end
	end
end

-- Check if a page belongs to a category (walking up hierarchy).
function AngryAssign:PageBelongsToCategory(pageId, catId)
	local page = AngryAssign_Pages[pageId]
	if not page then return false end
	local id = page.CategoryId
	while id do
		if id == catId then return true end
		local cat = AngryAssign_Categories[id]
		id = cat and cat.CategoryId or nil
	end
	return false
end
