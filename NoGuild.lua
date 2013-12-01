------------------------------------------------------------------------
--	NoGuild
--	Block guild solicitations.
------------------------------------------------------------------------

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

local db, myName, myRealm
local last, result
local blockedThisSession, filterMessages, filterCount, replying = {}, {}, 0

local BNGetFriendToonInfo, BNGetNumFriends, BNGetNumFriendToons, CanComplainChat, GetAutoDeclineGuildInvites, IsInGuild, UnitInParty, UnitInRaid, UnitIsInMyGuild
	= BNGetFriendToonInfo, BNGetNumFriends, BNGetNumFriendToons, CanComplainChat, GetAutoDeclineGuildInvites, IsInGuild, UnitInParty, UnitInRaid, UnitIsInMyGuild
local format, strfind, strjoin, strlower, strmatch, tinsert, tostring, tremove, type
	= format, strfind, strjoin, strlower, strmatch, tinsert, tostring, tremove, type

local L = setmetatable({}, { __index = function(t, k)
	if k == nil then return "" end
	local v = tostring(k)
	rawset(t, k, v)
	return v
end })

local function print(str, ...)
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

local function debug(lvl, str, ...)
	if str and lvl <= 5 then
		if (...) then
			if type(str) == "string" and strmatch(str, "%%[dfqsx%d%.]") then
				DEFAULT_CHAT_FRAME:AddMessage("|cffffff77[NoGuild]|r " .. format(str, ...))
			else
				DEFAULT_CHAT_FRAME:AddMessage("|cffffff77[NoGuild]|r " .. strjoin(" ", tostringall(str, ...)))
			end
		else
			DEFAULT_CHAT_FRAME:AddMessage("|cffffff77[NoGuild]|r " .. tostring(str))
		end
	end
end

------------------------------------------------------------------------

local function FilterSystemMessage(self, event, message)
	if filterMessages[message] then
		debug(1, "CHAT_MSG_SYSTEM", message)
		filterMessages[message] = nil
		filterCount = filterCount - 1
		if filterCount == 0 then
			ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", FilterSystemMessage)
		end
		return true
	end
end

local function FilterOutgoingWhisper(self, event, message)
	if message == db.reply then
		debug(1, "CHAT_MSG_WHISPER_INFORM", message)
		ChatFrame_RemoveMessageEventFilter("CHAT_MSG_WHISPER_INFORM", FilterOutgoingWhisper)
		return true
	end
end

------------------------------------------------------------------------

