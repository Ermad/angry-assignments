--[[-----------------------------------------------------------------------------
TreeGroup Container
Container that uses a tree control to switch between groups.
-------------------------------------------------------------------------------]]
local Type, Version = "AngryTreeGroup", 3
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then return end

local IsLegion = select(4, GetBuildInfo()) >= 70000

-- Lua APIs
local next, pairs, ipairs, assert, type = next, pairs, ipairs, assert, type
local math_min, math_max, floor = math.min, math.max, floor
local select, tremove, unpack, tconcat = select, table.remove, unpack, table.concat

-- WoW APIs
local CreateFrame, UIParent = CreateFrame, UIParent
local GetCursorPosition, IsMouseButtonDown = GetCursorPosition, IsMouseButtonDown

-- Drag-and-drop constants
local DRAG_THRESHOLD_SQ = 25 -- 5 pixels squared
local DROP_ZONE_EDGE = 0.25  -- top/bottom 25% for above/below zones

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: GameTooltip, FONT_COLOR_CODE_CLOSE

-- Recycling functions
local new, del
do
	local pool = setmetatable({},{__mode='k'})
	function new()
		local t = next(pool)
		if t then
			pool[t] = nil
			return t
		else
			return {}
		end
	end
	function del(t)
		for k in pairs(t) do
			t[k] = nil
		end
		pool[t] = true
	end
end

local DEFAULT_TREE_WIDTH = 175
local DEFAULT_TREE_SIZABLE = true

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]
local function GetButtonUniqueValue(line)
	local parent = line.parent
	if parent and parent.value then
		return GetButtonUniqueValue(parent).."\001"..line.value
	else
		return line.value
	end
end

local function UpdateButton(button, treeline, selected, canExpand, isExpanded)
	local self = button.obj
	local toggle = button.toggle
	local text = treeline.text or ""
	local icon = treeline.icon
	local iconCoords = treeline.iconCoords
	local level = treeline.level
	local value = treeline.value
	local uniquevalue = treeline.uniquevalue
	local disabled = treeline.disabled

	button.treeline = treeline
	button.value = value
	button.uniquevalue = uniquevalue
	if selected then
		button:LockHighlight()
		button.selected = true
	else
		button:UnlockHighlight()
		button.selected = false
	end
	button:GetNormalTexture()
	button.level = level
	if ( level == 1 ) then
		button.text:SetPoint("LEFT", (icon and 16 or 0) + 8, 2)
	else
		button.text:SetPoint("LEFT", (icon and 16 or 0) + 8 * level, 2)
	end

	if disabled then
		button:EnableMouse(false)
		button.text:SetText("|cff808080"..text..FONT_COLOR_CODE_CLOSE)
	else
		button.text:SetText(text)
		button:EnableMouse(true)
	end

	if icon then
		button.icon:SetTexture(icon)
		button.icon:SetPoint("LEFT", 8 * level, (level == 1) and 0 or 1)
	else
		button.icon:SetTexture(nil)
	end

	if iconCoords then
		button.icon:SetTexCoord(unpack(iconCoords))
	else
		button.icon:SetTexCoord(0, 1, 0, 1)
	end

	if canExpand or level == 1 then
		button:SetNormalFontObject("GameFontNormal")
		button:SetHighlightFontObject("GameFontHighlight")
	else
		button:SetNormalFontObject("GameFontHighlight")
		button:SetHighlightFontObject("GameFontHighlight")
	end

	if canExpand then
		if not isExpanded then
			toggle:SetNormalTexture("Interface\\Buttons\\UI-PlusButton-UP")
			toggle:SetPushedTexture("Interface\\Buttons\\UI-PlusButton-DOWN")
		else
			toggle:SetNormalTexture("Interface\\Buttons\\UI-MinusButton-UP")
			toggle:SetPushedTexture("Interface\\Buttons\\UI-MinusButton-DOWN")
		end
		toggle:Show()
	else
		toggle:Hide()
	end
end

local function ShouldDisplayLevel(tree)
	local result = false
	for _, v in ipairs(tree) do
		if v.children == nil and v.visible ~= false then
			result = true
		elseif v.children then
			result = result or ShouldDisplayLevel(v.children)
		end
		if result then return result end
	end
	return false
end

