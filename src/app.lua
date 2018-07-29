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

local anidb
local frame
local fileList

local fileInfos  = {}
local lastFileId = 0 -- Local ID, not fid on AniDB.

local settings = {
	autoHash        = true,
	movieExtensions = newSet{"avi","flv","mkv","mov","mp4","mpeg","mpg","ogm","ogv","swf","webm","wmv"},
	trunkateFolders = true,
}

--==============================================================
--==============================================================
--==============================================================

local addFileInfo, removeFileInfo
local getFileStatus, getFileInfoByRow, getFileRow
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
			id        = lastFileId,

			path      = path,
			name      = "",
			folder    = "",

			ed2k      = "",
			size      = getFileSize(path),

			lid       = -1,

			isHashing = false,
		}
	end

	fileInfo.name      = getFilename(path)
	fileInfo.folder    = getDirectory(path)
	fileInfo.isHashing = false

	setAndInsert(fileInfos, path, fileInfo)

	local wxRow = listCtrlInsertRow(
		fileList, fileInfo.name, fileInfo.folder, formatBytes(fileInfo.size), "?", getFileStatus(fileInfo)
	)
	fileList:SetItemData(wxRow, fileInfo.id)

	if settings.autoHash and fileInfo.ed2k == "" then
		setFileInfo(fileInfo, "isHashing", true)
		anidb:hashFile(path)
	end

	return fileInfo
end

function removeFileInfo(fileInfo)
	fileInfo = fileInfos[fileInfo.path]
	if not fileInfo then  return  end

	unsetAndRemove(fileInfos, fileInfo.path)

	local wxRow = getFileRow(fileInfo)
	fileList:DeleteItem(wxRow)
end



function updateFileList()
	if not fileInfos[1] then return end

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

	fileList:SortItems(function(a, b)
		a = itemWith(fileInfos, "id", a)
		b = itemWith(fileInfos, "id", b)
		if a.folder ~= b.folder then
			return a.folder < b.folder and -1 or 1
		end
		if a.name ~= b.name then
			return a.name < b.name and -1 or 1
		end
		return 0 -- Should never happen.
	end, 0)

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



function setFileInfo(fileInfo, k, v)
	if fileInfo[k] == v then
		return
	end

	fileInfo[k] = v

	local wxRow = fileList:FindItem(-1, fileInfo.id)
	if wxRow == -1 then
		logprinterror(nil, "File %d is not in list.", fileInfo.id)
		return
	end

	if isAny(k, "ed2k","isHashing") then
		fileList:SetItem(wxRow, FILE_COLUMN_STATUS, getFileStatus(fileInfo))
	end
end



function getFileStatus(fileInfo)
	return
		fileInfo.isHashing     and "Calculating hash"
		or fileInfo.ed2k == "" and "Not hashed"
		or "Hashed"
end

function getFileRow(fileInfo)
	local wxRow = fileList:FindItem(-1, fileInfo.id)
	return wxRow ~= -1 and wxRow or nil
end

function getFileInfoByRow(wxRow)
	return itemWith(fileInfos, "id", fileList:GetItemData(wxRow))
end



--==============================================================
--==============================================================
--==============================================================

