--[[============================================================
--=
--=  Dialogs
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--==============================================================

	about
	addmylist
	changelog
	credentials
	missingFile
	settings

--============================================================]]

-- Max length of UDP packages (over PPPoE) is 1400 bytes. Let's try to
-- stay within the bounds before attempting to send MYLISTADD.
--
-- https://wiki.anidb.net/w/UDP_API_Definition#General
--
-- UDP message example when adding:
--    MYLISTADD ed2k=4b7e0f1101fb3ef95e187f6f086cf6b3&other=&s=GM3Fz97&size=3669066876&source=&state=2&storage=&tag=#a01340e&viewdate=1333248804&viewed=1
--
local MAX_UDP_MESSAGE_LENGTH     = 1400
local APPROX_BASE_MESSAGE_LENGTH = 150
local SAFETY_MESSAGE_LENGTH      = 20

local VIEWED_STATES = {
	{value=nil,   title=""},
	{value=true,  title="Yes"},
	{value=false, title="No"},
}

local MYLIST_STATES = {
	{value=nil,                           title=""},
	{value=MYLIST_STATE_UNKNOWN,          title="Unknown / unspecified"},
	{value=MYLIST_STATE_INTERNAL_STORAGE, title="Internal storage (HDD/SSD)"},
	{value=MYLIST_STATE_EXTERNAL_STORAGE, title="External storage (CD, DVD etc.)"},
	-- {value=MYLIST_STATE_REMOTE_STORAGE,   title="Remote storage (NAS, cloud etc.)"}, -- AniDB complains! :/
	{value=MYLIST_STATE_DELETED,          title="Deleted"},
}

local dialogs = {}



--==============================================================
--==============================================================
--==============================================================

local addMylistaddFields



