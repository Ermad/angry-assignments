Angry Assignments+
==================

Angry Assignments+ is a fork of the original Angry Assignments addon, rebuilt for modern World of Warcraft. It gives your raid leaders and officers a shared set of assignment pages that can be edited, synced across the guild, and displayed on screen during encounters. Whether you are organizing cooldown rotations, healing assignments, or interrupt orders, AA+ keeps everyone on the same page.

The addon works across all WoW versions: Retail (The War Within), Mists Classic, Wrath Classic, TBC Classic, and Vanilla Classic.

What Changed in the Fork
------------------------------

Angry Assignments+ is a complete overhaul of the original addon. The major changes include:

* **Modular codebase** -- The original monolithic Core.lua (2,700 lines) has been split into focused modules: Core, Comm, Permissions, Pages, Display, Window, Options, TokenPanel, and Minimap. This makes the addon easier to maintain and extend.
* **Tokens and Roster panel** -- A new side panel in the edit window with clickable raid icons, role icons, buff icons, color codes, and a searchable player roster. Click any token to insert it at your cursor.
* **Clear Names** -- A one-click button that strips all player names from the current page while keeping markers and structure intact. Great for reusing assignment templates week to week.
* **Minimap button** -- Left-click to open the edit window, right-click to toggle the display. Can be hidden in settings.
* **Expanded permissions** -- New "Allow Raid Leader" and "Allow Raid Assistants" toggles let you accept assignments from non-guild raids without enabling "Allow All."
* **Sound on Update** -- Optional audio notification when assignments change.
* **Show After Combat** -- Automatically re-shows assignments when combat ends (if Hide on Combat is enabled).
* **Display Max Lines** -- Control how many lines the on-screen display can show (10 to 200).
* **Share pages** -- Right-click any page or category to share it with your raid or party. Shared pages arrive in a dedicated "Shared with me" section on the receiving player's list, tagged with the sender's name. Duplicate content is automatically detected and skipped.
* **Currently Displayed category** -- The page tree now shows a pinned "Currently Displayed" entry at the top so you can always find the active assignment at a glance.
* **Duplicate page** -- Right-click any page in the tree to create a copy with all its content.
* **Simplified color syntax** -- Close a color section with `|` instead of `|r` (e.g. `|cblue text|`). The old `|r` syntax still works.
* **Upgraded compression** -- Replaced LibCompress with LibDeflate for more efficient addon communication.
* **Updated protocol** -- Communication protocol bumped to version 2 for improved reliability.
* **Expanded Classic support** -- Added Cataclysm Classic and Mists Classic detection, plus dedicated TOC files for TBC, Vanilla, and Mists.
* **Build tooling** -- Makefile, luacheck linting, GitHub Actions CI, and packaging scripts for contributors.

Using AA+ as a Raider
------------------------------

**Keybinding:** Open your game keybindings menu and look under "Angry Assignments+." Bind "Toggle Display" to a key you can press quickly. This is the fastest way to show or hide assignments during a fight.

**Configuration:** Open the settings panel through the game's Interface menu (Addons tab, "Angry Assignments+"), or type `/aa` in chat to open the edit window directly. Use `/aa config` to go straight to settings. From the settings panel you can:

* **Toggle Display** / **Toggle Lock** -- Show or hide the on-screen assignments, and lock or unlock the display frame so you can reposition it.
* **Highlight Words** -- Enter your character name (and any short nicknames your raid uses for you) so those words stand out in a different color. Separate multiple words with commas or spaces. If you add the special word "Group", then raid group labels like G1 or G2 will highlight automatically whenever you belong to that group.
* **Hide on Combat / Show After Combat** -- Automatically hide assignments when combat starts, and optionally bring them back when combat ends. You can always press your keybinding to show them again mid-fight.
* **Sound on Update** -- Play an audio cue whenever the displayed assignments change.
* **Display Max Lines** -- Set how many lines the on-screen display can show (default 70).
* **Font settings** -- Choose the font face, size, color, outline style, and line spacing for the on-screen text. You can also set the highlight color separately.
* **Display Backdrop** -- Show a colored background behind the assignment text for better readability. The backdrop color and transparency are adjustable.
* **Update Notification Color** -- Change the color of the glow animation that plays when assignments are updated.
* **Minimap Button** -- Toggle the minimap icon on or off. Left-click the minimap button to open the edit window; right-click to toggle the display.

