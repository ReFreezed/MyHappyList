--[[============================================================
--=
--=  Event Handlers
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

local eHandlers = {}



eHandlers["need_credentials"] = function()
	dialogs.credentials()
end



eHandlers["message_count"] = function(msgCount)
	if msgCount == 0 then
		statusBarSetField(statusBar, STATUS_BAR_FIELD_MESSAGE_QUEUE, "")
	else
		statusBarSetField(statusBar, STATUS_BAR_FIELD_MESSAGE_QUEUE, "Task queue: %d", msgCount)
	end
end



eHandlers["ed2k_success"] = function(path, ed2kHash, fileSize)
	for _, fileInfo in ipairs(fileInfos) do
		if fileInfo.ed2k == "" and fileInfo.path == path then
			setFileInfo(fileInfo, "ed2k",      ed2kHash)
			setFileInfo(fileInfo, "isHashing", false)
			saveFileInfos()

			if appSettings.autoAddToMylist then
				-- addMylistByEd2k() will act as getMylistByEd2k() if an entry already exist.
				anidb:addMylistByEd2k(fileInfo.ed2k, fileInfo.size)
			else
				anidb:getMylistByEd2k(fileInfo.ed2k, fileInfo.size)
			end

			break
		end
	end
end

eHandlers["ed2k_fail"] = function(path)
	for _, fileInfo in ipairs(fileInfos) do
		if fileInfo.isHashing and fileInfo.path == path then
			-- @Incomplete: Show an error message.
			setFileInfo(fileInfo, "isHashing", false)
			break
		end
	end
end



eHandlers["login_success"] = function()
end

eHandlers["login_badlogin"] = function()
	pause("badlogin")
	showError("Bad Login", "The username and/or password is incorrect.")
	unpause("badlogin")

	anidb.canAskForCredentials = false -- Prevent a need_credentials event.
	dialogs.credentials()
end

eHandlers["login_fail"] = function(userMessage)
end



eHandlers["mylistget_success"] = function(mylistEntry)
	local fileInfo
		=  mylistEntry.lid  and itemWith(fileInfos, "lid",mylistEntry.lid)
		or mylistEntry.ed2k and itemWith(fileInfos, "ed2k",mylistEntry.ed2k, "size",mylistEntry.size)
		or mylistEntry.fid  and itemWith(fileInfos, "fid",mylistEntry.fid)

	if not fileInfo then  return  end

	setFileInfo(fileInfo, "lid",          mylistEntry.lid)
	setFileInfo(fileInfo, "fid",          mylistEntry.fid)
	setFileInfo(fileInfo, "mylistStatus", MYLIST_STATUS_YES)
	saveFileInfos()
end

eHandlers["mylistget_missing"] = function(ed2kHash, fileSize)
	local fileInfo = itemWith(fileInfos, "ed2k",ed2kHash, "size",fileSize)
	if not fileInfo then  return  end

	setFileInfo(fileInfo, "lid",          -1) -- A previously existing entry may have been removed.
	setFileInfo(fileInfo, "fid",          -1)
	setFileInfo(fileInfo, "mylistStatus", MYLIST_STATUS_NO)
	saveFileInfos()
end

eHandlers["mylistget_found_multiple_entries"] = function(mylistSelection)
	-- @Incomplete
end

eHandlers["mylistget_fail"] = function(userMessage)
end



eHandlers["mylistadd_success"] = function(mylistEntryPartial, isEdit)
	if not isEdit then
		-- Should we fetch new fresh data for edited entries too? Not sure if
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
end

eHandlers["mylistadd_success_multiple"] = function(count)
	-- @Incomplete
end

eHandlers["mylistadd_found_multiple_files"] = function(fids)
	-- @Incomplete
end

eHandlers["mylistadd_no_file"] = function(fid)
	local fileInfo = itemWith(fileInfos, "fid",fid)
	if not fileInfo then  return  end

	setFileInfo(fileInfo, "lid",          -1)
	setFileInfo(fileInfo, "fid",          -1) -- The file must have been removed from AniDB for some reason.
	setFileInfo(fileInfo, "mylistStatus", MYLIST_STATUS_INVALID)
	saveFileInfos()
end

eHandlers["mylistadd_no_file_with_hash"] = function(ed2kHash, fileSize)
	local fileInfo = itemWith(fileInfos, "ed2k",ed2kHash, "size",fileSize)
	if not fileInfo then  return  end

	setFileInfo(fileInfo, "lid",          -1)
	setFileInfo(fileInfo, "fid",          -1)
	setFileInfo(fileInfo, "mylistStatus", MYLIST_STATUS_INVALID)
	saveFileInfos()
end

eHandlers["mylistadd_fail"] = function(userMessage)
end



eHandlers["mylistdelete_success"] = function(mylistEntryMaybePartial)
	local fileInfo
		=  itemWith(fileInfos, "lid",mylistEntryMaybePartial.lid)
		or mylistEntryMaybePartial.ed2k and itemWith(fileInfos, "ed2k",mylistEntryMaybePartial.ed2k, "size",mylistEntryMaybePartial.size)
		or mylistEntryMaybePartial.fid  and itemWith(fileInfos, "fid",mylistEntryMaybePartial.fid)

	if not fileInfo then  return  end

	setFileInfo(fileInfo, "lid",          -1)
	setFileInfo(fileInfo, "fid",          -1)
	setFileInfo(fileInfo, "mylistStatus", MYLIST_STATUS_NO)
	saveFileInfos()
end

eHandlers["mylistdelete_fail"] = function(userMessage)
end



eHandlers["blackout_start"] = function()
end

eHandlers["blackout_stop"] = function()
end



eHandlers["ping_fail"] = function(userMessage)
end



eHandlers["resend"] = function(command)
end



eHandlers["new_version_available"] = function(userMessage)
	if updateAvailableMessageReceived then  return  end
	updateAvailableMessageReceived = true

	-- @UX: A less intrusive "Update Available" notification.
	showMessage("Update Available", "A new version of MyHappyList is available.")
end

eHandlers["message"] = function(userMessage)
	showMessage("Message", userMessage)
end



eHandlers["error_response_timeout"] = function(command)
	showError(
		"Timeout",
		"Got no response from AniDB in time. Maybe the server is offline or your Internet connection is down?"
			.."\n\nCommand: "..command
	)
end



eHandlers._error = function(eName, userMessage)
	showError("Error", F("%s: %s", eName, userMessage))
end

return eHandlers