-- ... = addMylistaddFields( parent, sizerParent [, valuesCurrent, mylistEntry ] )
function addMylistaddFields(parent, sizerParent, valuesCurrent, mylistEntry)

	-- Viewed.
	----------------------------------------------------------------

	local labels = getColumn(VIEWED_STATES, "title")
	labels[1] = valuesCurrent and "(default)" or "(don't change)"

	local viewedRadio = wxRadioBox(
		parent, wxID_ANY, "Watched", wxDEFAULT_POSITION, wxDEFAULT_SIZE,
		labels, 0, wxRA_SPECIFY_ROWS -- @Incomplete: Allow direct editing of viewdate.
	)
	sizerParent:Add(viewedRadio, 0, wxGROW)

	if valuesCurrent and valuesCurrent.viewed ~= nil then
		viewedRadio:SetSelection(indexWith(VIEWED_STATES, "value", valuesCurrent.viewed)-1)
	end

	-- MyList state.
	----------------------------------------------------------------

	sizerParent:AddSpacer(MARGIN_S)

	local labels = getColumn(MYLIST_STATES, "title")
	labels[1] = valuesCurrent and "(default)" or "(don't change)"

	local mylistStateRadio = wxRadioBox(
		parent, wxID_ANY, "State", wxDEFAULT_POSITION, wxDEFAULT_SIZE,
		labels, 0, wxRA_SPECIFY_ROWS
	)
	sizerParent:Add(mylistStateRadio, 0, wxGROW)

	if valuesCurrent and valuesCurrent.state ~= nil then
		mylistStateRadio:SetSelection(indexWith(MYLIST_STATES, "value", valuesCurrent.state)-1)
	end

	-- Source.
	----------------------------------------------------------------

	sizerParent:AddSpacer(MARGIN_S)

	local panel      = wxPanel(parent, wxID_ANY)
	local sizerPanel = wxBoxSizer(wxHORIZONTAL)

	local sourceCheckbox = wxCheckBox(panel, wxID_ANY, "Source:")
	sourceCheckbox:SetSizeHints(60, getHeight(sourceCheckbox))
	sourceCheckbox:SetToolTip("I.e. ed2k, DC, FTP or IRC")
	sourceCheckbox:SetValue(valuesCurrent ~= nil and valuesCurrent.source ~= nil)
	sizerPanel:Add(sourceCheckbox, 0, wxGROW)

	local sourceInput = wxTextCtrl(panel, wxID_ANY, (valuesCurrent and valuesCurrent.source or ""))
	sourceInput:SetSizeHints(200, getHeight(sourceInput))
	sourceInput:SetMaxLength(MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH)
	sourceInput:SetToolTip(sourceCheckbox:GetToolTip():GetTip())
	sizerPanel:Add(sourceInput, 0, wxGROW)

	if not (valuesCurrent and valuesCurrent.source) then
		sourceInput:Enable(false)
	end
	if not valuesCurrent and mylistEntry and mylistEntry.source then
		sourceInput:SetValue(mylistEntry.source)
	end

	on(sourceCheckbox, "COMMAND_CHECKBOX_CLICKED", function(e)
		sourceInput:Enable(e:IsChecked())
		sourceInput:SetFocus()
	end)

	on(panel, "LEFT_DOWN", function(e)
		if not sourceCheckbox:IsChecked() then
			checkBoxClick(sourceCheckbox)
		end
	end)

	panel:SetAutoLayout(true)
	panel:SetSizer(sizerPanel)
	sizerParent:Add(panel, 0, wxGROW)

	-- Storage.
	----------------------------------------------------------------

	sizerParent:AddSpacer(MARGIN_S)

	local panel      = wxPanel(parent, wxID_ANY)
	local sizerPanel = wxBoxSizer(wxHORIZONTAL)

	local storageCheckbox = wxCheckBox(panel, wxID_ANY, "Storage:")
	storageCheckbox:SetSizeHints(60, getHeight(storageCheckbox))
	storageCheckbox:SetToolTip("I.e. the label of the CD with this file")
	storageCheckbox:SetValue(valuesCurrent ~= nil and valuesCurrent.storage ~= nil)
	sizerPanel:Add(storageCheckbox, 0, wxGROW)

	local storageInput = wxTextCtrl(panel, wxID_ANY, (valuesCurrent and valuesCurrent.storage or ""))
	storageInput:SetSizeHints(200, getHeight(storageInput))
	storageInput:SetMaxLength(MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH)
	storageInput:SetToolTip(storageCheckbox:GetToolTip():GetTip())
	sizerPanel:Add(storageInput, 0, wxGROW)

	if not (valuesCurrent and valuesCurrent.storage) then
		storageInput:Enable(false)
	end
	if not valuesCurrent and mylistEntry and mylistEntry.storage then
		storageInput:SetValue(mylistEntry.storage)
	end

	on(storageCheckbox, "COMMAND_CHECKBOX_CLICKED", function(e)
		storageInput:Enable(e:IsChecked())
		storageInput:SetFocus()
	end)

	on(panel, "LEFT_DOWN", function(e)
		if not storageCheckbox:IsChecked() then
			checkBoxClick(storageCheckbox)
		end
	end)

	panel:SetAutoLayout(true)
	panel:SetSizer(sizerPanel)
	sizerParent:Add(panel, 0, wxGROW)

	-- Other.
	----------------------------------------------------------------

	sizerParent:AddSpacer(MARGIN_M)

	local panel      = wxPanel(parent, wxID_ANY)
	local sizerPanel = wxBoxSizer(wxHORIZONTAL)

	local otherCheckbox = wxCheckBox(panel, wxID_ANY, "Note:")
	otherCheckbox:SetSizeHints(60, getHeight(otherCheckbox))
	otherCheckbox:SetValue(valuesCurrent ~= nil and valuesCurrent.other ~= nil)
	sizerPanel:Add(otherCheckbox)

	local otherInput = wxTextCtrl(
		panel, wxID_ANY, (valuesCurrent and valuesCurrent.other or ""),
		wxDEFAULT_POSITION, wxSize(200, 100), wxTE_MULTILINE
	)
	local colorOn  = otherInput:GetBackgroundColour()
	local colorOff = wxSystemSettings.GetColour(wxSYS_COLOUR_3DFACE)
	otherInput:SetMaxLength(MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH)
	sizerPanel:Add(otherInput, 0, wxGROW)

	if not (valuesCurrent and valuesCurrent.other) then
		otherInput:Enable(false)
		otherInput:SetBackgroundColour(colorOff)
	end
	if not valuesCurrent and mylistEntry and mylistEntry.other then
		otherInput:SetValue(mylistEntry.other)
	end

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

	panel:SetAutoLayout(true)
	panel:SetSizer(sizerPanel)
	sizerParent:Add(panel, 0, wxGROW)

	----------------------------------------------------------------

	return
		viewedRadio,
		mylistStateRadio,
		storageCheckbox, storageInput,
		sourceCheckbox,  sourceInput,
		otherCheckbox,   otherInput
