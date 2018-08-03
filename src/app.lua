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

local FILE_INFO_DONT_SERIALIZE -- Set later.

local FILE_COLUMN_FILE -- Set later.
local FILE_COLUMN_FOLDER
local FILE_COLUMN_SIZE
local FILE_COLUMN_VIEWED
local FILE_COLUMN_STATUS

local MYLIST_STATUS_UNKNOWN = 0
local MYLIST_STATUS_NO      = 1
local MYLIST_STATUS_YES     = 2
local MYLIST_STATUS_INVALID = 3 -- AniDB don't know of the file (ed2k+size missing).  @Incomplete: Use this!

local DROP_FILES_TO_ADD_MESSAGE = "Drop files here to add them!"

local STATUS_BAR_FIELD_MESSAGE_QUEUE = 1

local frame
local statusBar
local fileList

local anidb
local appIcons
local bigBoldFont

local fileInfos  = {}
local lastFileId = 0 -- Local ID, not fid on AniDB.

local updateAvailableMessageReceived = false

local settings = {
	autoHash        = true,
	autoAddToMylist = false, -- @Incomplete

	movieExtensions = newSet{"avi","flv","mkv","mov","mp4","mpeg","mpg","ogm","ogv","swf","webm","wmv"},
	trunkateFolders = true,
}

--==============================================================
--==============================================================
--==============================================================

local setStatusText

local addFileInfo, removeFileInfo
local anyFileInfos, noFileInfos
local eachFileInfoByRow, getFileInfosByRows, getSelectedFileInfos
local getFileInfoByRow, getFileRow
local getFileStatus, getFileViewed
local saveFileInfos, loadFileInfos
local setFileInfo
local updateFileList



-- fileInfo = addFileInfo( path )
-- fileInfo = addFileInfo( fileInfo ) -- For loading phase.
FILE_INFO_DONT_SERIALIZE = newSet{"name","folder","isHashing"}
function addFileInfo(path)
	local fileInfo

	if type(path) == "table" then
		fileInfo = path
		path     = fileInfo.path

	else
		fileInfo = fileInfos[path]
		if fileInfo then  return fileInfo  end

		lastFileId = lastFileId+1

		fileInfo = {
			id           = lastFileId,

			path         = path,
			name         = "",
			folder       = "",

			ed2k         = "",
			size         = getFileSize(path),
			fid          = -1,

			mylistStatus = MYLIST_STATUS_UNKNOWN,
			lid          = -1,

			isHashing    = false,
		}
	end

	fileInfo.name      = getFilename(path)
	fileInfo.folder    = getDirectory(path)
	fileInfo.isHashing = false

	setAndInsert(fileInfos, path, fileInfo)

	if #fileInfos == 1 then
		fileList:DeleteItem(0)
		fileList:Enable(true)
	end

	local wxRow = listCtrlInsertRow(
		fileList, fileInfo.name, fileInfo.folder, formatBytes(fileInfo.size),
		getFileViewed(fileInfo), getFileStatus(fileInfo)
	)
	fileList:SetItemData(wxRow, fileInfo.id)

	if fileInfo.ed2k == "" and settings.autoHash then
		setFileInfo(fileInfo, "isHashing", true)
		anidb:hashFile(path)

	elseif fileInfo.lid == -1 and fileInfo.ed2k ~= "" and fileInfo.mylistStatus == MYLIST_STATUS_UNKNOWN then
		anidb:getMylistByEd2k(fileInfo.ed2k, fileInfo.size)

	elseif fileInfo.lid ~= -1 and fileInfo.fid == -1 then
		-- The app probably stopped before getting this info last session.
		anidb:getMylist(fileInfo.lid)
	end

	return fileInfo
end

function removeFileInfo(fileInfo)
	fileInfo = fileInfos[fileInfo.path]
	if not fileInfo then  return  end

	unsetAndRemove(fileInfos, fileInfo.path)

	local wxRow = getFileRow(fileInfo)
	fileList:DeleteItem(wxRow)

	if noFileInfos() then
		listCtrlInsertRow(fileList, DROP_FILES_TO_ADD_MESSAGE)
		listCtrlSelectRows(fileList)
		fileList:Enable(false)
	end
end



