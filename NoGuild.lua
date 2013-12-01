--[[--------------------------------------------------------------------
	NoGuild
	Blocks guild solicitations in whispers and public chat channels.
	Written by Phanx <addons@phanx.net>
	This is free and unencumbered software released into the public domain.
	See the accompanying README and UNLICENSE files for more information.
	http://www.wowinterface.com/downloads/info-NoGuild.html
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
	"tues", "thurs",
}

--	And probably at least one of these words.
local L2 = {
	"[^i]le?ve?l? ?%d",
	"active", "applicant",
	"casual", "core",
	"exceptional", "e?xpe?r?i?e?n?c?e?",
	"farm", "fill", "focus", "fun",
	"goal",
	"hardcore", "helpful",
	"info", "interest", "invite",
	"join",
	"laid back", "looking",
	"member",
	"newly formed", "nice",
	"progression", "pve", "pvp",
	"raid", "rbg", "repu?t?a?t?i?o?n?", "roster",
	"server time", "skilled", "social",
	"tabard",
	"unlock",
	"ventr?i?l?o?",
	"want", "we are", "we plan t?on?", "weekend", "weekly", "would you like",
}

--	Guild spam usually does not contain these words.
local OK = { "tank", "heal", "dps", "lfm", "lfg", "scenario" }

------------------------------------------------------------------------

NoGuildMessages = {}

local format, strfind, strjoin, strlower, strmatch, tinsert, tostring, tremove, type
    = format, strfind, strjoin, strlower, strmatch, tinsert, tostring, tremove, type

local BNGetFriendToonInfo, BNGetNumFriends, BNGetNumFriendToons, CanComplainChat, GetAutoDeclineGuildInvites, IsInGuild, UnitInParty, UnitInRaid, UnitIsInMyGuild
    = BNGetFriendToonInfo, BNGetNumFriends, BNGetNumFriendToons, CanComplainChat, GetAutoDeclineGuildInvites, IsInGuild, UnitInParty, UnitInRaid, UnitIsInMyGuild

local function debug(lvl, str, ...)
	if str then
		if (...) then
			if type(str) == "string" and strmatch(str, "%%[dfqsx%d%.]") then
				DEFAULT_CHAT_FRAME:AddMessage("|cffffcc33[NoGuild]|r " .. format(str, ...))
			else
				DEFAULT_CHAT_FRAME:AddMessage("|cffffcc33[NoGuild]|r " .. strjoin(" ", tostringall(str, ...)))
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffffcc33[NoGuild]|r " .. tostring(str))
		end
	end
end

------------------------------------------------------------------------

local last, result

local function exspaminate(self, event, message, sender, _, _, _, flag, _, _, _, _, line, guid)
	if line == last then
		return result
	end
	last, result = line, nil

	if GetAutoDeclineGuildInvites() == 0 and not IsInGuild() then
		return -- debug("ALLOWED [GetAutoDeclineGuildInvites]", tostring(GetAutoDeclineGuildInvites()), "[IsInGuild]", tostring(IsInGuild()))
	end

	-- debug("[flag]", tostring(flag), "[line]", tostring(line), "[CanComplainChat]", tostring(CanComplainChat(line)))

	if flag == "GM" or flag == "DEV" then
		return -- debug("ALLOWED [flag]", flag)
	end

	if event == "CHAT_MSG_CHANNEL" and (channelId == 0 or type(channelId) ~= "number") then
		-- Ignore custom channels
		return
	end

	if not CanComplainChat(line) or UnitIsInMyGuild(sender) or UnitInRaid(sender) or UnitInParty(sender) then
		return --[[ debug("ALLOWED",
			"[CanComplainChat]", tostring(CanComplainChat(line)   or "nil"),
			"[UnitIsInMyGuild]", tostring(UnitIsInMyGuild(sender) or "nil"),
			"[UnitInRaid]",      tostring(UnitInRaid(sender)      or "nil"),
			"[UnitInParty]",     tostring(UnitInParty(sender)     or "nil")) ]]
	end

	if event == "CHAT_MSG_WHISPER" then
		local _, numBnetFriends = BNGetNumFriends()
		for i = 1, numBnetFriends do
			for j = 1, BNGetNumFriendToons(i) do
				local _, name, game = BNGetFriendToonInfo(i, j)
				if name == sender and game == "WoW" then
					return -- debug("ALLOWED [BNGetFriendToonInfo]", i, j, name, game)
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
		-- debug("Blocked message with score %d from |Hplayer:%s:%d|h%s|h:", score, sender, line, sender)
		-- debug("   ", message)
		tinsert(NoGuildMessages, 1, format("[%d] %s: %s", score, sender, message))
		result = true
		return true
	end

	result = nil
end

------------------------------------------------------------------------

local addon = CreateFrame("Frame")
addon:RegisterEvent("PLAYER_LOGIN")
addon:SetScript("OnEvent", function()
	-- Initialize log
	NoGuildMessages = NoGuildMessages or {}
	db = NoGuildMessages

	-- Truncate log
	for i = 50, #db do
		db[i] = nil
	end

	-- Spammers love that "personal touch"
	tinsert(L1, (UnitName("player")))

	-- Los!
	ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", exspaminate)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", exspaminate)
end)