local function FilterIncoming(self, event, message, sender, _, _, _, flag, _, _, _, _, line, guid)
	if line == last then
		return result
	end
	last, result = line, nil

	if GetAutoDeclineGuildInvites() == 0 and not IsInGuild() then
		return --debug(1, "ALLOWED [GetAutoDeclineGuildInvites]", tostring(GetAutoDeclineGuildInvites()), "[IsInGuild]", tostring(IsInGuild()))
	end

	--debug(2, "[flag]", tostring(flag), "[line]", tostring(line), "[CanComplainChat]", tostring(CanComplainChat(line)))

	if flag == "GM" or flag == "DEV" then
		return --debug(1, "ALLOWED [flag]", flag)
	end

	if event == "CHAT_MSG_CHANNEL" and (channelId == 0 or type(channelId) ~= "number") then
		-- Ignore custom channels
		return
	end

	if not CanComplainChat(line) or UnitIsInMyGuild(sender) or UnitInRaid(sender) or UnitInParty(sender) then
		return debug(1, "ALLOWED [CanComplainChat]", tostring(CanComplainChat(line) or "nil"),
			"[UnitIsInMyGuild]", tostring(UnitIsInMyGuild(sender) or "nil"),
			"[UnitInRaid]", tostring(UnitInRaid(sender) or "nil"),
			"[UnitInParty]", tostring(UnitInParty(sender) or "nil"))
	end

	if event == "CHAT_MSG_WHISPER" then
		for i = 1, select(2, BNGetNumFriends()) do
			for j = 1, BNGetNumFriendToons(i) do
				local _, name, game = BNGetFriendToonInfo(i, j)
				if name == sender and game == "WoW" then
					return debug(1, "ALLOWED [BNGetFriendToonInfo]", i, j, name, game)
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

	if score > 1 then
		if score > db.threshold then
			tinsert(NoGuildMessages[myRealm], format("[%d] %s: %s", score, sender, message))
			if db.debug then
				print(L["Blocked message with score %d from |Hplayer:%s:%d|h%s|h:"], score, sender, line, sender)
				print("   ", message)
			end

			if event == "CHAT_MSG_WHISPER" and db.reply then
				-- ### NODEBUG
				-- ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", FilterOutgoingWhisper)
				-- SendChatMessage(db.reply, "WHISPER", nil, sender)
			end

			local n = 1 + (blockedThisSession[sender] or 0)
			if n > db.ignore then
				if db.debug then
					print(L["Ignoring |Hplayer:%s:%d|h%s|h for sending more than %d guild ads this session."], sender, line, sender, db.ignore)
				end

				ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", FilterSystemMessage)

				local ignores = GetNumIgnores()
				while ignores > 45 do
					local oldest = tremove(db.history, 1)
					if not oldest then break end
					filterCount = filterCount + 1
					filterMessages[format(ERR_IGNORE_REMOVED_S, oldest)] = true
					-- ### DEBUG
					debug(1, "%d ignores, removing %s", ignores, oldest)
					DelIgnore(oldest)
					ignores = GetNumIgnores()
				end

				filterCount = filterCount + 1
				filterMessages[format(ERR_IGNORE_ADDED_S, sender)] = true
				-- ### DEBUG
				debug(1, "AddIgnore", sender)
				AddIgnore(sender)

				table.insert(db.history, sender)
			end
			blockedThisSession[sender] = n

			result = true
			return true
		end

		if db.debug then
			-- ### DEBUG
			debug(1, L["Allowed message with score %d from |Hplayer:%s|h%s|h."], score, sender, sender)
		end
	end

	result = nil
end

------------------------------------------------------------------------

local addon = CreateFrame("Frame")
addon:RegisterEvent("PLAYER_LOGIN")
addon:SetScript("OnEvent", function()
	local default = {
		debug = true,
		history = {},
		ignore = 0,
		reply = "[NoGuild] Your message was blocked because it looks like a guild solicitation, and I'm not looking for a guild right now.",
		threshold = 3,
	}
	NoGuildDB = NoGuildDB or {}
	db = NoGuildDB
	for k, v in pairs(default) do
		if db[k] == nil then
			db[k] = v
		end
	end

	myName = UnitName("player")
	myRealm = GetRealmName()

	tinsert(L1, myName) -- never seen a legit whisper that includes my character name, it's always spam of some kind

	NoGuildMessages = NoGuildMessages or {}
	NoGuildMessages[myRealm] = NoGuildMessages[myRealm] or {}

	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", FilterIncoming)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", FilterIncoming)
end)

------------------------------------------------------------------------

local panel = CreateFrame("Frame", nil, InterfaceOptionsFramePanelContainer)
panel.name = "NoGuild"
panel:Hide()

panel:SetScript("OnShow", function(self)
	if not panel.title then
		-- setup
	end
	-- refresh
end)

------------------------------------------------------------------------

SLASH_NOGUILD1 = "/noguild"
SLASH_NOGUILD2 = "/nog"

SlashCmdList["NOGUILD"] = function(cmd)
	cmd = cmd:trim()
	if cmd:lower() == "noreply" then
		db.reply = false
		print(L["Reply now disabled."])
	elseif cmd:len() > 0 then
		db.reply = "[NoGuild] " .. cmd
		print(L["Reply now set to:"], cmd)
	else
		print(L["Enter a new reply message, or use 'noreply' to disable replies."])
		if db.reply then
			print(L["Reply currently set to:"], db.reply:sub(11))
		else
			print(L["Reply currently disabled."])
		end
	end
end