function updateFileList()
	if noFileInfos() then return end

	local commonFolder        = ""
	local allInSameFolder     = true
	local filesInCommonFolder = false

	-- Start the common folder value with a path that isn't the shortest.
	if fileInfos[2] then
		for _, fileInfo in ipairs(fileInfos) do
			if #fileInfo.folder > #commonFolder then
				commonFolder = fileInfo.folder
			end
		end
	end

	-- Narrow down the value to the actual common folder.
	for _, fileInfo in ipairs(fileInfos) do
		for ptr = 1, math.max(#fileInfo.folder, #commonFolder) do
			if fileInfo.folder:byte(ptr) ~= commonFolder:byte(ptr) then
				commonFolder        = commonFolder:sub(1, ptr-1)
				allInSameFolder     = false
				filesInCommonFolder = false
				break
			end
		end

		if #commonFolder <= 5 then
			commonFolder = ""
			break
		end

		if fileInfo.folder == commonFolder then
			filesInCommonFolder = true
		end
	end

	-- print(commonFolder, "allSame", allInSameFolder, "inCommon", filesInCommonFolder)

	local ptr    = (findPreviousChar(commonFolder, "/", #commonFolder) or 1)-1
	local prefix = commonFolder:sub(1, ptr)

	if #prefix <= 5 then  prefix = ""  end

	local usePrefix = (settings.trunkateFolders and prefix ~= "")

	for _, fileInfo in ipairs(fileInfos) do
		listCtrlSetItem(
			fileList,
			getFileRow(fileInfo),
			FILE_COLUMN_FOLDER,
			usePrefix and "..."..fileInfo.folder:sub(#prefix+1) or fileInfo.folder
		)
	end

	listCtrlSort(fileList, function(a, b)
		a = itemWith(fileInfos, "id",a)
		b = itemWith(fileInfos, "id",b)
		if a.folder ~= b.folder then
			return a.folder < b.folder and -1 or 1
		end
		if a.name ~= b.name then
			return a.name < b.name and -1 or 1
		end
		return 0 -- Should never happen.
	end)

	local colorStripe1 = wx.wxWHITE
	local colorStripe2 = wx.wxColour(245, 245, 245)

	for wxRow = 0, fileList:GetItemCount()-1 do
		local color = (wxRow%2 == 0 and colorStripe1 or colorStripe2)
		fileList:SetItemBackgroundColour(wxRow, color)
	end
end


do
	local FILE_INFO_VERSION = 1

	function saveFileInfos()
		local path = CACHE_DIR.."/files"

		backupFileIfExists(path)
		local file = assert(openFile(path, "w"))

		writeLine(file, FILE_INFO_VERSION)

		for _, fileInfo in ipairs(fileInfos) do
			writeLine(file) -- An empty line separates file entries.

			for k, v in pairsSorted(fileInfo) do
				if not FILE_INFO_DONT_SERIALIZE[k] then
					writeSimpleKv(file, k, v, path)
				end
			end
		end

		file:close()
	end

	function loadFileInfos()
		local path = CACHE_DIR.."/files"
		if not isFile(path) then  return  end

		local file = assert(openFile(path, "r"))
		local ln   = 0

		local fileInfo = nil

		local function finishEntry()
			if not fileInfo then  return  end

			if fileInfo.id then
				addFileInfo(fileInfo)
				lastFileId = math.max(fileInfo.id, lastFileId)
			else
				logprinterror(nil, "%s:%d: Missing ID for previous entry. Skipping.", path, ln)
			end

			fileInfo = nil
		end

		lastFileId = 0

		for line in file:lines() do
			ln = ln+1

			if ln == 1 then
				local ver = tonumber(line)
				if not (isInt(ver) and ver >= 1 and ver <= FILE_INFO_VERSION) then
					errorf("%s:%d: Missing or invalid version number.", path, ln)
				end

			elseif line == "" then
				finishEntry() -- An empty line separates file entries.

			else
				local k, v = parseSimpleKv(line, path, ln)

				if k then
					fileInfo = fileInfo or {}
					if fileInfo[k] ~= nil then
						logprinterror(nil, "%s:%d: Duplicate key '%s'. Overwriting.", path, ln, k)
					end
					fileInfo[k] = v
				end
			end
		end

		finishEntry()
		file:close()

		updateFileList()
	end
end



-- setFileInfo( fileInfo, key, value [, force=false ] )
function setFileInfo(fileInfo, k, v, force)
	if fileInfo[k] == v and not force then
		return
	end

	fileInfo[k] = v

	local wxRow = fileList:FindItem(-1, fileInfo.id)
	if wxRow == -1 then
		logprinterror(nil, "File %d is not in list.", fileInfo.id)
		return
	end

	if isAny(k, "lid","fid","ed2k","isHashing","mylistStatus") then
		fileList:SetItem(wxRow, FILE_COLUMN_VIEWED, getFileViewed(fileInfo))
		fileList:SetItem(wxRow, FILE_COLUMN_STATUS, getFileStatus(fileInfo))
	end
end



function getFileStatus(fileInfo)
	return
		nil
		or fileInfo.isHashing                         and "Calculating hash"
		or fileInfo.mylistStatus == MYLIST_STATUS_YES and "In MyList"
		or fileInfo.mylistStatus == MYLIST_STATUS_NO  and "Not in MyList"
		or fileInfo.ed2k         ~= ""                and "Hashed"
		or "Not hashed"
end

function getFileViewed(fileInfo)
	local lid = fileInfo.lid
	if lid == -1 then  return "?"  end

	local mylistEntry = anidb:getCacheMylist(lid)
	if not mylistEntry then  return "?"  end

	local time = mylistEntry.viewdate
	return time == 0 and "No" or os.date("%Y-%m-%d", time)
end



function getFileRow(fileInfo)
	local wxRow = fileList:FindItem(-1, fileInfo.id)
	return wxRow ~= -1 and wxRow or nil
end

function getFileInfoByRow(wxRow)
	return (itemWith(fileInfos, "id",fileList:GetItemData(wxRow)))
end



function eachFileInfoByRow(wxRows)
	local i = 0
	return function()
		i = i+1
		local wxRow = wxRows[i]
		if wxRow then  return getFileInfoByRow(wxRow)  end
	end
end

function getFileInfosByRows(wxRows)
	local fileInfosToReturn = {}
	for _, wxRow in ipairs(wxRows) do
		table.insert(fileInfosToReturn, getFileInfoByRow(wxRow))
	end
	return fileInfosToReturn
end

-- fileInfos, wxRows = getSelectedFileInfos( [ onlyHashed=false ] )
function getSelectedFileInfos(onlyHashed)
	local wxRows            = listCtrlGetSelectedRows(fileList)
	local fileInfosSelected = getFileInfosByRows(wxRows)

	if onlyHashed then
		for i, fileInfo in ipairsr(fileInfosSelected) do
			if fileInfo.ed2k == "" then
				table.remove(fileInfosSelected, i)
			end
		end
	end

	return fileInfosSelected, wxRows
end



function anyFileInfos()
	return fileInfos[1] ~= nil
end

function noFileInfos()
	return not fileInfos[1]
end



-- setStatusText( text )
-- setStatusText( format, ... )
function setStatusText(s, ...)
	if select("#", ...) > 0 then
		s = s:format(...)
	end
	frame:SetStatusText(s)
end



--==============================================================
--==============================================================
--==============================================================

local anidbEventHandlers = {
	["messagecount"] =
		function(msgCount)
			if msgCount == 0 then
				statusBarSetField(statusBar, STATUS_BAR_FIELD_MESSAGE_QUEUE, "")
			else
				statusBarSetField(statusBar, STATUS_BAR_FIELD_MESSAGE_QUEUE, "Task queue: %d", msgCount)
			end
		end,

	["ed2ksuccess"] =
		function(path, ed2kHash, fileSize)
			for _, fileInfo in ipairs(fileInfos) do
				if fileInfo.ed2k == "" and fileInfo.path == path then
					setFileInfo(fileInfo, "ed2k",      ed2kHash)
					setFileInfo(fileInfo, "isHashing", false)
					saveFileInfos()

					anidb:getMylistByEd2k(fileInfo.ed2k, fileInfo.size)
					break
				end
			end
		end,
	["ed2kfail"] =
		function(path)
			for _, fileInfo in ipairs(fileInfos) do
				if fileInfo.isHashing and fileInfo.path == path then
					-- @Incomplete: Show an error message.
					setFileInfo(fileInfo, "isHashing", false)
					break
				end
			end
		end,

	["loginsuccess"] =
		function() end,
	["loginbadlogin"] =
		function()
			anidb:clearMessageQueue()
			-- @Incomplete: Show login form.
			showError(frame, "Bad Login", "The username or password is incorrect.")
		end,
	["loginfail"] =
		function(userMessage) end,

	["mylistgetsuccess"] =
		function(what, ...) -- @Cleanup: Get rid of 'what' argument.
			if what == "entry" then
				local mylistEntry = ...

				local fileInfo
					=  mylistEntry.lid  and itemWith(fileInfos, "lid",mylistEntry.lid)
					or mylistEntry.ed2k and itemWith(fileInfos, "ed2k",mylistEntry.ed2k, "size",mylistEntry.size)
					or mylistEntry.fid  and itemWith(fileInfos, "fid",mylistEntry.fid)

				if fileInfo then
					setFileInfo(fileInfo, "lid",          mylistEntry.lid)
					setFileInfo(fileInfo, "fid",          mylistEntry.fid)
					setFileInfo(fileInfo, "mylistStatus", MYLIST_STATUS_YES)
					saveFileInfos()
				end

			elseif what == "none" then
				local ed2kHash, fileSize = ...
				local fileInfo = itemWith(fileInfos, "ed2k",ed2kHash)

				if fileInfo then
					setFileInfo(fileInfo, "lid",          -1) -- A previously existing entry may have been removed.
					setFileInfo(fileInfo, "fid",          -1)
					setFileInfo(fileInfo, "mylistStatus", MYLIST_STATUS_NO)
					saveFileInfos()
				end

			elseif what == "selection" then
				local mylistSelection = ...
				-- @Incomplete

			else
				logprinterror(nil, "mylistgetsuccess: Unknown what value '%s'.", what)
			end
		end,
	["mylistgetfail"] =
		function(userMessage) end,

	["mylistaddsuccess"] =
		function(mylistEntryPartial, isEdit)
			if not isEdit then
				-- Should we fetch new fresh data for edited entries? Not sure if
				-- the assurance of having up-to-date data is needed here. Everything
				-- should already be up to date.
				anidb:getMylist(mylistEntryPartial.lid)
			end

			local fileInfo
				=  mylistEntryPartial.ed2k and itemWith(fileInfos, "ed2k",mylistEntryPartial.ed2k, "size",mylistEntryPartial.size)
				or mylistEntryPartial.fid  and itemWith(fileInfos, "fid",mylistEntryPartial.fid)

			if not fileInfo then  return  end

			setFileInfo(fileInfo, "lid",          mylistEntryPartial.lid, true)
			setFileInfo(fileInfo, "fid",          mylistEntryPartial.fid or -1)
			setFileInfo(fileInfo, "mylistStatus", MYLIST_STATUS_YES)
			saveFileInfos()
		end,
	["mylistaddsuccessmultiple"] =
		function(count)
			-- @Incomplete
		end,
	["mylistaddfoundmultiplefiles"] =
		function(fids)
			-- @Incomplete
		end,
	["mylistaddfail"] =
		function(userMessage) end,

	["mylistdeletesuccess"] =
		function(mylistEntryMaybePartial)
			local fileInfo
				=  itemWith(fileInfos, "lid",mylistEntryMaybePartial.lid)
				or mylistEntryMaybePartial.ed2k and itemWith(fileInfos, "ed2k",mylistEntryMaybePartial.ed2k, "size",mylistEntryMaybePartial.size)
				or mylistEntryMaybePartial.fid  and itemWith(fileInfos, "fid",mylistEntryMaybePartial.fid)

			if not fileInfo then  return  end

			setFileInfo(fileInfo, "lid",          -1)
			setFileInfo(fileInfo, "fid",          -1)
			setFileInfo(fileInfo, "mylistStatus", MYLIST_STATUS_NO)
			saveFileInfos()
		end,
	["mylistdeletefail"] =
		function(userMessage) end,

	["blackoutstart"] =
		function() end,
	["blackoutstop"] =
		function() end,

	["pingfail"] =
		function(userMessage) end,

	["resend"] =
		function(command) end,

	["newversionavailable"] =
		function(userMessage)
			if updateAvailableMessageReceived then  return  end
			updateAvailableMessageReceived = true

			-- @UX: A less intrusive "Update Available" notification.
			showMessage(frame, "Update Available", "A new version of MyHappyList is available.")
		end,
	["message"] =
		function(userMessage)
			showMessage(frame, "Message", userMessage)
		end,

	["errorresponsetimeout"] =
		function(command)
			showError(
				frame,
				"Timeout",
				"Got no response from AniDB in time. Maybe the server is offline or your Internet connection is down?"
					.."\n\nCommand: "..command
			)
		end,
	_error =
		function(eName, userMessage)
			showError(frame, "Error", F("%s: %s", eName, userMessage))
		end,
}

--==============================================================
--= Prepare Stuff ==============================================
--==============================================================

log("~~~ MyHappyList ~~~")
log(os.date"%Y-%m-%d %H:%M:%S")

if DEBUG_LOCAL then
	print("!! DEBUG (local) !!")
elseif DEBUG then
	print("!!!!!! DEBUG !!!!!!")
end

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

assert(createDirectory("local"))
assert(createDirectory("logs"))
assert(createDirectory("temp"))
assert(createDirectory(CACHE_DIR))

local logFilePath = "logs/output.log"
logFile = assert(openFile(logFilePath, "a"))
local wxPleaseJustStop = wx.wxLogNull()

anidb = require"Anidb"()

bigBoldFont = wx.wxFont(1.2*wx.wxNORMAL_FONT:GetPointSize(), wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_BOLD)

appIcons = wx.wxIconBundle("gfx/appicon.ico", wxBITMAP_TYPE_ANY)

-- Main window.
--==============================================================
frame = wx.wxFrame(
	wxNULL,
	wxID_ANY,
	"MyHappyList"..(DEBUG_LOCAL and " [OFFLINE]" or ""),
	wxDEFAULT_POSITION,
	WxSize(1300, 400),
	wxDEFAULT_FRAME_STYLE
)

frame:DragAcceptFiles(true)

frame:SetIcons(appIcons)

on(frame, "CLOSE_WINDOW", function(e)
	if
		e:CanVeto()
		and anidb:getActiveMessageCount() > 0
		and not confirm(frame, "Exit", "The task queue is not empty. Data may get lost. Exit anyway?", "Exit")
	then
		e:Veto() -- Abort exit.
	else
		e:Skip() -- Proceed with exit.
	end
end)

on(frame, "DROP_FILES", function(e, paths)
	local pathsToAdd = {}

	for _, path in ipairs(paths) do
		local mode = getFileMode(path)

		if mode == "directory" then
			traverseFiles(path, function(path, pathRel, name, ext)
				if settings.movieExtensions[ext:lower()] then
					table.insert(pathsToAdd, path)
				end

				if pathsToAdd[MAX_DROPPED_FILES+1] then
					return true -- Break.
				end
			end)

		elseif mode == "file" then
			if settings.movieExtensions[getExtension(getFilename(path)):lower()] then
				table.insert(pathsToAdd, path)
			end
		end

		if pathsToAdd[MAX_DROPPED_FILES+1] then
			showError(frame, "Error", F("Too many dropped files. (Max is %d)", MAX_DROPPED_FILES))
			return
		end
	end

	if not pathsToAdd[1] then  return  end

	local previousLastWxRow = (anyFileInfos() and fileList:GetItemCount() or 0)-1

	for _, path in ipairs(pathsToAdd) do
		addFileInfo(toNormalPath(path))
	end

	saveFileInfos()
	listCtrlSelectRows(fileList, range(previousLastWxRow+1, fileList:GetItemCount()-1))
	updateFileList()
end)

--[[
local accelerators = {}
onAccelerator(frame, accelerators, "c", KC_1, function(e)
	print("Hello")
end)
setAccelerators(frame, accelerators)
--]]

-- Status bar.
--==============================================================
local GAUGE_WIDTH  = 100
local GAUGE_MARGIN = 3

statusBar = frame:CreateStatusBar()
statusBarInitFields(statusBar, {-1, 120, GAUGE_WIDTH+2*GAUGE_MARGIN})
statusBarSetField(statusBar, STATUS_BAR_FIELD_MESSAGE_QUEUE, "")

local progressGauge = wx.wxGauge(
	statusBar, wxID_ANY, 100, wxDEFAULT_POSITION, WxSize(GAUGE_WIDTH, getHeight(statusBar)-2*GAUGE_MARGIN), wxGA_SMOOTH
)
-- progressGauge:SetValue(50)

on(statusBar, "SIZE", function(e, w, h)
	progressGauge:Move(w-getWidth(progressGauge)-GAUGE_MARGIN, GAUGE_MARGIN)
	e:Skip()
end)

-- Menus.
--==============================================================
local menuFile  = wx.wxMenu()
local menuEdit  = wx.wxMenu()
local menuDebug = DEBUG and wx.wxMenu() or nil
local menuHelp  = wx.wxMenu()

-- File menu.
--------------------------------

newMenuItem(menuFile, frame, wxID_EXIT, "E&xit\tCtrl+Q", "Quit the program", function(e)
	frame:Close()
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
	newMenuItem(menuDebug, frame, "logout", function(e)
		anidb:logout()
	end)
	newMenuItem(menuDebug, frame, "dropSession", function(e)
		if anidb:dropSession() then
			logprint(nil, "Session dropped.")
		end
	end)

	newMenuItemSeparator(menuDebug)

	if DEBUG_LOCAL then
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
	else
		newMenuItem(menuDebug, frame, "getMylistByEd2k", function(e)
			anidb:getMylistByEd2k("9244372db8b1e10c5882d5e0ad814a35", 367902232)
		end)
	end

	newMenuItemSeparator(menuDebug)

	newMenuItem(menuDebug, frame, "clearMessageQueue", function(e)
		anidb:clearMessageQueue()
	end)
end

-- Help menu.
--------------------------------

-- newMenuItem(menuHelp, frame, "&Forum Thread", "Go to MyHappyList's forum thread on AniDB", function(e)
-- 	-- @Incomplete
-- end)

-- newMenuItem(menuHelp, frame, "&Changes", "View the changelog", function(e)
-- 	-- @Incomplete
-- end)

newMenuItem(menuHelp, frame, "&Log", "Open the text log in Notepad", function(e)
	-- @UX: Show a window with the log instead of using Notepad.
	openFileInNotepad(logFilePath)
end)

newMenuItem(menuHelp, frame, wxID_ABOUT, "&About", "About MyHappyList", function(e)
	local title     = "MyHappyList "..APP_VERSION
	local copyright = "Copyright © 2018 Marcus 'ReFreezed' Thunström. MIT license."
	local desciption
		= "MyHappyList is made using Lua, wxLua, Alien FFI, LuaSocket and rhash. "
		.."The executable is built using srlua, ResourceHacker and ImageMagick."

	local dialog = wx.wxDialog(frame, wxID_ANY, "About MyHappyList")
	local sizer  = wx.wxBoxSizer(wxVERTICAL)

	on(dialog, "CHAR_HOOK", function(e, kc)
		if kc == KC_ESCAPE then
			dialog:EndModal(wxID_CANCEL)
		else
			e:Skip()
		end
	end)

	-- Icon.
	local bm = wx.wxBitmap()
	bm:CopyFromIcon(appIcons:GetIcon(32))
	local bmObj = wx.wxStaticBitmap(dialog, wxID_ANY, bm)
	sizer:Add(bmObj, 0, wxALIGN_CENTRE_HORIZONTAL)

	sizer:AddSpacer(8)

	-- Title.
	local textObj = wx.wxStaticText(dialog, wxID_ANY, title, wxDEFAULT_POSITION, wxDEFAULT_SIZE, wxALIGN_CENTRE_HORIZONTAL)
	textObj:SetFont(bigBoldFont)
	sizer:Add(textObj, 0, wxGROW_ALL)

	sizer:AddSpacer(8)

	-- Copyright.
	local textObj = wx.wxStaticText(dialog, wxID_ANY, copyright, wxDEFAULT_POSITION, wxDEFAULT_SIZE, wxALIGN_CENTRE_HORIZONTAL)
	sizer:Add(textObj, 0, wxGROW_ALL)

	sizer:AddSpacer(8)

	-- Description.
	local textObj = wx.wxStaticText(dialog, wxID_ANY, desciption)
	textObj:Wrap(400)
	sizer:Add(textObj, 0, wxGROW_ALL)

	sizer:AddSpacer(20)

	-- Close button.
	local button = newButton(dialog, wxID_OK, "Close", function(e)
		dialog:EndModal(e:GetId())
	end)
	button:SetSizeHints(100, getHeight(button)+2*3)
	sizer:Add(button, 0, wxALIGN_CENTRE_HORIZONTAL)

	local sizerWrapper = wx.wxBoxSizer(wxHORIZONTAL)
	sizerWrapper:Add(sizer, 0, wxGROW_ALL, 20)

	dialog:SetAutoLayout(true)
	dialog:SetSizer(sizerWrapper)

	dialog:Fit()
	dialog:Centre()

	dialog:ShowModal()
end)

--------------------------------

local menuBar = wx.wxMenuBar()

menuBar:Append(menuFile,  "&File")
menuBar:Append(menuEdit,  "&Edit")
if DEBUG then menuBar:Append(menuDebug, "&Debug") end
menuBar:Append(menuHelp,  "&Help")

frame:SetMenuBar(menuBar)

-- AniDB update timer.
--==============================================================

local anidbUpdateTimer = newTimer(function(e)
	anidb:update()

	for eName, _1, _2, _3, _4, _5 in anidb:events() do
		if not isAny(eName, "messagecount") then
			logprint(nil, "Event: %s", eName)
		end

		local handler = anidbEventHandlers[eName]
		if handler then
			handler(_1, _2, _3, _4, _5)

		elseif eName:find"^error" then
			anidbEventHandlers._error(eName, _1)
		end
	end
end)

-- File list.
--==============================================================

local function removeSelectedFiles()
	local fileInfosSelected, wxRows = getSelectedFileInfos()
	if not fileInfosSelected[1] then  return  end

	for _, fileInfo in ipairsr(fileInfosSelected) do
		removeFileInfo(fileInfo)
	end

	saveFileInfos()
	updateFileList()

	if anyFileInfos() then
		listCtrlSelectRows(fileList, {wxRows[1]}, true)
	end
end

local function addToOrEditMylistForSelectedFiles()
	local fileInfosSelected = getSelectedFileInfos(true)
	if not fileInfosSelected[1] then  return  end

	-- Max length of UDP packages (over PPPoE) is 1400 bytes. Let's try to
	-- stay within the bounds before attempting to send anything.
	--
	-- https://wiki.anidb.net/w/UDP_API_Definition#General
	--
	-- UDP message example when adding:
	--    MYLISTADD ed2k=4b7e0f1101fb3ef95e187f6f086cf6b3&other=&s=GM3Fz97&size=3669066876&source=&state=2&storage=&tag=#a01340e&viewdate=1333248804&viewed=1
	--
	local MAX_UDP_MESSAGE_LENGTH     = 1400
	local APPROX_BASE_MESSAGE_LENGTH = 150
	local SAFETY_MESSAGE_LENGTH      = 20

	local dialog = wx.wxDialog(frame, wxID_ANY, "Add to / Edit MyList")

	on(dialog, "CHAR_HOOK", function(e, kc)
		if kc == KC_ESCAPE then
			dialog:EndModal(wxID_CANCEL)
		else
			e:Skip()
		end
	end)

	-- File count text.
	----------------------------------------------------------------

	newText(dialog, F("Adding/editing %d files.", #fileInfosSelected))

	wx.wxStaticLine(dialog, wxID_ANY)

	-- Viewed.
	----------------------------------------------------------------

	local VIEWED_STATES = {
		{value=nil,   title="Don't change"},
		{value=true,  title="Yes"}, -- @Incomplete: Allow direct editing of viewdate.
		{value=false, title="No"},
	}

	local viewedRadio = wx.wxRadioBox(
		dialog, wxID_ANY, "Watched", wxDEFAULT_POSITION, wxDEFAULT_SIZE,
		getColumn(VIEWED_STATES, "title"), 0, wxRA_SPECIFY_ROWS
	)

	-- MyList state.
	----------------------------------------------------------------

	local MYLIST_STATES = {
		{value=nil,                           title="Don't change"},
		{value=MYLIST_STATE_UNKNOWN,          title="Unknown / unspecified"},
		{value=MYLIST_STATE_INTERNAL_STORAGE, title="Internal storage (HDD/SSD)"},
		{value=MYLIST_STATE_EXTERNAL_STORAGE, title="External storage (CD, DVD etc.)"},
		-- {value=MYLIST_STATE_REMOTE_STORAGE,   title="Remote storage (NAS, cloud etc.)"}, -- AniDB complains! :/
		{value=MYLIST_STATE_DELETED,          title="Deleted"},
	}

	local mylistStateRadio = wx.wxRadioBox(
		dialog, wxID_ANY, "State", wxDEFAULT_POSITION, wxDEFAULT_SIZE,
		getColumn(MYLIST_STATES, "title"), 0, wxRA_SPECIFY_ROWS
	)

	-- Source.
	----------------------------------------------------------------

	local panel = wx.wxPanel(dialog, wx.wxID_ANY)

	local sourceCheckbox = wx.wxCheckBox(panel, wxID_ANY, "Source:")
	sourceCheckbox:SetSizeHints(60, getHeight(sourceCheckbox))
	sourceCheckbox:SetToolTip("Source: i.e. ed2k, DC, FTP or IRC")

	local sourceInput = wx.wxTextCtrl(panel, wxID_ANY)
	sourceInput:SetSizeHints(200, getHeight(sourceInput))
	sourceInput:SetMaxLength(MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH)
	sourceInput:SetToolTip(sourceCheckbox:GetToolTip():GetTip())
	sourceInput:Enable(false)

	on(sourceCheckbox, "COMMAND_CHECKBOX_CLICKED", function(e)
		sourceInput:Enable(e:IsChecked())
		sourceInput:SetFocus()
	end)

	on(panel, "LEFT_DOWN", function(e)
		if not sourceCheckbox:IsChecked() then
			checkBoxClick(sourceCheckbox)
		end
	end)

	setBoxSizer(panel, wxHORIZONTAL, 0, wxALIGN_CENTER_VERTICAL)

	-- Storage.
	----------------------------------------------------------------

	local panel = wx.wxPanel(dialog, wx.wxID_ANY)

	local storageCheckbox = wx.wxCheckBox(panel, wxID_ANY, "Storage:")
	storageCheckbox:SetSizeHints(60, getHeight(storageCheckbox))
	storageCheckbox:SetToolTip("Storage: i.e. the label of the CD with this file")

	local storageInput = wx.wxTextCtrl(panel, wxID_ANY)
	storageInput:SetSizeHints(200, getHeight(storageInput))
	storageInput:SetMaxLength(MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH)
	storageInput:SetToolTip(storageCheckbox:GetToolTip():GetTip())
	storageInput:Enable(false)

	on(storageCheckbox, "COMMAND_CHECKBOX_CLICKED", function(e)
		storageInput:Enable(e:IsChecked())
		storageInput:SetFocus()
	end)

	on(panel, "LEFT_DOWN", function(e)
		if not storageCheckbox:IsChecked() then
			checkBoxClick(storageCheckbox)
		end
	end)

	setBoxSizer(panel, wxHORIZONTAL, 0, wxALIGN_CENTER_VERTICAL)

	-- Other.
	----------------------------------------------------------------

	local panel = wx.wxPanel(dialog, wx.wxID_ANY)

	local otherCheckbox = wx.wxCheckBox(panel, wxID_ANY, "Note:")
	otherCheckbox:SetSizeHints(60, getHeight(otherCheckbox))

	local otherInput = wx.wxTextCtrl(panel, wxID_ANY, "", wxDEFAULT_POSITION, WxSize(200, 100), wxTE_MULTILINE)
	local colorOn  = otherInput:GetBackgroundColour()
	local colorOff = wx.wxSystemSettings.GetColour(wxSYS_COLOUR_3DFACE)
	otherInput:SetMaxLength(MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH)
	otherInput:Enable(false)
	otherInput:SetBackgroundColour(colorOff)

	on(otherCheckbox, "COMMAND_CHECKBOX_CLICKED", function(e)
		otherInput:Enable(e:IsChecked())
		otherInput:SetBackgroundColour(e:IsChecked() and colorOn or colorOff)
		otherInput:SetFocus()
	end)

	on(otherInput, "KEY_DOWN", function(e, kc)
		if kc == KC_A and e:GetModifiers() == wxMOD_CONTROL then
			textCtrlSelectAll(otherInput)
		else
			e:Skip()
		end
	end)

	on(panel, "LEFT_DOWN", function(e)
		if not otherCheckbox:IsChecked() then
			checkBoxClick(otherCheckbox)
		end
	end)

	setBoxSizer(panel, wxHORIZONTAL)

	-- Buttons.
	----------------------------------------------------------------

	wx.wxStaticLine(dialog, wxID_ANY)

	local panel = wx.wxPanel(dialog, wx.wxID_ANY)

	newButton(panel, wxID_OK, "Add / Edit", function(e)
		dialog:EndModal(e:GetId())
	end)

	newButton(panel, wxID_CANCEL, "Cancel", function(e)
		dialog:EndModal(e:GetId())
	end)

	setBoxSizer(panel, wxHORIZONTAL):PrependStretchSpacer()

	----------------------------------------------------------------

	setBoxSizerWithSpace(dialog, wxVERTICAL, 10, 4, 0, wxGROW)
	dialog:Fit()
	dialog:Centre()

	local viewed, state, storage, source, other

	while true do
		local id = dialog:ShowModal()
		if id ~= wxID_OK then  return  end

		viewed  = VIEWED_STATES[viewedRadio:GetSelection()+1].value
		state   = MYLIST_STATES[mylistStateRadio:GetSelection()+1].value
		storage = storageCheckbox:IsChecked() and storageInput:GetValue() or nil
		source  = sourceCheckbox:IsChecked()  and sourceInput:GetValue()  or nil
		other   = otherCheckbox:IsChecked()   and otherInput:GetValue()   or nil

		local totalStrLen = #(storage or "") + #(source or "") + #(other or ""):gsub("\n", "<br />")

		if APPROX_BASE_MESSAGE_LENGTH + totalStrLen > MAX_UDP_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH then
			showWarning(
				frame,
				"Too Long Texts",
				F(
					"The combined length of the storage, source and note texts is too long to send over the network. "
						.."The supported maximum length is around %d characters.",
					MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH
				)
			)
			-- Loop back and show the dialog again.

		else
			break -- Continue.
		end
	end

	local values = {
		viewed  = viewed,
		state   = state,
		storage = storage,
		source  = source,
		other   = other,
	}

	for _, fileInfo in ipairs(fileInfosSelected) do
		if fileInfo.lid ~= -1 then
			if next(values) then
				anidb:editMylist(fileInfo.lid, values)
			end

		elseif fileInfo.ed2k ~= "" then
			anidb:addMylistByEd2k(fileInfo.ed2k, fileInfo.size, values)
		end
	end
end

fileList = wx.wxListCtrl(
	frame, wxID_ANY, wxDEFAULT_POSITION, wxDEFAULT_SIZE,
	wxLC_REPORT
)

FILE_COLUMN_FILE   = listCtrlInsertColumn(fileList, "File",    500)
FILE_COLUMN_FOLDER = listCtrlInsertColumn(fileList, "Folder",  500)
FILE_COLUMN_SIZE   = listCtrlInsertColumn(fileList, "Size",    80)
FILE_COLUMN_VIEWED = listCtrlInsertColumn(fileList, "Watched", 80)
FILE_COLUMN_STATUS = listCtrlInsertColumn(fileList, "Status",  120)

listCtrlInsertRow(fileList, DROP_FILES_TO_ADD_MESSAGE)
fileList:Enable(false)

on(fileList, "COMMAND_LIST_ITEM_ACTIVATED", function(e, wxRow)
	local fileInfo = getFileInfoByRow(wxRow)
	if fileInfo then  openFileExternally(fileInfo.path)  end
end)

on(fileList, "KEY_DOWN", function(e, kc)
	if kc == KC_SPACE and not e:HasModifiers() then
		-- Do nothing. For some reason space activates the selected item.

	elseif anyFileInfos() then
		if kc == KC_DELETE then
			removeSelectedFiles()

		elseif kc == KC_A and e:GetModifiers() == wxMOD_CONTROL then
			listCtrlSelectRows(fileList, range(0, fileList:GetItemCount()-1))

		elseif kc == KC_F2 then
			addToOrEditMylistForSelectedFiles()

		else
			e:Skip()
		end
	else
		e:Skip()
	end
end)

on(fileList, "CONTEXT_MENU", function(e)
	local fileInfosSelected = getSelectedFileInfos()
	if not fileInfosSelected[1] then  return  end

	local anyIsHashed      = false

	local anyIsUnknown     = false
	local anyIsNotInMylist = false
	local anyIsInMylist    = false

	-- local anyIsWatched     = false
	-- local anyIsUnwatched   = false

	for _, fileInfo in ipairs(fileInfosSelected) do
		if fileInfo.ed2k ~= "" then
			anyIsHashed = true
		end

		if fileInfo.mylistStatus == MYLIST_STATUS_YES then
			anyIsInMylist    = true
		elseif fileInfo.mylistStatus == MYLIST_STATUS_NO then
			anyIsNotInMylist = true
		else
			anyIsUnknown     = true
		end

		-- if fileInfo.lid ~= -1 then
		-- 	local mylistEntry = anidb:getCacheMylist(fileInfo.lid)
		-- 	if mylistEntry and mylistEntry.viewdate then
		-- 		if mylistEntry.viewdate == 0 then
		-- 			anyIsUnwatched = true
		-- 		else
		-- 			anyIsWatched   = true
		-- 		end
		-- 	end
		-- end
	end

	local popupMenu = wx.wxMenu()
	----------------------------------------------------------------

	if fileInfosSelected[2] then
		newMenuItemLabel(popupMenu, #fileInfosSelected.." Files Selected")
		newMenuItemSeparator(popupMenu)
	end

	local helpText = fileInfosSelected[2] and "Open the first selected file" or "Open the file"
	newMenuItem(popupMenu, frame, "&Play\tEnter", helpText, function(e)
		openFileExternally(fileInfosSelected[1].path)
	end)

	newMenuItem(popupMenu, frame, "Mark as &Watched", "Mark selected files as watched", function(e)
		local values = {viewed=true}

		for _, fileInfo in ipairs(fileInfosSelected) do
			if fileInfo.lid ~= -1 then
				anidb:editMylist(fileInfo.lid, values)

			elseif fileInfo.ed2k ~= "" then
				anidb:addMylistByEd2k(fileInfo.ed2k, fileInfo.size, values)
			end
		end
	end):Enable(anyIsHashed)

	newMenuItem(popupMenu, frame, "Open &Contaning Folder", "Open the folder contaning the file", function(e)
		local fileInfo = fileInfosSelected[1]
		showFileInExplorer(fileInfo.path)
	end)

	newMenuItem(popupMenu, frame, "&Remove from List\tDelete", "Remove selected files from the list", function(e)
		removeSelectedFiles()
	end)

	----------------------------------------------------------------
	newMenuItemSeparator(popupMenu)

	newMenuItem(popupMenu, frame, "Add to / &Edit MyList\tF2", "Add file to, or edit, MyList", function(e)
		addToOrEditMylistForSelectedFiles()
	end):Enable(anyIsHashed)

	newMenuItem(popupMenu, frame, "&Delete from MyList", "Delete file from MyList", function(e)
		if not confirm(frame, "Delete from MyList", "Delete the selected files from MyList?", "Delete") then  return  end

		for _, fileInfo in ipairs(fileInfosSelected) do
			if fileInfo.lid ~= -1 then
				anidb:deleteMylist(fileInfo.lid)
			end
		end
	end):Enable(anyIsInMylist)

	----------------------------------------------------------------
	newMenuItemSeparator(popupMenu)

	local submenu = wx.wxMenu()

	newMenuItem(
		submenu, frame, "Copy ed2k to Clipboard", "Copy ed2k hash to clipboard",
		function(e)
			local fileInfo = fileInfosSelected[1]
			clipboardSetText(fileInfo.ed2k)
			setStatusText("Copied ed2k hash of '%s' to clipboard", fileInfo.name)
		end
	):Enable(#fileInfosSelected == 1 and anyIsHashed)

	newMenuItem(popupMenu, frame, "More", submenu)

	----------------------------------------------------------------
	if DEBUG then
		newMenuItemSeparator(popupMenu)

		newMenuItem(popupMenu, frame, "[DEBUG] Calculate ed2k", function(e)
			for _, fileInfo in ipairs(fileInfosSelected) do
				if fileInfo.ed2k == "" and not fileInfo.isHashing then
					setFileInfo(fileInfo, "isHashing", true)
					anidb:hashFile(fileInfo.path)
				end
			end
		end)

		newMenuItem(popupMenu, frame, "[DEBUG] Get MYLIST", function(e)
			for _, fileInfo in ipairs(fileInfosSelected) do
				if fileInfo.lid ~= "" then
					anidb:getMylist(fileInfo.lid, true)
				elseif fileInfo.ed2k ~= "" then
					anidb:getMylistByEd2k(fileInfo.ed2k, fileInfo.size)
				end
			end
		end)
	end

	----------------------------------------------------------------
	local wxRows = listCtrlGetSelectedRows(fileList)
	listCtrlPopupMenu(fileList, popupMenu, wxRows[#wxRows], e:GetPosition())
end)

-- Loading.
--==============================================================

loadFileInfos()

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
if anidb:isLoggedIn() and not DEBUG then
	anidb:clearMessageQueue()
	anidb:logout()
	anidb:update(true)
	-- We don't have time to wait for a reply to logout(), so just remove the session info right away.
	anidb:dropSession()
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
