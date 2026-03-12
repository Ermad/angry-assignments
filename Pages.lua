local _, ns = ...
local AngryAssign = LibStub("AceAddon-3.0"):GetAddon("AngryAssignments")

local LibDeflate = LibStub("LibDeflate")

local selectedLastValue = ns.selectedLastValue
local tReverse = ns.tReverse

local SHARED_CATEGORY_ID   = ns.SHARED_CATEGORY_ID
local DISPLAYED_TREE_VALUE = ns.DISPLAYED_TREE_VALUE
local SHARED_TREE_VALUE    = ns.SHARED_TREE_VALUE

----------------------------------
-- Tree Building               --
----------------------------------

-- Sort tree nodes using explicit sort order if available, falling back to alphabetical.
-- contextKey is "root" for root-level items, or a categoryId for items within a category.
local function SortTreeNodes(tree, contextKey)
	local order = AngryAssign_State.sortOrder and AngryAssign_State.sortOrder[contextKey]
	if not order then
		table.sort(tree, function(a, b) return a.text < b.text end)
		return
	end

	local position = {}
	for i, val in ipairs(order) do
		position[val] = i
	end

	local maxPos = #order
	table.sort(tree, function(a, b)
		local posA = position[a.value]
		local posB = position[b.value]
		if posA and posB then
			return posA < posB
		elseif posA then
			return true
		elseif posB then
			return false
		else
			return a.text < b.text
		end
	end)
	return maxPos -- suppress unused warning
end

local function GetTree_InsertPage(tree, page, filter)
	local pageName = page.Name
	-- Variable indicator: show {$} if page uses variable tokens
	if AngryAssign:PageHasVariableTokens(page.Id) then
		pageName = pageName .. " |cff00cc00{$}|r"
	end
	local node
	if page.Id == AngryAssign_State.displayed then
		node = { value = page.Id, text = pageName, icon = "Interface\\BUTTONS\\UI-GuildButton-MOTD-Up" }
	else
		node = { value = page.Id, text = pageName }
	end
	if filter then
		node.visible = page.Name:lower():find(filter, 1, true) ~= nil
	end
	table.insert(tree, node)
end

local function GetTree_InsertChildren(categoryId, displayedPages, filter)
	local tree = {}
	for _, cat in pairs(AngryAssign_Categories) do
		if cat.CategoryId == categoryId then
			local catName = cat.Name
			if AngryAssign_Variables and AngryAssign_Variables.categories
				and AngryAssign_Variables.categories[cat.Id]
				and next(AngryAssign_Variables.categories[cat.Id]) then
				catName = catName .. " |cff00cc00[V]|r"
			end
			table.insert(tree, { value = -cat.Id, text = catName, children = GetTree_InsertChildren(cat.Id, displayedPages, filter) })
		end
	end

	for _, page in pairs(AngryAssign_Pages) do
		if page.CategoryId == categoryId then
			displayedPages[page.Id] = true
			GetTree_InsertPage(tree, page, filter)
		end
	end

	SortTreeNodes(tree, categoryId)
	return tree
end

