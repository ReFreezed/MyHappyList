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

math.randomseed(os.time())
math.random()

require"appEnvironment"



--==============================================================
--= Prepare Stuff ==============================================
--==============================================================

logHeader()

-- Move old folders.
bypassDirectoryProtection = true
assert(renameDirectoryIfExists(DIR_CACHE_OLD, DIR_CACHE))
assert(renameDirectoryIfExists(DIR_LOGS_OLD,  DIR_LOGS))
assert(renameDirectoryIfExists(DIR_TEMP_OLD,  DIR_TEMP))
bypassDirectoryProtection = false

-- Creating folders should be done as early as possible, in case they get used right away.
assert(createDirectory(DIR_CACHE))
assert(createDirectory(DIR_CONFIG))
assert(createDirectory(DIR_LOGS))
assert(createDirectory(DIR_TEMP))

-- Move files from old folders.
local function move(dirOld, dirNew, pathRelative)
	assert(renameFileIfExists(dirOld.."/"..pathRelative,         dirNew.."/"..pathRelative))
	assert(renameFileIfExists(dirOld.."/"..pathRelative..".bak", dirNew.."/"..pathRelative..".bak"))
end
bypassDirectoryProtection = true
move(DIR_CONFIG_OLD, DIR_CONFIG, (DEBUG_LOCAL and "/loginDebug" or "/login"))
move(DIR_CONFIG_OLD, DIR_CONFIG, "settings")
removeDirectory(DIR_CONFIG_OLD) -- Only succeeds if the folder is empty, which is what we want.
bypassDirectoryProtection = false

eventQueue = require"EventQueue"()

-- Prepare AniDB connection before opening the log file, in case the socket cannot open.
-- Don't wanna risk having multiple MyHappyLists running and appending to the same file.
anidb = require"Anidb"()

logStart("output")

appIcons   = wxIconBundle("gfx/appicon.ico", wxBITMAP_TYPE_ANY)
fontTitle  = wxFont(1.2*wxFONT_NORMAL.PointSize, wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_BOLD)

-- Update updater.
local unzipDir = updater_getUnzipDir()
if isDirectory(unzipDir) then
	logprint(nil, "Finishing update: Updating updater...")

	local dangerModeActive = (appZip ~= nil)

	if dangerModeActive then
		table.insert(WRITABLE_DIRS, DIR_APP)
	end
	updater_moveFilesAfterUnzipUpdater(dangerModeActive)
	if dangerModeActive then
		table.remove(WRITABLE_DIRS)
	end

	assert(removeDirectoryAndChildren(unzipDir, false))
	logprint(nil, "Finishing update: Updating updater... done!")
end

-- We need to load settings early for translations to work everywhere.
loadSettings()



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
topFrame.Icons = appIcons

