--[[============================================================
--=
--=  AniDB Event Handlers
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

return {
	["needcredentials"] =
	function()
		dialogs.credentials()
	end,



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

				if appSettings.autoAddToMylist then
					-- addMylistByEd2k() will act as getMylistByEd2k() if an entry already exist.
					anidb:addMylistByEd2k(fileInfo.ed2k, fileInfo.size)
				else
					anidb:getMylistByEd2k(fileInfo.ed2k, fileInfo.size)
				end

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
	function()
	end,

	["loginbadlogin"] =
	function()
		pause("badlogin")
		showError("Bad Login", "The username and/or password is incorrect.")
		unpause("badlogin")

		anidb.canAskForCredentials = false -- Prevent a needcredentials event.
		dialogs.credentials()
	end,

	["loginfail"] =
	function(userMessage)
	end,



	["mylistgetsuccess"] =
	function(mylistEntry)
		local fileInfo
			=  mylistEntry.lid  and itemWith(fileInfos, "lid",mylistEntry.lid)
			or mylistEntry.ed2k and itemWith(fileInfos, "ed2k",mylistEntry.ed2k, "size",mylistEntry.size)
			or mylistEntry.fid  and itemWith(fileInfos, "fid",mylistEntry.fid)

		if not fileInfo then  return  end

		setFileInfo(fileInfo, "lid",          mylistEntry.lid)
		setFileInfo(fileInfo, "fid",          mylistEntry.fid)
		setFileInfo(fileInfo, "mylistStatus", MYLIST_STATUS_YES)
		saveFileInfos()
	end,

	["mylistgetmissing"] =
	function(ed2kHash, fileSize)
		local fileInfo = itemWith(fileInfos, "ed2k",ed2kHash, "size",fileSize)
		if not fileInfo then  return  end

		setFileInfo(fileInfo, "lid",          -1) -- A previously existing entry may have been removed.
		setFileInfo(fileInfo, "fid",          -1)
		setFileInfo(fileInfo, "mylistStatus", MYLIST_STATUS_NO)
		saveFileInfos()
	end,

	["mylistgetfoundmultipleentries"] =
	function(mylistSelection)
		-- @Incomplete
	end,

	["mylistgetfail"] =
	function(userMessage)
	end,



	["mylistaddsuccess"] =
	function(mylistEntryPartial, isEdit)
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
	end,

	["mylistaddsuccessmultiple"] =
	function(count)
		-- @Incomplete
	end,

	["mylistaddfoundmultiplefiles"] =
	function(fids)
		-- @Incomplete
	end,

	["mylistaddnofile"] =
	function(fid)
		local fileInfo = itemWith(fileInfos, "fid",fid)
		if not fileInfo then  return  end

		setFileInfo(fileInfo, "lid",          -1)
		setFileInfo(fileInfo, "fid",          -1) -- The file must have been removed from AniDB for some reason.
		setFileInfo(fileInfo, "mylistStatus", MYLIST_STATUS_INVALID)
		saveFileInfos()
	end,

	["mylistaddnofilewithhash"] =
	function(ed2kHash, fileSize)
		local fileInfo = itemWith(fileInfos, "ed2k",ed2kHash, "size",fileSize)
		if not fileInfo then  return  end

		setFileInfo(fileInfo, "lid",          -1)
		setFileInfo(fileInfo, "fid",          -1)
		setFileInfo(fileInfo, "mylistStatus", MYLIST_STATUS_INVALID)
		saveFileInfos()
	end,

	["mylistaddfail"] =
	function(userMessage)
	end,



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
	function(userMessage)
	end,



	["blackoutstart"] =
	function()
	end,

	["blackoutstop"] =
	function()
	end,



	["pingfail"] =
	function(userMessage)
	end,



	["resend"] =
	function(command)
	end,



	["newversionavailable"] =
	function(userMessage)
		if updateAvailableMessageReceived then  return  end
		updateAvailableMessageReceived = true

		-- @UX: A less intrusive "Update Available" notification.
		showMessage("Update Available", "A new version of MyHappyList is available.")
	end,

	["message"] =
	function(userMessage)
		showMessage("Message", userMessage)
	end,



	["errorresponsetimeout"] =
	function(command)
		showError(
			"Timeout",
			"Got no response from AniDB in time. Maybe the server is offline or your Internet connection is down?"
				.."\n\nCommand: "..command
		)
	end,

	_error =
	function(eName, userMessage)
		showError("Error", F("%s: %s", eName, userMessage))
	end,
}
