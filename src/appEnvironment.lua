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
--============================================================]]

FILE_INFO_DONT_SERIALIZE       = newSet{"name","folder","isHashing"}

FILE_COLUMN_FILE               = nil -- Set in 'app'.
FILE_COLUMN_FOLDER             = nil
FILE_COLUMN_SIZE               = nil
FILE_COLUMN_VIEWED             = nil
FILE_COLUMN_STATUS             = nil

MYLIST_STATUS_UNKNOWN          = 0
MYLIST_STATUS_NO               = 1
MYLIST_STATUS_YES              = 2
MYLIST_STATUS_INVALID          = 3 -- AniDB don't know of the file (ed2k+size missing).  @Incomplete: Use this!

DROP_FILES_TO_ADD_MESSAGE      = "Drop files here to add them!"

STATUS_BAR_FIELD_MESSAGE_QUEUE = 1



anidb      = nil
appIcons   = nil
fontTitle  = nil

topFrame   = nil
statusBar  = nil
fileList   = nil

fileInfos  = {}
lastFileId = 0 -- Local ID, not fid on AniDB.

updateAvailableMessageReceived = false

appSettings = {
	autoHash        = true,
	autoAddToMylist = false, -- @Incomplete

	movieExtensions = newSet{"avi","flv","mkv","mov","mp4","mpeg","mpg","ogm","ogv","swf","webm","wmv"},
	trunkateFolders = true,
}

dialogs = require"dialogs"



--==============================================================
--= Functions ==================================================
--==============================================================

-- setStatusText

-- addFileInfo, removeFileInfo, removeSelectedFileInfos
-- anyFileInfos, noFileInfos
-- eachFileInfoByRow, getFileInfosByRows, getSelectedFileInfos
-- getFileInfoByRow, getFileRow
-- getFileStatus, getFileViewed
-- saveFileInfos, loadFileInfos
-- setFileInfo
-- updateFileList



-- fileInfo = addFileInfo( path )
-- fileInfo = addFileInfo( fileInfo ) -- For loading phase.
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

	if fileInfo.ed2k == "" and appSettings.autoHash then
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

	local usePrefix = (appSettings.trunkateFolders and prefix ~= "")

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
	topFrame:SetStatusText(s)
end