end

--==============================================================
--==============================================================
--==============================================================



function dialogs.about()
	local title     = "MyHappyList "..APP_VERSION
	local copyright = "Copyright © 2018 Marcus 'ReFreezed' Thunström. MIT license."
	local desciption
		= "MyHappyList is made using Lua, wxLua, LuaSocket and rhash. "
		.."The executable is built using srlua, ResourceHacker and ImageMagick."

	local dialog = wxDialog(topPanel, wxID_ANY, "About MyHappyList")
	local sizer  = wxBoxSizer(wxVERTICAL)

	-- Icon.
	local bm = wxBitmap()
	bm:CopyFromIcon(appIcons:GetIcon(32))
	local bmObj = wxStaticBitmap(dialog, wxID_ANY, bm)
	sizer:Add(bmObj, 0, wxALIGN_CENTRE_HORIZONTAL)

	sizer:AddSpacer(MARGIN_M)

	-- Title.
	local textObj = wxStaticText(dialog, wxID_ANY, title, wxDEFAULT_POSITION, wxDEFAULT_SIZE, wxALIGN_CENTRE_HORIZONTAL)
	textObj:SetFont(fontTitle)
	sizer:Add(textObj, 0, wxGROW)

	sizer:AddSpacer(MARGIN_M)

	-- Copyright.
	local textObj = wxStaticText(dialog, wxID_ANY, copyright, wxDEFAULT_POSITION, wxDEFAULT_SIZE, wxALIGN_CENTRE_HORIZONTAL)
	sizer:Add(textObj, 0, wxGROW)

	sizer:AddSpacer(MARGIN_M)

	-- Description.
	local textObj = wxStaticText(dialog, wxID_ANY, desciption)
	textObj:Wrap(400)
	sizer:Add(textObj, 0, wxGROW)

	sizer:AddSpacer(MARGIN_L)

	-- Close button.
	local button = newButton(dialog, wxID_OK, "Close")
	button:SetSizeHints(100, getHeight(button)+2*3)
	sizer:Add(button, 0, wxALIGN_CENTRE_HORIZONTAL)

	local sizerWrapper = wxBoxSizer(wxHORIZONTAL)
	sizerWrapper:Add(sizer, 0, wxGROW_ALL, MARGIN_L)

	dialog:SetAutoLayout(true)
	dialog:SetSizer(sizerWrapper)

	dialog:Fit()
	dialog:Centre()

	dialog:ShowModal()
end



