--[[
		Gotl - Guardians of the Light - Turalyon - Europe Server
		Zul Gurub Master Loot Addon
		
		Author: Rui Barreiros <rui@ngen.org>
		
		This addons automatically distributes equally coins/bijous by all the raid using 2 working modes
		Classes on mode:
			Takes classes into account when choosing the list of players allowed to get the coin/bijou
			so, when a coin/bijou for warriors, mages, priests for example drops only those classes will get
			them, and will always award the players with less ammount of coins/bijous

		Classes off mode:
			Evenly distributes the loot regardless the class
			
		Example:
		Suppose player A wins the first coin, he will only be allowed to get a 2nd coin when all the raid members
		(if classes are off) get also 1 coin or (if classes are on) he will only be allowed to roll if te players
		for wich the coin classes is needed have also 1 coin.
		
	$Id: GotlZgLoot.lua,v 1.6 2006/05/14 00:01:57 GotlZGLoot Exp $
	
	Changelog:
	14/05/2006: v 1.0.5
		William - Fixed a nasty bug introduced by previous condition fix on the ignore function
	29/04/2006: v 1.0.4
		WIlliam - Fixed a condition where it didn't let to choose either coins or bijous on the ignore function
		William - Added help cmd
	27/04/2006: v 1.0.4 - ALPHA
		William - New command added - quietroll - Only shows the winner of the roll instead of all that entered the roll
		William - Fixed GZGL_DeleteLoot function name
		William - Added DeleteLoot functionality
		William - Added ignore, unignore, showignore commands for ignoring players to enter into rolls
	xx/xx/xxxx: v 1.0.3
		William - Several small bug fixes and typos
	05/03/2006: v 1.0.2
		Tenin - Bug fix about debug info message not handling correctly the money on the loot
		William - Fixed a class discovery bug, was getting messed around when GetMasterLootCandidate wasn\'t returning a valid player name
		William - Added a small delay (3 secs) before parsing the next loot content, just to give enough time to give the previous loot to the player
	13/02/2006: v 1.0.1
		Fix on the routine to process loot, now processes correctly all the loot if it has more than 1 item and items that
		should be ignored by the addon (like random boe armor/weapons)
	12/02/2006: v 1.0.0
		First release
		
	Known Bugs:
	There are no known bugs atm, except that sometimes due to the time to deliver 1 item to a player, 
	often the 2nd item on the same loot is rolled but not delivered, it has to be done manually (trying to figure out a way of fixing this).
	
]]--

GZGL_SessionLoot = {};
GZGL_Config = {};

GZGL_VERSION = "1.0.5";

--[[

Basic function handlers for events, onload, onevent, command and config initializers

]]--

function GZGL_OnLoad()
	-- Register Events to listen to
	local frame = CreateFrame("FRAME", "FooAddonFrame");
	frame:RegisterEvent("VARIABLES_LOADED")
	frame:RegisterEvent("LOOT_OPENED")

	-- Reset config
	GZGL_InitConfig();

	-- Register chat command
	SLASH_GZGL1 = "/gzgl";
	SlashCmdList["GZGL"] = function (msg)
								GZGL_CmdHandler(msg);
						   end
	frame:SetScript("OnEvent", GZGL_OnEvent);
end

function GZGL_OnEvent(self, event)
	if(event == "VARIABLES_LOADED") then
		GZGL_Print("Gotl ZG Master Looter Loaded");
	end
	if (event == "LOOT_OPENED") then
		GZGL_ProcessLootOpen();
	end
end

function GZGL_InitConfig()
	if(GZGL_Config.accountClasses == nil) then
		GZGL_Config.accountClasses = false;
	end

	if(GZGL_Config.enabled == nil) then
		GZGL_Config.enabled = false;
	end
	
	if(GZGL_Config.debug == nil) then
		GZGL_Config.debug = false;
	end
	
	if(GZGL_Config.quietroll == nil) then
		GZGL_Config.quietroll = true;
	end
end