function AngryAssign:GetTree(filter)
	local tree = {}
	local displayedPages = {}

	-- 1. "Currently Displayed" virtual category (always first)
	local displayedChildren = {}
	local displayedId = AngryAssign_State.displayed
	if displayedId then
		local page = self:Get(displayedId)
		if page then
			local node = { value = page.Id, text = page.Name, icon = "Interface\\BUTTONS\\UI-GuildButton-MOTD-Up" }
			if filter then
				node.visible = page.Name:lower():find(filter, 1, true) ~= nil
			end
			table.insert(displayedChildren, node)
		end
	end
	table.insert(tree, {
		value = DISPLAYED_TREE_VALUE,
		text = "Currently Displayed",
		icon = "Interface\\BUTTONS\\UI-GuildButton-MOTD-Up",
		children = displayedChildren,
	})

	-- 2. "Shared with me" virtual category (always second)
	local sharedChildren = {}
	for _, page in pairs(AngryAssign_Pages) do
		if page.CategoryId == SHARED_CATEGORY_ID then
			displayedPages[page.Id] = true
			GetTree_InsertPage(sharedChildren, page, filter)
		end
	end
	table.sort(sharedChildren, function(a,b) return a.text < b.text end)
	table.insert(tree, {
		value = SHARED_TREE_VALUE,
		text = "Shared with me",
		children = sharedChildren,
	})

	-- 3. User categories and root pages (existing logic, sorted alphabetically)
	local userTree = {}
	for _, cat in pairs(AngryAssign_Categories) do
		if not cat.CategoryId then
			local catName = cat.Name
			if AngryAssign_Variables and AngryAssign_Variables.categories
				and AngryAssign_Variables.categories[cat.Id]
				and next(AngryAssign_Variables.categories[cat.Id]) then
				catName = catName .. " |cff00cc00[V]|r"
			end
			table.insert(userTree, { value = -cat.Id, text = catName, children = GetTree_InsertChildren(cat.Id, displayedPages, filter) })
		end
	end

	for _, page in pairs(AngryAssign_Pages) do
		if page.CategoryId ~= SHARED_CATEGORY_ID and (not page.CategoryId or not displayedPages[page.Id]) then
			GetTree_InsertPage(userTree, page, filter)
		end
	end

	SortTreeNodes(userTree, "root")
	for _, node in ipairs(userTree) do
		table.insert(tree, node)
	end

	-- 4. Templates root category (always at bottom)
	do
		local templateChildren = {}

		-- Built-in templates
		if ns.templateTree then
			for _, raidNode in ipairs(ns.templateTree.children) do
				if filter then
					local filteredBosses = {}
					for _, boss in ipairs(raidNode.children) do
						local copy = { value = boss.value, text = boss.text }
						copy.visible = boss.text:lower():find(filter, 1, true) ~= nil
						table.insert(filteredBosses, copy)
					end
					table.insert(templateChildren, { value = raidNode.value, text = raidNode.text, icon = raidNode.icon, children = filteredBosses })
				else
					table.insert(templateChildren, raidNode)
				end
			end
		end

		-- User templates
		local ut = AngryAssign_State.userTemplates
		if ut then
			for _, utCat in pairs(ut.categories) do
				local catChildren = {}
				for _, utPage in pairs(ut.pages) do
					if utPage.CategoryId == utCat.Id then
						local node = { value = utPage.Id, text = utPage.Name }
						if filter then
							node.visible = utPage.Name:lower():find(filter, 1, true) ~= nil
						end
						table.insert(catChildren, node)
					end
				end
				table.sort(catChildren, function(a, b) return a.text < b.text end)
				table.insert(templateChildren, { value = -utCat.Id, text = utCat.Name, children = catChildren })
			end

			for _, utPage in pairs(ut.pages) do
				if not utPage.CategoryId then
					local node = { value = utPage.Id, text = utPage.Name }
					if filter then
						node.visible = utPage.Name:lower():find(filter, 1, true) ~= nil
					end
					table.insert(templateChildren, node)
				end
			end
		end

		if #templateChildren > 0 then
			table.insert(tree, {
				value = ns.TEMPLATE_ROOT_VALUE,
				text = "Templates",
				icon = "Interface\\BUTTONS\\UI-GuildButton-PublicNote-Up",
				children = templateChildren,
			})
		end
	end

	return tree
end

function AngryAssign:UpdateTree(id)
	if not self.window then return end
	local filter = self.searchFilter
	self.window.tree:SetTree( self:GetTree(filter), filter ~= nil )
	if id then
		self:SetSelectedId( id )
	end
	self:UpdateStatusText()
end

function AngryAssign:UpdateStatusText()
	if not self.window then return end
	local page = self:Get(AngryAssign_State.displayed)
	if self.window.status_text then
		if page then
			self.window.status_text:SetText("Displayed: " .. page.Name)
		else
			self.window.status_text:SetText("No page displayed")
		end
	end
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
		StaticPopupDialogs[popup_name].text = "The page you are editing has been updated by "..sender..".\n\nYou can view this update by reverting your changes."
		StaticPopup_Show(popup_name)
		return true
	else
		return false
	end
end

----------------------------------
-- Selection & Button State    --
----------------------------------