function dialogs.addmylist(fileInfosToAddOrEdit)
	local fileInfoFirst = fileInfosToAddOrEdit[1]
	if not fileInfoFirst then  return  end

	local mylistEntry = nil
	if not fileInfosToAddOrEdit[2] and fileInfoFirst.lid ~= -1 then
		mylistEntry = anidb:getCacheMylist(fileInfoFirst.lid)
	end

	local dialog       = wxDialog(topPanel, wxID_ANY, "Add to / Edit MyList")
	local sizerDialog  = wxBoxSizer(wxVERTICAL)

	-- File count text.
	----------------------------------------------------------------

	local textObj = newText(dialog, F(
		"Adding/editing %d file%s.",
		#fileInfosToAddOrEdit, (#fileInfosToAddOrEdit == 1 and "" or "s")
	))
	sizerDialog:Add(textObj)

	sizerDialog:AddSpacer(MARGIN_S)

	local line = wxStaticLine(dialog, wxID_ANY)
	sizerDialog:Add(line, 0, wxGROW)

	-- Mylist fields.
	----------------------------------------------------------------

	sizerDialog:AddSpacer(MARGIN_S)

	local
		viewedRadio,
		mylistStateRadio,
		storageCheckbox, storageInput,
		sourceCheckbox,  sourceInput,
		otherCheckbox,   otherInput
		= addMylistaddFields(dialog, sizerDialog, nil, mylistEntry)

	-- Buttons.
	----------------------------------------------------------------

	sizerDialog:AddSpacer(MARGIN_S)

	local line = wxStaticLine(dialog, wxID_ANY)
	sizerDialog:Add(line, 0, wxGROW)

	sizerDialog:AddSpacer(MARGIN_S)

	local sizerButtons = wxStdDialogButtonSizer()

	local button = newButton(dialog, wxID_OK, "Add / Edit", function(e)
		local viewed  = VIEWED_STATES[viewedRadio:GetSelection()+1].value
		local state   = MYLIST_STATES[mylistStateRadio:GetSelection()+1].value
		local storage = storageCheckbox:IsChecked() and storageInput:GetValue() or nil
		local source  = sourceCheckbox:IsChecked()  and sourceInput:GetValue()  or nil
		local other   = otherCheckbox:IsChecked()   and otherInput:GetValue()   or nil

		local totalStrLen = #(storage or "") + #(source or "") + #(other or ""):gsub("\n", "<br />")

		if APPROX_BASE_MESSAGE_LENGTH + totalStrLen > MAX_UDP_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH then
			showWarning(
				"Too Long Texts",
				F(
					"The combined length of the storage, source and note texts is too long to send over the network. "
						.."The supported maximum length is around %d characters.",
					MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH
				)
			)
			return -- Don't close the dialog.
		end

		local values = {
			viewed  = viewed,
			state   = state,
			storage = storage,
			source  = source,
			other   = other,
		}

		for _, fileInfo in ipairs(fileInfosToAddOrEdit) do
			if fileInfo.lid ~= -1 then
				if next(values) then
					anidb:editMylist(fileInfo.lid, values)
				end

			elseif fileInfo.ed2k ~= "" then
				anidb:addMylistByEd2k(fileInfo.ed2k, fileInfo.size, values)
			end
		end

		e:Skip()
	end)
	sizerButtons:SetAffirmativeButton(button)

	local button = newButton(dialog, wxID_CANCEL, "Cancel")
	sizerButtons:SetCancelButton(button)

	sizerButtons:Realize()
	sizerDialog:Add(sizerButtons, 0, wxGROW)

	----------------------------------------------------------------

	local sizerWrapper = wxBoxSizer(wxHORIZONTAL)
	sizerWrapper:Add(sizerDialog, 0, wxGROW_ALL, MARGIN_M)

	dialog:SetAutoLayout(true)
	dialog:SetSizer(sizerWrapper)

	dialog:Fit()
	dialog:Centre()

	dialog:ShowModal()
end



