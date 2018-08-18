--[[============================================================
--=
--=  App Environment
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--==============================================================

	pause, unpause, isPaused
	setSetting, loadSettings, saveSettings, scheduleSaveSettings, scheduleSaveSettingsIfNeeded, setSettingsChanged
	setStatusText

	addFileInfo, removeFileInfo, removeSelectedFileInfos
	anyFileInfos, noFileInfos
	checkFileInfos
	eachFileInfoByRow, getFileInfosByRows, getSelectedFileInfos
	getFileInfoByRow, getFileRow
	getFileStatus, getFileViewed
	openContainingFolder
	saveFileInfos, loadFileInfos
	setFileInfo
	updateFileList

--============================================================]]

FILE_INFO_DONT_SERIALIZE       = newSet{"name","folder","isHashing"}

FILE_COLUMN_FILE               = 1
FILE_COLUMN_FOLDER             = 2
FILE_COLUMN_SIZE               = 3
FILE_COLUMN_VIEWED             = 4
FILE_COLUMN_STATUS             = 5
FILE_COLUMN_LAST               = 5

MYLIST_STATUS_UNKNOWN          = 0
MYLIST_STATUS_NO               = 1
MYLIST_STATUS_YES              = 2
MYLIST_STATUS_INVALID          = 3 -- AniDB don't know of the file (ed2k+size missing).  @Incomplete: Use this!

DROP_FILES_TO_ADD_MESSAGE      = "Drop files here to add them!"

STATUS_BAR_FIELD_MESSAGE_QUEUE = 1



anidb            = nil
appIcons         = nil
fontTitle        = nil

topFrame         = nil
statusBar        = nil
topPanel         = nil
loginButton      = nil
fileList         = nil

anidbUpdateTimer = nil

fileInfos        = {}
lastFileId       = 0 -- Local ID, not fid on AniDB.

updateAvailableMessageReceived = false

appSettings = {
	autoAddToMylist        = true,
	autoHash               = true,
	autoRemoveDeletedFiles = false,
	truncateFolders        = true,

	movieExtensions = {"avi","flv","mkv","mov","mp4","mpeg","mpg","ogm","ogv","swf","webm","wmv"},

	mylistDefaults = {
		state   = MYLIST_STATE_INTERNAL_STORAGE,
		viewed  = nil, -- bool
		source  = nil, -- string
		storage = nil, -- string
		other   = nil, -- string (newlines allowed)
	},

	windowSizeX     = -1,
	windowSizeY     = -1,
	windowPositionX = -1,
	windowPositionY = -1,
	windowMaximized = false,

	["fileColumnWidth"..FILE_COLUMN_FILE]   = 500,
	["fileColumnWidth"..FILE_COLUMN_FOLDER] = 500,
	["fileColumnWidth"..FILE_COLUMN_SIZE]   = 80,
	["fileColumnWidth"..FILE_COLUMN_VIEWED] = 80,
	["fileColumnWidth"..FILE_COLUMN_STATUS] = 120,
}

dialogs = require"dialogs"



--==============================================================
--= Functions ==================================================
--==============================================================