**Positioning the display:** Unlock the display (use the config button, `/aa lock`, or a keybinding). A red anchor strip will appear. Drag it where you want your assignments to show. The arrow on the left side controls whether text grows upward or downward from the anchor. Adjust the width of the strip to set where lines wrap. When you are happy with the placement, click the lock icon on the strip.

**During raids:** Whenever assignments are updated, the display will reappear on your screen with a glow notification (and a sound, if you enabled that option). If you re-log or reload your UI during a raid, the addon automatically re-syncs from the raid leader. When you leave the raid, the display clears.

Using AA+ as an Officer or Raid Assistant
-------------------------------------------

### Permissions

Editing pages and changing what is displayed on screen is restricted to authorized players. The permission system works as follows:

* **Guild officer raids (default):** When "Allow Guild Officers" is enabled and the raid leader is a guild officer, all leaders and assistants in that raid can send assignments. Officer ranks are detected automatically using the Communities API.
* **Allow Raid Leader:** Lets the raid/group leader send assignments, even in non-guild raids.
* **Allow Raid Assistants:** Lets raid assistants send assignments, even in non-guild raids.
* **Allow All:** Trusts any raid. All leaders and assistants can send assignments regardless of guild status. Useful for pugs or cross-guild groups.
* **Allow Players:** A list of specific player names. When one of these players is the raid leader, all leaders and assistants in that raid are trusted.

**Important note about raid assistants:** For a raid assistant to send assignments, the **raid leader** must be authorized on the receiving player's end. Being promoted to assistant alone is not enough. If you are running a pug or cross-guild raid, either enable "Allow All" in your config, or have raiders add the raid leader's name to their "Allow Players" list.

Each player's addon validates incoming changes independently, so unauthorized edits are silently rejected.

### The Edit Window

Bind "Toggle Window" in your keybindings, use `/aa window`, or left-click the minimap button. This opens the editing interface. You can scale the edit window up or down via the "Scale" slider in configuration or with `/aa scale`.

The left side shows your assignment pages organized in a tree. Two permanent entries appear at the top: **Currently Displayed** (the page your raid is currently viewing) and **Shared with me** (pages other players have shared with you). Below those are your own pages and categories. You can arrange pages into categories and sub-categories by right-clicking a page. Categories are stored locally and are not synced to other players.

**Page management (bottom-left or right-click menu):**
* **Add** -- Create a new blank page.
* **Rename** -- Rename the selected page. The new name is sent to guild members who are online.
* **Delete** -- Remove the page locally. Other guild members will keep their copy. If someone later edits or sends that page, you will receive it again.
* **Duplicate** -- Create a copy of the selected page with all its content (available from the right-click menu).
* **Share** -- Send the page to everyone in your current raid or party (available from the right-click menu). The page arrives in their "Shared with me" section with your name attached. If a player already has a page with identical content, the duplicate is skipped automatically. You can also right-click a category and choose "Share All Pages" to share every page inside it at once.

Shared pages can be moved out of "Shared with me" into your own categories by right-clicking and assigning a category, just like any other page. The "Currently Displayed" and "Shared with me" entries at the top of the tree cannot be renamed, deleted, or shared as categories.

**Editing buttons:**
* **Accept** -- Save your changes, update the page timestamp, and send the new version to everyone online in the guild. If the page you edited is the one currently displayed, everyone will see the update immediately.
* **Revert** -- Discard your current edits and go back to the last saved version.
* **Restore** -- Recall the last version of this page that you personally edited and accepted. Useful for recovering your work if someone else made unwanted changes. You still need to press "Accept" afterward to save the restored version.
* **Send and Display** -- Send the page to the guild and set it as the active on-screen display for everyone in the raid. If you are not in a raid, it previews on your own screen.
* **Clear Displayed** -- Remove the on-screen display for everyone in the raid without changing any page content.
* **Output** -- Send the current assignments to raid, party, or instance chat as plain text.

If someone else saves edits to the same page while you are editing it, a pop-up will notify you. You can continue your work and overwrite their version with "Accept", or press "Revert" to load their version instead. (Tip: before reverting, copy your in-progress section with Ctrl+C, then revert, and paste it back with Ctrl+V.)

Individual pages are identified internally with unique IDs. The names in the edit window are just labels, so multiple pages can share the same name. Renames are synced to online guild members. Deletes are local only.