on(topFrame, "CLOSE_WINDOW", function(e)
	if
		e:CanVeto()
		and anidb:getActiveMessageCount() > 0
		and not confirm(T"label_exit", T"message_confirmExitDuringTask", T"label_exit", nil, nil, true)
	then
		e:Veto()
		return
	end

	-- Must do this here because of callbacks that reference wxWindow objects.
	saveSettings()

	-- Begin destruction!
	--------------------------------

	for child in eachChildRecursively(topFrame, true) do
		if isClass(child, "wxDialog") and child:IsModal() then
			child:EndModal(wxID_CANCEL)
		end
	end

	topFrame:Destroy() -- Needed?
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
			showError("Error", T("error_tooManyDroppedFiles", {n=MAX_DROPPED_FILES}))
			return
		end
	end

	if not pathsToAdd[1] then  return  end

	local previousLastWxRow = (anyFileInfos() and fileList.ItemCount or 0)-1

	for _, path in ipairs(pathsToAdd) do
		addFileInfo(toNormalPath(path))
	end

	saveFileInfos()
	listCtrlSelectRows(fileList, range(previousLastWxRow+1, fileList.ItemCount-1))
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
-- progressGauge.Value = 50

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

newMenuItem(menuFile, topFrame, T"menuItem_settings"..(DEBUG and "\tAlt+S" or ""), T"menuItem_settings_tip", function(e)
	dialogs.settings()
end)

if appZip or DEBUG then
	newMenuItemSeparator(menuFile)

	newMenuItem(menuFile, topFrame, T"menuItem_updateProgram", T"menuItem_updateProgram_tip", function(e)
		dialogs.updateApp()
	end)
end

newMenuItemSeparator(menuFile)

newMenuItem(menuFile, topFrame, wxID_EXIT, T"menuItem_exit".."\tCtrl+Q", T"menuItem_exit_tip", function(e)
	maybeQuit()
end)

-- Help.
--------------------------------

newMenuItem(menuHelp, topFrame, T"menuItem_changelog", T"menuItem_changelog_tip", function(e)
	dialogs.changelog()
end)

newMenuItem(menuHelp, topFrame, T"menuItem_log", T"menuItem_log_tip", function(e)
	-- @UX: Show a window with the log instead of using Notepad.
	openFileInNotepad(logFilePath)
end)

newMenuItemSeparator(menuHelp)

newMenuItem(menuHelp, topFrame, T"menuItem_forumThread", T"menuItem_forumThread_tip", function(e)
	local url = "https://anidb.net/perl-bin/animedb.pl?show=cmt&id=83307"
	if not wxLaunchDefaultBrowser(url) then
		showError("Error", F("%s\n\n%s", T"error_launchDefaultBrowser", url))
	end
end)

newMenuItem(menuHelp, topFrame, T"menuItem_repository", T"menuItem_repository_tip", function(e)
	local url = "https://github.com/ReFreezed/MyHappyList"
	if not wxLaunchDefaultBrowser(url) then
		showError("Error", F("%s\n\n%s", T"error_launchDefaultBrowser", url))
	end
end)

newMenuItemSeparator(menuHelp)

newMenuItem(menuHelp, topFrame, wxID_ABOUT, T"menuItem_about", T"menuItem_about_tip", function(e)
	dialogs.about()
end)

-- Debug.
--------------------------------

if DEBUG then
	newMenuItem(menuDebug, topFrame, "scriptCaptureAsync\tF7", function(e)
		local n = math.random(1000, 9999)
		print(n, "start")
		scriptCaptureAsync("test", function(output)
			print(n, "end", makePrintable(output))
		end)
	end)
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

menuBar:Append(menuFile, T"menuItem_file")
if DEBUG then  menuBar:Append(menuDebug, "&Debug")  end
menuBar:Append(menuHelp, T"menuItem_help")

topFrame.MenuBar = menuBar



topPanel        = wxPanel(topFrame, wxID_ANY)
local sizerMain = wxBoxSizer(wxVERTICAL)



-- Bars above file list.
--==============================================================

loginButton = newButton(topPanel, wxID_ANY, T"label_logIn", function(e)
	dialogs.credentials()
end)
loginButton:SetSizeHints(getWidth(loginButton), 1.4*getHeight(loginButton))
loginButton.BackgroundColour = wxColour(255, 255, 0)
loginButton:Show(false)
sizerMain:Add(loginButton, 0, wxGROW)



-- File list.
--==============================================================

fileList = wxListCtrl(
	topPanel, wxID_ANY, wxDEFAULT_POSITION, wxDEFAULT_SIZE,
	wxLC_REPORT
)
sizerMain:Add(fileList, 1, wxGROW)

assert(listCtrlInsertColumn(fileList, T"label_file",      appSettings["fileColumnWidth"..FILE_COLUMN_FILE])   == FILE_COLUMN_FILE-1)
assert(listCtrlInsertColumn(fileList, T"label_directory", appSettings["fileColumnWidth"..FILE_COLUMN_FOLDER]) == FILE_COLUMN_FOLDER-1)
assert(listCtrlInsertColumn(fileList, T"label_fileSize",  appSettings["fileColumnWidth"..FILE_COLUMN_SIZE])   == FILE_COLUMN_SIZE-1)
assert(listCtrlInsertColumn(fileList, T"label_watched",   appSettings["fileColumnWidth"..FILE_COLUMN_VIEWED]) == FILE_COLUMN_VIEWED-1)
assert(listCtrlInsertColumn(fileList, T"label_status",    appSettings["fileColumnWidth"..FILE_COLUMN_STATUS]) == FILE_COLUMN_STATUS-1)

listCtrlInsertRow(fileList, T"message_dropFilesHereInList")
fileList:Enable(false)

on(fileList, "COMMAND_LIST_ITEM_ACTIVATED", function(e, wxRow)
	local fileInfo = getFileInfoByRow(wxRow)
	local path     = fileInfo and fileInfo.path
	if isFile(path) then
		openFileExternally(path)
	else
		showError("Error", F("%s\n\n%s", T"error_missingFile", path))
		checkFileInfos()
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
		local mods = e.Modifiers

		if kc == KC_DELETE and mods == wxMOD_NONE then
			removeSelectedFileInfos()

		elseif kc == KC_A and mods == wxMOD_CONTROL then
			listCtrlSelectRows(fileList, range(0, fileList.ItemCount-1))

		elseif kc == KC_F2 and mods == wxMOD_NONE then
			dialogs.addmylist(getSelectedFileInfos(true))

		elseif kc == KC_O and mods == wxMOD_CONTROL+wxMOD_SHIFT then
			local fileInfo = getSelectedFileInfos()[1]
			if fileInfo then
				openContainingFolder(fileInfo.path)
			end

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

	local anyIsPossiblyOnAnidb = false
	local anyIsUnknown         = false
	local anyIsNotInMylist     = false
	local anyIsInMylist        = false

	-- local anyIsWatched     = false
	-- local anyIsUnwatched   = false

	for _, fileInfo in ipairs(fileInfosSelected) do
		if fileInfo.ed2k ~= "" then
			anyIsHashed = true
		end

		if     fileInfo.mylistStatus == MYLIST_STATUS_YES then
			anyIsPossiblyOnAnidb = true
			anyIsInMylist        = true
		elseif fileInfo.mylistStatus == MYLIST_STATUS_NO then
			anyIsPossiblyOnAnidb = true
			anyIsNotInMylist     = true
		elseif fileInfo.mylistStatus == MYLIST_STATUS_INVALID then
			-- void
		else
			anyIsPossiblyOnAnidb = true
			anyIsUnknown         = true
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
		newMenuItemLabel(popupMenu, T("label_numFilesSelected", {n=#fileInfosSelected}))
		newMenuItemSeparator(popupMenu)
	end

	newMenuItem(popupMenu, fileList, T"menuItem_play".."\tEnter", T"menuItem_play_tip", function(e)
		local path = fileInfosSelected[1].path
		if isFile(path) then
			openFileExternally(path)
		else
			showError("Error", F("%s\n\n%s", T"error_missingFile", path))
			checkFileInfos()
		end
	end)

	newMenuItem(popupMenu, fileList, T"menuItem_markAsWatched", T"menuItem_markAsWatched_tip", function(e)
		local values = {viewed=true}

		for _, fileInfo in ipairs(fileInfosSelected) do
			if fileInfo.lid ~= -1 then
				anidb:editMylist(fileInfo.lid, values)

			elseif fileInfo.ed2k ~= "" then
				anidb:addMylistByEd2k(fileInfo.ed2k, fileInfo.size, values)
			end
		end
	end):Enable(anyIsPossiblyOnAnidb)

	newMenuItem(popupMenu, fileList, T"menuItem_openContainingFolder".."\tCtrl+Shift+O", T"menuItem_openContainingFolder_tip", function(e)
		openContainingFolder(fileInfosSelected[1].path)
	end)

	newMenuItem(popupMenu, fileList, T"menuItem_removeFromList".."\tDelete", T"menuItem_removeFromList_tip", function(e)
		removeSelectedFileInfos()
	end)

	----------------------------------------------------------------
	newMenuItemSeparator(popupMenu)

	newMenuItem(popupMenu, fileList, T"menuItem_addToOrEditMylist".."\tF2", T"menuItem_addToOrEditMylist_tip", function(e)
		dialogs.addmylist(getSelectedFileInfos(true))
	end):Enable(anyIsHashed and anyIsPossiblyOnAnidb)

	----------------------------------------------------------------
	newMenuItemSeparator(popupMenu)

	local submenu = wxMenu()

	newMenuItem(
		submenu, topFrame, T"menuItem_copyEd2kToClipboard", T"menuItem_copyEd2kToClipboard_tip",
		function(e)
			if fileInfosSelected[2] then
				local ed2ks = getColumn(fileInfosSelected, "ed2k")
				clipboardSetText(table.concat(ed2ks, "\n"))
				setStatusText(T("message_ed2kCopiedToClipboard", {n=#fileInfosSelected}))
			else
				local fileInfo = fileInfosSelected[1]
				clipboardSetText(fileInfo.ed2k)
				setStatusText(T("message_ed2kCopiedToClipboard_single", {filename=fileInfo.name}))
			end
		end
	):Enable(anyIsHashed)

	newMenuItemSeparator(submenu)

	newMenuItem(submenu, fileList, T"menuItem_refreshStatus", T"menuItem_refreshStatus_tip", function(e)
		for _, fileInfo in ipairs(fileInfosSelected) do
			softUpdateFileInfo(fileInfo, true)
		end
		checkFileInfos()
	end)

	newMenuItemSeparator(submenu)

	newMenuItem(submenu, fileList, T"menuItem_deleteFromMylist", T"menuItem_deleteFromMylist_tip", function(e)
		if not confirm(T"label_deleteFromMylist", T"message_deleteFromMylist", T"label_delete") then  return  end

		for _, fileInfo in ipairs(fileInfosSelected) do
			if fileInfo.lid ~= -1 then
				anidb:deleteMylist(fileInfo.lid)
			end
		end
	end):Enable(anyIsInMylist)

	newMenuItem(popupMenu, fileList, T"menuItem_more", submenu)

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
	end

	----------------------------------------------------------------
	local wxRows = listCtrlGetSelectedRows(fileList)
	listCtrlPopupMenu(fileList, popupMenu, wxRows[#wxRows], e.Position)
end)



--==============================================================

topFrame.DefaultItem = fileList
topPanel.AutoLayout  = true
topPanel.Sizer       = sizerMain

local updateTimer = newTimer(function(e)
	anidb:update()

	local eHandlers = require"eventHandlers"

	for eName, _1, _2, _3, _4, _5 in eventQueue:events() do
		if not isAny(eName, "message_count") then
			logprint(nil, "Event: %s", eName)
		end

		local handler = eHandlers[eName]
		if handler then
			handler(_1, _2, _3, _4, _5)

		elseif eName:find"^error" or eName:find"^%w+:error" then
			eHandlers._error(eName, _1)

		else
			logprinterror("App", "Unhandled event '%s'.", eName)
		end
	end
end)



--==============================================================
--= Load Stuff =================================================
--==============================================================

-- Note: The settings file has already been loaded here above.

loadFileInfos()

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

updateTimer:Start(1000/20)

settingsAreFrozen = false

wxGetApp():MainLoop()



--==============================================================
--= Exit =======================================================
--==============================================================

-- saveSettings() -- No, do this in CLOSE_WINDOW instead!

processStopAll(true) -- May take some time as we try to end the processes gracefully.

anidb:destroy()
anidb = nil

if clearTempDirOnExit and isDirectory(DIR_TEMP) then
	emptyDirectory(DIR_TEMP, true)
end

logprint(nil, "Exiting normally.")
logEnd()


