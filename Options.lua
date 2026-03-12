local _, ns = ...
local AngryAssign = LibStub("AceAddon-3.0"):GetAddon("AngryAssignments")

local LSM = LibStub("LibSharedMedia-3.0")

local HexToRGB = ns.HexToRGB
local RGBToHex = ns.RGBToHex

local blizOptionsPanel
function AngryAssign:InitOptions()
	local ver = ns.AngryAssign_Version
	if ver:sub(1,1) == "@" then ver = "dev" end

	local options = {
		name = "Angry Assignments+ "..ver,
		handler = AngryAssign,
		type = "group",
		args = {
			window = {
				type = "execute",
				order = 3,
				name = "Toggle Window",
				desc = "Shows/hides the edit window (also available in game keybindings)",
				func = function() AngryAssign_ToggleWindow() end
			},
			help = {
				type = "execute",
				order = 99,
				name = "Help",
				hidden = true,
				func = function()
					LibStub("AceConfigCmd-3.0").HandleCommand(self, "aa", "AngryAssign", "")
				end
			},
			toggle = {
				type = "execute",
				order = 1,
				name = "Toggle Display",
				desc = "Shows/hides the display frame (also available in game keybindings)",
				func = function() AngryAssign_ToggleDisplay() end
			},
			show = {
				type = "execute",
				order = 1.1,
				name = "Show Display",
				desc = "Shows the display frame",
				hidden = true,
				cmdHidden = false,
				func = function() AngryAssign:ShowDisplay() end
			},
			hide = {
				type = "execute",
				order = 1.2,
				name = "Hide Display",
				desc = "Hides the display frame",
				hidden = true,
				cmdHidden = false,
				func = function() AngryAssign:HideDisplay() end
			},
			deleteall = {
				type = "execute",
				name = "Delete All Pages",
				desc = "Deletes all pages",
				order = 4,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				func = function()
					AngryAssign_State.displayed = nil
					AngryAssign_Pages = {}
					AngryAssign_Categories = {}
					self:UpdateTree()
					self:UpdateSelected()
					self:UpdateDisplayed()
					if self.window then self.window.tree:SetSelected(nil) end
					self:Print("All pages have been deleted.")
				end
			},
			defaults = {
				type = "execute",
				name = "Restore Defaults",
				desc = "Restore configuration values to their default settings",
				order = 10,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				func = function()
					self:RestoreDefaults()
				end
			},
			output = {
				type = "execute",
				name = "Output",
				desc = "Outputs currently displayed assignents to chat",
				order = 11,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				func = function()
					self:OutputDisplayed()
				end
			},
			send = {
				type = "input",
				name = "Send and Display",
				desc = "Sends page with specified name",
				order = 12,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				get = function(info) return "" end,
				set = function(info, val)
					local result = self:DisplayPageByName( val:trim() )
					if result == false then
						self:Print( RED_FONT_COLOR_CODE .. "A page with the name \""..val:trim().."\" could not be found.|r" )
					elseif not result then
						self:Print( RED_FONT_COLOR_CODE .. "You don't have permission to send a page.|r" )
					end
				end
			},
			clear = {
				type = "execute",
				name = "Clear",
				desc = "Clears currently displayed page",
				order = 13,
				hidden = true,
				cmdHidden = false,
				confirm = true,
				func = function()
					if not self:PermissionCheck() then return end
					self:ClearDisplayed()
					self:SendDisplay( nil, true )
				end
			},
			backup = {
				type = "execute",
				order = 20,
				name = "Backup Pages",
				desc = "Creates a backup of all pages with their current contents",
				func = function()
					self:CreateBackup()
					self:Print("Created a backup of all pages.")
				end
			},
			resetposition = {
				type = "execute",
				order = 22,
				name = "Reset Position",
				desc = "Resets position for the assignment display",
				func = function()
					self:ResetPosition()
				end
			},
			version = {
				type = "execute",
				order = 21,
				name = "Version Check",
				desc = "Displays a list of all users (in the raid) running the addon and the version they're running",
				func = function()
					if (IsInRaid() or IsInGroup()) then
						ns.versionList = {} -- start with a fresh version list, when displaying it
						self:SendOutMessage({ "VER_QUERY" })
						self:ScheduleTimer("VersionCheckOutput", 3)
						self:Print("Version check running...")
					else
						self:Print("You must be in a raid group to run the version check.")
					end
				end
			},
			lock = {
				type = "execute",
				order = 2,
				name = "Toggle Lock",
				desc = "Shows/hides the display mover (also available in game keybindings)",
				func = function() self:ToggleLock() end
			},
			behavior = {
				type = "group",
				order = 5,
				name = "Behavior",
				inline = true,
				args = {
					hideoncombat = {
						type = "toggle",
						order = 1,
						name = "Hide on Combat",
						desc = "Enable to hide display frame upon entering combat",
						get = function(info) return self:GetConfig('hideoncombat') end,
						set = function(info, val)
							self:SetConfig('hideoncombat', val)
						end
					},
					showaftercombat = {
						type = "toggle",
						order = 2,
						name = "Show After Combat",
						desc = "Re-shows assignments when combat ends (if Hide on Combat is enabled)",
						get = function(info) return self:GetConfig('showaftercombat') end,
						set = function(info, val)
							self:SetConfig('showaftercombat', val)
						end
					},
					updateSound = {
						type = "toggle",
						order = 3,
						name = "Sound on Update",
						desc = "Play a sound when assignments are updated",
						get = function(info) return self:GetConfig('updateSound') end,
						set = function(info, val)
							self:SetConfig('updateSound', val)
						end
					},
				}
			},
			display = {
				type = "group",
				order = 6,
				name = "Display",
				inline = true,
				args = {
					displayMaxLines = {
						type = "range",
						order = 1,
						name = "Display Max Lines",
						desc = "Maximum number of lines shown in the display frame",
						min = 10,
						max = 200,
						step = 5,
						get = function(info) return self:GetConfig('displayMaxLines') end,
						set = function(info, val)
							self:SetConfig('displayMaxLines', val)
							self:UpdateMedia()
							self:UpdateDisplayed()
						end
					},
					scale = {
						type = "range",
						order = 2,
						name = "Scale",
						desc = "Sets the scale of the edit window (does not affect the display frame)",
						min = 0.3,
						max = 3,
						get = function(info) return self:GetConfig('scale') end,
						set = function(info, val)
							self:SetConfig('scale', val)
							if AngryAssign.window then AngryAssign.window.frame:SetScale(val) end
						end
					},
					backdrop = {
						type = "toggle",
						order = 3,
						name = "Display Backdrop",
						desc = "Enable to display a backdrop behind the assignment display",
						get = function(info) return self:GetConfig('backdropShow') end,
						set = function(info, val)
							self:SetConfig('backdropShow', val)
							self:UpdateBackdrop()
						end
					},
					backdropcolor = {
						type = "color",
						order = 4,
						name = "Backdrop Color",
						desc = "The color used by the backdrop",
						hasAlpha = true,
						get = function(info)
							local hex = self:GetConfig('backdropColor')
							return HexToRGB(hex)
						end,
						set = function(info, r, g, b, a)
							self:SetConfig('backdropColor', RGBToHex(r, g, b, a))
							self:UpdateMedia()
							self:UpdateDisplayed()
						end
					},
					updatecolor = {
						type = "color",
						order = 5,
						name = "Update Notification Color",
						desc = "The color used by the update notification glow",
						get = function(info)
							local hex = self:GetConfig('glowColor')
							return HexToRGB(hex)
						end,
						set = function(info, r, g, b)
							self:SetConfig('glowColor', RGBToHex(r, g, b))
							self.display_glow:SetVertexColor(r, g, b)
							self.display_glow2:SetVertexColor(r, g, b)
						end
					},
					showMinimapButton = {
						type = "toggle",
						order = 6,
						name = "Show Minimap Button",
						desc = "Show or hide the minimap button",
						hidden = function() return not LibStub("LibDBIcon-1.0", true) end,
						get = function(info) return self:GetConfig('showMinimapButton') end,
						set = function(info, val)
							self:SetConfig('showMinimapButton', val)
							self:UpdateMinimapButton()
						end
					},
				}
			},
			font = {
				type = "group",
				order = 7,
				name = "Font",
				inline = true,
				args = {
					fontname = {
						type = 'select',
						order = 1,
						dialogControl = 'LSM30_Font',
						name = 'Face',
						desc = 'Sets the font face used to display a page',
						values = LSM:HashTable("font"),
						get = function(info) return self:GetConfig('fontName') end,
						set = function(info, val)
							self:SetConfig('fontName', val)
							self:UpdateMedia()
						end
					},
					fontheight = {
						type = "range",
						order = 2,
						name = "Size",
						desc = function()
							return "Sets the font height used to display a page"
						end,
						min = 6,
						max = 24,
						step = 1,
						get = function(info) return self:GetConfig('fontHeight') end,
						set = function(info, val)
							self:SetConfig('fontHeight', val)
							self:UpdateMedia()
						end
					},
					fontflags = {
						type = "select",
						order = 3,
						name = "Outline",
						desc = "Sets the font outline used to display a page",
						values = { ["NONE"] = "None", ["OUTLINE"] = "Outline", ["THICKOUTLINE"] = "Thick Outline", ["MONOCHROMEOUTLINE"] = "Monochrome" },
						get = function(info)
							local val = self:GetConfig('fontFlags')
							if val == "" then return "NONE" end
							return val
						end,
						set = function(info, val)
							self:SetConfig('fontFlags', val)
							self:UpdateMedia()
						end
					},
					color = {
						type = "color",
						order = 4,
						name = "Normal Color",
						desc = "The normal color used to display assignments",
						get = function(info)
							local hex = self:GetConfig('color')
							return HexToRGB(hex)
						end,
						set = function(info, r, g, b)
							self:SetConfig('color', RGBToHex(r, g, b))
							self:UpdateMedia()
							self:UpdateDisplayed()
						end
					},
					highlightcolor = {
						type = "color",
						order = 5,
						name = "Highlight Color",
						desc = "The color used to emphasize highlighted words",
						get = function(info)
							local hex = self:GetConfig('highlightColor')
							return HexToRGB(hex)
						end,
						set = function(info, r, g, b)
							self:SetConfig('highlightColor', RGBToHex(r, g, b))
							self:UpdateDisplayed()
						end
					},
					highlight = {
						type = "input",
						order = 6,
						name = "Highlight Words",
						desc = "A list of words to highlight on displayed pages (separated by spaces or punctuation)\n\nUse 'Group' to highlight the current group you are in, ex. G2",
						get = function(info) return self:GetConfig('highlight') end,
						set = function(info, val)
							self:SetConfig('highlight', val)
							self:UpdateDisplayed()
						end
					},
					linespacing = {
						type = "range",
						order = 7,
						name = "Line Spacing",
						desc = function()
							return "Sets the line spacing used to display a page"
						end,
						min = 0,
						max = 10,
						step = 1,
						get = function(info) return self:GetConfig('lineSpacing') end,
						set = function(info, val)
							self:SetConfig('lineSpacing', val)
							self:UpdateMedia()
							self:UpdateDisplayed()
						end
					},
				}
			},
			permissions = {
				type = "group",
				order = 8,
				name = "Permissions",
				inline = true,
				args = {
					allowOfficers = {
						type = "toggle",
						order = 1,
						name = "Allow Guild Officers",
						desc = "Trust raids led by guild officers — all leaders and assistants in those raids can send assignments",
						get = function(info) return self:GetConfig('allowOfficers') end,
						set = function(info, val)
							self:SetConfig('allowOfficers', val)
							self:PermissionsUpdated()
						end
					},
					allowRaidLeader = {
						type = "toggle",
						order = 2,
						name = "Allow Raid Leader",
						desc = "Allow the raid/group leader to send assignments, even in non-guild raids",
						get = function(info) return self:GetConfig('allowRaidLeader') end,
						set = function(info, val)
							self:SetConfig('allowRaidLeader', val)
							self:PermissionsUpdated()
						end
					},
					allowRaidAssistants = {
						type = "toggle",
						order = 3,
						name = "Allow Raid Assistants",
						desc = "Allow raid assistants to send assignments, even in non-guild raids",
						get = function(info) return self:GetConfig('allowRaidAssistants') end,
						set = function(info, val)
							self:SetConfig('allowRaidAssistants', val)
							self:PermissionsUpdated()
						end
					},
					allowall = {
						type = "toggle",
						order = 4,
						name = "Allow All",
						desc = "Trust any raid — all leaders and assistants can send assignments regardless of guild status",
						get = function(info) return self:GetConfig('allowall') end,
						set = function(info, val)
							self:SetConfig('allowall', val)
							self:PermissionsUpdated()
						end
					},
					allowplayers = {
						type = "input",
						order = 5,
						name = "Allow Players",
						desc = "A list of player names — when one of these players is the raid leader, all leaders and assistants in that raid can send assignments",
						get = function(info) return self:GetConfig('allowplayers') end,
						set = function(info, val)
							self:SetConfig('allowplayers', val)
							self:PermissionsUpdated()
						end
					},
				}
			}
		}
	}

	self:RegisterChatCommand("aa", "ChatCommand")
	LibStub("AceConfig-3.0"):RegisterOptionsTable("AngryAssign", options)

	blizOptionsPanel = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("AngryAssign", "Angry Assignments+")
	blizOptionsPanel.default = function() self:RestoreDefaults() end
end