function dialogs.credentials()
	local dialog       = wxDialog(topPanel, wxID_ANY, "Credentials to AniDB")
	local sizerDialog  = wxBoxSizer(wxVERTICAL)

	-- Inputs.
	----------------------------------------------------------------

	local user, pass = anidb:getCredentials()

	-- Username. 3-16 characters. A-Z, a-z, 0-9, - and _ only.
	local sizerSection = wxBoxSizer(wxHORIZONTAL)

	local textObj = wxStaticText(dialog, wxID_ANY, "Username:")
	textObj:SetSizeHints(60, getHeight(textObj))
	sizerSection:Add(textObj)

	local userInput = wxTextCtrl(dialog, wxID_ANY, (user or ""))
	userInput:SetMaxLength(16)
	sizerSection:Add(userInput, 1, wxGROW)

	sizerDialog:Add(sizerSection, 1, wxGROW)

	sizerDialog:AddSpacer(MARGIN_XS)

	-- Password. 4-64 characters. ASCII only.
	local sizerSection = wxBoxSizer(wxHORIZONTAL)

	local textObj = wxStaticText(dialog, wxID_ANY, "Password:")
	textObj:SetSizeHints(60, getHeight(textObj))
	sizerSection:Add(textObj)

	local passInput = wxTextCtrl(dialog, wxID_ANY, (pass or ""), wxDEFAULT_POSITION, wxDEFAULT_SIZE, wxTE_PASSWORD)
	passInput:SetMaxLength(64)
	sizerSection:Add(passInput, 1, wxGROW)

	sizerDialog:Add(sizerSection, 1, wxGROW)

	-- Text.
	----------------------------------------------------------------

	sizerDialog:AddSpacer(MARGIN_M)

	local textObj = wxStaticText(dialog, wxID_ANY, "Note: These credentials will be saved in 'local/login'.")
	sizerDialog:Add(textObj, 0, wxGROW)

	-- Buttons.
	----------------------------------------------------------------

	sizerDialog:AddSpacer(MARGIN_M)

	local sizerButtons = wxStdDialogButtonSizer()

	local button = newButton(dialog, wxID_OK, "Save", function(e)
		local user = userInput:GetValue()
		local pass = passInput:GetValue()

		-- Username. 3-16 characters. A-Z, a-z, 0-9, - and _ only.
		if #user < 3 or #user > 16 or user:find"[^-%w_]" then
			showMessage("Username", "The username is invalid.")
			userInput:SetFocus()

		-- Password. 4-64 characters. ASCII only.
		elseif #pass < 4 or #pass > 64 or pass:find"[%z\1-\31\128-\255]" then
			showMessage("Password", "The password is invalid.")
			passInput:SetFocus()

		else
			anidb:setCredentials(user, pass)
			hide(loginButton, topPanel)
			e:Skip()
		end
	end)
	sizerButtons:SetAffirmativeButton(button)

	local button = newButton(dialog, wxID_CANCEL, "Cancel")
	sizerButtons:SetCancelButton(button)

	sizerButtons:Realize()
	sizerDialog:Add(sizerButtons, 0, wxGROW)

	----------------------------------------------------------------

	local sizerWrapper = wxBoxSizer(wxHORIZONTAL)
	sizerWrapper:Add(sizerDialog, 0, wxGROW_ALL, MARGIN_M)

	dialog:SetAutoLayout(true)
	dialog:SetSizer(sizerWrapper)

	dialog:Fit()
	dialog:Centre()

	show(loginButton, topPanel)

	pause("credentials")
	dialog:ShowModal()
	unpause("credentials")
end