local function addLine(self, v, tree, level, parent)
	local line = new()
	line.value = v.value
	line.text = v.text
	line.icon = v.icon
	line.iconCoords = v.iconCoords
	line.disabled = v.disabled
	line.tree = tree
	line.level = level
	line.parent = parent
	line.visible = v.visible
	line.uniquevalue = GetButtonUniqueValue(line)
	if v.children then
		line.hasChildren = true
	else
		line.hasChildren = nil
	end
	self.lines[#self.lines+1] = line
	return line
end

--fire an update after one frame to catch the treeframes height
local function FirstFrameUpdate(frame)
	local self = frame.obj
	frame:SetScript("OnUpdate", nil)
	self:RefreshTree()
end

local function BuildUniqueValue(...)
	local n = select('#', ...)
	if n == 1 then
		return ...
	else
		return (...).."\001"..BuildUniqueValue(select(2,...))
	end
end

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Expand_OnClick(frame)
	local button = frame.button
	local self = button.obj
	local status = (self.status or self.localstatus).groups
	status[button.uniquevalue] = not status[button.uniquevalue]
	self:RefreshTree()
end

local function Button_OnClick(frame, button)
	local self = frame.obj
	-- Suppress click if a drag just completed
	if self.dragState and self.dragState.isDragging then return end
	local result = self:Fire("OnClick", frame.uniquevalue, frame.selected, button)
	if result ~= false and not frame.selected then
		self:SetSelected(frame.uniquevalue)
		frame.selected = true
		frame:LockHighlight()
		self:RefreshTree()
	end
	AceGUI:ClearFocus()
end

local function Button_OnDoubleClick(button) -- luacheck: ignore 211 (unused, kept for future use)
	local self = button.obj
	local groups = (self.status or self.localstatus).groups
	groups[button.uniquevalue] = not groups[button.uniquevalue]
	self:RefreshTree()
end

local function Button_OnEnter(frame)
	local self = frame.obj
	self:Fire("OnButtonEnter", frame.uniquevalue, frame)

	if self.enabletooltips then
		GameTooltip:SetOwner(frame, "ANCHOR_NONE")
		GameTooltip:SetPoint("LEFT",frame,"RIGHT")
		GameTooltip:SetText(frame.text:GetText() or "", 1, .82, 0, true)

		GameTooltip:Show()
	end
end

local function Button_OnLeave(frame)
	local self = frame.obj
	self:Fire("OnButtonLeave", frame.uniquevalue, frame)

	if self.enabletooltips then
		GameTooltip:Hide()
	end
end

local function DragTracker_OnUpdate(frame)
	local self = frame.obj
	local ds = self.dragState
	if not ds then
		frame:Hide()
		return
	end

	local scale = UIParent:GetEffectiveScale()
	local curX, curY = GetCursorPosition()
	curX, curY = curX / scale, curY / scale

	if not ds.isDragging then
		-- Mouse released before reaching drag threshold → normal click
		if not IsMouseButtonDown("LeftButton") then
			self:CancelDrag()
			return
		end
		local dx = curX - ds.startX
		local dy = curY - ds.startY
		if (dx * dx + dy * dy) > DRAG_THRESHOLD_SQ then
			ds.isDragging = true
			self.dragIndicator.text:SetText(ds.text)
			self.dragIndicator:Show()
		end
	else
		if not IsMouseButtonDown("LeftButton") then
			self:CompleteDrop()
			return
		end
		-- Move drag indicator with cursor
		self.dragIndicator:ClearAllPoints()
		self.dragIndicator:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", curX + 12, curY - 4)
		-- Update drop target highlight
		self:UpdateDropTarget(curX, curY)
	end
end

local function Button_OnMouseDown(frame, mouseButton)
	if mouseButton ~= "LeftButton" then return end
	local self = frame.obj
	if self.dragState then return end

	local scale = UIParent:GetEffectiveScale()
	local curX, curY = GetCursorPosition()
	self.dragState = {
		sourceButton = frame,
		sourceValue = frame.value,
		sourceUniqueValue = frame.uniquevalue,
		text = frame.text:GetText() or "",
		startX = curX / scale,
		startY = curY / scale,
		isDragging = false,
	}
	self.dragTracker:Show()
end

local function OnScrollValueChanged(frame, value)
	if frame.obj.noupdate then return end
	local self = frame.obj
	local status = self.status or self.localstatus
	status.scrollvalue = floor(value + 0.5)
	self:RefreshTree()
	AceGUI:ClearFocus()
end

local function Tree_OnSizeChanged(frame)
	frame.obj:RefreshTree()
end

local function Tree_OnMouseWheel(frame, delta)
	local self = frame.obj
	if self.showscroll then
		local scrollbar = self.scrollbar
		local min, max = scrollbar:GetMinMaxValues()
		local value = scrollbar:GetValue()
		local newvalue = math_min(max,math_max(min,value - delta))
		if value ~= newvalue then
			scrollbar:SetValue(newvalue)
		end
	end
end

local function Dragger_OnLeave(frame)
	frame:SetBackdropColor(1, 1, 1, 0)
end

local function Dragger_OnEnter(frame)
	frame:SetBackdropColor(1, 1, 1, 0.8)
end

local function Dragger_OnMouseDown(frame)
	local treeframe = frame:GetParent()
	treeframe:StartSizing("RIGHT")
end

local function Dragger_OnMouseUp(frame)
	local treeframe = frame:GetParent()
	local self = treeframe.obj
	local parentframe = treeframe:GetParent()
	treeframe:StopMovingOrSizing()
	--treeframe:SetScript("OnUpdate", nil)
	treeframe:SetUserPlaced(false)
	--Without this :GetHeight will get stuck on the current height, causing the tree contents to not resize
	treeframe:SetHeight(0)
	treeframe:SetPoint("TOPLEFT", parentframe, "TOPLEFT",0,0)
	treeframe:SetPoint("BOTTOMLEFT", parentframe, "BOTTOMLEFT",0,0)

	local status = self.status or self.localstatus
	status.treewidth = treeframe:GetWidth()

	treeframe.obj:Fire("OnTreeResize",treeframe:GetWidth())
	-- recalculate the content width
	treeframe.obj:OnWidthSet(status.fullwidth)
	-- update the layout of the content
	treeframe.obj:DoLayout()
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		self:SetTreeWidth(DEFAULT_TREE_WIDTH, DEFAULT_TREE_SIZABLE)
		self:EnableButtonTooltips(true)
		self.frame:SetScript("OnUpdate", FirstFrameUpdate)
	end,

	["OnRelease"] = function(self)
		self.status = nil
		for k, v in pairs(self.localstatus) do
			if k == "groups" then
				for k2 in pairs(v) do
					v[k2] = nil
				end
			else
				self.localstatus[k] = nil
			end
		end
		self.localstatus.scrollvalue = 0
		self.localstatus.treewidth = DEFAULT_TREE_WIDTH
		self.localstatus.treesizable = DEFAULT_TREE_SIZABLE
		self:CancelDrag()
	end,

	["EnableButtonTooltips"] = function(self, enable)
		self.enabletooltips = enable
	end,

	["CreateButton"] = function(self)
		local num = AceGUI:GetNextWidgetNum("TreeGroupButton")
		local button = CreateFrame("Button", ("AceGUI30TreeButton%d"):format(num), self.treeframe, "OptionsListButtonTemplate")
		button.obj = self

		local icon = button:CreateTexture(nil, "OVERLAY")
		icon:SetWidth(14)
		icon:SetHeight(14)
		button.icon = icon

		button:SetScript("OnClick",Button_OnClick)
		--button:SetScript("OnDoubleClick", Button_OnDoubleClick)
		button:SetScript("OnEnter",Button_OnEnter)
		button:SetScript("OnLeave",Button_OnLeave)
		button:SetScript("OnMouseDown", Button_OnMouseDown)

		button.toggle.button = button
		button.toggle:SetScript("OnClick",Expand_OnClick)

		button.text:SetHeight(14) -- Prevents text wrapping

		return button
	end,

	["SetStatusTable"] = function(self, status)
		assert(type(status) == "table")
		self.status = status
		if not status.groups then
			status.groups = {}
		end
		if not status.scrollvalue then
			status.scrollvalue = 0
		end
		if not status.treewidth then
			status.treewidth = DEFAULT_TREE_WIDTH
		end
		if status.treesizable == nil then
			status.treesizable = DEFAULT_TREE_SIZABLE
		end
		self:SetTreeWidth(status.treewidth,status.treesizable)
		self:RefreshTree()
	end,

	--sets the tree to be displayed
	["SetTree"] = function(self, tree, filter)
		self.filter = filter
		if tree then
			assert(type(tree) == "table")
		end
		self.tree = tree
		self:RefreshTree()
	end,

	["BuildLevel"] = function(self, tree, level, parent)
		local groups = (self.status or self.localstatus).groups

		for _, v in ipairs(tree) do
			if v.children then
				if not self.filter or ShouldDisplayLevel(v.children) then
					local line = addLine(self, v, tree, level, parent)
					if groups[line.uniquevalue] then
						self:BuildLevel(v.children, level+1, line)
					end
				end
			elseif v.visible ~= false or not self.filter then
				addLine(self, v, tree, level, parent)
			end
		end
	end,

	["RefreshTree"] = function(self,scrollToSelection)
		local buttons = self.buttons
		local lines = self.lines

		for _, v in ipairs(buttons) do
			v:Hide()
		end
		while lines[1] do
			local t = tremove(lines)
			for k in pairs(t) do
				t[k] = nil
			end
			del(t)
		end

		if not self.tree then return end
		--Build the list of visible entries from the tree and status tables
		local status = self.status or self.localstatus
		local groupstatus = status.groups
		local tree = self.tree

		local treeframe = self.treeframe

		status.scrollToSelection = status.scrollToSelection or scrollToSelection	-- needs to be cached in case the control hasn't been drawn yet (code bails out below)

		self:BuildLevel(tree, 1)

		local numlines = #lines

		local maxlines = (floor(((self.treeframe:GetHeight()or 0) - 20 ) / 18))
		if maxlines <= 0 then return end

		local first, last

		scrollToSelection = status.scrollToSelection
		status.scrollToSelection = nil

		if numlines <= maxlines then
			--the whole tree fits in the frame
			status.scrollvalue = 0
			self:ShowScroll(false)
			first, last = 1, numlines
		else
			self:ShowScroll(true)
			--scrolling will be needed
			self.noupdate = true
			self.scrollbar:SetMinMaxValues(0, numlines - maxlines)
			--check if we are scrolled down too far
			if numlines - status.scrollvalue < maxlines then
				status.scrollvalue = numlines - maxlines
			end
			self.noupdate = nil
			first, last = status.scrollvalue+1, status.scrollvalue + maxlines
			--show selection?
			if scrollToSelection and status.selected then
				local show
				for i,line in ipairs(lines) do	-- find the line number
					if line.uniquevalue==status.selected then
						show=i
					end
				end
				if not show then
					-- selection was deleted or something?
				elseif show>=first and show<=last then
					-- all good
				else
					-- scrolling needed!
					if show<first then
						status.scrollvalue = show-1
					else
						status.scrollvalue = show-maxlines
					end
					first, last = status.scrollvalue+1, status.scrollvalue + maxlines
				end
			end
			if self.scrollbar:GetValue() ~= status.scrollvalue then
				self.scrollbar:SetValue(status.scrollvalue)
			end
		end

		local buttonnum = 1
		for i = first, last do
			local line = lines[i]
			local button = buttons[buttonnum]
			if not button then
				button = self:CreateButton()

				buttons[buttonnum] = button
				button:SetParent(treeframe)
				button:SetFrameLevel(treeframe:GetFrameLevel()+1)
				button:ClearAllPoints()
				if buttonnum == 1 then
					local topOffset = self.treeTopOffset or -10
					if self.showscroll then
						button:SetPoint("TOPRIGHT", -22, topOffset)
						button:SetPoint("TOPLEFT", 0, topOffset)
					else
						button:SetPoint("TOPRIGHT", 0, topOffset)
						button:SetPoint("TOPLEFT", 0, topOffset)
					end
				else
					button:SetPoint("TOPRIGHT", buttons[buttonnum-1], "BOTTOMRIGHT",0,0)
					button:SetPoint("TOPLEFT", buttons[buttonnum-1], "BOTTOMLEFT",0,0)
				end
			end

			UpdateButton(button, line, status.selected == line.uniquevalue, line.hasChildren, groupstatus[line.uniquevalue] )
			button:Show()
			buttonnum = buttonnum + 1
		end

	end,

	["SetSelected"] = function(self, value)
		local status = self.status or self.localstatus
		if status.selected ~= value then
			status.selected = value
			self:Fire("OnGroupSelected", value)
		end
	end,

	["Select"] = function(self, uniquevalue, ...)
		self.filter = false
		local status = self.status or self.localstatus
		local groups = status.groups
		local path = {...}
		for i = 1, #path do
			groups[tconcat(path, "\001", 1, i)] = true
		end
		status.selected = uniquevalue
		self:RefreshTree(true)
		self:Fire("OnGroupSelected", uniquevalue)
	end,

	["SelectByPath"] = function(self, ...)
		self:Select(BuildUniqueValue(...), ...)
	end,

	["SelectByValue"] = function(self, uniquevalue)
		self:Select(uniquevalue, ("\001"):split(uniquevalue))
	end,

	["ShowScroll"] = function(self, show)
		self.showscroll = show
		if show then
			self.scrollbar:Show()
			if self.buttons[1] then
				self.buttons[1]:SetPoint("TOPRIGHT", self.treeframe,"TOPRIGHT",-22,-10)
			end
		else
			self.scrollbar:Hide()
			if self.buttons[1] then
				self.buttons[1]:SetPoint("TOPRIGHT", self.treeframe,"TOPRIGHT",0,-10)
			end
		end
	end,

	["OnWidthSet"] = function(self, width)
		local content = self.content
		local treeframe = self.treeframe
		local status = self.status or self.localstatus
		status.fullwidth = width

		local contentwidth = width - status.treewidth - 20
		if contentwidth < 0 then
			contentwidth = 0
		end
		content:SetWidth(contentwidth)
		content.width = contentwidth

		local maxtreewidth = math_min(400, width - 50)

		if maxtreewidth > 100 and status.treewidth > maxtreewidth then
			self:SetTreeWidth(maxtreewidth, status.treesizable)
		end
		if treeframe.SetResizeBounds then -- WoW 10.0
			treeframe:SetResizeBounds(100, 1, maxtreewidth, 1600)
		else
			treeframe:SetMaxResize(maxtreewidth, 1600)
		end
	end,

	["OnHeightSet"] = function(self, height)
		local content = self.content
		local contentheight = height - 20
		if contentheight < 0 then
			contentheight = 0
		end
		content:SetHeight(contentheight)
		content.height = contentheight
	end,

	["SetTreeWidth"] = function(self, treewidth, resizable)
		if not resizable then
			if type(treewidth) == 'number' then
				resizable = false
			elseif type(treewidth) == 'boolean' then
				resizable = treewidth
				treewidth = DEFAULT_TREE_WIDTH
			else
				resizable = false
				treewidth = DEFAULT_TREE_WIDTH
			end
		end
		self.treeframe:SetWidth(treewidth)
		self.dragger:EnableMouse(resizable)

		local status = self.status or self.localstatus
		status.treewidth = treewidth
		status.treesizable = resizable

		-- recalculate the content width
		if status.fullwidth then
			self:OnWidthSet(status.fullwidth)
		end
	end,

	["GetTreeWidth"] = function(self)
		local status = self.status or self.localstatus
		return status.treewidth or DEFAULT_TREE_WIDTH
	end,

	["UpdateDropTarget"] = function(self, curX, curY)
		local buttons = self.buttons
		local ds = self.dragState
		if not ds then return end

		local bestButton, bestZone

		for _, button in ipairs(buttons) do
			if button:IsShown() and button.treeline then
				local bLeft = button:GetLeft()
				local bTop = button:GetTop()
				local bBottom = button:GetBottom()
				local bRight = button:GetRight()

				if bLeft and curX >= bLeft and curX <= bRight and curY >= bBottom and curY <= bTop then
					local height = bTop - bBottom
					local relY = (curY - bBottom) / height

					if button.treeline.hasChildren then
						-- Category: top/bottom 25% = above/below, middle 50% = into
						if relY > (1 - DROP_ZONE_EDGE) then
							bestZone = "above"
						elseif relY < DROP_ZONE_EDGE then
							bestZone = "below"
						else
							bestZone = "into"
						end
					else
						-- Page/leaf: top 50% = above, bottom 50% = below
						if relY > 0.5 then
							bestZone = "above"
						else
							bestZone = "below"
						end
					end
					bestButton = button
					break
				end
			end
		end

		-- Don't highlight source item as a drop target
		if bestButton and bestButton.uniquevalue == ds.sourceUniqueValue then
			bestButton = nil
		end

		-- Update visuals
		if bestButton then
			self.dropTarget = {
				value = bestButton.value,
				uniquevalue = bestButton.uniquevalue,
				zone = bestZone,
				button = bestButton,
			}
			self:UpdateDropLine(bestButton, bestZone)
		else
			self.dropTarget = nil
			self.dropLine:Hide()
			self.dropHighlight:Hide()
		end
	end,

	["UpdateDropLine"] = function(self, button, zone)
		local dropLine = self.dropLine
		local dropHighlight = self.dropHighlight

		if zone == "into" then
			dropLine:Hide()
			dropHighlight:ClearAllPoints()
			dropHighlight:SetPoint("TOPLEFT", button, "TOPLEFT")
			dropHighlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT")
			dropHighlight:Show()
		else
			dropHighlight:Hide()
			dropLine:ClearAllPoints()
			if zone == "above" then
				dropLine:SetPoint("LEFT", button, "TOPLEFT", 0, 0)
				dropLine:SetPoint("RIGHT", button, "TOPRIGHT", 0, 0)
			else
				dropLine:SetPoint("LEFT", button, "BOTTOMLEFT", 0, 0)
				dropLine:SetPoint("RIGHT", button, "BOTTOMRIGHT", 0, 0)
			end
			dropLine:Show()
		end
	end,

	["CompleteDrop"] = function(self)
		local ds = self.dragState
		local dt = self.dropTarget

		-- Hide visuals
		self.dragIndicator:Hide()
		self.dropLine:Hide()
		self.dropHighlight:Hide()
		self.dragTracker:Hide()

		-- Fire callback if we have a valid drop target
		if ds and dt then
			self:Fire("OnDragDrop", ds.sourceValue, ds.sourceUniqueValue, dt.value, dt.uniquevalue, dt.zone)
		end

		self.dragState = nil
		self.dropTarget = nil
	end,

	["CancelDrag"] = function(self)
		self.dragIndicator:Hide()
		self.dropLine:Hide()
		self.dropHighlight:Hide()
		self.dragTracker:Hide()
		self.dragState = nil
		self.dropTarget = nil
	end,

	["LayoutFinished"] = function(self, width, height)
		if self.noAutoHeight then return end
		self:SetHeight((height or 0) + 20)
	end
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local PaneBackdrop  = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true, tileSize = 16, edgeSize = 16,
	insets = { left = 3, right = 3, top = 5, bottom = 3 }
}

