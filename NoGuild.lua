--[[--------------------------------------------------------------------
	NoGuild
	Blocks guild solicitations in whispers and public chat channels.
	Copyright (c) 2013-2015 Phanx. All rights reserved.
	http://www.wowinterface.com/downloads/info22644-NoGuild.html
	http://www.curse.com/addons/wow/noguild/
	https://github.com/Phanx/NoGuild
----------------------------------------------------------------------]]

--	Almost all guild spam has at least one of these words.
local L1 = {
	-- All languages
	"<", ">", "%%", "%*", "%d/%d", "%d%-%d", "%d:%d%d", "%d ?[ap]m",
	"%f[%a]lf .*gu?ilde?%f[%A]", -- en/de
	-- English
	"bank tab",
	"free guild repair", "free repair",
	"guild", "guilld", "giuld", "gulid", -- people are really bad at typing
	"le?ve?l ?25",
	"main raid", "member", "memeber",
	"perk", "progressio?ng?", "pv[ep] guild",
	"raidi?n?g? ?team", "re[cq]ruit",
	"mumble", "teamspeak", "ventrilo",
	"http", "www", "%.com", "%.net", "%.org",
	"monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
	"tues", "thurs?",
	-- German
	"%d ?uhr",
	"bankfächern", "bewerbung",
	"ep bonus",
	"gegründet", "gesucht werden", "gilde[n%s]", "gildenboni", "gildenname", "gildensatzung", "gildenstamm", "gilde .+ such[te]", "gründung",
	"levelbon[iu]s?", "levelgilde", "lust auf.* gilde",
	"massen ?wie?der ?belebung", "mitstreiter",
	"pv[ep]%-?gilde",
	"raid%-?tage", "raidgilde", "raidorientert", "raidzeit", "rekrutier",
	"schnelleres reiten", "socius", "stammplatz", "stufe ?25", "%f[%a]such[est] .*gilde%f[%A]",
	"montag", "dienstag", "mittwoch", "donnerstag", "freitag", "samstag", "sonntag",
	-- Danish
	"dansk", "søger",
	-- Polish
	"gildia", "polski", "szuka",
	-- Swedish
	"söker lirare", "casualraida",
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
	"verpflichtung", "verstärkung", "wilkommen",
}

--	Guild spam usually does not contain these words.
local OK = {
	"|hachievement", "|hinstancelock", "|hitem", "|hquest", "|htrade",
	"arena", "[235]v[235]", " [235]s",
	"challenge mode", "cm gold", "flex", "^lf [^g][^u]", "lfm", "lfg", "scenario", -- "tank", "heal", "dps",
	"ffa", "no reserve",
	-- "galak", "%f[%a]sha%f[%A]", "%f[%a]soo%f[%A]",
	"%f[%a]wt[bs]%f[%A]",
	-- German
	"abend", "heute", "morgen",
	"gildengruppe", "herausforderung", "%f[%a]id%f[%A]", "kaufe", "rbg push", "szenario", "vk%f[%A]",
}

------------------------------------------------------------------------

NoGuildMessages = {}

local format, strjoin, strlower, strmatch, strtrim, tinsert, tostring, tremove, type
    = format, strjoin, strlower, strmatch, strtrim, tinsert, tostring, tremove, type

local BNGetFriendToonInfo, BNGetNumFriends, BNGetNumFriendToons, CanComplainChat, UnitInParty, UnitInRaid
    = BNGetFriendToonInfo, BNGetNumFriends, BNGetNumFriendToons, CanComplainChat, UnitInParty, UnitInRaid

local function debug(str, ...)
	if type(str) == "string" and strmatch(str, "%%[dfqsx%d%.]") then
		(DEBUG_CHAT_FRAME or ChatFrame3):AddMessage("|cffffcc33[NoGuild]|r " .. format(str, ...))
	elseif (...) then
		(DEBUG_CHAT_FRAME or ChatFrame3):AddMessage("|cffffcc33[NoGuild]|r " .. strjoin(" ", tostringall(str, ...)))
	elseif str then
		(DEBUG_CHAT_FRAME or ChatFrame3):AddMessage("|cffffcc33[NoGuild]|r " .. tostring(str))
	end
end

------------------------------------------------------------------------

local seen, last, result = {}

local function GetGuildSpamScore(message)
	local score = 0
	local messagelower = gsub(strlower(strtrim(message)), "{.-}", "")
	for i = 1, #L1 do
		if strmatch(messagelower, L1[i]) then
			score = score + 4
		end
	end
	for i = 1, #L2 do
		if strmatch(messagelower, L2[i]) then
			score = score + 1
		end
	end
	for i = 1, #OK do
		if strmatch(messagelower, OK[i]) then
			score = score - 4
		end
	end
	return score
end
--@debug@
_G.GetGuildSpamScore = GetGuildSpamScore
--@end-debug@

local function exspaminate(self, event, message, sender, _, _, _, flag, _, channel, _, _, line, guid)
	if line == last then
		return result
	end
	last, result = line, nil

	if event == "CHAT_MSG_CHANNEL" and (channel == 0 or type(channel) ~= "number") then
		-- Ignore custom channels
		return -- debug("ALLOWED custom channel:", channel)
	end

	if not CanComplainChat(line) then
		return -- debug("ALLOWED not CanComplainChat")
	end

	-- TODO: does CanComplainChat obviate this check?
	local stripper = Ambiguate(sender, "none")
	if UnitInRaid(stripper) or UnitInParty(stripper) then
		return -- debug("ALLOWED group member")
	end

	if event == "CHAT_MSG_WHISPER" then
		if flag == "GM" or flag == "DEV" then
			return -- debug("ALLOWED flag:", flag)
		end
		local _, numBnetFriends = BNGetNumFriends()
		for i = 1, numBnetFriends do
			for j = 1, BNGetNumFriendToons(i) do
				local _, name, game = BNGetFriendToonInfo(i, j)
				if name == sender and game == "WoW" then
					return -- debug("ALLOWED BNet friend:", i, j, name, game)
				end
			end
		end
	end

	local score = GetGuildSpamScore(message)
	if score > 3 then
		-- debug("Blocked message with score %d from |Hplayer:%s:%d|h%s|h:", score, sender, line, sender)
		-- debug("   ", message)
		if not seen[message] then
			tinsert(NoGuildMessages, 1, format("[%d] %s: %s", score, sender, message))
		end
		result = true
		return true
	end
	-- if event == "CHAT_MSG_WHISPER" and score > 0 then
		-- debug("Allowed message with score %d from |Hplayer:%s:%d|h%s|h:", score, sender, line, sender)
	-- end
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

		-- Guild Mail, Hasty Hearth, Mass Resurrection, Mobile Banking, Mount Up, The Quick and the Dead
		for _, spell in next, { 83951, 83944, 83968, 83958, 78633, 83950 } do
			local name = GetSpellInfo(spell)
			if name then
				tinsert(L1, strlower(name))
			end
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

	if GetAutoDeclineGuildInvites() then
		-- Los!
		ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", exspaminate)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", exspaminate)
	else
		-- Halt!
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_CHANNEL", exspaminate)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER", exspaminate)
	end
end)