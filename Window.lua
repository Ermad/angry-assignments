local _, ns = ...
local AngryAssign = LibStub("AceAddon-3.0"):GetAddon("AngryAssignments")

local AceGUI = LibStub("AceGUI-3.0")

local EasyMenu = ns.EasyMenu
local selectedLastValue = ns.selectedLastValue

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

-- Helper to find the edit box in a StaticPopup dialog across WoW versions.
-- In patch 11.2+, dialog.editBox (lowercase) became nil; the edit box is
-- accessible via dialog.EditBox (capitalized) or the global frame name.
local function GetDialogEditBox(dialog)
	return dialog.editBox or dialog.EditBox
		or (dialog.GetName and dialog:GetName() and _G[dialog:GetName().."EditBox"])
end

local function AngryAssign_AddPage(widget, event, value)
	local popup_name = "AngryAssign_AddPage"
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				local eb = GetDialogEditBox(self)
				local text = eb and eb:GetText() or ""
				if text ~= "" then AngryAssign:CreatePage(text) end
			end,
			EditBoxOnEnterPressed = function(self)
				local eb = GetDialogEditBox(self:GetParent())
				local text = eb and eb:GetText() or ""
				if text ~= "" then AngryAssign:CreatePage(text) end
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

local function AngryAssign_RenamePage(pageId)
	local page = AngryAssign:Get(pageId)
	if not page then return end

	local popup_name = "AngryAssign_RenamePage_"..page.Id
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				local eb = GetDialogEditBox(self)
				local text = eb and eb:GetText() or ""
				AngryAssign:RenamePage(page.Id, text)
			end,
			EditBoxOnEnterPressed = function(self)
				local eb = GetDialogEditBox(self:GetParent())
				local text = eb and eb:GetText() or ""
				AngryAssign:RenamePage(page.Id, text)
				self:GetParent():Hide()
			end,
			OnShow = function(self)
				local eb = GetDialogEditBox(self)
				if eb then eb:SetText(page.Name) end
			end,
			whileDead = true,
			hasEditBox = true,
			EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopupDialogs[popup_name].text = 'Rename page "'.. page.Name ..'" to:'

	StaticPopup_Show(popup_name)
end

local function AngryAssign_DeletePage(pageId)
	local page = AngryAssign:Get(pageId)
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

local function AngryAssign_AddCategory(widget, event, value)
	local popup_name = "AngryAssign_AddCategory"
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				local eb = GetDialogEditBox(self)
				local text = eb and eb:GetText() or ""
				if text ~= "" then AngryAssign:CreateCategory(text) end
			end,
			EditBoxOnEnterPressed = function(self)
				local eb = GetDialogEditBox(self:GetParent())
				local text = eb and eb:GetText() or ""
				if text ~= "" then AngryAssign:CreateCategory(text) end
				self:GetParent():Hide()
			end,
			text = "New category name:",
			hasEditBox = true,
			whileDead = true,
			EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopup_Show(popup_name)
end

local function AngryAssign_RenameCategory(catId)
	local cat = AngryAssign:GetCat(catId)
	if not cat then return end

	local popup_name = "AngryAssign_RenameCategory_"..cat.Id
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				local eb = GetDialogEditBox(self)
				local text = eb and eb:GetText() or ""
				AngryAssign:RenameCategory(cat.Id, text)
			end,
			EditBoxOnEnterPressed = function(self)
				local eb = GetDialogEditBox(self:GetParent())
				local text = eb and eb:GetText() or ""
				AngryAssign:RenameCategory(cat.Id, text)
				self:GetParent():Hide()
			end,
			OnShow = function(self)
				local eb = GetDialogEditBox(self)
				if eb then eb:SetText(cat.Name) end
			end,
			whileDead = true,
			hasEditBox = true,
			EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopupDialogs[popup_name].text = 'Rename category "'.. cat.Name ..'" to:'

	StaticPopup_Show(popup_name)
end

local function AngryAssign_DeleteCategory(catId)
	local cat = AngryAssign:GetCat(catId)
	if not cat then return end

	local popup_name = "AngryAssign_DeleteCategory_"..cat.Id
	if StaticPopupDialogs[popup_name] == nil then
		StaticPopupDialogs[popup_name] = {
			button1 = OKAY,
			button2 = CANCEL,
			OnAccept = function(self)
				AngryAssign:DeleteCategory(cat.Id)
			end,
			whileDead = true,
			hideOnEscape = true,
			preferredIndex = 3
		}
	end
	StaticPopupDialogs[popup_name].text = 'Are you sure you want to delete category "'.. cat.Name ..'"?'

	StaticPopup_Show(popup_name)