### Tokens and Roster Panel

The edit window includes a side panel called "Tokens & Roster" with clickable shortcuts for common formatting. Click any item to insert it at your cursor position in the assignment text.

**Raid Icons** -- All eight raid markers: skull, cross, square, moon, triangle, diamond, circle, star.

**Roles & Buffs** -- Tank, Healer, DPS, Bloodlust, and Healthstone icons.

**Color Codes** -- Standard colors (blue, green, red, yellow, orange, pink, purple) and class colors (warrior, paladin, hunter, rogue, priest, shaman, mage, warlock, druid, death knight). Click a color to insert its escape code.

**Players** -- A searchable list of your current raid or guild members, shown in class colors. Click a name to insert it into the text.

**Clear Names** -- Strips all player names from the current page while preserving raid markers, role icons, and line structure. This makes it easy to reuse an assignment template without manually clearing names each week.

### Text Formatting Reference

Assignment pages support inline tokens that render as icons or colored text on the display:

**Raid markers:**
`{star}`, `{circle}`, `{diamond}`, `{triangle}`, `{moon}`, `{square}`, `{cross}` (or `{x}`), `{skull}` -- or numbered as `{rt1}` through `{rt8}`.

**Role icons:**
`{tank}`, `{healer}`, `{dps}` (or `{damage}`).

**Buff icons:**
`{bl}` or `{bloodlust}`, `{hero}` or `{heroism}`, `{hs}` or `{healthstone}`.

**Class icons:**
`{warrior}`, `{paladin}`, `{hunter}`, `{rogue}`, `{priest}`, `{shaman}`, `{mage}`, `{warlock}`, `{druid}`, `{deathknight}`, `{monk}`, `{demonhunter}`, `{evoker}` (availability depends on your WoW version).

**Spell links and icons:**
`{spell 12345}` inserts a clickable spell link. `{icon spell_holy_sealofprotection}` or `{icon 12345}` inserts any game icon by texture name or spell ID. Look up icon names on [Wowhead](http://www.wowhead.com) by clicking on a spell's icon.

**Encounter Journal (Cataclysm and later):**
`{boss 12345}` inserts a boss icon by encounter ID. `{journal 12345}` inserts a journal section icon.

**Color shortcuts:**
`|cblue`, `|cgreen`, `|cred`, `|cyellow`, `|corange`, `|cpink`, `|cpurple` for standard colors. `|cwarrior`, `|cpaladin`, `|chunter`, `|crogue`, `|cpriest`, `|cshaman`, `|cmage`, `|cwarlock`, `|cdruid`, `|cdk` (or `|cdeathknight`) for class colors. End colored sections with `|` (or `|r`).

You can also use any standard WoW UI escape sequences. See the [WoWWiki page on UI escape sequences](http://www.wowwiki.com/UI_escape_sequences) for the full list.

### WeakAuras and Addon Integration

Other addons and WeakAuras can interact with Angry Assignments+ through these functions:

* `AngryAssign:GetDisplayedPage()` -- Returns the full page object for the currently displayed page.
* `AngryAssign:GetDisplayedPageContent()` -- Returns the text content of the currently displayed page.
* `AngryAssign:DisplayPageByName(name)` -- Display a page by its name.
* `AngryAssign:DisplayPage(id)` -- Display a page by its internal ID.

The addon fires the message `ANGRY_ASSIGNMENTS_UPDATE` whenever the displayed page changes.

Slash Commands
-----------------

All commands use the `/aa` prefix:

| Command | Description |
|---|---|
| `/aa` | Open the edit window |
| `/aa config` | Open the settings panel (also `/aa options`) |
| `/aa toggle` | Toggle the on-screen display |
| `/aa show` | Show the display |
| `/aa hide` | Hide the display |
| `/aa lock` | Toggle lock on the display anchor |
| `/aa window` | Toggle the edit window |
| `/aa send <name>` | Find a page by name and display it to the raid |
| `/aa output` | Output current assignments to chat |
| `/aa clear` | Clear the currently displayed page |
| `/aa version` | Run a version check across your raid |
| `/aa backup` | Back up all pages for later restore |
| `/aa deleteall` | Delete all stored pages (with confirmation) |
| `/aa help` | List all available commands |

Credits
---------

Originally created by the guild Angry (US-Illidan). This fork is maintained by Ariailis.