local DraggerBackdrop  = {
	bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
	edgeFile = nil,
	tile = true, tileSize = 16, edgeSize = 0,
	insets = { left = 3, right = 3, top = 7, bottom = 7 }
}

local function Constructor()
	local num = AceGUI:GetNextWidgetNum(Type)
	local frame = CreateFrame("Frame", nil, UIParent)

	local treeframe = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	treeframe:SetPoint("TOPLEFT")
	treeframe:SetPoint("BOTTOMLEFT")
	treeframe:SetWidth(DEFAULT_TREE_WIDTH)
	treeframe:EnableMouseWheel(true)
	treeframe:SetBackdrop(PaneBackdrop)
	treeframe:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
	treeframe:SetBackdropBorderColor(0.4, 0.4, 0.4)
	treeframe:SetResizable(true)
	if treeframe.SetResizeBounds then -- WoW 10.0
		treeframe:SetResizeBounds(100, 1, 400, 1600)
	else
		treeframe:SetMinResize(100, 1)
		treeframe:SetMaxResize(400, 1600)
	end
	treeframe:SetScript("OnUpdate", FirstFrameUpdate)
	treeframe:SetScript("OnSizeChanged", Tree_OnSizeChanged)
	treeframe:SetScript("OnMouseWheel", Tree_OnMouseWheel)

	local dragger = CreateFrame("Frame", nil, treeframe, BackdropTemplateMixin and "BackdropTemplate" or nil)
	dragger:SetWidth(8)
	dragger:SetPoint("TOP", treeframe, "TOPRIGHT")
	dragger:SetPoint("BOTTOM", treeframe, "BOTTOMRIGHT")
	dragger:SetBackdrop(DraggerBackdrop)
	dragger:SetBackdropColor(1, 1, 1, 0)
	dragger:SetScript("OnEnter", Dragger_OnEnter)
	dragger:SetScript("OnLeave", Dragger_OnLeave)
	dragger:SetScript("OnMouseDown", Dragger_OnMouseDown)
	dragger:SetScript("OnMouseUp", Dragger_OnMouseUp)

	local scrollbar = CreateFrame("Slider", ("AceConfigDialogTreeGroup%dScrollBar"):format(num), treeframe, "UIPanelScrollBarTemplate")
	scrollbar:SetScript("OnValueChanged", nil)
	scrollbar:SetPoint("TOPRIGHT", -10, -26)
	scrollbar:SetPoint("BOTTOMRIGHT", -10, 26)
	scrollbar:SetMinMaxValues(0,0)
	scrollbar:SetValueStep(1)
	scrollbar:SetValue(0)
	scrollbar:SetWidth(16)
	scrollbar:SetScript("OnValueChanged", OnScrollValueChanged)

	local scrollbg = scrollbar:CreateTexture(nil, "BACKGROUND")
	scrollbg:SetAllPoints(scrollbar)

	if IsLegion then
		scrollbg:SetColorTexture(0,0,0,0.4)
	else
		scrollbg:SetTexture(0,0,0,0.4)
	end

	local border = CreateFrame("Frame", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	border:SetPoint("TOPLEFT", treeframe, "TOPRIGHT")
	border:SetPoint("BOTTOMRIGHT")
	border:SetBackdrop(PaneBackdrop)
	border:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
	border:SetBackdropBorderColor(0.4, 0.4, 0.4)

	--Container Support
	local content = CreateFrame("Frame", nil, border)
	content:SetPoint("TOPLEFT", 10, -10)
	content:SetPoint("BOTTOMRIGHT", -10, 10)

	-- Drag-and-drop frames
	local dragTracker = CreateFrame("Frame", nil, treeframe)
	dragTracker:Hide()
	dragTracker:SetScript("OnUpdate", DragTracker_OnUpdate)

	local dragIndicator = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	dragIndicator:SetSize(180, 20)
	dragIndicator:SetBackdrop({
		bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true, tileSize = 16, edgeSize = 8,
		insets = { left = 2, right = 2, top = 2, bottom = 2 }
	})
	dragIndicator:SetBackdropColor(0, 0, 0, 0.85)
	dragIndicator:SetBackdropBorderColor(0.4, 0.6, 1, 0.8)
	dragIndicator:SetFrameStrata("TOOLTIP")
	dragIndicator:Hide()
	local dragText = dragIndicator:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	dragText:SetPoint("LEFT", 4, 0)
	dragText:SetPoint("RIGHT", -4, 0)
	dragText:SetWordWrap(false)
	dragIndicator.text = dragText

	local dropLine = treeframe:CreateTexture(nil, "OVERLAY")
	dropLine:SetHeight(2)
	if IsLegion then
		dropLine:SetColorTexture(0.3, 0.6, 1, 0.8)
	else
		dropLine:SetTexture(0.3, 0.6, 1, 0.8)
	end
	dropLine:Hide()

	local dropHighlight = treeframe:CreateTexture(nil, "OVERLAY")
	if IsLegion then
		dropHighlight:SetColorTexture(0.3, 0.6, 1, 0.15)
	else
		dropHighlight:SetTexture(0.3, 0.6, 1, 0.15)
	end
	dropHighlight:Hide()

	local widget = {
		frame         = frame,
		lines         = {},
		levels        = {},
		buttons       = {},
		hasChildren   = {},
		localstatus   = { groups = {}, scrollvalue = 0 },
		filter        = false,
		treeframe     = treeframe,
		dragger       = dragger,
		scrollbar     = scrollbar,
		border        = border,
		content       = content,
		dragTracker   = dragTracker,
		dragIndicator = dragIndicator,
		dropLine      = dropLine,
		dropHighlight = dropHighlight,
		type          = Type
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end
	treeframe.obj, dragger.obj, scrollbar.obj, dragTracker.obj = widget, widget, widget, widget

	return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