end

local function AngryAssign_AssignCategory(frame, entryId, catId)
	HideDropDownMenu(1)

	AngryAssign:AssignCategory(entryId, catId)
end

local function AngryAssign_RevertPage(widget, event, value)
	if not AngryAssign.window then return end
	AngryAssign:UpdateSelected(true)
end

local function AngryAssign_DisplayPage(widget, event, value)
	if not AngryAssign:PermissionCheck() then return end
	local id = AngryAssign:SelectedId()
	AngryAssign:DisplayPage( id )
end

local function AngryAssign_ClearPage(widget, event, value)
	if not AngryAssign:PermissionCheck() then return end

	AngryAssign:ClearDisplayed()
	AngryAssign:SendDisplay( nil, true )
end

local function AngryAssign_TextChanged(widget, event, value)
	AngryAssign.window.button_revert:SetDisabled(false)
	AngryAssign.window.button_restore:SetDisabled(false)
	AngryAssign.window.button_display:SetDisabled(true)
	AngryAssign.window.button_output:SetDisabled(true)
end

local function AngryAssign_TextEntered(widget, event, value)
	AngryAssign:UpdateContents(AngryAssign:SelectedId(), value)
end

local function AngryAssign_RestorePage(widget, event, value)
	if not AngryAssign.window then return end
	local page = AngryAssign_Pages[AngryAssign:SelectedId()]
	if not page or not page.Backup then return end

	AngryAssign.window.text:SetText( page.Backup )
	AngryAssign.window.text.button:Enable()
	AngryAssign_TextChanged(widget, event, value)
end

local function AngryAssign_CategoryMenuList(entryId, parentId)
	local categories = {}

	local checkedId
	if entryId > 0 then
		local page = AngryAssign_Pages[entryId]
		checkedId = page.CategoryId
	else
		local cat = AngryAssign_Categories[-entryId]
		checkedId = cat.CategoryId
	end

	for _, cat in pairs(AngryAssign_Categories) do
		if cat.Id ~= -entryId and (parentId or not cat.CategoryId) and (not parentId or cat.CategoryId == parentId) then
			local subMenu = AngryAssign_CategoryMenuList(entryId, cat.Id)
			table.insert(categories, { text = cat.Name, value = cat.Id, menuList = subMenu, hasArrow = (subMenu ~= nil), checked = (checkedId == cat.Id), func = AngryAssign_AssignCategory, arg1 = entryId, arg2 = cat.Id })
		end
	end

	table.sort(categories, function(a,b) return a.text < b.text end)

	if #categories > 0 then
		return categories
	end
end

local PagesDropDownList
function AngryAssign_PageMenu(pageId)
	local page = AngryAssign_Pages[pageId]
	if not page then return end

	if not PagesDropDownList then
		PagesDropDownList = {
			{ notCheckable = true, isTitle = true },
			{ text = "Rename", notCheckable = true, func = function(frame, pageId) AngryAssign_RenamePage(pageId) end },
			{ text = "Delete", notCheckable = true, func = function(frame, pageId) AngryAssign_DeletePage(pageId) end },
			{ text = "Duplicate", notCheckable = true, func = function(frame, pageId) AngryAssign:DuplicatePage(pageId) end },
			{ text = "Share", notCheckable = true, func = function(frame, pageId) AngryAssign:SharePage(pageId) end },
			{ text = "Category", notCheckable = true, hasArrow = true },
		}
	end

	local permission = AngryAssign:PermissionCheck()
	local inGroup = IsInRaid() or IsInGroup()

	PagesDropDownList[1].text = page.Name
	PagesDropDownList[2].arg1 = pageId
	PagesDropDownList[2].disabled = not permission
	PagesDropDownList[3].arg1 = pageId
	PagesDropDownList[4].arg1 = pageId
	PagesDropDownList[4].disabled = not permission
	PagesDropDownList[5].arg1 = pageId
	PagesDropDownList[5].disabled = not permission or not inGroup

	local categories = AngryAssign_CategoryMenuList(pageId)
	if categories ~= nil then
		PagesDropDownList[6].menuList = categories
		PagesDropDownList[6].disabled = false
	else
		PagesDropDownList[6].menuList = {}
		PagesDropDownList[6].disabled = true
	end

	return PagesDropDownList