function AngryAssign:UpdateSelected(destructive)
	if not self.window then return end
	local selectedId = self:SelectedId()
	local page = self:Get(selectedId)
	local isTemplate = self:IsTemplatePage(selectedId)
	local permission = self:PermissionCheck()
	if destructive or not self.window.text.button:IsEnabled() then
		if page then
			self.window.text:SetText( page.Contents )
		else
			self.window.text:SetText("")
		end
		self.window.text.button:Disable()
	end
	if isTemplate then
		-- Template pages are read-only: disable editing, show only Duplicate/Display
		self.window.button_revert:SetDisabled(true)
		self.window.button_display:SetDisabled(not permission)
		self.window.button_output:SetDisabled(not permission)
		self.window.button_restore:SetDisabled(true)
		self.window.text:SetDisabled(true)
	elseif page and permission then
		self.window.button_revert:SetDisabled(not self.window.text.button:IsEnabled())
		self.window.button_display:SetDisabled(self.window.text.button:IsEnabled())
		self.window.button_output:SetDisabled(self.window.text.button:IsEnabled())
		self.window.button_restore:SetDisabled(not self.window.text.button:IsEnabled() and page.Backup == page.Contents)
		self.window.text:SetDisabled(false)
	else
		self.window.button_revert:SetDisabled(true)
		self.window.button_display:SetDisabled(true)
		self.window.button_output:SetDisabled(true)
		self.window.button_restore:SetDisabled(true)
		self.window.text:SetDisabled(true)
	end
	if permission then
		self.window.button_add:SetDisabled(false)
		self.window.button_clear:SetDisabled(false)
	else
		self.window.button_add:SetDisabled(true)
		self.window.button_clear:SetDisabled(true)
	end
	self:RefreshSidePanel()
end

----------------------------------
-- Performing changes functions --
----------------------------------

function AngryAssign:SelectedId()
	return selectedLastValue( AngryAssign_State.tree.selected )
end

function AngryAssign:SetSelectedId(selectedId)
	-- Handle template pages (select by 3-level path: Templates > Raid > Boss)
	local tmplPage = ns.templatePages[selectedId]
	if tmplPage then
		local catTreeValue = -(tmplPage.CategoryId)
		self.window.tree:SelectByPath(ns.TEMPLATE_ROOT_VALUE, catTreeValue, selectedId)
		return
	end

	local page = AngryAssign_Pages[selectedId]
	if page then
		if page.CategoryId == SHARED_CATEGORY_ID then
			self.window.tree:SelectByPath(SHARED_TREE_VALUE, page.Id)
		elseif page.CategoryId then
			local cat = AngryAssign_Categories[page.CategoryId]
			local path = { }
			while cat do
				table.insert(path, -cat.Id)
				if cat.CategoryId then
					cat = AngryAssign_Categories[cat.CategoryId]
				else
					cat = nil
				end
			end
			tReverse(path)
			table.insert(path, page.Id)
			self.window.tree:SelectByPath(unpack(path))
		else
			self.window.tree:SelectByValue(page.Id)
		end
	else
		self.window.tree:SetSelected()
	end
end

function AngryAssign:Get(id)
	if id == nil then id = self:SelectedId() end
	return AngryAssign_Pages[id] or ns.templatePages[id] or (AngryAssign_State.userTemplates and AngryAssign_State.userTemplates.pages[id])
end

function AngryAssign:GetCat(id)
	return AngryAssign_Categories[id]
end

function AngryAssign:Hash(name, contents)
	return LibDeflate:Adler32(name .. "\n" .. contents)
end

function AngryAssign:CreatePage(name)
	if not self:PermissionCheck() then return end
	local id = self:Hash("page", math.random(2000000000))

	AngryAssign_Pages[id] = { Id = id, Updated = time(), UpdateId = self:Hash(name, ""), Name = name, Contents = "", ContentHash = LibDeflate:Adler32("") }
	self:AppendToSortOrder("root", id)
	self:UpdateTree(id)
	self:SendPage(id, true)
end

function AngryAssign:DuplicatePage(sourceId)
	if not self:PermissionCheck() then return end
	local source = self:Get(sourceId)
	if not source then return end
	local id = self:Hash("page", math.random(2000000000))
	AngryAssign_Pages[id] = {
		Id = id, Updated = time(),
		UpdateId = self:Hash("Copy of " .. source.Name, ""),
		Name = "Copy of " .. source.Name,
		Contents = source.Contents,
		ContentHash = LibDeflate:Adler32(source.Contents),
	}
	self:AppendToSortOrder("root", id)
	self:UpdateTree(id)
	self:SendPage(id, true)
