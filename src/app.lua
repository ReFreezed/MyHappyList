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

require"appEnvironment"



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

-- Creating folders should be done first, in case they get used right away.
assert(createDirectory("local"))
assert(createDirectory("logs"))
assert(createDirectory("temp"))
assert(createDirectory(CACHE_DIR))

-- Prepare AniDB connection before opening the log file, in case the socket cannot open.
-- Don't wanna risk having multiple MyHappyLists running and appending to the same file.
anidb = require"Anidb"()

local logFilePath = "logs/output.log"
logFile = assert(openFile(logFilePath, "a"))

appIcons  = wxIconBundle("gfx/appicon.ico", wxBITMAP_TYPE_ANY)
fontTitle = wxFont(1.2*wxFONT_NORMAL:GetPointSize(), wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_BOLD)



-- Top frame.
--==============================================================

topFrame = wxFrame(
	wxNULL,
	wxID_ANY,
	"MyHappyList"..(DEBUG_LOCAL and " [OFFLINE]" or ""),
	wxDEFAULT_POSITION,
	wxSize(1300, 400),
	wxDEFAULT_FRAME_STYLE
)

topFrame:DragAcceptFiles(true)
topFrame:SetIcons(appIcons)

on(topFrame, "CLOSE_WINDOW", function(e)
	if
		e:CanVeto()
		and anidb:getActiveMessageCount() > 0
		and not confirm("Exit", "The task queue is not empty. Data may get lost. Exit anyway?", "Exit")
	then
		e:Veto() -- Abort exit.
		return
	end

	e:Skip() -- Proceed with exit.

	-- Must do this here because of callbacks that reference wxWindow objects.
	saveSettings()
end)