end

local CategoriesDropDownList
local function AngryAssign_CategoryMenu(catId)
	local cat = AngryAssign_Categories[catId]
	if not cat then return end

	if not CategoriesDropDownList then
		CategoriesDropDownList = {
			{ notCheckable = true, isTitle = true },
			{ text = "Rename", notCheckable = true, func = function(frame, catId) AngryAssign_RenameCategory(catId) end },
			{ text = "Delete", notCheckable = true, func = function(frame, catId) AngryAssign_DeleteCategory(catId) end },
			{ text = "Share All Pages", notCheckable = true, func = function(frame, catId) AngryAssign:ShareCategory(catId) end },
			{ text = "Category", notCheckable = true, hasArrow = true },
		}
	end

	local permission = AngryAssign:PermissionCheck()
	local inGroup = IsInRaid() or IsInGroup()

	CategoriesDropDownList[1].text = cat.Name
	CategoriesDropDownList[2].arg1 = catId
	CategoriesDropDownList[3].arg1 = catId
	CategoriesDropDownList[4].arg1 = catId
	CategoriesDropDownList[4].disabled = not permission or not inGroup

	local categories = AngryAssign_CategoryMenuList(-catId)
	if categories ~= nil then
		CategoriesDropDownList[5].menuList = categories
		CategoriesDropDownList[5].disabled = false
	else
		CategoriesDropDownList[5].menuList = {}
		CategoriesDropDownList[5].disabled = true
	end

	return CategoriesDropDownList
end

local TemplatePageDropDownList
local function AngryAssign_TemplatePageMenu(pageId)
	local page = AngryAssign:GetTemplatePage(pageId)
	if not page then return end

	if not TemplatePageDropDownList then
		TemplatePageDropDownList = {
			{ notCheckable = true, isTitle = true },
			{ text = "Duplicate", notCheckable = true, func = function(_, id) AngryAssign:DuplicatePage(id) end },
		}
	end

	local permission = AngryAssign:PermissionCheck()
	TemplatePageDropDownList[1].text = page.Name .. " (Template)"
	TemplatePageDropDownList[2].arg1 = pageId
	TemplatePageDropDownList[2].disabled = not permission

	return TemplatePageDropDownList
end

local TemplateCatDropDownList
local function AngryAssign_TemplateCategoryMenu(catTreeValue)
	local catName = ns.templateCatNames[catTreeValue]
	if not catName then return end

	if not TemplateCatDropDownList then
		TemplateCatDropDownList = {
			{ notCheckable = true, isTitle = true },
			{ text = "Duplicate All", notCheckable = true, func = function(_, tv) AngryAssign:DuplicateTemplateCategory(tv) end },
		}
	end

	local permission = AngryAssign:PermissionCheck()
	TemplateCatDropDownList[1].text = catName .. " (Template)"
	TemplateCatDropDownList[2].arg1 = catTreeValue
	TemplateCatDropDownList[2].disabled = not permission

	return TemplateCatDropDownList
end

local AngryAssign_DropDown
local function AngryAssign_TreeClick(widget, event, value, selected, button)
	HideDropDownMenu(1)
	local selectedId = selectedLastValue(value)
	if AngryAssign:IsVirtualCategory(selectedId) then
		if button == "RightButton" and AngryAssign:IsTemplateCategory(selectedId) then
			if not AngryAssign_DropDown then
				AngryAssign_DropDown = CreateFrame("Frame", "AngryAssignMenuFrame", UIParent, "UIDropDownMenuTemplate")
			end
			EasyMenu(AngryAssign_TemplateCategoryMenu(selectedId), AngryAssign_DropDown, "cursor", 0, 0, "MENU")
		elseif button ~= "RightButton" then
			local status = (widget.status or widget.localstatus).groups
			status[value] = not status[value]
			widget:RefreshTree()
		end
		return false
	end
	if selectedId < 0 then
		if button == "RightButton" then
			if not AngryAssign_DropDown then
				AngryAssign_DropDown = CreateFrame("Frame", "AngryAssignMenuFrame", UIParent, "UIDropDownMenuTemplate")
			end
			EasyMenu(AngryAssign_CategoryMenu(-selectedId), AngryAssign_DropDown, "cursor", 0 , 0, "MENU")

		else
			local status = (widget.status or widget.localstatus).groups
			status[value] = not status[value]
			widget:RefreshTree()
		end
		return false
	else
		if button == "RightButton" then
			if not AngryAssign_DropDown then
				AngryAssign_DropDown = CreateFrame("Frame", "AngryAssignMenuFrame", UIParent, "UIDropDownMenuTemplate")
			end
			-- Template pages get a restricted menu (Duplicate only)
			if AngryAssign:IsTemplatePage(selectedId) then
				EasyMenu(AngryAssign_TemplatePageMenu(selectedId), AngryAssign_DropDown, "cursor", 0, 0, "MENU")
			else
				EasyMenu(AngryAssign_PageMenu(selectedId), AngryAssign_DropDown, "cursor", 0 , 0, "MENU")
			end

			return false
		end
	end
