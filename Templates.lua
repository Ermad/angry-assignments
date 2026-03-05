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

-- User template constants
local USER_TEMPLATE_PAGE_BASE = 2147300000
local USER_TEMPLATE_CAT_BASE  = 2147350000

function AngryAssign:IsTemplatePage(id)
	if ns.templatePageIds[id] then return true end
	if AngryAssign_State.userTemplates and AngryAssign_State.userTemplates.pages[id] then return true end
	return false
end

function AngryAssign:IsTemplateCategory(treeValue)
	if ns.templateCatIds[treeValue] then return true end
	if treeValue and AngryAssign_State.userTemplates and AngryAssign_State.userTemplates.categories[-treeValue] then return true end
	return false
end

function AngryAssign:GetTemplatePage(id)
	return ns.templatePages[id] or (AngryAssign_State.userTemplates and AngryAssign_State.userTemplates.pages[id])
end

function AngryAssign:IsUserTemplatePage(id)
	return AngryAssign_State.userTemplates and AngryAssign_State.userTemplates.pages[id] ~= nil
end

function AngryAssign:IsUserTemplateCat(catId)
	return AngryAssign_State.userTemplates and AngryAssign_State.userTemplates.categories[catId] ~= nil
end

local function NextUserTemplatePageId()
	local id = USER_TEMPLATE_PAGE_BASE
	local pages = AngryAssign_State.userTemplates and AngryAssign_State.userTemplates.pages
	if pages then
		while pages[id] do id = id + 1 end
	end
	return id
end

function AngryAssign:CopyToUserTemplate(sourceValue)
	local ut = AngryAssign_State.userTemplates
	if not ut then return end

	if sourceValue > 0 then
		local source = self:Get(sourceValue)
		if not source then return end
		local id = NextUserTemplatePageId()
		ut.pages[id] = {
			Id = id,
			Name = source.Name,
			Contents = source.Contents,
		}
	else
		local catId = -sourceValue
		local cat = AngryAssign_Categories[catId]
		if not cat then return end

		local newCatId = USER_TEMPLATE_CAT_BASE
		while ut.categories[newCatId] do newCatId = newCatId + 1 end

		local pages = self:GetCategoryPages(catId)
		for _, page in ipairs(pages) do
			local newPageId = NextUserTemplatePageId()
			ut.pages[newPageId] = {
				Id = newPageId,
				Name = page.Name,
				Contents = page.Contents,
				CategoryId = newCatId,
			}
		end

		ut.categories[newCatId] = {
			Id = newCatId,
			Name = cat.Name,
		}
	end

	self:UpdateTree()
end

function AngryAssign:DeleteUserTemplatePage(id)
	local ut = AngryAssign_State.userTemplates
	if not ut or not ut.pages[id] then return end
	ut.pages[id] = nil
	if self.window and self:SelectedId() == id then
		self:SetSelectedId(nil)
		self:UpdateSelected(true)
	end
	self:UpdateTree()
end

function AngryAssign:DeleteUserTemplateCat(catId)
	local ut = AngryAssign_State.userTemplates
	if not ut or not ut.categories[catId] then return end
	for pageId, page in pairs(ut.pages) do
		if page.CategoryId == catId then
			ut.pages[pageId] = nil
		end
	end
	ut.categories[catId] = nil
	self:UpdateTree()
end