on(topFrame, "DROP_FILES", function(e, paths)
	local pathsToAdd = {}

	for _, path in ipairs(paths) do
		if isDirectory(path) then
			traverseFiles(path, function(path, pathRel, name, ext)
				if indexOf(appSettings.movieExtensions, ext:lower()) then
					table.insert(pathsToAdd, path)
				end

				if pathsToAdd[MAX_DROPPED_FILES+1] then
					return true -- Break.
				end
			end)

		elseif isFile(path) then
			if indexOf(appSettings.movieExtensions, getExtension(getFilename(path)):lower()) then
				table.insert(pathsToAdd, path)
			end
		end

		if pathsToAdd[MAX_DROPPED_FILES+1] then
			showError("Error", F("Too many dropped files. (Max is %d)", MAX_DROPPED_FILES))
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

-- Note: The SIZE event fires even when the size hasn't changed (which is silly).
local oldW, oldH = getSize(topFrame)

on(topFrame, "SIZE", function(e, w, h)
	e:Skip()
	if w == oldW and h == oldH then  return  end

	if topFrame:IsMaximized() then
		setSetting("windowMaximized", true)
	else
		setSetting("windowMaximized", false)
		setSetting("windowSizeX", w)
		setSetting("windowSizeY", h)
	end

	oldW = w
	oldH = h
end)

on(topFrame, "MOVE", function(e, x, y)
	e:Skip()
	if not topFrame:IsMaximized() then
		setSetting("windowPositionX", x)
		setSetting("windowPositionY", y)
	end
end)

--[[
local accelerators = {}
onAccelerator(topFrame, accelerators, "c", KC_1, function(e)
	print("Hello")
end)
setAccelerators(topFrame, accelerators)
--]]



-- Status bar.
--==============================================================

local GAUGE_WIDTH  = 100
local GAUGE_MARGIN = 3

statusBar = topFrame:CreateStatusBar()
statusBarInitFields(statusBar, {-1, 120, GAUGE_WIDTH+2*GAUGE_MARGIN})
statusBarSetField(statusBar, STATUS_BAR_FIELD_MESSAGE_QUEUE, "")

local progressGauge = wxGauge(
	statusBar, wxID_ANY, 100, wxDEFAULT_POSITION, wxSize(GAUGE_WIDTH, getHeight(statusBar)-2*GAUGE_MARGIN), wxGA_SMOOTH
)
-- progressGauge:SetValue(50)

on(statusBar, "SIZE", function(e, w, h)
	e:Skip()
	progressGauge:Move(w-getWidth(progressGauge)-GAUGE_MARGIN, GAUGE_MARGIN)
end)



-- Menus.
--==============================================================

local menuFile  = wxMenu()
local menuHelp  = wxMenu()
local menuDebug = DEBUG and wxMenu() or nil

-- File.
--------------------------------

newMenuItem(menuFile, topFrame, "&Settings"..(DEBUG and "\tAlt+S" or ""), "Change settings", function(e)
	dialogs.settings()
end)

newMenuItemSeparator(menuFile)

newMenuItem(menuFile, topFrame, wxID_EXIT, "E&xit\tCtrl+Q", "Quit the program", function(e)
	topFrame:Close()
end)

-- Help.
--------------------------------

newMenuItem(menuHelp, topFrame, "&Forum Thread", "Go to MyHappyList's forum thread on AniDB", function(e)
	local url = "https://anidb.net/perl-bin/animedb.pl?show=cmt&id=83307"
	if not wxLaunchDefaultBrowser(url) then
		showError("Error", "Could not launch default browser.\n\n"..url)
	end
end)

-- newMenuItem(menuHelp, topFrame, "&Changes", "View the changelog", function(e)
-- 	-- @Incomplete
-- end)

newMenuItem(menuHelp, topFrame, "&Log", "Open the text log in Notepad", function(e)
	-- @UX: Show a window with the log instead of using Notepad.
	openFileInNotepad(logFilePath)
end)

newMenuItem(menuHelp, topFrame, wxID_ABOUT, "&About", "About MyHappyList", function(e)
	dialogs.about()
end)

-- Debug.
--------------------------------

if DEBUG then
	newMenuItem(menuDebug, topFrame, "checkFileInfos\tF5", function(e)
		checkFileInfos()
	end)

	newMenuItemSeparator(menuDebug)

	newMenuItem(menuDebug, topFrame, "ping", function(e)
		anidb:ping()
	end)
	newMenuItem(menuDebug, topFrame, "login", function(e)
		anidb:login()
	end)
	newMenuItem(menuDebug, topFrame, "logout", function(e)
		anidb:logout()
	end)
	newMenuItem(menuDebug, topFrame, "dropSession", function(e)
		if anidb:dropSession() then
			logprint(nil, "Session dropped.")
		end
	end)

	newMenuItemSeparator(menuDebug)

	if DEBUG_LOCAL then
		newMenuItem(menuDebug, topFrame, "getMylistByFile", function(e)
			anidb:getMylistByFile(getFileContents"local/exampleFilePathGb.txt")
		end)
		newMenuItem(menuDebug, topFrame, "addMylistByFile", function(e)
			anidb:addMylistByFile(getFileContents"local/exampleFilePathGb.txt")
		end)
		newMenuItem(menuDebug, topFrame, "deleteMylist x2", function(e)
			anidb:deleteMylist(115)
			anidb:deleteMylist(2468)
		end)
	else
		newMenuItem(menuDebug, topFrame, "getMylistByEd2k", function(e)
			anidb:getMylistByEd2k("9244372db8b1e10c5882d5e0ad814a35", 367902232)
		end)
	end

	newMenuItemSeparator(menuDebug)

	newMenuItem(menuDebug, topFrame, "clearMessageQueue", function(e)
		anidb:clearMessageQueue()
	end)
end

--------------------------------

local menuBar = wxMenuBar()

menuBar:Append(menuFile, "&File")
if DEBUG then  menuBar:Append(menuDebug, "&Debug")  end
menuBar:Append(menuHelp, "&Help")

topFrame:SetMenuBar(menuBar)



topPanel        = wxPanel(topFrame, wxID_ANY)
local sizerMain = wxBoxSizer(wxVERTICAL)



-- Bars above file list.
--==============================================================

loginButton = newButton(topPanel, wxID_ANY, "Log In", function(e)
	dialogs.credentials()
end)
loginButton:SetSizeHints(getWidth(loginButton), 1.4*getHeight(loginButton))
loginButton:SetBackgroundColour(wxColour(255, 255, 0))
loginButton:Show(false)
sizerMain:Add(loginButton, 0, wxGROW)



-- File list.
--==============================================================

fileList = wxListCtrl(
	topPanel, wxID_ANY, wxDEFAULT_POSITION, wxDEFAULT_SIZE,
	wxLC_REPORT
)
sizerMain:Add(fileList, 1, wxGROW)

assert(listCtrlInsertColumn(fileList, "File",    100) == FILE_COLUMN_FILE-1)
assert(listCtrlInsertColumn(fileList, "Folder",  100) == FILE_COLUMN_FOLDER-1)
assert(listCtrlInsertColumn(fileList, "Size",    100) == FILE_COLUMN_SIZE-1)
assert(listCtrlInsertColumn(fileList, "Watched", 100) == FILE_COLUMN_VIEWED-1)
assert(listCtrlInsertColumn(fileList, "Status",  100) == FILE_COLUMN_STATUS-1)

listCtrlInsertRow(fileList, DROP_FILES_TO_ADD_MESSAGE)
fileList:Enable(false)

on(fileList, "COMMAND_LIST_ITEM_ACTIVATED", function(e, wxRow)
	local fileInfo = getFileInfoByRow(wxRow)
	local path     = fileInfo and fileInfo.path
	if isFile(path) then
		openFileExternally(path)
	else
		showError("Error", F("File does not exist.\n\n%s", path))
	end
end)

local saveColumnWidthsTimer = newTimer(function(e)
	scheduleSaveSettings()
end)

on(fileList, "COMMAND_LIST_COL_END_DRAG", function(e, wxCol, w)
	e:Skip()

	-- No event detects double clicks on column separators, so we have to do some silliness.
	setSetting(
		"fileColumnWidth"..(wxCol+1),
		function()
			return fileList:GetColumnWidth(wxCol)
		end,
		false
	)
	saveColumnWidthsTimer:Start(1000, true)
end)

on(fileList, "KEY_DOWN", function(e, kc)
	if kc == KC_SPACE and not e:HasModifiers() then
		-- Do nothing. For some reason space activates the selected item.

	elseif anyFileInfos() then
		if kc == KC_DELETE then
			removeSelectedFileInfos()

		elseif kc == KC_A and e:GetModifiers() == wxMOD_CONTROL then
			listCtrlSelectRows(fileList, range(0, fileList:GetItemCount()-1))

		elseif kc == KC_F2 then
			dialogs.addmylist(getSelectedFileInfos(true))

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

	local popupMenu = wxMenu()
	----------------------------------------------------------------

	if fileInfosSelected[2] then
		newMenuItemLabel(popupMenu, #fileInfosSelected.." Files Selected")
		newMenuItemSeparator(popupMenu)
	end

	newMenuItem(popupMenu, fileList, "&Play\tEnter", "Open the file", function(e)
		local path = fileInfosSelected[1].path
		if isFile(path) then
			openFileExternally(path)
		else
			showError("Error", F("File does not exist.\n\n%s", path))
		end
	end)

	newMenuItem(popupMenu, fileList, "Mark as &Watched", "Mark selected files as watched", function(e)
		local values = {viewed=true}

		for _, fileInfo in ipairs(fileInfosSelected) do
			if fileInfo.lid ~= -1 then
				anidb:editMylist(fileInfo.lid, values)

			elseif fileInfo.ed2k ~= "" then
				anidb:addMylistByEd2k(fileInfo.ed2k, fileInfo.size, values)
			end
		end
	end):Enable(anyIsHashed)

	newMenuItem(popupMenu, fileList, "Open &Containing Folder", "Open the folder containing the file", function(e)
		local path = fileInfosSelected[1].path
		if isDirectory(getDirectory(path)) then
			showFileInExplorer(path)
		else
			showError("Error", F("Folder does not exist.\n\n%s", path))
		end
	end)

	newMenuItem(popupMenu, fileList, "&Remove from List\tDelete", "Remove selected files from the list", function(e)
		removeSelectedFileInfos()
	end)

	----------------------------------------------------------------
	newMenuItemSeparator(popupMenu)

	newMenuItem(popupMenu, fileList, "Add to / &Edit MyList\tF2", "Add file to, or edit, MyList", function(e)
		dialogs.addmylist(getSelectedFileInfos(true))
	end):Enable(anyIsHashed)

	newMenuItem(popupMenu, fileList, "&Delete from MyList", "Delete file from MyList", function(e)
		if not confirm("Delete from MyList", "Delete the selected files from MyList?", "Delete") then  return  end

		for _, fileInfo in ipairs(fileInfosSelected) do
			if fileInfo.lid ~= -1 then
				anidb:deleteMylist(fileInfo.lid)
			end
		end
	end):Enable(anyIsInMylist)

	----------------------------------------------------------------
	newMenuItemSeparator(popupMenu)

	local submenu = wxMenu()

	newMenuItem(
		submenu, topFrame, "Copy ed2k to Clipboard", "Copy ed2k hash to clipboard",
		function(e)
			local fileInfo = fileInfosSelected[1]
			clipboardSetText(fileInfo.ed2k)
			setStatusText("Copied ed2k hash of '%s' to clipboard", fileInfo.name)
		end
	):Enable(#fileInfosSelected == 1 and anyIsHashed)

	newMenuItem(popupMenu, fileList, "More", submenu)

	----------------------------------------------------------------
	if DEBUG then
		newMenuItemSeparator(popupMenu)

		newMenuItem(popupMenu, fileList, "[DEBUG] Calculate ed2k", function(e)
			for _, fileInfo in ipairs(fileInfosSelected) do
				if fileInfo.ed2k == "" and not fileInfo.isHashing then
					setFileInfo(fileInfo, "isHashing", true)
					anidb:hashFile(fileInfo.path)
				end
			end
		end)

		newMenuItem(popupMenu, fileList, "[DEBUG] Get MYLIST", function(e)
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



--==============================================================

topFrame:SetDefaultItem(fileList)
topPanel:SetAutoLayout(true)
topPanel:SetSizer(sizerMain)

anidbUpdateTimer = newTimer(function(e)
	anidb:update()

	local eHandlers = require"anidbEventHandlers"

	for eName, _1, _2, _3, _4, _5 in anidb:events() do
		if not isAny(eName, "messagecount") then
			logprint(nil, "Event: %s", eName)
		end

		local handler = eHandlers[eName]
		if handler then
			handler(_1, _2, _3, _4, _5)

		elseif eName:find"^error" then
			eHandlers._error(eName, _1)
		end
	end
end)



--==============================================================
--= Load Stuff =================================================
--==============================================================

loadSettings()
loadFileInfos()

fileList:SetColumnWidth(FILE_COLUMN_FILE-1,   appSettings["fileColumnWidth"..FILE_COLUMN_FILE])
fileList:SetColumnWidth(FILE_COLUMN_FOLDER-1, appSettings["fileColumnWidth"..FILE_COLUMN_FOLDER])
fileList:SetColumnWidth(FILE_COLUMN_SIZE-1,   appSettings["fileColumnWidth"..FILE_COLUMN_SIZE])
fileList:SetColumnWidth(FILE_COLUMN_VIEWED-1, appSettings["fileColumnWidth"..FILE_COLUMN_VIEWED])
fileList:SetColumnWidth(FILE_COLUMN_STATUS-1, appSettings["fileColumnWidth"..FILE_COLUMN_STATUS])

if not (appSettings.windowSizeX == -1 and appSettings.windowSizeY == -1) then
	topFrame:SetSize(appSettings.windowSizeX, appSettings.windowSizeY)
end
if appSettings.windowPositionX == -1 and appSettings.windowPositionY == -1 then
	topFrame:Center()
else
	topFrame:Move(appSettings.windowPositionX, appSettings.windowPositionY)
end
topFrame:Maximize(appSettings.windowMaximized)

if anyFileInfos() then
	fileList:SetFocus()
	listCtrlSelectRows(fileList, {0})
end

-- Right when topFrame is visible.
newTimer(0, true, function()
	checkFileInfos()
end)



--==============================================================
--= Show GUI ===================================================
--==============================================================

topFrame:Show(true)

anidbUpdateTimer:Start(1000/10)

settingsAreFrozen = false

wxGetApp():MainLoop()



--==============================================================
--= Exit =======================================================
--==============================================================

-- saveSettings() -- No, do this in CLOSE_WINDOW instead.

processStopAll(true) -- May take some time as we try to end the processes gracefully.

anidb:destroy()
anidb = nil

-- Cleanup.
if isDirectory"temp" then
	traverseFiles("temp", function(path)
		if not deleteFile(path) then
			logprinterror("App", "Could not delete file '%s'.", path)
		end
	end)
end

logprint(nil, "Exiting normally.")
logFile:close()
logFile = nil