function GZGL_CmdHandler(msg)
	local msgArgs;
	local numArgs;

	msg = string.lower(msg);
	msgArgs = GetArgs(msg, " ");
	numArgs = table.getn(msgArgs);

	if(numArgs == 0) then -- display help
		GZGL_CmdHelp();
		return;
	end

	if (msgArgs[1] == "on") then
		GZGL_Config.enabled = true;
		GZGL_Print("Enabled");
	elseif (msgArgs[1] == "off") then
		GZGL_Config.enabled = nil;
		GZGL_Print("Disabled");
	elseif (msgArgs[1] == "classes") then
		if(msgArgs[2] ~= nil) then
			if(msgArgs[2] == "on") then
				GZGL_Config.accountClasses = true;
				GZGL_Print("Class Accounting Enabled");
			elseif (msgArgs[2] == "off") then
				GZGL_Config.accountClasses = nil;
				GZGL_Print("Class Accounting Disabled");
			end
		else
			GZGL_CmdHelp();
		end
	elseif (msgArgs[1] == "reset") then
		GZGL_ResetSessionLoot();
		GZGL_Print("Session Loot Reset");
	elseif (msgArgs[1] == "debug") then
		if(msgArgs[2] ~= nil) then
			if(msgArgs[2] == "on") then
				GZGL_Config.debug = true;
				GZGL_Print("Debug On");
			elseif (msgArgs[2] == "off") then
				GZGL_Config.debug = false;
				GZGL_Print("Debug Off");
			end
		else
			GZGL_CmdHelp();
		end
	elseif (msgArgs[1] == "saveloot") then
		if(msgArgs[2] ~= nil and msgArgs[3] ~= nil) then
			GZGL_SaveLoot(msgArgs[2], msgArgs[3]);
		else
			GZGL_CmdHelp();
		end
	elseif (msgArgs[1] == "deleteloot") then
		if(msgArgs[2] ~= nil) then
			GZGL_DeleteLoot(msgArgs[2], msgArgs[3]);
		else
			GZGL_CmdHelp();
		end
	elseif (msgArgs[1] == "showloot") then
		GZGL_ShowLoot(msgArgs[2]);
	elseif (msgArgs[1] == "quietroll") then
		if(msgArgs[2] == "on") then
			GZGL_Config.quietroll = true;
			GZGL_Print("Quiet Rolling is ON");
		else
			GZGL_Config.quietroll = false;
			GZGL_Print("Quiet Rolling is OFF");
		end
	elseif (msgArgs[1] == "ignore") then
		if(msgArgs[2] ~= nil) then
			GZGL_Ignore(msgArgs[2], msgArgs[3]);
		else
			GZGL_CmdHelp();
		end
	elseif (msgArgs[1] == "unignore") then
		if(msgArgs[2] ~= nil) then
			GZGL_UnIgnore(msgArgs[2]);
		else
			GZGL_CmdHelp();
		end
	elseif (msgArgs[1] == "showignore") then
		GZGL_ShowIgnoreList(msgArgs[2]);
	elseif (msgArgs[1] == "help") then
		GZGL_CmdHelp();
	end
end

function GZGL_CmdHelp()
	GZGL_Print("Gotl Zul Gurub Loot : v"..GZGL_VERSION);
	GZGL_Print("help                  :  This help message");
	GZGL_Print("on/off                :  Enable or Disable the addon");
	GZGL_Print("quietroll <on|off>    :  Enable or Disable Quiet Rolls, only shows the winner");
	GZGL_Print("classes <on|off>      :  Turn on or off the only classes that need the roll will be able to loot it feature");
	GZGL_Print("showloot [raid|party] :  Show what was looted so far");
	GZGL_Print("reset                 :  Cleanup all the saved loot");
	GZGL_Print("debug <on|off>        :  Turns on/off Debugging");
	GZGL_Print("saveloot <player> <shift-click item>  :  Saves into that player the item link (has to be a link)");
	GZGL_Print("deleteloot <player> [shift-click item]:  Deletes the item (has to be a link) from player loot, if no item is specified deletes all");
	GZGL_Print("ignore <player> [coins|bijous]        :  Removes the player from the loot, if the second argument is ommited, ignores all loot");
	GZGL_Print("unignore <player>     :  Removes the player from the ignored for loot state");
	GZGL_Print("showignore [raid|party] :  Displays a list of all ignore players and for what selected loot");
end

--[[

Event handlers, functions to process specific events

]]--