end

function AngryAssign:CreateWindow()
	local window = AceGUI:Create("Frame")
	window:SetTitle("Angry Assignments+")
	window:SetLayout("Flow")
	if AngryAssign:GetConfig('scale') then window.frame:SetScale( AngryAssign:GetConfig('scale') ) end
	window:SetStatusTable(AngryAssign_State.window)
	window:Hide()
	AngryAssign.window = window

	AngryAssign_Window = window.frame
	if window.frame.SetResizeBounds then -- WoW 10.0+
		window.frame:SetResizeBounds(700, 400)
	elseif window.frame.SetMinResize then
		window.frame:SetMinResize(700, 400)
	end
	window.frame:SetFrameStrata("HIGH")
	window.frame:SetFrameLevel(1)
	window.frame:SetClampedToScreen(true)
	-- Not added to UISpecialFrames — prevents CloseAllWindows() from hiding
	-- the window when the Blizzard Settings panel opens (e.g. /aa config).
	-- The window has its own close button and can be toggled with /aa.

	local tree = AceGUI:Create("AngryTreeGroup")
	tree.treeTopOffset = -32
	tree:SetTree( self:GetTree() )
	tree:SelectByValue(1)
	tree:SetStatusTable(AngryAssign_State.tree)
	tree:SetFullWidth(true)
	tree:SetFullHeight(true)
	tree:SetLayout("Flow")
	tree:SetCallback("OnGroupSelected", function(widget, event, value) AngryAssign:UpdateSelected(true) end)
	tree:SetCallback("OnClick", AngryAssign_TreeClick)
	window:AddChild(tree)
	window.tree = tree

	local searchBox = CreateFrame("EditBox", nil, tree.treeframe, "SearchBoxTemplate")
	searchBox:SetHeight(20)
	searchBox:SetPoint("TOPLEFT", tree.treeframe, "TOPLEFT", 12, -6)
	searchBox:SetPoint("TOPRIGHT", tree.treeframe, "TOPRIGHT", -12, -6)
	searchBox:SetAutoFocus(false)

	searchBox:HookScript("OnTextChanged", function(box)
		local query = box:GetText()
		if query == "" then
			AngryAssign.searchFilter = nil
		else
			AngryAssign.searchFilter = query:lower()
		end
		AngryAssign:UpdateTree()
	end)
	searchBox:HookScript("OnEscapePressed", function(box)
		box:SetText("")
	end)

	local text = AceGUI:Create("MultiLineEditBox")
	text:SetLabel(nil)
	text:SetFullWidth(true)
	text:SetFullHeight(true)
	text:SetCallback("OnTextChanged", AngryAssign_TextChanged)
	text:SetCallback("OnEnterPressed", AngryAssign_TextEntered)
	tree:AddChild(text)
	window.text = text
	text.button:SetWidth(75)
	local buttontext = text.button:GetFontString()
	buttontext:ClearAllPoints()
	buttontext:SetPoint("TOPLEFT", text.button, "TOPLEFT", 15, -1)
	buttontext:SetPoint("BOTTOMRIGHT", text.button, "BOTTOMRIGHT", -15, 1)

	tree:PauseLayout()
	local button_display = AceGUI:Create("Button")
	button_display:SetText("Send and Display")
	button_display:SetWidth(140)
	button_display:SetHeight(22)
	button_display:ClearAllPoints()
	button_display:SetPoint("BOTTOMRIGHT", text.frame, "BOTTOMRIGHT", 0, 4)
	button_display:SetCallback("OnClick", AngryAssign_DisplayPage)
	tree:AddChild(button_display)
	window.button_display = button_display

	local button_revert = AceGUI:Create("Button")
	button_revert:SetText("Revert")
	button_revert:SetWidth(80)
	button_revert:SetHeight(22)
	button_revert:ClearAllPoints()
	button_revert:SetDisabled(true)
	button_revert:SetPoint("BOTTOMLEFT", text.button, "BOTTOMRIGHT", 6, 0)
	button_revert:SetCallback("OnClick", AngryAssign_RevertPage)
	tree:AddChild(button_revert)
	window.button_revert = button_revert

	local button_restore = AceGUI:Create("Button")
	button_restore:SetText("Restore")
	button_restore:SetWidth(80)
	button_restore:SetHeight(22)
	button_restore:ClearAllPoints()
	button_restore:SetPoint("LEFT", button_revert.frame, "RIGHT", 6, 0)
	button_restore:SetCallback("OnClick", AngryAssign_RestorePage)
	tree:AddChild(button_restore)
	window.button_restore = button_restore

	local button_output = AceGUI:Create("Button")
	button_output:SetText("Output")
	button_output:SetWidth(80)
	button_output:SetHeight(22)
	button_output:ClearAllPoints()
	button_output:SetPoint("BOTTOMLEFT", button_restore.frame, "BOTTOMRIGHT", 6, 0)
	button_output:SetCallback("OnClick", AngryAssign_OutputDisplayed)
	tree:AddChild(button_output)
	window.button_output = button_output

	window:PauseLayout()
	local button_add = AceGUI:Create("Button")
	button_add:SetText("Add")
	button_add:SetWidth(80)
	button_add:SetHeight(19)
	button_add:ClearAllPoints()
	button_add:SetPoint("BOTTOMLEFT", window.frame, "BOTTOMLEFT", 16, 18)
	button_add:SetCallback("OnClick", AngryAssign_AddPage)
	window:AddChild(button_add)
	window.button_add = button_add

	local button_add_cat = AceGUI:Create("Button")
	button_add_cat:SetText("Add Category")
	button_add_cat:SetWidth(120)
	button_add_cat:SetHeight(19)
	button_add_cat:ClearAllPoints()
	button_add_cat:SetPoint("BOTTOMLEFT", button_add.frame, "BOTTOMRIGHT", 5, 0)
	button_add_cat:SetCallback("OnClick", function() AngryAssign_AddCategory() end)
	window:AddChild(button_add_cat)
	window.button_add_cat = button_add_cat

	local status_text = window.frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	status_text:SetPoint("LEFT", button_add_cat.frame, "RIGHT", 10, 0)
	status_text:SetPoint("RIGHT", window.frame, "RIGHT", -220, 0)
	status_text:SetJustifyH("LEFT")
	status_text:SetTextColor(1, 0.82, 0, 1)
	window.status_text = status_text

	local button_clear = AceGUI:Create("Button")
	button_clear:SetText("Clear")
	button_clear:SetWidth(80)
	button_clear:SetHeight(19)
	button_clear:ClearAllPoints()
	button_clear:SetPoint("BOTTOMRIGHT", window.frame, "BOTTOMRIGHT", -135, 18)
	button_clear:SetCallback("OnClick", AngryAssign_ClearPage)
	window:AddChild(button_clear)
	window.button_clear = button_clear

	local toggle_panel = CreateFrame("Button", nil, window.frame, "UIPanelButtonTemplate")
	toggle_panel:SetSize(80, 20)
	toggle_panel:SetPoint("TOPRIGHT", window.frame, "TOPRIGHT", -20, -10)
	toggle_panel:SetText("Tokens")
	toggle_panel:SetScript("OnClick", function()
		if AngryAssign.tokenpanel and AngryAssign.tokenpanel.frame then
			if AngryAssign.tokenpanel.frame:IsShown() then
				AngryAssign.tokenpanel.frame:Hide()
			else
				AngryAssign.tokenpanel.frame:Show()
			end
		end
	end)
	window.toggle_panel = toggle_panel

	self:UpdateSelected(true)
	self:UpdateMedia()

	self:CreateTokenPanel()
end