-- fileInfo = addFileInfo( path )
-- fileInfo = addFileInfo( fileInfo ) -- For the loading phase.
function addFileInfo(pathOrFi)
	local fi, path

	if type(pathOrFi) == "table" then
		fi   = pathOrFi
		path = fi.path

	else
		path = pathOrFi
		fi   = fileInfos[path]
		if fi then  return fi  end

		lastFileId = lastFileId+1

		fi = {
			-- Don't forget to update FILE_INFO_DONT_SERIALIZE when necessary.
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

	fi.name      = getFilename(path)
	fi.folder    = getDirectory(path)
	fi.isHashing = false

	setAndInsert(fileInfos, path, fi)

	if #fileInfos == 1 then
		fileList:DeleteItem(0)
		fileList:Enable(true)
	end

	local wxRow = listCtrlInsertRow(fileList, fi.name, fi.folder, formatBytes(fi.size), getFileViewed(fi), getFileStatus(fi))
	fileList:SetItemData(wxRow, fi.id)

	if not isFile(path) then
		-- Do nothing here. checkFileInfos() should be called at some point after this function.

	elseif fi.ed2k == "" and appSettings.autoHash then
		setFileInfo(fi, "isHashing", true)
		anidb:hashFile(path)

	elseif fi.lid == -1 and fi.ed2k ~= "" and not appSettings.autoAddToMylist and fi.mylistStatus == MYLIST_STATUS_UNKNOWN then
		anidb:getMylistByEd2k(fi.ed2k, fi.size)

	elseif fi.lid == -1 and fi.ed2k ~= "" and appSettings.autoAddToMylist and fi.mylistStatus ~= MYLIST_STATUS_INVALID then
		-- This will act as getMylistByEd2k() if an entry already exist.
		anidb:addMylistByEd2k(fi.ed2k, fi.size)

	elseif fi.lid ~= -1 and fi.fid == -1 then
		-- The app probably stopped before getting this info last session.
		anidb:getMylist(fi.lid)
	end

	return fi
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

function removeSelectedFileInfos()
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

	local usePrefix = (appSettings.truncateFolders and prefix ~= "")

	for _, fileInfo in ipairs(fileInfos) do
		listCtrlSetItem(
			fileList,
			getFileRow(fileInfo),
			FILE_COLUMN_FOLDER-1,
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

	local colorStripe1 = wxCOLOUR_WHITE
	local colorStripe2 = wxColour(245, 245, 245)

	for wxRow = 0, fileList:GetItemCount()-1 do
		local color = (wxRow%2 == 0 and colorStripe1 or colorStripe2)
		fileList:SetItemBackgroundColour(wxRow, color)
	end
end


do
	local FILE_INFO_VERSION = 1

	function saveFileInfos()
		logprint("App", "Saving file info.")

		if DEBUG_DISABLE_VARIOUS_FILE_SAVING then  return  end

		local path = DIR_CACHE.."/files"

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
		local path = DIR_CACHE.."/files"
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
				logprinterror("App", "%s:%d: Missing ID for previous entry. Skipping.", path, ln)
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
						logprinterror("App", "%s:%d: Duplicate key '%s'. Overwriting.", path, ln, k)
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

	if k == "path" then
		local pathOld = fileInfo.path
		local pathNew = v

		fileInfo.path   = pathNew
		fileInfo.name   = getFilename(pathNew)
		fileInfo.folder = getDirectory(pathNew)

		-- @Robustness: Check if fileInfos[pathNew] is already occupied.
		fileInfos[pathOld] = nil
		fileInfos[pathNew] = fileInfo

		anidb:reportLocalFileMoved(pathOld, pathNew)

	else
		fileInfo[k] = v
	end

	local wxRow = getFileRow(fileInfo)
	if not wxRow then
		logprinterror("App", "File %d is not in list.", fileInfo.id)
		return
	end

	if isAny(k, "lid","fid","ed2k","isHashing","mylistStatus") then
		fileList:SetItem(wxRow, FILE_COLUMN_VIEWED-1, getFileViewed(fileInfo))
		fileList:SetItem(wxRow, FILE_COLUMN_STATUS-1, getFileStatus(fileInfo))

	elseif isAny(k, "path") then
		fileList:SetItem(wxRow, FILE_COLUMN_FILE-1,   fileInfo.name)
		fileList:SetItem(wxRow, FILE_COLUMN_FOLDER-1, fileInfo.folder)
	end
end



function getFileStatus(fileInfo)
	return
		nil
		or fileInfo.isHashing                              and "Calculating hash"
		or fileInfo.mylistStatus == MYLIST_STATUS_INVALID  and "Not on AniDB"
		or fileInfo.mylistStatus == MYLIST_STATUS_YES      and "In MyList"
		or fileInfo.mylistStatus == MYLIST_STATUS_NO       and "Not in MyList"
		or fileInfo.ed2k         ~= ""                     and "Hashed"
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
	topFrame:SetStatusText(s)
end



do
	local PATH_SETTINGS = DIR_CONFIG.."/settings"

	local saveScheduled = false
	local saveTimer     = nil

	local callbacks     = {}

	-- setSetting( key, value    [, startSaveTimer=true ] )
	-- setSetting( key, callback [, startSaveTimer=true ] )
	-- Note: The callback is called twice - immediately and before saving.
	function setSetting(k, vOrCb, startSaveTimer)
		if settingsAreFrozen       then  return  end
		if appSettings[k] == vOrCb then  return  end

		if type(vOrCb) == "function" then
			callbacks[k]   = vOrCb
			appSettings[k] = vOrCb()
		else
			callbacks[k]   = nil
			appSettings[k] = vOrCb
		end

		if startSaveTimer == false then
			saveScheduled = true
		else
			scheduleSaveSettings()
		end
	end

	function loadSettings()
		readSimpleEntryFile(PATH_SETTINGS, appSettings, true)
	end

	function saveSettings()
		if not saveScheduled then  return  end
		if isPaused()        then  return  end

		local _callbacks = callbacks
		callbacks = {}
		for k, cb in pairs(_callbacks) do
			appSettings[k] = cb()
		end

		if saveTimer then  saveTimer:Stop()  end

		logprint("App", "Saving settings.")

		if not DEBUG_DISABLE_VARIOUS_FILE_SAVING then
			assert(writeSimpleEntryFile(PATH_SETTINGS, appSettings))
		end
		saveScheduled = false
	end

	-- scheduleSaveSettings( [ delay=SAVE_DELAY ] )
	function scheduleSaveSettings(delay)
		delay = delay or SAVE_DELAY

		saveScheduled = true

		saveTimer = saveTimer or newTimer(function(e)  saveSettings()  end)
		saveTimer:Start(delay, true)
	end

	-- scheduleSaveSettingsIfNeeded( )
	function scheduleSaveSettingsIfNeeded()
		if not saveScheduled                   then  return  end
		if saveTimer and saveTimer:IsRunning() then  return  end

		scheduleSaveSettings()
	end

	function setSettingsChanged()
		saveScheduled = true
	end
end




do
	local function silentlyCheckFileAndMaybeRegisterMove(fileInfo, dirNew)
		local pathOld = fileInfo.path
		if isFile(pathOld) then  return  end

		local pathNew = F("%s/%s", dirNew, fileInfo.name)

		if not fileInfos[pathNew] and isFile(pathNew) and getFileSize(pathNew) == fileInfo.size then
			setFileInfo(fileInfo, "path", pathNew)
		end
	end

	local function checkFile(fileInfo, i)
		local pathOld = fileInfo.path
		if isFile(pathOld) then  return  end

		if appSettings.autoRemoveDeletedFiles then
			removeFileInfo(fileInfo)
			anidb:reportLocalFileDeleted(pathOld)
			return true
		end

		local pathNew = dialogs.missingFile(pathOld)
		if not pathNew then
			-- Leave fileInfo as-is. (Should we mark it so we don't ask for a new path again?)
			return false
		end

		if pathNew == "" then
			removeFileInfo(fileInfo)
			anidb:reportLocalFileDeleted(pathOld)
			return true
		end

		local fileSize = getFileSize(pathNew)

		if fileSize ~= fileInfo.size then
			showError("Different File", F(
				"The size of the file on the old path was different than the file on the new path.\n\n"
				.."%.0f bytes (old)\n%.0f bytes (new)\n\n%s", fileInfo.size, fileSize, pathNew
			))

			return checkFile(fileInfo, i)
		end

		setFileInfo(fileInfo, "path", pathNew)

		for j = 1, i-1 do
			silentlyCheckFileAndMaybeRegisterMove(fileInfos[j], getDirectory(pathNew))
		end

		return true
	end

	function checkFileInfos()
		local anyFileInfoChanged = false

		-- Check deleted/moved files.
		for i, fileInfo in ipairsr(fileInfos) do
			anyFileInfoChanged = checkFile(fileInfo, i) or anyFileInfoChanged
		end

		-- @@ Do autoHash etc.

		if anyFileInfoChanged then
			saveFileInfos()
			updateFileList()
		end
	end
end



do
	local pauseKeys = {}

	function pause(k)
		if pauseKeys[k] then
			pauseKeys[k] = pauseKeys[k]+1

		else
			if not isPaused() then
				logprint(nil, "Paused by '%s'.", k)
			end
			pauseKeys[k] = 1
		end
	end

	function unpause(k)
		if not pauseKeys[k] then
			logprinterror(nil, "Tried to remove non-existent pause key '%s'.", k)

		elseif pauseKeys[k] > 1 then
			pauseKeys[k] = pauseKeys[k]-1

		else
			pauseKeys[k] = nil
			if not isPaused() then
				logprint(nil, "Unpaused by '%s'.", k)
				scheduleSaveSettingsIfNeeded()
			end
		end
	end

	function isPaused()
		return next(pauseKeys) ~= nil
	end
end



function openContainingFolder(path)
	if isDirectory(getDirectory(path)) then
		showFileInExplorer(path)
	else
		showError("Error", F("Folder does not exist.\n\n%s", path))
		checkFileInfos()
	end
end