function GZGL_ProcessLootOpen()
	if(GZGL_PreCheck() == false) then
		return;
	end
   
	local lootItems = GetNumLootItems();
	if(lootItems >= 1) then
		-- Process all items in the loot
		for i=1, lootItems, 1 do
			-- If it's an item (not money), if it's a coin or a bijou (rari < 4) and is in our list of coins and bijous

			if(LootSlotHasItem(i)) then
				local loot = GZGL_GetLootInfo(i);
				GZGL_Print("Processing Loot: "..loot.itemLink, "", 1);
				
				if((loot.rari < 4) and (GZGL[loot.name] ~= nil)) then
					GZGL_Print("Valid loot, Getting Possible Players", "", 1);
				
					local possiblePlayers = GZGL_GetPossiblePlayer(loot);

					if(GZGL_Config.debug == true) then
						GZGL_Print("Chosen Players for loot: "..loot.itemLink, "", 1);
						for n=1, table.getn(possiblePlayers), 1 do
							GZGL_Print(possiblePlayers[n].name, "", 1);
						end
					end
				
					if(GZGL_Config.accountClasses == true and GZGL_Config.quietroll == false) then
						GZGL_Print("Rolling for Selected Classes: "..table.concat(GZGL[loot.name], ", "), "raid");
					end
				
					GZGL_Print("Rolling", "", 1);
					local maxRoll = table.getn(possiblePlayers);
					if(GZGL_Config.quietroll == false) then
						for c=1, maxRoll, 1 do
							if(possiblePlayers[c].name ~= nil) then
								GZGL_Print(c.." - "..possiblePlayers[c].name.." ("..possiblePlayers[c].class..")", "raid");
							end
						end
					end

					local winner = random(1, maxRoll);
					GZGL_Print("Roll: "..winner.." - "..possiblePlayers[winner].name.." wins: "..loot.itemLink, "raid");
				
					GZGL_Print("Delivering loot: "..loot.itemLink, "", 1);
					GZGL_DeliverLoot(possiblePlayers[winner], loot);
				else
					-- setup later, if auto boe loot on
				end
			else
				local loot = GZGL_GetLootInfo(i);
				-- setup later, if auto money loot on
				if(loot.quant == 0) then -- money
					-- Can't find a way of looting money automatically
				else
					-- Check is its a BoE and see who is BoE looter
					-- If BoE looter defined then auto-loot it
				end
			end
		end
	end
end

--[[

Miscelaneous functions

]]--

function GZGL_Ignore(player, itype)
	player = string.gsub(player, "^%l", string.upper)

	if(itype == nil) then
		itype = "all";
	elseif (itype ~= "coins" and itype ~= "bijous") then
		GZGL_Print("Invalid type " .. itype .. " only coins or bijous allowed");
		return;
	end

	-- init the table if it wasn't before
	if(GZGL_SessionLoot[player] == nil) then
		GZGL_Print("First player ".. player .." loot today, initing table", "", 1);
		GZGL_SessionLoot[player] = {};
		GZGL_SessionLoot[player].loot = {};
		GZGL_SessionLoot[player].coins = 0;
		GZGL_SessionLoot[player].bijous = 0;
		GZGL_SessionLoot[player].ignore = itype;
	else
		GZGL_SessionLoot[player].ignore = itype;
	end

	GZGL_Print("Player " .. player .. " Is currently being ignored on " .. itype);
	return;
end

function GZGL_UnIgnore(player)
	player = string.gsub(player, "^%l", string.upper)

	-- Is the player being ignored on any loot ?
	if(GZGL_SessionLoot[player] ~= nil) then
		if(GZGL_SessionLoot[player].ignore == nil) then
			GZGL_Print("The player " .. player .. " is not being ignored.");
			return;
		end
	else
		GZGL_Print("The player " .. player .. " is not being ignored.");
		return;
	end

	GZGL_SessionLoot[player].ignore = nil;
	GZGL_Print("Player " .. player .. " is not being ignored for loot anymore.");
	return;
end