end

function AngryAssign:DuplicateTemplateCategory(catTreeValue)
	if not self:PermissionCheck() then return end
	local pageIds = ns.templateCatPages[catTreeValue]
	local catName = ns.templateCatNames[catTreeValue]
	if not pageIds or not catName then return end

	local catId = self:Hash("cat", math.random(2000000000))
	AngryAssign_Categories[catId] = { Id = catId, Name = catName }

	local firstId
	for _, sourcePageId in ipairs(pageIds) do
		local source = ns.templatePages[sourcePageId]
		if source then
			local id = self:Hash("page", math.random(2000000000))
			AngryAssign_Pages[id] = {
				Id = id, Updated = time(),
				UpdateId = self:Hash(source.Name, ""),
				Name = source.Name,
				Contents = source.Contents,
				ContentHash = LibDeflate:Adler32(source.Contents),
				CategoryId = catId,
			}
			if not firstId then firstId = id end
			self:SendPage(id, true)
		end
	end

	self:AppendToSortOrder("root", -catId)
	if AngryAssign_State.tree.groups then
		AngryAssign_State.tree.groups[-catId] = true
	end
	self:UpdateTree(firstId)
end

function AngryAssign:RenamePage(id, name)
	if self:IsTemplatePage(id) then return end
	local page = self:Get(id)
	if not page or not self:PermissionCheck() then return end

	page.Name = name
	page.Updated = time()
	page.UpdateId = self:Hash(page.Name, page.Contents)

	self:SendPage(id, true)
	self:UpdateTree()
	if AngryAssign_State.displayed == id then
		self:UpdateDisplayed()
		self:ShowDisplay()
	end
end

function AngryAssign:DeletePage(id)
	if self:IsTemplatePage(id) then return end
	local delPage = AngryAssign_Pages[id]
	local delContext = delPage and (delPage.CategoryId or "root") or "root"
	AngryAssign_Pages[id] = nil
	if AngryAssign_Variables and AngryAssign_Variables.pages then
		AngryAssign_Variables.pages[id] = nil
	end
	self:RemoveFromSortOrder(delContext, id)
	if self.window and self:SelectedId() == id then
		self:SetSelectedId(nil)
		self:UpdateSelected(true)
	end
	if AngryAssign_State.displayed == id then
		self:ClearDisplayed()
	end
	self:UpdateTree()
end

function AngryAssign:TouchPage(id)
	if self:IsTemplatePage(id) then return end
	if not self:PermissionCheck() then return end
	local page = self:Get(id)
	if not page then return end

	page.Updated = time()
end

function AngryAssign:CreateCategory(name)
	local id = self:Hash("cat", math.random(2000000000))

	AngryAssign_Categories[id] = { Id = id, Name = name }
	self:AppendToSortOrder("root", -id)

	if AngryAssign_State.tree.groups then
		AngryAssign_State.tree.groups[ -id ] = true
	end
	self:UpdateTree()
end

function AngryAssign:RenameCategory(id, name)
	local cat = self:GetCat(id)
	if not cat then return end

	cat.Name = name

	self:UpdateTree()
end

function AngryAssign:DeleteCategory(id)
	local cat = self:GetCat(id)
	if not cat then return end

	local selectedId = self:SelectedId()

	for _, c in pairs(AngryAssign_Categories) do
		if cat.Id == c.CategoryId then
			c.CategoryId = cat.CategoryId
		end
	end

	for _, p in pairs(AngryAssign_Pages) do
		if cat.Id == p.CategoryId then
			p.CategoryId = cat.CategoryId
		end
	end

	AngryAssign_Categories[id] = nil
	if AngryAssign_Variables and AngryAssign_Variables.categories then
		AngryAssign_Variables.categories[id] = nil
	end
	self:RemoveFromSortOrder(cat.CategoryId or "root", -id)
	if AngryAssign_State.sortOrder then
		AngryAssign_State.sortOrder[id] = nil
	end

	self:UpdateTree()
	self:SetSelectedId(selectedId)
end

