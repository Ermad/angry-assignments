local _, ns = ...
local AngryAssign = LibStub("AceAddon-3.0"):GetAddon("AngryAssignments")

-- Deterministic ID ranges for templates (won't collide with Adler32 hashes)
local TEMPLATE_CAT_BASE   = 2147483600   -- raid category IDs (up to 99 raids)
local TEMPLATE_PAGE_BASE  = 2147400000   -- page IDs (raidIdx * 100 + bossIdx)
ns.TEMPLATE_ROOT_VALUE    = -2147483500  -- parent "Templates" category tree value

-- Lookup tables populated at load time
ns.templatePages = {}    -- pageId -> virtual page object
ns.templateCatIds = {}   -- negativeCatId -> true (for tree value checks)
ns.templatePageIds = {}  -- pageId -> true
ns.templateCatPages = {} -- catTreeValue -> ordered list of pageIds
ns.templateCatNames = {} -- catTreeValue -> raid name string
ns.templateTree = nil    -- single root tree node with raid children (or nil if no data)

-- Template tree value sentinel (used by IsVirtualCategory extension)
ns.TEMPLATE_TREE_VALUES = {}

local function BuildTemplates()
	local data
	if ns.isClassicTBC then
		data = ns.TemplateData and ns.TemplateData.TBC
	elseif ns.isClassicWrath then
		data = ns.TemplateData and ns.TemplateData.Wrath
	elseif ns.isClassicCata then
		data = ns.TemplateData and ns.TemplateData.Cata
	elseif ns.isClassicMoP then
		data = ns.TemplateData and ns.TemplateData.MoP
	elseif ns.isClassicVanilla then
		data = ns.TemplateData and ns.TemplateData.Vanilla
	end

	if not data then return end

	-- Root "Templates" node is a virtual category
	ns.TEMPLATE_TREE_VALUES[ns.TEMPLATE_ROOT_VALUE] = true

	local raidNodes = {}
	for raidIdx, raid in ipairs(data) do
		local catId = TEMPLATE_CAT_BASE + raidIdx
		local catTreeValue = -catId
		ns.templateCatIds[catTreeValue] = true
		ns.TEMPLATE_TREE_VALUES[catTreeValue] = true
		ns.templateCatNames[catTreeValue] = raid.name
		ns.templateCatPages[catTreeValue] = {}

		local children = {}
		for bossIdx, boss in ipairs(raid.bosses) do
			local pageId = TEMPLATE_PAGE_BASE + raidIdx * 100 + bossIdx
			ns.templatePages[pageId] = {
				Id = pageId,
				Name = boss.name,
				Contents = boss.contents,
				IsTemplate = true,
				CategoryId = catId,
			}
			ns.templatePageIds[pageId] = true
			table.insert(ns.templateCatPages[catTreeValue], pageId)
			table.insert(children, {
				value = pageId,
				text = boss.name,
			})
		end

		table.insert(raidNodes, {
			value = catTreeValue,
			text = raid.name,
			icon = "Interface\\MINIMAP\\Dungeon",
			children = children,
		})
	end

	ns.templateTree = {
		value = ns.TEMPLATE_ROOT_VALUE,
		text = "Templates",
		icon = "Interface\\BUTTONS\\UI-GuildButton-PublicNote-Up",
		children = raidNodes,
	}
end

BuildTemplates()

function AngryAssign:IsTemplatePage(id)
	return ns.templatePageIds[id] == true
end

function AngryAssign:IsTemplateCategory(treeValue)
	return ns.templateCatIds[treeValue] == true
end

function AngryAssign:GetTemplatePage(id)
	return ns.templatePages[id]
end