-- adds to the player the loot
function GZGL_SaveLoot(player, item)
	GZGL_Print("Getting item ID", "", 1);
	
	local itemId = GZGL_GetIdFromItemLink(item);
	player = string.gsub(player, "^%l", string.upper)
	
	GZGL_Print("Item ID: "..itemId, "", 1);

	if(itemId == nil) then
		GZGL_Print("The linked item could not be found or it is not a valid shift-click link");
		return;
	end
	
	local lootInfo = {};
	lootInfo.itemId = itemId;
	lootInfo.name, lootInfo.link, lootInfo.rari, lootInfo.level, lootInfo.type, lootInfo.subType, lootInfo.quant = GetItemInfo(itemId);
	lootInfo.itemLink = GZGL_CreateItemLink(lootInfo);

	if(GZGL[lootInfo.name] == nil) then -- not a coin/bijou
		GZGL_Print("The item is not a coin or bijou");
		return;
	end

	GZGL_Print("Adding to player: " .. player .. " the loot " .. lootInfo.itemLink, "", 1);

	-- init the table if it wasn't before
	if(GZGL_SessionLoot[player] == nil) then
		GZGL_Print("First player ".. player .." loot today, initing table", "", 1);
		GZGL_SessionLoot[player] = {};
		GZGL_SessionLoot[player].loot = {};
		GZGL_SessionLoot[player].coins = 0;
		GZGL_SessionLoot[player].bijous = 0;
		GZGL_SessionLoot[player].ignore = nil;
	end

	-- Add the item to his loot table
	GZGL_Print("Adding itemlink to his loot table: "..lootInfo.itemLink, "", 1);
	table.insert(GZGL_SessionLoot[player].loot, lootInfo);
	
	-- Increase his coin/bijou loot count
	if(lootInfo.rari == 2) then
		GZGL_Print("Old Coin Player Count: "..GZGL_SessionLoot[player].coins, "", 1);
		GZGL_SessionLoot[player].coins = GZGL_SessionLoot[player].coins + 1;
		GZGL_Print("Current Coin Player Count: "..GZGL_SessionLoot[player].coins, "", 1);
	elseif(lootInfo.rari == 3) then
		GZGL_Print("Old Bijous Player Count: "..GZGL_SessionLoot[player].bijous, "", 1);
		GZGL_SessionLoot[player].bijous = GZGL_SessionLoot[player].bijous + 1;
		GZGL_Print("Current Bijous Player Count: "..GZGL_SessionLoot[player].bijous, "", 1);
	end	
end

-- deletes the item (or all items) from player loot
function GZGL_DeleteLoot(player, item)
	GZGL_Print("Getting item ID", "", 1);
	
	local itemId = GZGL_GetIdFromItemLink(item);
	player = string.gsub(player, "^%l", string.upper)
	
	GZGL_Print("Item ID: "..itemId, "", 1);

	if(itemId == nil) then
		GZGL_Print("The linked item could not be found or it is not a valid shift-click link");
		return;
	end

	local lootInfo = {};
	lootInfo.itemId = itemId;
	lootInfo.name, lootInfo.link, lootInfo.rari, lootInfo.level, lootInfo.type, lootInfo.subType, lootInfo.quant = GetItemInfo(itemId);
	lootInfo.itemLink = GZGL_CreateItemLink(lootInfo);
	
	if(GZGL[lootInfo.name] == nil) then -- not a coin/bijou
		GZGL_Print("The item is not a coin or bijou");
		return;
	end

	GZGL_Print("Removing from player: " .. player .. " the loot " .. lootInfo.itemLink, "", 1);

	if(GZGL_SessionLoot[player] == nil) then
		GZGL_Print("The player hasn't looted anything yet.");
		return;
	end

	-- Search if the player has it
	for idx, loot in GZGL_SessionLoot[player].loot do
		if(loot.itemId == lootInfo.itemId) then
			GZGL_Print("Item " .. loot.itemLink .. " Removed from player " .. player, "", 1);
			table.remove(GZGL_SessionLoot[player].loot, idx);

			if(loot.rari == 2) then
				GZGL_Print("Old Coin Player Count: " .. GZGL_SessionLoot[player].coins, "", 1);
				GZGL_SessionLoot[player].coins = GZGL_SessionLoot[player].coins - 1;
				GZGL_Print("Current Coin Player Count: " .. GZGL_SessionLoot[player].coins, "", 1);
				return;
			elseif (loot.rari == 3) then
				GZGL_Print("Old Bijou Player Count: " .. GZGL_SessionLoot[player].bijous, "", 1);
				GZGL_SessionLoot[player].bijous = GZGL_SessionLoot[player].bijous - 1;
				GZGL_Print("Current Bijou Player Count: " .. GZGL_SessionLoot[player].bijous, "", 1);
				return;
			end
		end
	end

	-- If it reaches here, item wasn't found on the player
	GZGL_Print("Item " .. lootInfo.itemLink .. " not found on player " .. player);
	return;
