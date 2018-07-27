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

local movieExtensionSet = newSet{"avi","flv","mkv","mov","mp4","mpeg","mpg","ogm","ogv","swf","webm","wmv"} -- @Setting

--==============================================================
local addFile

function addFile(path)
	print(path)
	-- @@
end

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
--==============================================================
frame = wx.wxFrame(WX_NULL, WX_ID_ANY, "MyHappyList", WX_DEFAULT_POSITION, WxSize(1000, 400), WX_DEFAULT_FRAME_STYLE)

setTimerDummyOwner(frame)

frame:CreateStatusBar()
-- frame:SetStatusText("...")

frame:DragAcceptFiles(true)

on(frame, "DROP_FILES", function(e, paths)
	local pathsToAdd = {}

	for _, path in ipairs(paths) do
		local mode = getFileMode(path)

		if mode == "directory" then
			traverseFiles(path, function(path, pathRel, name, ext)
				if movieExtensionSet[ext:lower()] then
					table.insert(pathsToAdd, path)
				end

				if pathsToAdd[MAX_DROPPED_FILES+1] then
					return true -- Break.
				end
			end)

		elseif mode == "file" then
			table.insert(pathsToAdd, path)
		end

		if pathsToAdd[MAX_DROPPED_FILES+1] then
			showError(frame, "Error", F("Too many dropped files. (Max is %d)", MAX_DROPPED_FILES))
			return
		end
	end

	for _, path in ipairs(pathsToAdd) do
		addFile(toNormalPath(path))
	end
end)

--[[
local accelerators = {}
onAccelerator(frame, accelerators, "c", KC_1, function(e)
	print("Hello")
end)
setAccelerators(frame, accelerators)
--]]

-- Menus.
--==============================================================
local menuFile  = wx.wxMenu()
local menuEdit  = wx.wxMenu()
local menuDebug = wx.wxMenu()
local menuHelp  = wx.wxMenu()

-- File menu.
--------------------------------

newMenuItem(menuFile, frame, WX_ID_EXIT, "E&xit\tCtrl+Q", "Quit the program", function(e)
	frame:Close(true)
end)

-- Edit menu.
--------------------------------

newMenuItem(menuEdit, frame, "&Settings", "Change settings", function(e)
	showMessage(frame, "Settings", "@Incomplete")
end)

-- Debug menu.
--------------------------------

if DEBUG then
	newMenuItem(menuDebug, frame, "ping", function(e)
		anidb:ping()
	end)
	newMenuItem(menuDebug, frame, "login", function(e)
		anidb:login()
	end)

	newMenuItemSeparator(menuDebug)

	newMenuItem(menuDebug, frame, "getMylistByFile", function(e)
		anidb:getMylistByFile(getFileContents"local/exampleFilePathGb.txt")
	end)
	newMenuItem(menuDebug, frame, "addMylistByFile", function(e)
		anidb:addMylistByFile(getFileContents"local/exampleFilePathGb.txt")
	end)
	newMenuItem(menuDebug, frame, "deleteMylist x2", function(e)
		anidb:deleteMylist(115)
		anidb:deleteMylist(2468)
	end)

	newMenuItemSeparator(menuDebug)

	newMenuItem(menuDebug, frame, "clearMessageQueue", function(e)
		anidb:clearMessageQueue()
	end)
end

-- Help menu.
--------------------------------

newMenuItem(menuHelp, frame, "&Forum Thread", "Go to MyHappyList's forum thread on AniDB", function(e)
	showMessage(frame, "Link", "@Incomplete")
end)
-- newMenuItem(menuHelp, frame, "&Changes", "View the changelog", function(e)
-- 	showMessage(frame, "Changelog", "@Incomplete")
-- end)
newMenuItem(menuHelp, frame, WX_ID_ABOUT, "&Log", "Show text log", function(e)
	showMessage(frame, "Log", "@Incomplete")
end)
newMenuItem(menuHelp, frame, WX_ID_ABOUT, "&About", "About MyHappyList", function(e)
	showMessage(frame, "About MyHappyList", "@Incomplete")
end)

--------------------------------

local menuBar = wx.wxMenuBar()
menuBar:Append(menuFile,  "&File")
menuBar:Append(menuEdit,  "&Edit")
menuBar:Append(menuDebug, "&Debug")
menuBar:Append(menuHelp,  "&Help")
frame:SetMenuBar(menuBar)

-- AniDB update timer.
--==============================================================

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
--==============================================================
--[[
local panel = wx.wxPanel(frame, WX_ID_ANY)

local y = 0
local function addButton(caption, cb)
	local button = newButton(panel, caption, WxPoint(0, y), WxSize(150, 26), cb)
	y = y+button:GetSize():GetHeight()
end

addButton("ping", function(e) end)
newText(panel, "Text?", WxPoint(0, y))
]]

-- File list.
--==============================================================
local fileList = wx.wxListCtrl(
	frame, WX_ID_ANY, WX_DEFAULT_POSITION, WX_DEFAULT_SIZE,
	WX_LC_REPORT + WX_LC_HRULES --+ WX_LC_SORT_ASCENDING
)

listCtrlInsertColumn(fileList, "File", 800)
listCtrlInsertColumn(fileList, "Size")
listCtrlInsertColumn(fileList, "Watched")

listCtrlInsertItem(fileList, "Super_Anime_Ep_1.mkv", formatBytes(math.random(8000000, 350000000)), "Yes")
listCtrlInsertItem(fileList, "Super_Anime_Ep_2.mkv", formatBytes(math.random(8000000, 350000000)), "No")
listCtrlInsertItem(fileList, "Super_Anime_Ep_3.mkv", formatBytes(math.random(8000000, 350000000)), "No")

-- Sizer for frame.
--==============================================================
--[[ Is this needed?
local frameSizer = wx.wxBoxSizer(WX_VERTICAL)
frame:SetAutoLayout(true)
frame:SetSizer(frameSizer)

for _, child in eachChild(frame) do
	if not is(child, frame:GetStatusBar()) then
		frameSizer:Add(fileList, 1, WX_GROW+WX_ALL, 0)
	end
end
--]]

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
		if not deleteFile(path) then
			logprinterror(nil, "Could not delete file '%s'.", path)
		end
	end)
end

logprint(nil, "Exiting normally.")
logFile:close()
logFile = nil