function AngryAssign:AssignCategory(entryId, parentId)
	local page, cat
	if entryId > 0 then
		page = self:Get(entryId)
	else
		cat = self:GetCat(-entryId)
	end
	local parent = self:GetCat(parentId)
	if not (page or cat) or not parent then return end

	-- Record old context for sort order maintenance
	local oldContextKey
	if page then
		oldContextKey = page.CategoryId or "root"
	elseif cat then
		oldContextKey = cat.CategoryId or "root"
	end

	if page then
		if page.CategoryId == parentId then
			page.CategoryId = nil
		else
			page.CategoryId = parentId
		end
	end

	if cat then
		if cat.CategoryId == parentId then
			cat.CategoryId = nil
		else
			cat.CategoryId = parentId
		end
	end

	-- Update sort orders if context changed
	local newContextKey
	if page then
		newContextKey = page.CategoryId or "root"
	elseif cat then
		newContextKey = cat.CategoryId or "root"
	end
	if oldContextKey and newContextKey and oldContextKey ~= newContextKey then
		self:RemoveFromSortOrder(oldContextKey, entryId)
		self:AppendToSortOrder(newContextKey, entryId)
	end

	local selectedId = self:SelectedId()
	self:UpdateTree()
	if selectedId == entryId then
		self:SetSelectedId( selectedId )
	end
end

--------------------------------------
-- Sort Order Helpers               --
--------------------------------------

local function GetRootValue(uniquevalue)
	if not uniquevalue then return nil end
	local s = tostring(uniquevalue)
	local sep = s:find("\001", 1, true)
	if sep then
		return tonumber(s:sub(1, sep - 1))
	else
		return tonumber(s)
	end
end

function AngryAssign:RemoveFromSortOrder(contextKey, value)
	local order = AngryAssign_State.sortOrder and AngryAssign_State.sortOrder[contextKey]
	if not order then return end
	for i = #order, 1, -1 do
		if order[i] == value then
			table.remove(order, i)
			break
		end
	end
end

function AngryAssign:AppendToSortOrder(contextKey, value)
	if AngryAssign_State.sortOrder and AngryAssign_State.sortOrder[contextKey] then
		table.insert(AngryAssign_State.sortOrder[contextKey], value)
	end
end

-- Initialize a sort order for a context by capturing the current alphabetical order.
function AngryAssign:InitSortOrder(contextKey)
	if AngryAssign_State.sortOrder[contextKey] then
		return AngryAssign_State.sortOrder[contextKey]
	end

	local items = {}
	if contextKey == "root" then
		for _, cat in pairs(AngryAssign_Categories) do
			if not cat.CategoryId then
				table.insert(items, { value = -cat.Id, name = cat.Name })
			end
		end
		for _, page in pairs(AngryAssign_Pages) do
			if not page.CategoryId then
				table.insert(items, { value = page.Id, name = page.Name })
			end
		end
	else
		for _, cat in pairs(AngryAssign_Categories) do
			if cat.CategoryId == contextKey then
				table.insert(items, { value = -cat.Id, name = cat.Name })
			end
		end
		for _, page in pairs(AngryAssign_Pages) do
			if page.CategoryId == contextKey then
				table.insert(items, { value = page.Id, name = page.Name })
			end
		end
	end

	table.sort(items, function(a, b) return a.name < b.name end)

	local order = {}
	for _, item in ipairs(items) do
		table.insert(order, item.value)
	end

	AngryAssign_State.sortOrder[contextKey] = order
	return order
end

--------------------------------------
-- Drag-and-Drop Handling           --
--------------------------------------

function AngryAssign:ValidateDrop(sourceValue, sourceUniqueValue, targetValue, targetUniqueValue, zone)
	-- Check if source/target are in virtual contexts (Displayed, Shared, Templates)
	local sourceRoot = GetRootValue(sourceUniqueValue)
	local targetRoot = GetRootValue(targetUniqueValue)

	-- Can't drag items from virtual contexts
	if self:IsVirtualCategory(sourceRoot) then return false end

	-- Block drops to Displayed/Shared; allow drops into Templates (copy-to-template)
	if targetRoot == DISPLAYED_TREE_VALUE or targetRoot == SHARED_TREE_VALUE then return false end
	if self:IsVirtualCategory(targetRoot) then
		return zone == "into"
	end

	-- Can't drag shared pages
	if sourceValue > 0 then
		local sp = AngryAssign_Pages[sourceValue]
		if sp and sp.CategoryId == SHARED_CATEGORY_ID then return false end
	end

	-- Can't drag template pages
	if sourceValue > 0 and self:IsTemplatePage(sourceValue) then return false end

	-- For "into" zone, target must be a category (negative value)
	if zone == "into" and targetValue >= 0 then return false end

	-- Can't drop a category into itself or its descendants
	if sourceValue < 0 and targetValue < 0 and zone == "into" then
		local sourceCatId = -sourceValue
		local targetCatId = -targetValue
		local id = targetCatId
		while id do
			if id == sourceCatId then return false end
			local c = AngryAssign_Categories[id]
			id = c and c.CategoryId or nil
		end
	end

	return true