end

-- get id from item link
function GZGL_GetIdFromItemLink(itemLink)
    --local output = "";
    --for i = 1, string.len( itemLink ) do
        --output = output .. string.sub( itemLink, i, i ) .. " ";
    --end
	
    for itemid in string.gmatch(itemLink, ":(%d+):" ) do
        return itemid;
    end
end

-- creates a link for an item
function GZGL_CreateItemLink(loot)
	local r,g,b,hex = GetItemQualityColor(loot.rari);
	return hex .. "|Hitem:" .. loot.itemId .. ":0:0:0|h[" .. loot.name .. "]|h|r";
end

-- Displays the current player ignore list
function GZGL_ShowIgnoreList(showto)
	local hasIgnore = false;

	for key, value in ipairs(GZGL_SessionLoot) do
		if(GZGL_SessionLoot[key].ignore ~= nil) then
			GZGL_Print("Player " .. key .. " is being ignored for " .. GZGL_SessionLoot[key].ignore .. " loot.", showto);
			hasIgnore = true;
		end
	end

	if(hasIgnore == false) then
		GZGL_Print("No players are currently being ignored for loot.", showto);
	end
end

-- shows the current loot table
function GZGL_ShowLoot(showto)
	local hasLoot = false;

	for key, value in ipairs(GZGL_SessionLoot) do
		local rstr = key..": ";
	  
		if(GZGL_SessionLoot[key].coins ~= nil) then
			rstr = rstr .."Coins: "..GZGL_SessionLoot[key].coins;
		end
	
		if(GZGL_SessionLoot[key].bijous ~= nil) then
			rstr = rstr .." Bijous: "..GZGL_SessionLoot[key].bijous.." ";
		end

		local lstr = "";
		if(GZGL_SessionLoot[key].loot ~= nil) then
			if(table.getn(GZGL_SessionLoot[key].loot) > 0) then
				for i=1, table.getn(GZGL_SessionLoot[key].loot), 1 do
					if(GZGL_SessionLoot[key].loot[i] ~= nil) then
						lstr = lstr .. GZGL_SessionLoot[key].loot[i].itemLink .. " ";
					end
				end
			end
		end

		if(showto == "raid" or showto == "party") then
			GZGL_Print(rstr .. " " .. lstr, showto);
		else
			GZGL_Print(rstr .. " " .. lstr);
		end
		hasLoot = true;
	end
	
	if(hasLoot == false) then
		GZGL_Print("There is no loot saved");
	end
end

-- cleans up all loot saved
function GZGL_ResetSessionLoot()
	GZGL_SessionLoot = nil;
	GZGL_SessionLoot = {};
end

-- Returns a table with all the info of the loot item
function GZGL_GetLootInfo(slot)
	local lootInfo = {};
	lootInfo.itemIndex = slot;
	lootInfo.icon, lootInfo.name, lootInfo.quant, lootInfo.currencyID, lootInfo.rari, lootInfo.locked = GetLootSlotInfo(slot);
	
	-- 28/02/2006
	-- BUG FIX: when in debug mode, some debug messages do not handle the coins (money loot) correctly
	-- Fixed by Tenin @ Gotl
	if(lootInfo.quant > 0) then
		lootInfo.itemLink = GetLootSlotLink(slot);
		lootInfo.itemId = GZGL_GetIdFromItemLink(lootInfo.itemLink);
	else
		lootInfo.itemLink = lootInfo.name;
		lootInfo.itemId = 0;
	end
	
	lootInfo.itemDescr = lootInfo.quant.." x "..lootInfo.itemLink;
	return lootInfo;
end

