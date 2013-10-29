This addon was written by the guild Angry (US-Illidan) to handle assignments during raids.  It provides a convenient way to store and share assignments for different bosses, allowing editing by multiple people (officers/raid assistants), and displaying the information to raiders in a configurable and readable format.

Using AA as a raider
------------------------------
First, you'll likely want to configure a keybinding for the "Toggle Display" function (it should appear under "Angry Assignments" in your game keybindings menu), this will let you easily show/hide the on-screen assignments display during raids.  

The rest of the important configuration is primarily in the game's Interface menu, Addons tab, where you should now have a menu for "Angry Assignments" (you can also bring this screen up with the "/aa" command):

* "Toggle Display" will toggle the on-screen display on and off (can also use "/aa toggle", but most of the time you'll want to use the keybinding discussed above).
* "Toggle Lock" will lock/unlock the anchor for the on-screen display (can also use "/aa lock" or a keybinding), so that you can configure its location, direction, and width.
* In the "Highlight" field, you can set some words that will always be highlighted in on-screen assignments.  Separate multiple words with commas or spaces.  Typically, you will want to set this to your name and any short versions of it that are commonly used.  If you add the special word "Group" into the list of highlights, then raid group numbers (ie "G1", "G2", etc) that appear in assignments will always be highlighted whenever you are a part of that group.
* You may wish to turn on the "Hide on Combat" option which will automatically hide the on-screen assignments whenever you get into combat.  You can always bring them back up during combat by using the keybinding (or other methods mentioned above).
* You can configure the font face, size, color, and outline style that will be used for the on-screen assignments.  You can also configure the color used for highlighted words.
* The "Toggle Window" and "Scale" features here are used for the edit window that officers/raid assistants use to edit assignments.  If you are not going to be doing that, then you can safely ignore them.

For initial setup, unlock the on-screen display if necessary (use the button mentioned above, or "/aa lock", or the keybinding if you set one for it), and you should see a red horizontal strip.  You can adjust the width of the strip (long lines will be word-wrapped as needed) and place it in whatever location you want.  The up/down arrow at the far left of the strip will determine whether the assignments text goes up or down from the location at which you place the strip.  When you're done, click the lock on the strip and it will disappear from view.

During raids, whenever any change in assignments occurs, the new assignments will re-appear on your screen if you had hidden them (along with a noticeable visual indicator).  They will auto-hide during combat, if you selected that option above, but you can bring them back up at any time during combat by using the Toggle Display keybinding or other methods.  If you re-log or reload your UI during the raid, your addon will pull information from the raid leader to get back in sync (if you are the raid leader yourself, it will use saved data).  Upon leaving the raid, the on-screen assignments will go away.  

Using AA as an officer/raid assistant
---------------------------------------------------

Editing of assignment pages and changing of on-screen display is restricted to officers in your guild , and people who are raid assistants in a raid you're in (if the raid is led by a guild officer).  Officer ranks in your guild are autodetected based on which ranks have officer chat access.  Each player's addon will reject any page changes or display requests from unauthorized players.

You will likely want to configure a keybinding for "Toggle Window" in the game keybindings.  This brings up the edit window, which is what officers and raid assistants will use to modify the assignment pages.  The edit window can be scaled up or down via the "Scale" parameter in the configuration menu (or via "/aa scale").

The edit window contains a list of assignment pages you have on the left.  When you select one, you'll see the current contents of that page on the right.  You can "Add", "Rename", and "Delete" pages via the buttons at the far bottom left.

When editing pages, you'll have several buttons of interest:

* "Accept" will become available after you've begun changing a page.  It will save changes to the page, update its timestamp, and send the updated version to everyone online in the guild (replacing whatever version they may have had).  "Accept" does not change which page is currently displayed on-screen, but if the page you edited is the one being displayed, everyone will immediately see the new version (and if they had hidden their display, it will re-appear).
* "Revert" will become available after you've begun changing a page.  It will abandon your current edits, going back to the previous version of the page.
* "Restore" will recall the last version of the current page that you personally edited and accepted.  This can be used to get back to your "last good version" if someone else has made undesirable edits to the page in the meantime.  Note that if you want to save the restored version on top of the current version of the page, you still need to "Accept" after you "Restore", otherwise nothing really happens.  You can "Revert" to abort and go back to the current version of the page.
* "Send and Display" is only available while not actively editing a page.  It will update the timestamp on the page, send the current version to everyone online in the guild (replacing whatever version they may have had), and, if in a raid, make it the current on-screen display for everyone in the raid.  If you're not in a raid, it will display on-screen for you personally, so you can preview it.
* "Clear Displayed" will remove whatever on-screen display was currently in place, ie: everyone in the raid will now see nothing.  It doesn't affect the contents of any pages.

Within assignment pages, you can use raid symbols such as {rt1}, {rt2}, {circle}, {star}, etc.  {hs} or {healthstone} will insert the icon for a healthstone, and {bl} or {bloodlust} will insert the icon for bloodlust.  You can insert any other icon in the game using this syntax: {icon spell_holy_sealofprotection}.  Icon names can be looked up by going to a spell's page on [Wowhead](http://www.wowhead.com) and then clicking on the icon.  You can also use any UI escape sequences, see [WoWWiki's page](http://www.wowwiki.com/UI_escape_sequences) for a full list.

If someone else saves edits to a particular page while you are editing that page, you'll receive a pop-up box notifying you of the fact.  At that point, you can continue your edits and eventually overwrite their updated version by hitting "Accept", or alternatively you can hit "Revert" which will abandon your own edits, and instead bring up their updated version of the page.  (Tip: before you hit Revert, you might want to highlight the particular section you were working on, copy it with Ctrl+C, then hit Revert, highlight the same section in their version, and paste your changes on top of it with Ctrl+V).

Individual pages are identified internally with unique IDs.  The names seen in the edit window are only used for display purposes, so there can be multiple pages with the same name.  Much like an edit, if someone renames a page, that rename is sent out to everyone in the guild who's online at the time (others will get the rename later, whenever that page is next edited or sent).  Deletes, however, are only done locally - so if you delete a page, others will still have it.  If you've deleted a page, and later on someone else edits it or sends it, you'll get it back again.

Miscellaneous
--------------------

The "/aa help" command will list all console commands.

The "/aa version" command (also available from the config menu) will perform a version check.  You'll be shown the current AA version of everyone in the guild, plus a list of players in your raid that aren't running AA.

The "/aa backup" command (also available from the config menu) will store the current version of every page for later "Restore" (similar to if you had just edited every page and made no actual changes).

The "/aa deleteall" command will delete all pages you have stored.  This could be used occasionally to clean out old assignment pages that are no longer used, for example, when beginning a new tier.  Of course, if others in the guild still have those pages, and choose to edit them and/or send them out for display, you'll get them back if you're online at the time.
