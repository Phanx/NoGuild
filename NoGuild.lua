--[[--------------------------------------------------------------------
	NoGuild
	Blocks guild solicitations in whispers and public chat channels.
	Copyright (c) 2013-2014 Phanx. All rights reserved.
	See the accompanying README and LICENSE files for more information.
	http://www.wowinterface.com/downloads/info22644-NoGuild.html
	http://www.curse.com/addons/wow/noguild/
----------------------------------------------------------------------]]

--	Almost all guild spam has at least one of these words.
local L1 = {
	-- All languages
	"<", ">", "%%", "%*", "%d/%d", "%d%-%d", "%d:%d%d", "%d ?[ap]m",
	"%f[%a]lf .*gu?ilde?%f[%A]", -- en/de
	-- English
	"bank tab",
	"free guild repair", "free repair",
	"guild", "giuld", "gulid",
	"le?ve?l ?25",
	"main raid", "member", "memeber",
	"perk", "progressio?ng?", "pv[ep] guild",
	"recruit", "reqruit",
	"mumble", "teamspeak", "ventrilo",
	"http", "www", ".com", ".net", ".org",
	"monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
	"tues", "thurs?",
	-- German
	"%d ?uhr",
	"bankfächern", "bewerbung",
	"ep bonus",
	"gesucht werden", "gilde[n%s]", "gildenboni", "gildenname", "gildensatzung", "gildenstamm", "gilde .+ such[te]", "gründung",
	"levelbon[iu]s?", "levelgilde", "lust auf.* gilde",
	"massen ?wie?der ?belebung",
	"pv[ep]%-?gilde",
	"raid%-?tage", "raidgilde", "raidorientert", "raidzeit", "rekrutier",
	"schnelleres reiten", "socius", "stammplatz", "stufe ?25", "%f[%a]such[est] .*gilde%f[%A]",
	"montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag", "sonntag",
}

--	And probably at least one of these words.
local L2 = {
	"[^i]le?ve?l? ?%d",
	"active", "applicant", "apply",
	"casual", "consider[ei][dn]g?", "content", "core",
	"exceptional", "e?xpe?r?i?e?n?c?e?",
	"farm", "fill", "focus", "fun",
	"goal",
	"hardcore", "helpful",
	"info", "interest", "invite",
	"join",
	"laid back", "looking",
	"member",
	"newly formed", "nice",
	"pacific", "player", "progression", "pve", "pvp",
	"raid", "rbg", "realm", "repu?t?a?t?i?o?n?", "roster",
	"server time", "skilled", "social",
	"tabard", "times",
	"unlock",
	"ventr?i?l?o?",
	"want", "we are", "we plan t?on?", "weekend", "weekly", "would you like",
	-- German
	"18 jahren",
	"aktive", "anfänger", "atmosphäre", "aufz?u?bau", "bock",
	"entsprechend", "erfahren", "farmen", "gründe", "hoffe", "interesse", "klasse",
	"leveln", "lust", "möchte", "motivierte", "pflichten",
	"sozial", "spaß", "spiel", "stamm",
	"verplichtung", "verstärkung", "wilkommen",
}

--	Guild spam usually does not contain these words.
local OK = {
	"|hachivement", "|hinstancelock", "|hitem", "|hquest", "|htrade",
	"arena", "[235]v[235]", " [235]s",
	"challenge mode", "cm gold", "flex", "^lf ", "lfm", "lfg", "scenario", -- "tank", "heal", "dps",
	"ffa", "no reserve",
	-- "galak", "%f[%a]sha%f[%A]", "%f[%a]soo%f[%A]",
	"%f[%a]wt[bs]%f[%A]",
	-- German
	"abend", "heute", "morgen",
	"gildengruppe", "herausforderung", "%f[%a]id%f[%A]", "kaufe", "rbg push", "szenario", "vk%f[%A]",
}

------------------------------------------------------------------------

NoGuildMessages = {}

local format, strfind, strjoin, strlower, strmatch, strtrim, tinsert, tostring, tremove, type
    = format, strfind, strjoin, strlower, strmatch, strtrim, tinsert, tostring, tremove, type

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

local function GetGuildSpamScore(message)
	local score = 0
	local messagelower = gsub(strlower(strtrim(message)), "{.-}", "")--[[
	for i = 1, #L0 do
		if strfind(messagelower, L0[i]) then
			score = score + 10
		end
	end]]
	for i = 1, #L1 do
		if strfind(messagelower, L1[i]) then
			score = score + 4
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
	return score
end
_G.GetGuildSpamScore = GetGuildSpamScore

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

	local score = GetGuildSpamScore(message)

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

local addon = CreateFrame("Frame")
addon:RegisterEvent("PLAYER_LOGIN")
addon:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		-- Spammers love that "personal touch"
		local name = UnitName("player")
		tinsert(L1, strlower(name))

		-- Fast Track, Mount Up, Mr. Popularity
		for _, spell in ipairs({ 78631, 78633, 78634 }) do
			local name = GetSpellInfo(spell)
			if name then
				tinsert(L1, strlower(name))
			end
		end

		if NoGuildStatus == nil then
			SetAutoDeclineGuildInvites(1)
			NoGuildStatus = true
		end

		self:UnregisterEvent("PLAYER_LOGIN")
		self:RegisterEvent("DISABLE_DECLINE_GUILD_INVITE")
		self:RegisterEvent("ENABLE_DECLINE_GUILD_INVITE")
		self:RegisterEvent("PLAYER_GUILD_UPDATE")
		self:RegisterEvent("PLAYER_LOGOUT")

	elseif event == "PLAYER_LOGOUT" then
		-- Remove duplicate log entries
		local seen = {}
		for i = #NoGuildMessages, 1, -1 do
			local message = NoGuildMessages[i]
			if seen[message] then
				tremove(NoGuildMessages, i)
			else
				seen[message] = true
			end
		end
		-- Truncate log
		while #NoGuildMessages > 100 do
			tremove(NoGuildMessages, #NoGuildMessages)
		end
		-- End
		return
	end

	local enable = not not (IsInGuild() or GetAutoDeclineGuildInvites() == 1)
	if enable == NoGuildStatus and event ~= "PLAYER_LOGIN" then
		return
	end
	if enable then
		-- Los!
		ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", exspaminate)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", exspaminate)
	else
		-- Halt!
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CHANNEL", exspaminate)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", exspaminate)
	end
	NoGuildStatus = enable
end)