function dialogs.settings()
	local dialog       = wxDialog(topPanel, wxID_ANY, "Settings")
	local sizerDialog  = wxBoxSizer(wxVERTICAL)
	local sizerGrid    = wxGridBagSizer(MARGIN_L, MARGIN_L) -- 2x2

	on(dialog, "CHAR_HOOK", function(e, kc)
		if kc == KC_ESCAPE then
			-- @Incomplete: Confirm close, if any setting changed.
			if DEBUG then e:Skip() end
		else
			e:Skip()
		end
	end)

	-- General.
	----------------------------------------------------------------

	local sizerBox = wxStaticBoxSizer(wxVERTICAL, dialog, "General")
	sizerBox:GetStaticBox():SetFont(fontTitle)

	local autoHashCheckbox = wxCheckBox(dialog, wxID_ANY, "Start hashing files automatically")
	autoHashCheckbox:SetValue(appSettings.autoHash)
	sizerBox:Add(autoHashCheckbox)

	local autoAddToMylistCheckbox = wxCheckBox(dialog, wxID_ANY, "Automatically add files to MyList")
	autoAddToMylistCheckbox:SetValue(appSettings.autoAddToMylist)
	sizerBox:Add(autoAddToMylistCheckbox, 0, wxTOP, MARGIN_S)

	local autoRemoveDeletedFilesCheckbox = wxCheckBox(dialog, wxID_ANY, "Automatically remove moved/deleted files from list")
	autoRemoveDeletedFilesCheckbox:SetValue(appSettings.autoRemoveDeletedFiles)
	sizerBox:Add(autoRemoveDeletedFilesCheckbox, 0, wxTOP, MARGIN_S)

	local truncateFoldersCheckbox = wxCheckBox(dialog, wxID_ANY, "Show truncated folder paths")
	truncateFoldersCheckbox:SetValue(appSettings.truncateFolders)
	sizerBox:Add(truncateFoldersCheckbox, 0, wxTOP, MARGIN_M)

	sizerGrid:Add(sizerBox, wxGBPosition(0, 0), wxGBSpan(1, 1), wxGROW)

	-- File extensions.
	----------------------------------------------------------------

	local sizerBox = wxStaticBoxSizer(wxVERTICAL, dialog, "File Extensions")
	sizerBox:GetStaticBox():SetFont(fontTitle)

	local textObj = wxStaticText(
		dialog, wxID_ANY,
		"Only files with these extensions will get added when you drag files or folders into the window."
	)
	textObj:Wrap(250)
	sizerBox:Add(textObj, 0, wxGROW_ALL, MARGIN_S)

	local textObj = wxStaticText(dialog, wxID_ANY, "One extension per line.")
	textObj:Wrap(250)
	sizerBox:Add(textObj, 0, wxGROW_ALL, MARGIN_S)

	local extensionsInput = wxTextCtrl(
		dialog, wxID_ANY, table.concat(appSettings.movieExtensions, "\n"),
		wxDEFAULT_POSITION, wxSize(100, 200), wxTE_MULTILINE
	)
	sizerBox:Add(extensionsInput, 0, wxGROW)

	sizerGrid:Add(sizerBox, wxGBPosition(1, 0), wxGBSpan(1, 1), wxGROW)

	-- MyList defaults.
	----------------------------------------------------------------

	local sizerBox = wxStaticBoxSizer(wxVERTICAL, dialog, "MyList Defaults")
	sizerBox:GetStaticBox():SetFont(fontTitle)

	local
		viewedRadio,
		mylistStateRadio,
		storageCheckbox, storageInput,
		sourceCheckbox,  sourceInput,
		otherCheckbox,   otherInput
		= addMylistaddFields(dialog, sizerBox, appSettings.mylistDefaults)

	sizerGrid:Add(sizerBox, wxGBPosition(0, 1), wxGBSpan(2, 1), wxGROW)

	----------------------------------------------------------------

	sizerDialog:Add(sizerGrid, 1, wxGROW)

	-- Buttons.
	----------------------------------------------------------------

	sizerDialog:AddSpacer(MARGIN_L)

	local sizerButtons = wxStdDialogButtonSizer()

	local button = newButton(dialog, wxID_OK, "Save", function(e)
		local viewed  = VIEWED_STATES[viewedRadio:GetSelection()+1].value
		local state   = MYLIST_STATES[mylistStateRadio:GetSelection()+1].value
		local storage = storageCheckbox:IsChecked() and storageInput:GetValue() or nil
		local source  = sourceCheckbox:IsChecked()  and sourceInput:GetValue()  or nil
		local other   = otherCheckbox:IsChecked()   and otherInput:GetValue()   or nil

		local totalStrLen = #(storage or "") + #(source or "") + #(other or ""):gsub("\n", "<br />")

		if APPROX_BASE_MESSAGE_LENGTH + totalStrLen > MAX_UDP_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH then
			showWarning(
				"Too Long Texts",
				F(
					"The combined length of the storage, source and note texts is too long to send over the network. "
						.."The supported maximum length is around %d characters.",
					MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH
				)
			)
			return -- Don't close the dialog.
		end

		local mylistDefaults = {
			viewed  = viewed,
			state   = state,
			storage = storage,
			source  = source,
			other   = other,
		}

		local exts        = splitString(extensionsInput:GetValue(), "\n", 1, true)
		local extExisting = {[""]=true}

		for i, ext in ipairsr(exts) do
			ext     = trim(ext)
			exts[i] = ext

			if extExisting[ext] then  table.remove(exts, i)  end
			extExisting[ext] = true
		end

		sortNatural(exts)

		setSetting("autoAddToMylist",        autoAddToMylistCheckbox:IsChecked())
		setSetting("autoHash",               autoHashCheckbox:IsChecked())
		setSetting("autoRemoveDeletedFiles", autoRemoveDeletedFilesCheckbox:IsChecked())
		setSetting("truncateFolders",        truncateFoldersCheckbox:IsChecked())

		setSetting("movieExtensions",        exts)

		setSetting("mylistDefaults",         mylistDefaults)

		checkFileInfos()
		updateFileList()
		e:Skip()
	end)
	sizerButtons:SetAffirmativeButton(button)

	local button = newButton(dialog, wxID_CANCEL, "Cancel")
	sizerButtons:SetCancelButton(button)

	sizerButtons:Realize()
	sizerDialog:Add(sizerButtons, 0, wxGROW)

	----------------------------------------------------------------

	local sizerWrapper = wxBoxSizer(wxHORIZONTAL)
	sizerWrapper:Add(sizerDialog, 0, wxGROW_ALL, MARGIN_L)

	dialog:SetAutoLayout(true)
	dialog:SetSizer(sizerWrapper)

	dialog:Fit()
	dialog:Centre()

	dialog:ShowModal()