-- finds the highest looted bijous on 1 player
function GZGL_GetBijousHighestCount()
	GZGL_Print("Inside GZGL_GetBijousHighestCount", "", 1);
	local lootCount = 0;
	
	for player, value in GZGL_SessionLoot do
		GZGL_Print("Player "..player.." has "..GZGL_SessionLoot[player].bijous.." bijous", "", 1);
		if(GZGL_SessionLoot[player].bijous > lootCount) then
			lootCount = GZGL_SessionLoot[player].bijous;
			GZGL_Print("Loot count changed to "..lootCount, "", 1);
		end
	end
	
	GZGL_Print("Final loot Count: "..lootCount, "", 1);
	return lootCount;
end

-- finds the highest looted coins in 1 player
function GZGL_GetCoinsHighestCount()
	GZGL_Print("Inside GZGL_GetCoinsHighestCount", "", 1);
	local lootCount = 0;
	
	for player, value in ipairs(GZGL_SessionLoot) do
		if(GZGL_SessionLoot[player] ~= nil) then
			GZGL_Print("Player "..player.." has "..GZGL_SessionLoot[player].coins.." coins", "", 1);
			if(GZGL_SessionLoot[player].coins > lootCount) then
				lootCount = GZGL_SessionLoot[player].coins;
				GZGL_Print("Loot count changed to "..lootCount, "", 1);
			end
		end
	end

	GZGL_Print("Final loot Count: "..lootCount, "", 1);
	return lootCount;
end

--
function GZGL_SelectCoinsLeastAwarded(playerList)
	GZGL_Print("Inside GZGL_SelectCoinsLeastAwarded", "", 1);
	local selected = {};
	local lootCount = GZGL_GetCoinsHighestCount();

	for i=1, table.getn(playerList), 1 do
		if(playerList[i].name ~= nil) then
			GZGL_Print("Checking player "..playerList[i].name, "", 1);
			if(GZGL_SessionLoot[playerList[i].name] == nil) then -- no loot yet, enters automatically
				if(GZGL_SessionLoot[playerList[i].name].ignore == "all" or GZGL_SessionLoot[playerList[i].name].ignore == "coins") then
					GZGL_Print(playerList[i].name.." ignored from coins loot", "", 1);
				else
					GZGL_Print(playerList[i].name.." hasn't looted yet", "", 1);
					table.insert(selected, playerList[i]);
				end
			else
				GZGL_Print(playerList[i].name.." has loot "..GZGL_SessionLoot[playerList[i].name].coins.." coins", "", 1);
				if(GZGL_SessionLoot[playerList[i].name].ignore == "all" or GZGL_SessionLoot[playerList[i].name].ignore == "coins") then
					GZGL_Print(playerList[i].name.." ignored from coins loot", "", 1);
				else
					if(GZGL_SessionLoot[playerList[i].name].coins < lootCount) then
						GZGL_Print(playerList[i].name.." allowed to roll", "", 1);
						table.insert(selected, playerList[i]);
					end
				end
			end
		end
	end

	if(table.getn(selected) < 1) then
		GZGL_Print("All have the same ammount of loot, all enter roll", "", 1);
		return playerList;
	else
		GZGL_Print("Not all have the same ammount of loot", "", 1);
		return selected;
	end
end

--
function GZGL_SelectBijousLeastAwarded(playerList)
	GZGL_Print("Inside GZGL_SelectBijousLeastAwarded", "", 1);
	local selected = {};
	local lootCount = GZGL_GetBijousHighestCount();

	for i=1, table.getn(playerList), 1 do
		if(playerList[i].name ~= nil) then
			GZGL_Print("Checking player "..playerList[i].name, "", 1);
			if(GZGL_SessionLoot[playerList[i].name] == nil) then -- no loot yet, enters automatically
				if(GZGL_SessionLoot[playerList[i].name].ignore == "all" or GZGL_SessionLoot[playerList[i].name].ignore == "bijous") then
					GZGL_Print(playerList[i].name.." ignored from bijous loot", "", 1);
				else
					GZGL_Print(playerList[i].name.." hasn't looted yet", "", 1);
					table.insert(selected, playerList[i]);
				end
			else
				GZGL_Print(playerList[i].name.." has loot "..GZGL_SessionLoot[playerList[i].name].bijous.." bijous", "", 1);
				if(GZGL_SessionLoot[playerList[i].name].ignore == "all" or GZGL_SessionLoot[playerList[i].name].ignore == "bijous") then
					GZGL_Print(playerList[i].name.." ignored from bijous loot", "", 1);
				else
					if(GZGL_SessionLoot[playerList[i].name].bijous < lootCount) then
						GZGL_Print(playerList[i].name.." allowed to roll", "", 1);
						table.insert(selected, playerList[i]);
					end
				end
			end
		end
	end

	if(table.getn(selected) < 1) then
		GZGL_Print("All have the same ammount of loot, all enter roll", "", 1);
		return playerList;
	else
		GZGL_Print("Not all have the same ammount of loot", "", 1);
		return selected;
	end