local anidbEventHandlers = {
	["ed2ksuccess"] =
		function(path, ed2kHash, fileSize)
			for _, fileInfo in ipairs(fileInfos) do
				if fileInfo.ed2k == "" and fileInfo.path == path then
					setFileInfo(fileInfo, "ed2k",      ed2kHash)
					setFileInfo(fileInfo, "isHashing", false)
					saveFileInfos()
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
					saveFileInfos()
					break
				end
			end
		end,

	["loginsuccess"] =
		function() end,
	["loginbadlogin"] =
		function()
			showError(frame, "Bad Login", "The username or password is incorrect.")
			frame:Close(true)
		end,
	["loginfail"] =
		function(userMessage) end,

	["mylistgetsuccess"] =
		function(what, ...)
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
	["mylistgetfail"] =
		function(userMessage) end,

	["mylistaddsuccess"] =
		function(mylistEntryPartial)
			-- anidb:getMylist(mylistEntryPartial.lid) -- @@
		end,
	["mylistaddsuccessmultiple"] =
		function(count)
			-- @@
		end,
	["mylistaddfoundmultiplefiles"] =
		function(fids)
			-- @@
		end,
	["mylistaddfail"] =
		function(userMessage) end,

	["mylistdeletesuccess"] =
		function(count)
			-- @@
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

assert(createDirectory(CACHE_DIR))
assert(createDirectory("logs"))

logFile = assert(openFile("logs/output.log", "a"))

anidb = require"Anidb"()

-- Main window.
--==============================================================
frame = wx.wxFrame(WX_NULL, WX_ID_ANY, "MyHappyList", WX_DEFAULT_POSITION, WxSize(1300, 400), WX_DEFAULT_FRAME_STYLE)

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
				if settings.movieExtensions[ext:lower()] then
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

	if not pathsToAdd[1] then  return  end

	local previousLastWxRow = fileList:GetItemCount()-1

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

local function removeSelectedFiles()
	local wxRows = listCtrlGetSelectedRows(fileList)
	if not wxRows[1] then  return  end

	for _, wxRow in ipairsr(wxRows) do
		removeFileInfo(getFileInfoByRow(wxRow))
	end

	saveFileInfos()
	updateFileList()
	listCtrlSelectRows(fileList, {wxRows[1]}, true)
end

fileList = wx.wxListCtrl(
	frame, WX_ID_ANY, WX_DEFAULT_POSITION, WX_DEFAULT_SIZE,
	WX_LC_REPORT
)

FILE_COLUMN_FILE   = listCtrlInsertColumn(fileList, "File",    500)
FILE_COLUMN_FOLDER = listCtrlInsertColumn(fileList, "Folder",  500)
FILE_COLUMN_SIZE   = listCtrlInsertColumn(fileList, "Size",    80)
FILE_COLUMN_VIEWED = listCtrlInsertColumn(fileList, "Watched", 60)
FILE_COLUMN_STATUS = listCtrlInsertColumn(fileList, "Status",  120)

on(fileList, "COMMAND_LIST_ITEM_ACTIVATED", function(e, wxRow)
	local fileInfo = getFileInfoByRow(wxRow)
	openFileExternally(fileInfo.path)
end)

on(fileList, "KEY_DOWN", function(e, kc)
	if kc == KC_DELETE then
		removeSelectedFiles()

	elseif kc == KC_SPACE and not e:HasModifiers() then
		-- Do nothing. For some reason space activates the thing.

	elseif kc == KC_A and e:GetModifiers() == WX_MOD_CONTROL then
		listCtrlSelectRows(fileList, range(0, fileList:GetItemCount()-1))

	else
		e:Skip()
	end
end)

on(fileList, "CONTEXT_MENU", function(e)
	local wxRows = listCtrlGetSelectedRows(fileList)
	if not wxRows[1] then  return  end

	local popupMenu = wx.wxMenu()

	if wxRows[2] then
		newMenuItem(popupMenu, frame, #wxRows.." Files Selected"):Enable(false)
		newMenuItemSeparator(popupMenu)
	end

	local helpText = wxRows[2] and "Open the first selected file" or "Open the file"
	newMenuItem(popupMenu, frame, "&Play\tEnter", helpText, function(e)
		local fileInfo = getFileInfoByRow(wxRows[1])
		openFileExternally(fileInfo.path)
	end)

	newMenuItem(popupMenu, frame, "Remove from List\tDelete", "Remove selected files from the list", function(e)
		removeSelectedFiles()
	end)

	newMenuItem(popupMenu, frame, "Calculate hash", "Calculate ed2k hash for files", function(e)
		for _, wxRow in ipairs(wxRows) do
			local fileInfo = getFileInfoByRow(wxRow)

			if fileInfo.ed2k == "" and not fileInfo.isHashing then
				setFileInfo(fileInfo, "isHashing", true)
				anidb:hashFile(fileInfo.path)
			end
		end
	end)

	newMenuItemSeparator(popupMenu)

	newMenuItem(popupMenu, frame, "Add to MyList", "Add file to MyList", function(e)
		-- @@
	end)

	newMenuItem(popupMenu, frame, "Mark as &Watched", "Mark selected files as watched", function(e)
		-- @@
	end)

	listCtrlPopupMenu(fileList, popupMenu, wxRows[1], e:GetPosition())
end)

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