end

function AngryAssign:HandleDrop(sourceValue, sourceUniqueValue, targetValue, targetUniqueValue, zone)
	if not self:ValidateDrop(sourceValue, sourceUniqueValue, targetValue, targetUniqueValue, zone) then
		return
	end

	-- Copy-to-template action
	local targetRoot = GetRootValue(targetUniqueValue)
	if targetRoot and self:IsVirtualCategory(targetRoot) then
		self:CopyToUserTemplate(sourceValue)
		return
	end

	local sourceIsPage = sourceValue > 0

	-- Determine source context
	local sourceContextKey
	if sourceIsPage then
		local page = AngryAssign_Pages[sourceValue]
		sourceContextKey = (page and page.CategoryId) or "root"
	else
		local cat = AngryAssign_Categories[-sourceValue]
		sourceContextKey = (cat and cat.CategoryId) or "root"
	end

	if zone == "into" then
		-- Drop into a category
		local targetCatId = -targetValue

		-- Move source to target category
		if sourceIsPage then
			AngryAssign_Pages[sourceValue].CategoryId = targetCatId
		else
			AngryAssign_Categories[-sourceValue].CategoryId = targetCatId
		end

		-- Update sort orders
		self:RemoveFromSortOrder(sourceContextKey, sourceValue)
		local targetOrder = self:InitSortOrder(targetCatId)
		table.insert(targetOrder, sourceValue)

		-- Expand target category in tree
		if AngryAssign_State.tree.groups then
			AngryAssign_State.tree.groups[targetUniqueValue] = true
		end
	else
		-- above or below: reorder within or across contexts

		-- Determine target context
		local targetContextKey
		if targetValue > 0 then
			local page = AngryAssign_Pages[targetValue]
			targetContextKey = (page and page.CategoryId) or "root"
		else
			local cat = AngryAssign_Categories[-targetValue]
			targetContextKey = (cat and cat.CategoryId) or "root"
		end

		-- If moving between contexts, update CategoryId
		if sourceContextKey ~= targetContextKey then
			local newCatId = (targetContextKey == "root") and nil or targetContextKey
			if sourceIsPage then
				AngryAssign_Pages[sourceValue].CategoryId = newCatId
			else
				AngryAssign_Categories[-sourceValue].CategoryId = newCatId
			end
		end

		-- Remove from old context sort order
		self:RemoveFromSortOrder(sourceContextKey, sourceValue)

		-- Initialize target sort order if needed and find insertion point
		local targetOrder = self:InitSortOrder(targetContextKey)
		local insertIdx = #targetOrder + 1
		for i, val in ipairs(targetOrder) do
			if val == targetValue then
				if zone == "below" then
					insertIdx = i + 1
				else -- above
					insertIdx = i
				end
				break
			end
		end

		table.insert(targetOrder, insertIdx, sourceValue)
	end

	-- Rebuild tree and re-select
	local selectedId = self:SelectedId()
	self:UpdateTree()
	if selectedId then
		self:SetSelectedId(selectedId)
	end
end

function AngryAssign:UpdateContents(id, value)
	if self:IsTemplatePage(id) then return end
	if not self:PermissionCheck() then return end
	local page = self:Get(id)
	if not page then return end

	local new_content = value:gsub('^%s+', ''):gsub('%s+$', '')
	local contents_updated = new_content ~= page.Contents
	page.Contents = new_content
	page.Backup = new_content
	page.Updated = time()
	page.UpdateId = self:Hash(page.Name, page.Contents)
	page.ContentHash = LibDeflate:Adler32(page.Contents)

	self:SendPage(id, true)
	self:UpdateSelected(true)
	if AngryAssign_State.displayed == id then
		self:UpdateDisplayed()
		self:ShowDisplay()
		if contents_updated then self:DisplayUpdateNotification() end
	end