end

-- return a table with all the players candidate to loot based on they're class
-- and the item that is required class for
function GZGL_GetPossiblePlayer(loot)
	GZGL_Print("Geting Possible Players to roll on " .. loot.itemLink, "", 1);
	local rollPlayers = {};
	local name, tmp;
   
	for i=1, GetNumGroupMembers(), 1 do
		name = GetMasterLootCandidate(loot.itemIndex, i);
		-- if name == nil means that the player in that index (i) cannot get any loot from the master loor
		-- (maybe the player is either in another zone, or was dead and released after the mob died etc
		if(name ~= nil) then
			tmp = nil; -- i had some bad experiences to reset some tables only by asigning an empty {} table, just a 'let's make sure it cleaned correctly'
			tmp = {};
			tmp.name = name;
			tmp.idx = i;
			tmp.class = GZGL_GetClass(name);
	
			if(GZGL_Config.accountClasses == true) then
				GZGL_Print("Taking classes into account", "", 1);
				for c=1, table.getn(GZGL[loot.name]), 1 do
					GZGL_Print("Player : "..tmp.name.." Class: "..tmp.class, "", 1);
					if(string.lower(class) == string.lower(GZGL[loot.name][c])) then
						GZGL_Print("Player :"..tmp.name.. " allowed to enter draw", "", 1);
						table.insert(rollPlayers,  tmp);
					end
				end
			else
				GZGL_Print("Not taking classes into account, all enter", "", 1);
				table.insert(rollPlayers,  tmp);
			end
		end
	end

	-- Now let's select those with the least ammount of coins/bijous
	GZGL_Print("Getting least awarded players", "", 1);
	local leastAwarded = rollPlayers;

	if(loot.rari == 2) then -- coins
		leastAwarded = GZGL_SelectCoinsLeastAwarded(rollPlayers);
	elseif (loot.rari == 3) then -- bijous
		leastAwarded = GZGL_SelectBijousLeastAwarded(rollPlayers);
	end

	GZGL_Print("Least Awarded Players are:", "", 1);
	if(GZGL_Config.debug == true) then
		for i=1, table.getn(leastAwarded), 1 do
			GZGL_Print(leastAwarded[i].name, "", 1);
		end
	end

	return leastAwarded;
end

-- Delivers the loot to the winner and updates the current loot table
function GZGL_DeliverLoot(playerName, lootInfo)
	GZGL_Print("Delivering loot: ".. lootInfo.itemLink, "", 1);
	local idxName = GetMasterLootCandidate(lootInfo.itemIndex, playerName.idx);
	local idx = playerName.idx;

	if(idxName ~= playerName.name) then -- problem here, player changed or left
		GZGL_Print("Either player changed place or left, searching his new position.", "", 1);
		for i=1, GetNumGroupMembers(), 1 do
			local name = GetMasterLootCandidate(lootInfo.itemIndex, i);
			if(name == playerName.name) then -- found him, he just changed place
				GZGL_Print("Player found in a new position.", "", 1);
				idx = i;
				idxName = name;
				break;
			end
		end

		if(idx == playerName.idx) then -- we didn't found him, send warning, request manual intervention
			GZGL_Print("Player not found, must have left the raid.", "", 1);
			GZGL_Print("Player named: "..playerName.name.." has left the raid or changed places, impossible to find!!", "raid");
			GZGL_Print("Manual intervention required, aborting the delivery of the item: "..lootInto.itemLink, "raid");
			return;
		end
	end

	-- we got him, deliver, and save the data to the current session
	GZGL_Print("Giving Loot: " .. lootInfo.itemIndex .. " to " .. idxName);
	GiveMasterLoot(lootInfo.itemIndex, idx);
   
	-- init the table if it wasn't before
	if(GZGL_SessionLoot[idxName] == nil) then
		GZGL_Print("First player ".. idxName .." loot today, initing table", "", 1);
		GZGL_SessionLoot[idxName] = {};
		GZGL_SessionLoot[idxName].loot = {};
		GZGL_SessionLoot[idxName].coins = 0;
		GZGL_SessionLoot[idxName].bijous = 0;
		GZGL_SessionLoot[idxName].ignore = nil;
	end

	-- Add the item to his loot table
	GZGL_Print("Adding itemlink to his loot table: "..lootInfo.itemLink, "", 1);
	table.insert(GZGL_SessionLoot[idxName].loot, lootInfo);
	
	-- Increase his coin/bijou loot count
	if(lootInfo.rari == 2) then
		GZGL_Print("Old Coin Player Count: "..GZGL_SessionLoot[idxName].coins, "", 1);
		GZGL_SessionLoot[idxName].coins = GZGL_SessionLoot[idxName].coins + 1;
		GZGL_Print("Current Coin Player Count: "..GZGL_SessionLoot[idxName].coins, "", 1);
	elseif(lootInfo.rari == 3) then
		GZGL_Print("Old Bijous Player Count: "..GZGL_SessionLoot[idxName].bijous, "", 1);
		GZGL_SessionLoot[idxName].bijous = GZGL_SessionLoot[idxName].bijous + 1;
		GZGL_Print("Current Bijous Player Count: "..GZGL_SessionLoot[idxName].bijous, "", 1);
	end
end

-- Verifies if we should be enabled or not wheter were in a raid and Zul Gurub
-- it also needs to be set the Master Loot and we need to be master looter
function GZGL_PreCheck()
	if(GZGL_Config.enabled ~= true) then -- were disabled, just bail out
		return false;
	end

	local lootMethod, lootMaster = GetLootMethod();
	local realZone = GetRealZoneText();
   
	if( (lootMethod == "master") and (tonumber(lootMaster) == 0) and (realZone == "Zul'Gurub") and (GetNumGroupMembers() >= 1) ) then
		return true;
	else
		GZGL_Print("Not in master loot and were not the master looter or not in Zul'Gurub", "", 1);
		return false;
	end
end

-- returns the id in the raid of a player by name
function GZGL_GetIdFromPlayerName(pName)
	for i=1, GetNumGroupMembers(), 1 do
		name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i);
		if(string.lower(name) == string.lower(pName)) then
			return i;
		end
	end
