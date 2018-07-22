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
--==============================================================
--==============================================================

local anidbEventHandlers = {
	["loginsuccess"] = function()
		-- We probably want to perform a callback here from a previous action that required a login.
	end,
	["loginbadlogin"] = function()
		showError(frame, "Bad Login", "The username or password is incorrect.")
		frame:Close(true)
	end,
	["loginfail"] = function(userMessage)
		-- void
	end,

	["blackoutstart"] = function()
		-- void
	end,
	["blackoutstop"] = function()
		-- void
	end,

	["pingfail"] = function(userMessage)
		-- void
	end,

	["resend"] = function(command)
		-- void
	end,

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
--==============================================================
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

-- Main window.
----------------------------------------------------------------
frame = wx.wxFrame(WX_NULL, WX_ID_ANY, "MyHappyList", WX_DEFAULT_POSITION, WxSize(450, 450), WX_DEFAULT_FRAME_STYLE)

frame:CreateStatusBar()
-- frame:SetStatusText("...")

on(frame, "CLOSE_WINDOW", function(e)
	-- @@ Maybe save stuff.
	e:Skip()
end)

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

local anidbUpdateTimer = wx.wxTimer(frame)

on(frame, "TIMER", function(e)
	anidb:update()

	for eName, _1, _2, _3, _4, _5 in anidb:events() do
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

addButton("sendPing", function(e)
	anidb:sendPing()
end)

addButton("sendLogin", function(e)
	anidb:sendLogin()
end)

addButton("clearMessageQueue", function(e)
	anidb:clearMessageQueue()
end)

local textEl = newText(panel, "Text?", WxPoint(0, y))

--==============================================================
--==============================================================
--==============================================================

anidb = require"Anidb"()
anidbUpdateTimer:Start(1000/10)

frame:Center()
frame:Show(true)
wx.wxGetApp():MainLoop()

if anidb:isLoggedIn() then
	anidb:clearMessageQueue()
	anidb:sendLogout()
	anidb:update(true)
end