end



-- newPath = dialogs.missingFile( path )
-- newPath == string -- Chosen new path.
-- newPath == ""     -- Remove file from list.
-- newPath == nil    -- No new path chosen / Abort.
function dialogs.missingFile(path)
	local pathNew = ""

	local function chooseNewLocation(e)
		local topmostExistingDir = getDirectory(path)

		while not isDirectory(topmostExistingDir) do
			topmostExistingDir = getDirectory(topmostExistingDir)

			if topmostExistingDir == "" then
				break
			end
		end

		local ext = getExtension(path)

		local movieExtensionList
			=   appSettings.movieExtensions[1]
			and "*."..table.concat(appSettings.movieExtensions, ";*.")
			or  "-"

		local dialog = wxFileDialog(
			topFrame,
			wxFILE_SELECTOR_PROMPT_STRING,
			topmostExistingDir,
			getFilename(path),
			F("*.%s|*.%s|Movie files (%s)|%s|All files (*.*)|*.*", ext, ext, movieExtensionList, movieExtensionList),
			wxDEFAULT_DIALOG_STYLE + wxRESIZE_BORDER + wxFILE_MUST_EXIST
		)

		pause("wxFileDialog")
		local id = dialog:ShowModal()
		unpause("wxFileDialog")

		if id == wxID_CANCEL then
			cast(e:GetEventObject()):SetFocus(true) -- Fixes the dialog not getting back focus.
			return
		end

		pathNew = toNormalPath(dialog:GetPath())
		e:Skip() -- Continue closing the dialog.
	end

	local labels = {
		wxID_OK,     "Choose New Location", chooseNewLocation,
		wxID_REMOVE, "Remove from List",
		wxID_CANCEL, "Cancel",
	}
	local id = showButtonDialog("File Missing", "File has been moved or deleted:\n\n"..path, labels)

	if id == wxID_OK then
		return pathNew

	elseif id == wxID_REMOVE then
		return ""

	else
		return nil
	end
end



function dialogs.changelog()
	local dialog = wxDialog(topPanel, wxID_ANY, "Changelog")
	local sizer  = wxBoxSizer(wxVERTICAL)

	local changelog = getFileContents"data/changelog.txt":gsub("\r", "")

	local textCtrl = wxTextCtrl(
		dialog, wxID_ANY, changelog, wxDEFAULT_POSITION, wxSize(500, 300),
		wxTE_MULTILINE + wxTE_READONLY
	)
	sizer:Add(textCtrl, 0, wxGROW)

	local button = newButton(dialog, wxID_OK, "Close")
	button:SetSizeHints(100, getHeight(button)+2*3)
	sizer:Add(button, 0, wxALIGN_CENTRE_HORIZONTAL + wxALL, MARGIN_M)

	dialog:SetAutoLayout(true)
	dialog:SetSizer(sizer)

	dialog:Fit()
	dialog:Centre()

	dialog:ShowModal()
end



return dialogs
