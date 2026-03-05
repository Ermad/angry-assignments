local _, ns = ...
local AngryAssign = LibStub("AceAddon-3.0"):GetAddon("AngryAssignments")

local AceGUI = LibStub("AceGUI-3.0")

local SHARED_CATEGORY_ID = ns.SHARED_CATEGORY_ID

--------------------------------------
-- Tooltip helpers                  --
--------------------------------------

local function SetTooltip(widget, text)
	widget.frame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(widget.frame, "ANCHOR_RIGHT")
		GameTooltip:SetText(text, 1, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	widget.frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
end

local function InsertVarToken(key)
	local id = AngryAssign:SelectedId()
	if not id or id < 0 then return end
	if AngryAssign.window and AngryAssign.window.text then
		local editBox = AngryAssign.window.text.editBox
		editBox:SetFocus()
		editBox:Insert("{$" .. key .. "}")
		AngryAssign.window.text.button:Enable()
		AngryAssign.window.button_revert:SetDisabled(false)
		AngryAssign.window.button_restore:SetDisabled(false)
		AngryAssign.window.button_display:SetDisabled(true)
		AngryAssign.window.button_output:SetDisabled(true)
	end
end

--------------------------------------
-- Build variables section into     --
-- the combined side panel container--
--------------------------------------

function AngryAssign:BuildVariablesSection(container)
	local heading = AceGUI:Create("Heading")
	heading:SetText("Variables")
	heading:SetFullWidth(true)
	container:AddChild(heading)

	local selectedId = self:SelectedId()
	if not selectedId then
		self:VarPanel_AddLabel(container, "|cff808080Select a page or category|r")
		return
	end

	if selectedId < 0 then
		-- Category selected
		local catId = -selectedId
		if self:IsVirtualCategory(selectedId) then
			self:VarPanel_AddLabel(container, "|cff808080Variables not available for this section|r")
			return
		end
		self:BuildCategoryVariablesUI(container, catId)
	else
		-- Page selected
		if self:IsTemplatePage(selectedId) then
			self:VarPanel_AddLabel(container, "|cff808080Variables not available for templates|r")
			return
		end
		local page = self:Get(selectedId)
		if not page then
			self:VarPanel_AddLabel(container, "|cff808080No page selected|r")
			return
		end
		self:BuildPageVariablesUI(container, selectedId, page)
	end
end

--------------------------------------
-- Helper: add a label widget       --
--------------------------------------

function AngryAssign:VarPanel_AddLabel(content, text)
	local label = AceGUI:Create("Label")
	label:SetText(text)
	label:SetFullWidth(true)
	content:AddChild(label)
end

--------------------------------------
-- Category variables UI            --
--------------------------------------

function AngryAssign:BuildCategoryVariablesUI(content, catId)
	local cat = AngryAssign_Categories[catId]
	if not cat then return end

	-- Scan child pages for used variable tokens
	local vars = AngryAssign_Variables.categories[catId] or {}
	local usedVars = self:ScanCategoryVariableTokens(catId)

	-- Merge defined + used into sorted key list
	local allKeys = self:VarPanel_MergeKeys(vars, usedVars)

	if #allKeys == 0 then
		self:VarPanel_AddLabel(content, "|cff808080No variables defined or used.\nUse {$name} tokens in pages.|r")
	end

	-- Editable rows for each variable
	for _, key in ipairs(allKeys) do
		self:VarPanel_AddEditRow(content, key, vars[key], not vars[key], function(value)
			if not AngryAssign_Variables.categories[catId] then
				AngryAssign_Variables.categories[catId] = {}
			end
			if value == "" then
				AngryAssign_Variables.categories[catId][key] = nil
			else
				AngryAssign_Variables.categories[catId][key] = value
			end
			local displayedPage = self:Get(AngryAssign_State.displayed)
			if displayedPage and self:PageBelongsToCategory(AngryAssign_State.displayed, catId) then
				self:UpdateDisplayed()
			end
		end, function()
			-- Full delete: remove from storage + strip token from all category pages
			if AngryAssign_Variables.categories[catId] then
				AngryAssign_Variables.categories[catId][key] = nil
			end
			self:StripVariableToken(key, self:GetCategoryPages(catId))
			local displayedPage = self:Get(AngryAssign_State.displayed)
			if displayedPage and self:PageBelongsToCategory(AngryAssign_State.displayed, catId) then
				self:UpdateDisplayed()
			end
		end)
	end

	-- Add new variable row
	self:VarPanel_AddNewVarRow(content, function(key, value)
		if not AngryAssign_Variables.categories[catId] then
			AngryAssign_Variables.categories[catId] = {}
		end
		AngryAssign_Variables.categories[catId][key] = value
		self:RefreshSidePanel()
		local displayedPage = self:Get(AngryAssign_State.displayed)
		if displayedPage and self:PageBelongsToCategory(AngryAssign_State.displayed, catId) then
			self:UpdateDisplayed()
		end
	end)
end

--------------------------------------
-- Page variables UI                --
--------------------------------------

function AngryAssign:BuildPageVariablesUI(content, pageId, page)
	-- Section 1: Inherited category variables (read-only)
	local catId = page.CategoryId
	if catId and catId ~= SHARED_CATEGORY_ID then
		local catVars = self:GetMergedCategoryVars(catId)
		if next(catVars) then
			local sortedKeys = {}
			for k in pairs(catVars) do table.insert(sortedKeys, k) end
			table.sort(sortedKeys)

			local inheritLabel = AceGUI:Create("Label")
			inheritLabel:SetText("|cffaaaaaa  Inherited from category:|r")
			inheritLabel:SetFullWidth(true)
			content:AddChild(inheritLabel)

			for _, key in ipairs(sortedKeys) do
				local inheritRow = AceGUI:Create("InteractiveLabel")
				inheritRow:SetText(format("  |cff00cc00{$%s}|r = |cffaaaaaa%s|r", key, catVars[key]))
				inheritRow:SetFullWidth(true)
				inheritRow:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight")
				inheritRow:SetCallback("OnClick", function() InsertVarToken(key) end)
				SetTooltip(inheritRow, "Click to insert {$" .. key .. "}\nInherited from category — edit on the category")
				content:AddChild(inheritRow)
			end
		end
	end

	-- Section 2: Page variables (editable)
	-- Exclude tokens already covered by inherited category variables (unless page has its own override)
	local inheritedKeys = {}
	if catId and catId ~= SHARED_CATEGORY_ID then
		for k in pairs(self:GetMergedCategoryVars(catId)) do
			inheritedKeys[k:lower()] = true
		end
	end
	local pageVars = AngryAssign_Variables.pages[pageId] or {}
	local usedVars = self:ScanPageVariableTokens(pageId)
	for k in pairs(inheritedKeys) do
		if not pageVars[k] then
			usedVars[k] = nil
		end
	end
	local allKeys = self:VarPanel_MergeKeys(pageVars, usedVars)

	if #allKeys == 0 then
		self:VarPanel_AddLabel(content, "|cff808080No page variables.\nUse {$name} tokens in content.|r")
	end

	for _, key in ipairs(allKeys) do
		self:VarPanel_AddEditRow(content, key, pageVars[key], not pageVars[key], function(value)
			if not AngryAssign_Variables.pages[pageId] then
				AngryAssign_Variables.pages[pageId] = {}
			end
			if value == "" then
				AngryAssign_Variables.pages[pageId][key] = nil
			else
				AngryAssign_Variables.pages[pageId][key] = value
			end
			if AngryAssign_State.displayed == pageId then
				self:UpdateDisplayed()
			end
		end, function()
			-- Full delete: remove from storage + strip token from this page
			if AngryAssign_Variables.pages[pageId] then
				AngryAssign_Variables.pages[pageId][key] = nil
			end
			local p = AngryAssign_Pages[pageId]
			if p then
				self:StripVariableToken(key, { p })
			end
			if AngryAssign_State.displayed == pageId then
				self:UpdateDisplayed()
			end
		end)
	end

	-- Add new variable row
	self:VarPanel_AddNewVarRow(content, function(key, value)
		if not AngryAssign_Variables.pages[pageId] then
			AngryAssign_Variables.pages[pageId] = {}
		end
		AngryAssign_Variables.pages[pageId][key] = value
		self:RefreshSidePanel()
		if AngryAssign_State.displayed == pageId then
			self:UpdateDisplayed()
		end
	end)
end

--------------------------------------
-- Shared UI helpers                --
--------------------------------------

-- Merge defined variable keys and used token keys into a sorted list.
function AngryAssign:VarPanel_MergeKeys(definedVars, usedTokens)
	local keySet = {}
	local allKeys = {}
	for k in pairs(definedVars) do
		local lower = k:lower()
		if not keySet[lower] then
			table.insert(allKeys, lower)
			keySet[lower] = true
		end
	end
	for k in pairs(usedTokens) do
		if not keySet[k] then
			table.insert(allKeys, k)
			keySet[k] = true
		end
	end
	table.sort(allKeys)
	return allKeys
end

-- Add an editable row: {$key} = [editbox] [X]
function AngryAssign:VarPanel_AddEditRow(content, key, currentValue, isUndefined, onChange, onDelete)
	local row = AceGUI:Create("SimpleGroup")
	row:SetLayout("Flow")
	row:SetFullWidth(true)

	local keyLabel = AceGUI:Create("InteractiveLabel")
	local labelText
	if isUndefined then
		labelText = "|cff00cc00{$" .. key .. "}|r |cffff8800(no value — used in content)|r"
	else
		labelText = "|cff00cc00{$" .. key .. "}|r ="
	end
	keyLabel:SetText(labelText)
	keyLabel:SetWidth(isUndefined and 300 or 140)
	keyLabel:SetHighlight("Interface\\QuestFrame\\UI-QuestTitleHighlight")
	keyLabel:SetCallback("OnClick", function() InsertVarToken(key) end)
	if isUndefined then
		SetTooltip(keyLabel, "Click to insert {$" .. key .. "}\nShows because {$" .. key .. "} is used in the page text but has no value assigned")
	else
		SetTooltip(keyLabel, "Click to insert {$" .. key .. "}")
	end
	row:AddChild(keyLabel)

	if not isUndefined then
		local valueBox = AceGUI:Create("EditBox")
		valueBox:SetText(currentValue or "")
		valueBox:SetWidth(180)
		valueBox:DisableButton(false)
		valueBox:SetCallback("OnEnterPressed", function(_, _, value)
			onChange(value)
		end)
		row:AddChild(valueBox)
	end

	local delBtn = AceGUI:Create("InteractiveLabel")
	delBtn:SetText("|cffff4444X|r")
	delBtn:SetWidth(20)
	delBtn:SetCallback("OnClick", function()
		onDelete()
		AngryAssign:RefreshSidePanel()
	end)
	if isUndefined then
		SetTooltip(delBtn, "Remove {$" .. key .. "} from page content")
	else
		SetTooltip(delBtn, "Delete variable and remove {$" .. key .. "} from page content")
	end
	row:AddChild(delBtn)

	content:AddChild(row)
end

-- Add a "new variable" row with name + value fields.
function AngryAssign:VarPanel_AddNewVarRow(content, onAdd)
	local row = AceGUI:Create("SimpleGroup")
	row:SetLayout("Flow")
	row:SetFullWidth(true)

	local newKeyBox = AceGUI:Create("EditBox")
	newKeyBox:SetLabel("New variable")
	newKeyBox:SetWidth(120)
	newKeyBox:DisableButton(true)
	row:AddChild(newKeyBox)

	local newValueBox = AceGUI:Create("EditBox")
	newValueBox:SetLabel("Value")
	newValueBox:SetWidth(160)
	newValueBox:SetCallback("OnEnterPressed", function(_, _, value)
		local key = newKeyBox:GetText()
		if not key or key == "" then return end
		key = key:lower():gsub("%s+", "_")
		onAdd(key, value)
	end)
	row:AddChild(newValueBox)

	content:AddChild(row)
end