end

function AngryAssign:CreateBackup()
	for _, page in pairs(AngryAssign_Pages) do
		page.Backup = page.Contents
	end
	self:UpdateSelected()
end

function AngryAssign:ClearDisplayed()
	AngryAssign_State.displayed = nil
	AngryAssign_State.currentPage = 1
	self:UpdateDisplayed()
	self:HideDisplay()
	self:UpdateTree()
	self:SendMessage("ANGRY_ASSIGNMENTS_UPDATE")
end

----------------------------------
-- Sharing                     --
----------------------------------

function AngryAssign:IsVirtualCategory(treeValue)
	return treeValue == DISPLAYED_TREE_VALUE or treeValue == SHARED_TREE_VALUE
		or (ns.TEMPLATE_TREE_VALUES and ns.TEMPLATE_TREE_VALUES[treeValue])
end

function AngryAssign:HasContentHash(contents)
	local hash = LibDeflate:Adler32(contents)
	for _, page in pairs(AngryAssign_Pages) do
		if page.ContentHash and page.ContentHash == hash then
			return true
		end
	end
	return false
end

function AngryAssign:GetCategoryPages(catId)
	local result = {}
	for _, page in pairs(AngryAssign_Pages) do
		if page.CategoryId == catId then
			table.insert(result, page)
		end
	end
	for _, cat in pairs(AngryAssign_Categories) do
		if cat.CategoryId == catId then
			local subPages = self:GetCategoryPages(cat.Id)
			for _, p in ipairs(subPages) do
				table.insert(result, p)
			end
		end
	end
	return result
end

function AngryAssign:SharePage(pageId)
	if not self:PermissionCheck() then
		self:Print(RED_FONT_COLOR_CODE .. "You don't have permission to share pages.|r")
		return
	end
	if not (IsInRaid() or IsInGroup()) then
		self:Print(RED_FONT_COLOR_CODE .. "You must be in a group to share pages.|r")
		return
	end
	local page = AngryAssign_Pages[pageId]
	if not page then return end
	self:SendSharePage(pageId)
	self:Print("Shared page: " .. page.Name)
end

function AngryAssign:ShareCategory(catId)
	if not self:PermissionCheck() then
		self:Print(RED_FONT_COLOR_CODE .. "You don't have permission to share pages.|r")
		return
	end
	if not (IsInRaid() or IsInGroup()) then
		self:Print(RED_FONT_COLOR_CODE .. "You must be in a group to share pages.|r")
		return
	end
	local pages = self:GetCategoryPages(catId)
	if #pages == 0 then
		self:Print("No pages to share in this category.")
		return
	end
	for i, page in ipairs(pages) do
		self:ScheduleTimer("SendSharePage", (i - 1) * 0.5, page.Id)
	end
	self:Print("Sharing " .. #pages .. " page(s) from category.")
end

---------------------------------
-- Public API (for WeakAuras) --
---------------------------------

function AngryAssign:GetDisplayedPage()
	local id = AngryAssign_State.displayed
	if id then
		return self:Get(id)
	end
end

function AngryAssign:GetDisplayedPageContent()
	local page = self:GetDisplayedPage()
	if page then return page.Contents end
end

function AngryAssign:DisplayPageByName( name )
	for _, page in pairs(AngryAssign_Pages) do
		if page.Name == name then
			return self:DisplayPage( page.Id )
		end
	end
	return false
end

function AngryAssign:DisplayPage( id )
	if not self:PermissionCheck() then return end

	self:TouchPage( id )
	if not self:IsTemplatePage(id) then
		self:SendPage( id, true )
		self:SendDisplay( id, true )
	end

	if AngryAssign_State.displayed ~= id then
		AngryAssign_State.displayed = id
		AngryAssign_State.currentPage = 1
		AngryAssign:UpdateTree()
		AngryAssign:DisplayUpdateNotification()
	end

	AngryAssign:UpdateDisplayed()
	AngryAssign:ShowDisplay()

	self:SendMessage("ANGRY_ASSIGNMENTS_UPDATE")
	return true
end