end

-- Returns the class of the designated player
function GZGL_GetClass(raidIndex)
	for i=1, GetNumGroupMembers(), 1 do
		name, rank, subgroup, level, class, fileName, zone, online, isDead = GetRaidRosterInfo(i);
		if(string.lower(name) == string.lower(raidIndex)) then
			return class;
		end
	end
end


--[[
	General Print Function
		msg		-	The message to print
		target	-	The target to send the message to
		debug	-	Enable/Disable Debug message
		r		-	Red Value
		g		-	Green Value
		b		-	Blue Value
]]--
function GZGL_Print(msg, target, debug, r, g, b)
	local prefix = nil;
	local lr = 1.0;
	local lg = 0.6;
	local lb = 0.0;
	
	if(GZGL_Config.debug == false and debug ~= nil) then
		return;
	end
	
	if ( debug ~= nil ) then
		prefix = "<GotlZGLoot DEBUG> ";
	else
		prefix = "<GotlZGLoot> ";
	end
	if ( r ~= nil ) then
		lr = r;
	end
	if ( g ~= nil ) then
		lg = g;
	end
	if ( b ~= nil ) then
		lb = b;
	end
	if ( target == "raid" ) then
		SendChatMessage( prefix..msg, "RAID");
	else
		DEFAULT_CHAT_FRAME:AddMessage( prefix..msg, lr, lg, lb );
	end
end

--[[
Extract key/value from message.
]]--
function GetArgs(message, separator)

	-- Declare 'args' variable.
	local args = {};

	-- Declare 'i' integer.
	i = 0;

	-- Search for seperators in the string and return
	-- the separated data.
	for value in string.gmatch(message, "[^"..separator.."]+") do
		i = i + 1;
		args[i] = value;
	end -- end for

	-- Submit the filtered data.
	return args;
end -- end GetArgs()

