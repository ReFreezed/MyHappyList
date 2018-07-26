--[[============================================================
--=
--=  App
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

local anidb
local frame

--==============================================================

local anidbEventHandlers = {
	["loginsuccess"] = function() end,
	["loginbadlogin"] = function()
		showError(frame, "Bad Login", "The username or password is incorrect.")
		frame:Close(true)
	end,
	["loginfail"] = function(userMessage) end,

	["mylistgetsuccess"] = function(what, ...)
		if what == "entry" then
			local mylistEntry = ...
			-- @@

		elseif what == "selection" then
			local mylistSelection = ...
			-- @@

		elseif what ~= "none" then
			logprinterror(nil, "mylistgetsuccess: Unknown what value '%s'.", what)
		end
	end,
	["mylistgetfail"] = function(userMessage) end,

	["mylistaddsuccess"] = function(mylistEntryPartial)
		-- anidb:getMylist(mylistEntryPartial.lid) -- @@
	end,
	["mylistaddsuccessmultiple"] = function(count)
		-- @@
	end,
	["mylistaddfoundmultiplefiles"] = function(fids)
		-- @@
	end,
	["mylistaddfail"] = function(userMessage) end,

	["mylistdeletesuccess"] = function(count)
		-- @@
	end,
	["mylistdeletefail"] = function(userMessage) end,

	["blackoutstart"] = function() end,
	["blackoutstop"] = function() end,

	["pingfail"] = function(userMessage) end,

	["resend"] = function(command) end,

	["newversionavailable"] = function(userMessage)
		-- @UX: A less intrusive "Update Available" notification.
		showMessage(frame, "Update Available", "A new version of MyHappyList is available.")
	end,
	["message"] = function(userMessage)
		showMessage(frame, "Message", userMessage)
	end,

	["errorresponsetimeout"] = function(command)
		showError(
			frame,
			"Timeout",
			"Got no response from AniDB in time. Maybe the server is offline or your Internet connection is down?"
				.."\n\nCommand: "..command
		)
	end,
	_error = function(eName, userMessage)
		showError(frame, "Error", F("%s: %s", eName, userMessage))
	end,
}

--==============================================================
--= Prepare Stuff ==============================================
--==============================================================

log("~~~ MyHappyList ~~~")
log(os.date"%Y-%m-%d %H:%M:%S")

--[[
for _, t in ipairs{wx, wxlua} do
	for k, v in pairs(t) do
		k = k:gsub("^wx", "")
		if not _G[k] then
			-- print("ADD>>>", k, v)
		else
			print("?", k, type(v), v)
		end
	end
end
--]]

assert(createDirectory("logs"))
logFile = assert(io.open("logs/output.log", "a"))

anidb = require"Anidb"()

-- Main window.
----------------------------------------------------------------
frame = wx.wxFrame(WX_NULL, WX_ID_ANY, "MyHappyList", WX_DEFAULT_POSITION, WxSize(450, 450), WX_DEFAULT_FRAME_STYLE)

setTimerDummyOwner(frame)

frame:CreateStatusBar()
-- frame:SetStatusText("...")

--[[
local accelerators = {}
onAccelerator(frame, accelerators, "c", KC_1, function(e)
	print("Hello")
end)
frame:SetAcceleratorTable(wx.wxAcceleratorTable(accelerators))
--]]

-- Menus.
----------------------------------------------------------------
local menuFile = wx.wxMenu()
-- local menuHelp = wx.wxMenu()

newMenuItem(frame, menuFile, WX_ID_EXIT, "E&xit\tCtrl+Q", "Quit the program", function(e)
	frame:Close(true)
end)

-- newMenuItem(frame, menuHelp, WX_ID_ABOUT, "&About", "About MyHappyList", function(e)
-- 	showMessage(frame, "About MyHappyList", "@Incomplete")
-- end)

local menuBar = wx.wxMenuBar()
menuBar:Append(menuFile, "&File")
-- menuBar:Append(menuHelp, "&Help")
frame:SetMenuBar(menuBar)

-- AniDB update timer.
----------------------------------------------------------------

local anidbUpdateTimer = newTimer(function(e)
	anidb:update()

	for eName, _1, _2, _3, _4, _5 in anidb:events() do
		logprint(nil, "Event: %s", eName)

		local handler = anidbEventHandlers[eName]
		if handler then
			handler(_1, _2, _3, _4, _5)

		elseif eName:find"^error" then
			anidbEventHandlers._error(eName, _1)
		end
	end
end)

-- Main panel.
----------------------------------------------------------------
local panel = wx.wxPanel(frame, WX_ID_ANY)

local y = 0
local function addButton(caption, cb)
	local button = newButton(panel, caption, WxPoint(0, y), WxSize(150, 26), cb)
	y = y+button:GetSize():GetHeight()
end

addButton("ping", function(e)
	anidb:ping()
end)
addButton("login", function(e)
	anidb:login()
end)

addButton("getMylistByFile", function(e)
	anidb:getMylistByFile(getFileContents"local/exampleFilePathGb.txt")
end)
addButton("addMylistByFile", function(e)
	anidb:addMylistByFile(getFileContents"local/exampleFilePathGb.txt")
end)
addButton("deleteMylist x2", function(e)
	anidb:deleteMylist(115)
	anidb:deleteMylist(2468)
end)

addButton("clearMessageQueue", function(e)
	anidb:clearMessageQueue()
end)

local textEl = newText(panel, "Text?", WxPoint(0, y))

--==============================================================
--= Show GUI ===================================================
--==============================================================

frame:Center()
frame:Show(true)

anidbUpdateTimer:Start(1000/10)
wx.wxGetApp():MainLoop()

--==============================================================
--= Exit =======================================================
--==============================================================

-- AniDB wants us to log out.
if anidb:isLoggedIn() then
	anidb:clearMessageQueue()
	anidb:logout()
	anidb:update(true)
end

-- Cleanup.
if isDirectory"temp" then
	traverseFiles("temp", function(path)
		local ok, err = os.remove(path)
		if not ok then
			logprinterror(nil, "Could not delete file '%s': %s", path, err)
		end
	end)
end

logprint(nil, "Exiting normally.")
logFile:close()
logFile = nil
