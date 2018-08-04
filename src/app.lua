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

local wxPleaseJustStop = wx.wxLogNull()

assert(createDirectory("local"))
assert(createDirectory("logs"))
assert(createDirectory("temp"))
assert(createDirectory(CACHE_DIR))

local logFilePath = "logs/output.log"
logFile = assert(openFile(logFilePath, "a"))

anidb     = require"Anidb"()
appIcons  = wx.wxIconBundle("gfx/appicon.ico", wxBITMAP_TYPE_ANY)
fontTitle = wx.wxFont(1.2*wx.wxNORMAL_FONT:GetPointSize(), wxFONTFAMILY_DEFAULT, wxFONTSTYLE_NORMAL, wxFONTWEIGHT_BOLD)



-- Top frame.
--==============================================================

topFrame = wx.wxFrame(
	wxNULL,
	wxID_ANY,
	"MyHappyList"..(DEBUG_LOCAL and " [OFFLINE]" or ""),
	wxDEFAULT_POSITION,
	WxSize(1300, 400),
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
	else
		e:Skip() -- Proceed with exit.
	end
end)

on(topFrame, "DROP_FILES", function(e, paths)
	local pathsToAdd = {}

	for _, path in ipairs(paths) do
		local mode = getFileMode(path)

		if mode == "directory" then
			traverseFiles(path, function(path, pathRel, name, ext)
				if appSettings.movieExtensions[ext:lower()] then
					table.insert(pathsToAdd, path)
				end

				if pathsToAdd[MAX_DROPPED_FILES+1] then
					return true -- Break.
				end
			end)

		elseif mode == "file" then
			if appSettings.movieExtensions[getExtension(getFilename(path)):lower()] then
				table.insert(pathsToAdd, path)
			end
		end

		if pathsToAdd[MAX_DROPPED_FILES+1] then
			showError(topFrame, "Error", F("Too many dropped files. (Max is %d)", MAX_DROPPED_FILES))
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
local menuHelp  = wx.wxMenu()
local menuDebug = DEBUG and wx.wxMenu() or nil

-- File.
--------------------------------

newMenuItem(menuFile, topFrame, wxID_EXIT, "E&xit\tCtrl+Q", "Quit the program", function(e)
	topFrame:Close()
end)

-- Edit.
--------------------------------

newMenuItem(menuEdit, topFrame, "&Settings", "Change settings", function(e)
	showMessage("Settings", "@Incomplete")
end)

-- Help.
--------------------------------

-- newMenuItem(menuHelp, topFrame, "&Forum Thread", "Go to MyHappyList's forum thread on AniDB", function(e)
-- 	-- @Incomplete
-- end)

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

local menuBar = wx.wxMenuBar()

menuBar:Append(menuFile, "&File")
-- menuBar:Append(menuEdit, "&Edit")
if DEBUG then  menuBar:Append(menuDebug, "&Debug")  end
menuBar:Append(menuHelp, "&Help")

topFrame:SetMenuBar(menuBar)



topPanel        = wx.wxPanel(topFrame, wx.wxID_ANY)
local sizerMain = wx.wxBoxSizer(wxVERTICAL)



-- Bars above file list.
--==============================================================

loginButton = newButton(topPanel, wxID_ANY, "Log In", function(e)
	dialogs.credentials()
end)
loginButton:SetSizeHints(getWidth(loginButton), 1.4*getHeight(loginButton))
loginButton:SetBackgroundColour(wx.wxColour(255, 255, 0))
loginButton:Show(false)
sizerMain:Add(loginButton, 0, wxGROW)



-- File list.
--==============================================================

fileList = wx.wxListCtrl(
	topPanel, wxID_ANY, wxDEFAULT_POSITION, wxDEFAULT_SIZE,
	wxLC_REPORT
)
sizerMain:Add(fileList, 1, wxGROW_ALL)

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
			removeSelectedFileInfos()

		elseif kc == KC_A and e:GetModifiers() == wxMOD_CONTROL then
			listCtrlSelectRows(fileList, range(0, fileList:GetItemCount()-1))

		elseif kc == KC_F2 then
			dialogs.addmylist()

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
	newMenuItem(popupMenu, fileList, "&Play\tEnter", helpText, function(e)
		openFileExternally(fileInfosSelected[1].path)
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

	newMenuItem(popupMenu, fileList, "Open &Contaning Folder", "Open the folder contaning the file", function(e)
		local fileInfo = fileInfosSelected[1]
		showFileInExplorer(fileInfo.path)
	end)

	newMenuItem(popupMenu, fileList, "&Remove from List\tDelete", "Remove selected files from the list", function(e)
		removeSelectedFileInfos()
	end)

	----------------------------------------------------------------
	newMenuItemSeparator(popupMenu)

	newMenuItem(popupMenu, fileList, "Add to / &Edit MyList\tF2", "Add file to, or edit, MyList", function(e)
		dialogs.addmylist()
	end):Enable(anyIsHashed)

	newMenuItem(popupMenu, fileList, "&Delete from MyList", "Delete file from MyList", function(e)
		if not confirm(topFrame, "Delete from MyList", "Delete the selected files from MyList?", "Delete") then  return  end

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

loadFileInfos()

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
--= Show GUI ===================================================
--==============================================================

topFrame:Center()
topFrame:Show(true)

if anyFileInfos() then
	fileList:SetFocus()
	listCtrlSelectRows(fileList, {0})
end

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


