-------------------------------------------------------------------------
-----------------------------   Server    -------------------------------
-------------------------------------------------------------------------

local players = {}
local waiting = {}
local connecting = {}
local prePoints = Config.PriorityAccess;
local EmojiList = Config.EmojiList

StopResource('hardcap')

AddEventHandler("playerConnecting", function(name, reject, def)
	local source	= source
	local steamID = GetSteamID(source)

	if not steamID then
		reject(_U("nosteam"))
		CancelEvent()
		return
	end

	if not Rocade(steamID, def, source) then
		CancelEvent()
	end
end)

function Rocade(steamID, def, source)
	def.defer()
    AntiSpam(def)
	Purge(steamID)
	AddPlayer(steamID, source)
	table.insert(waiting, steamID)

	local stop = false
	repeat

		for i,p in ipairs(connecting) do
			if p == steamID then
				stop = true
				break
			end
		end

		for j,sid in ipairs(waiting) do
			for i,p in ipairs(players) do
				if sid == p[1] and p[1] == steamID and (GetPlayerPing(p[3]) == 0) then
					Purge(steamID)
					def.done(_U("accident"))

					return false
				end
			end
		end

		def.update(GetMessage(steamID))
		Citizen.Wait(Config.TimerRefreshClient * 1000)

	until stop

	def.done()
	return true
end

Citizen.CreateThread(function()
	local maxServerSlots = GetConvarInt('sv_maxclients', 32)

	while true do
		Citizen.Wait(Config.TimerCheckPlaces * 1000)
		CheckConnecting()
		if #waiting > 0 and #connecting + #GetPlayers() < maxServerSlots then
			ConnectFirst()
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		UpdatePoints()

		Citizen.Wait(Config.TimerUpdatePoints * 1000)
	end
end)

RegisterServerEvent("emotion_queue:playerKicked")
AddEventHandler("emotion_queue:playerKicked", function(src, points)
	local sid = GetSteamID(src)
	Purge(sid)

	for i,p in ipairs(prePoints) do
		if p[1] == sid then
			p[2] = p[2] - points
			return
		end
	end

	local initialPoints = GetInitialPoints(sid)
	table.insert(prePoints, {sid, initialPoints - points})
end)

RegisterServerEvent("emotion_queue:playerConnected")
AddEventHandler("emotion_queue:playerConnected", function()
	local sid = GetSteamID(source)
	Purge(sid)
end)

AddEventHandler("playerDropped", function(reason)
	local steamID = GetSteamID(source)
	Purge(steamID)
end)

function CheckConnecting()
	for i,sid in ipairs(connecting) do
		for j,p in ipairs(players) do
			if p[1] == sid and (GetPlayerPing(p[3]) == 500) then
				table.remove(connecting, i)
				break
			end
		end
	end
end

function ConnectFirst()
	if #waiting == 0 then return end

	local maxPoint = 0
	local maxSid = waiting[1][1]
	local maxWaitId = 1

	for i,sid in ipairs(waiting) do
		local points = GetPoints(sid)
		if points > maxPoint then
			maxPoint = points
			maxSid = sid
			maxWaitId = i
		end
	end
	
	table.remove(waiting, maxWaitId)
	table.insert(connecting, maxSid)
end

function GetPoints(steamID)
	for i,p in ipairs(players) do
		if p[1] == steamID then
			return p[2]
		end
	end
end

function UpdatePoints()
	for i,p in ipairs(players) do

		local found = false

		for j,sid in ipairs(waiting) do
			if p[1] == sid then
				p[2] = p[2] + Config.AddPoints
				found = true
				break
			end
		end

		if not found then
			for j,sid in ipairs(connecting) do
				if p[1] == sid then
					found = true
					break
				end
			end
		
			if not found then
				p[2] = p[2] - Config.RemovePoints
				if p[2] < GetInitialPoints(p[1]) - Config.RemovePoints then
					Purge(p[1])
					table.remove(players, i)
				end
			end
		end

	end
end

function AddPlayer(steamID, source)
	for i,p in ipairs(players) do
		if steamID == p[1] then
			players[i] = {p[1], p[2], source}
			return
		end
	end

	local initialPoints = GetInitialPoints(steamID)
	table.insert(players, {steamID, initialPoints, source})
end

function GetInitialPoints(steamID)
	local points = Config.RemovePoints + 1

	for n,p in ipairs(prePoints) do
		if p[1] == steamID then
			points = p[2]
			break
		end
	end

	return points
end

function GetPlace(steamID)
	local points = GetPoints(steamID)
	local place = 1

	for i,sid in ipairs(waiting) do
		for j,p in ipairs(players) do
			if p[1] == sid and p[2] > points then
				place = place + 1
			end
		end
	end
	
	return place
end

function GetMessage(steamID)
	local msg = ""

	if GetPoints(steamID) ~= nil then
		msg = _U("inqueue") .. " " .. GetPoints(steamID) .." " .. _U("route") ..".\n"

		msg = msg .. _U("position") .. GetPlace(steamID) .. "/".. #waiting .. " " .. ".\n"

		msg = msg .. "[ " .. _U("emojimassage")

		local e1 = RandomEmojiList()
		local e2 = RandomEmojiList()
		local e3 = RandomEmojiList()
		local emojis = e1 .. e2 .. e3

		if( e1 == e2 and e2 == e3 ) then
			emojis = emojis .. _U("emojiboost")
			LoterieBoost(steamID)
		end

		msg = msg .. emojis .. " ]"
	else
		msg = _U("error")
	end

	return msg
end

function LoterieBoost(steamID)
	for i,p in ipairs(players) do
		if p[1] == steamID then
			p[2] = p[2] + Config.LoterieBonusPoints
			return
		end
	end
end

function Purge(steamID)
	for n,sid in ipairs(connecting) do
		if sid == steamID then
			table.remove(connecting, n)
		end
	end

	for n,sid in ipairs(waiting) do
		if sid == steamID then
			table.remove(waiting, n)
		end
	end
end

function AntiSpam(def)
	for i=Config.AntiSpamTimer,0,-1 do
		def.update(_U("pleasewait") .. i .. _U("seconds"))
		Citizen.Wait(1000)
	end
end

function RandomEmojiList()
	randomEmoji = EmojiList[math.random(#EmojiList)]
	return randomEmoji
end

function GetSteamID(src)
	local sid = GetPlayerIdentifiers(src)[1] or false

	if (sid == false or sid:sub(1,5) ~= "steam") then
		return false
	end

	return sid
end

-------------------------------------------------------------------------
-------------------------------   End    --------------------------------
-------------------------------------------------------------------------

--This handles the version check
local versioner = exports['bcc-versioner'].initiate()
local repo = 'https://github.com/Emotion06/emotion_queue'
versioner.checkRelease(GetCurrentResourceName(), repo)