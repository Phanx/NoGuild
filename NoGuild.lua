--[[--------------------------------------------------------------------
	NoGuild
	Blocks guild solicitations in whispers and public chat channels.
	Written by Phanx <addons@phanx.net>
	This is free and unencumbered software released into the public domain.
	See the accompanying README and UNLICENSE files for more information.
	http://www.wowinterface.com/downloads/info22644-NoGuild.html
	http://www.curse.com/addons/wow/noguild/
----------------------------------------------------------------------]]

--	Almost all guild spam has at least one of these words.
local L1 = {
	"<", ">", "%%", "%*", "%d/%d", "%d%-%d", "%d:%d%d", "%d ?[ap]m",
	"bank tab",
	"fast track", "free guild repair", "free repair",
	"guild", "giuld", "gulid",
	"mount up", "mr. popularity", "mumble",
	"perk",
	"recruit", "reqruit",
	"teamspeak",
	"ventrilo",
	"monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
	"tues", "thurs?",
	-- German
	"%d ?uhr",
	"gilde[n%s]", "raid%-?tage",
	"montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag", "sonntag",
}

--	And probably at least one of these words.
local L2 = {
	"[{}]",
	"[^i]le?ve?l? ?%d",
	"active", "applicant", "apply",
	"casual", "consider[ei][dn]g?", "core",
	"exceptional", "e?xpe?r?i?e?n?c?e?",
	"farm", "fill", "focus", "fun",
	"goal",
	"hardcore", "helpful",
	"info", "interest", "invite",
	"join",
	"laid back", "looking",
	"member",
	"newly formed", "nice",
	"pacific", "progression", "pve", "pvp",
	"raid", "rbg", "repu?t?a?t?i?o?n?", "roster",
	"server time", "skilled", "social",
	"tabard", "times",
	"unlock",
	"ventr?i?l?o?",
	"want", "we are", "we plan t?on?", "weekend", "weekly", "would you like",
	-- German
	"atmosphäre", "farmen", "interesse", "leveln", "pflichten", "spaß", "verstärkung",
}

--	Guild spam usually does not contain these words.
local OK = {
	"^lf", "lfm", "lfg", "tank", "heal", "dps", "scenario", "ffa", "no reserve",
	"|ha?c?h?[iq][tu]?e[vms]", -- achievement/item/quest OK
	"wt[bs]",
}

------------------------------------------------------------------------

NoGuildMessages = {}

local format, strfind, strjoin, strlower, strmatch, tinsert, tostring, tremove, type
    = format, strfind, strjoin, strlower, strmatch, tinsert, tostring, tremove, type

local BNGetFriendToonInfo, BNGetNumFriends, BNGetNumFriendToons, CanComplainChat, UnitInParty, UnitInRaid, UnitIsInMyGuild
    = BNGetFriendToonInfo, BNGetNumFriends, BNGetNumFriendToons, CanComplainChat, UnitInParty, UnitInRaid, UnitIsInMyGuild

local function debug(str, ...)
	if (...) then
		if type(str) == "string" and strmatch(str, "%%[dfqsx%d%.]") then
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc33[NoGuild]|r " .. format(str, ...))
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc33[NoGuild]|r " .. strjoin(" ", tostringall(str, ...)))
		end
	elseif str then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffcc33[NoGuild]|r " .. tostring(str))
	end
end

------------------------------------------------------------------------

local seen, last, result = {}

local function exspaminate(self, event, message, sender, _, _, _, flag, _, channelID, _, _, line, guid)
	if line == last then
		return result
	end
	last, result = line, nil

	-- debug("[flag]", tostring(flag), "[line]", tostring(line), "[CanComplainChat]", tostring(CanComplainChat(line)))

	if flag == "GM" or flag == "DEV" then
		return --debug("ALLOWED [flag]", flag)
	end

	if event == "CHAT_MSG_CHANNEL" and (channelID == 0 or type(channelID) ~= "number") then
		-- Ignore custom channels
		return --debug("ALLOWED custom channel", channelID)
	end

	if not CanComplainChat(line) or UnitIsInMyGuild(sender) or UnitInRaid(sender) or UnitInParty(sender) then
		return --[[ debug("ALLOWED",
			"[CanComplainChat]", CanComplainChat(line),
			"[UnitIsInMyGuild]", UnitIsInMyGuild(sender),
			"[UnitInRaid]",      UnitInRaid(sender),
			"[UnitInParty]",     UnitInParty(sender)) ]]
	end

	if event == "CHAT_MSG_WHISPER" then
		local _, numBnetFriends = BNGetNumFriends()
		for i = 1, numBnetFriends do
			for j = 1, BNGetNumFriendToons(i) do
				local _, name, game = BNGetFriendToonInfo(i, j)
				if name == sender and game == "WoW" then
					return --debug("ALLOWED [BNGetFriendToonInfo]", i, j, name, game)
				end
			end
		end
	end

	local score = 0
	local messagelower = strlower(message)
	for i = 1, #L1 do
		if strfind(messagelower, L1[i]) then
			score = score + 2
		end
	end
	for i = 1, #L2 do
		if strfind(messagelower, L2[i]) then
			score = score + 1
		end
	end
	for i = 1, #OK do
		if strfind(messagelower, OK[i]) then
			score = score - 4
		end
	end

	if score > 3 then
		--debug("Blocked message with score %d from |Hplayer:%s:%d|h%s|h:", score, sender, line, sender)
		--debug("   ", message)
		if not seen[message] then
			tinsert(NoGuildMessages, 1, format("[%d] %s: %s", score, sender, message))
		end
		result = true
		return true
	end

	--if event == "CHAT_MSG_WHISPER" and score > 0 then
	--	debug("Allowed message with score %d from |Hplayer:%s:%d|h%s|h:", score, sender, line, sender)
	--end
	result = nil
end

------------------------------------------------------------------------

local enabled

local addon = CreateFrame("Frame")
addon:RegisterEvent("PLAYER_LOGIN")
addon:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		-- Spammers love that "personal touch"
		tinsert(L1, (UnitName("player")))

		self:UnregisterEvent("PLAYER_LOGIN")
		self:RegisterEvent("DISABLE_DECLINE_GUILD_INVITE")
		self:RegisterEvent("ENABLE_DECLINE_GUILD_INVITE")
		self:RegisterEvent("PLAYER_GUILD_UPDATE")
		self:RegisterEvent("PLAYER_LOGOUT")

	elseif event == "PLAYER_LOGOUT" then
		-- Truncate log
		while #NoGuildMessages > 100 do
			tremove(NoGuildMessages, #NoGuildMessages)
		end
		-- End
		return
	end

	local toenable = IsInGuild() or GetAutoDeclineGuildInvites() == 1
	if toenable == enabled then
		return
	end
	if toenable then
		-- Los!
		ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", exspaminate)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", exspaminate)
		enabled = true
	else
		-- Halt!
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CHANNEL", exspaminate)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", exspaminate)
		enabled = false
	end
end)