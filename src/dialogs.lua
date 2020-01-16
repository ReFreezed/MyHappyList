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
	updateApp

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
	{value=nil,   separateDate=false},
	{value=false, separateDate=false},
	{value=true,  separateDate=false},
	{value=true,  separateDate=true},
}

local MYLIST_STATES = {
	{value=nil},
	{value=MYLIST_STATE_UNKNOWN},
	{value=MYLIST_STATE_INTERNAL_STORAGE},
	{value=MYLIST_STATE_EXTERNAL_STORAGE},
	{value=MYLIST_STATE_REMOTE_STORAGE},
	{value=MYLIST_STATE_DELETED},
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

	local labels = {}
	for i, state in ipairs(VIEWED_STATES) do
		if state.value ~= nil then
			labels[i] = T(
				state.value
				and (
					valuesCurrent
					and "label_yes"
					or  (state.separateDate and "label_yesAtDate" or "label_yesNow")
				)
				or "label_no"
			)
		end
	end
	labels[1] = valuesCurrent and T"label_option_default" or T"label_option_doNotChange"
	if valuesCurrent then
		labels[#labels] = nil
	end

	local viewedRadio = wxRadioBox(
		parent, wxID_ANY, T"label_watched", wxDEFAULT_POSITION, wxDEFAULT_SIZE, labels, 0, wxRA_SPECIFY_ROWS
	)
	sizerParent:Add(viewedRadio, 0, wxGROW)

	if valuesCurrent and valuesCurrent.viewed ~= nil then
		viewedRadio.Selection = indexWith(VIEWED_STATES, "value", valuesCurrent.viewed)-1
	end

	-- View date.
	local viewDateInput = nil

	if not valuesCurrent then
		local panel      = wxPanel(parent, wxID_ANY)
		local sizerPanel = wxBoxSizer(wxHORIZONTAL)

		local textObj = wxStaticText(panel, wxID_ANY, T"label_viewDate".." (YYYY-MM-DD):")
		sizerPanel:Add(textObj, 0, wxALIGN_CENTRE_VERTICAL + wxRIGHT, MARGIN_XS)

		local validator = wxTextValidator(wxFILTER_INCLUDE_CHAR_LIST)
		validator:SetIncludes{"0","1","2","3","4","5","6","7","8","9"," ","-","/",":"}

		viewDateInput = wxTextCtrl(
			panel, wxID_ANY,
			(mylistEntry and mylistEntry.viewdate ~= 0 and os.date("%Y-%m-%d %H:%M:%S", mylistEntry.viewdate) or ""),
			wxDEFAULT_POSITION, wxDEFAULT_SIZE, 0, validator
		)
		viewDateInput:SetSizeHints(130, getHeight(viewDateInput))
		viewDateInput:Enable(false)
		sizerPanel:Add(viewDateInput)

		on({panel,textObj}, "LEFT_DOWN", function(e)
			if not viewDateInput:IsEnabled() then
				viewedRadio:SetSelection(indexWith(VIEWED_STATES, "separateDate",true)-1)
				viewDateInput:Enable(true)
				viewDateInput:SetFocus()
			end
		end)

		on(viewedRadio, "COMMAND_RADIOBOX_SELECTED", function(e, wxIndex)
			viewDateInput:Enable(VIEWED_STATES[wxIndex+1].separateDate)
		end)

		panel.AutoLayout = true
		panel.Sizer      = sizerPanel
		sizerParent:Add(panel, 0, wxGROW + wxTOP, MARGIN_S)
	end

	-- MyList state.
	----------------------------------------------------------------

	sizerParent:AddSpacer(MARGIN_S)

	local labels = {}
	for i, state in ipairs(MYLIST_STATES) do
		if state.value then
			labels[i] = T("label_mylistState_"..state.value)
		end
	end
	labels[1] = valuesCurrent and T"label_option_default" or T"label_option_doNotChange"

	local mylistStateRadio = wxRadioBox(
		parent, wxID_ANY, T"label_state", wxDEFAULT_POSITION, wxDEFAULT_SIZE,
		labels, 0, wxRA_SPECIFY_ROWS
	)
	sizerParent:Add(mylistStateRadio, 0, wxGROW)

	if valuesCurrent and valuesCurrent.state ~= nil then
		mylistStateRadio.Selection = indexWith(MYLIST_STATES, "value", valuesCurrent.state)-1
	end

	-- Source.
	----------------------------------------------------------------

	sizerParent:AddSpacer(MARGIN_S)

	local panel      = wxPanel(parent, wxID_ANY)
	local sizerPanel = wxBoxSizer(wxHORIZONTAL)

	local sourceCheckbox = wxCheckBox(panel, wxID_ANY, T"label_source"..":")
	sourceCheckbox:SetSizeHints(80, getHeight(sourceCheckbox))
	sourceCheckbox:SetToolTip(T"label_source_tip")
	sourceCheckbox.Value = (valuesCurrent ~= nil and valuesCurrent.source ~= nil)
	sizerPanel:Add(sourceCheckbox, 0, wxGROW)

	local sourceInput = wxTextCtrl(panel, wxID_ANY, (valuesCurrent and valuesCurrent.source or ""))
	sourceInput:SetSizeHints(220, getHeight(sourceInput))
	sourceInput.MaxLength = MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH
	sourceInput:SetToolTip(sourceCheckbox.ToolTip.Tip)
	sizerPanel:Add(sourceInput, 0, wxGROW)

	if not (valuesCurrent and valuesCurrent.source) then
		sourceInput:Enable(false)
	end
	if not valuesCurrent and mylistEntry and mylistEntry.source then
		sourceInput.Value = mylistEntry.source
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

	panel.AutoLayout = true
	panel.Sizer      = sizerPanel
	sizerParent:Add(panel, 0, wxGROW)

	-- Storage.
	----------------------------------------------------------------

	sizerParent:AddSpacer(MARGIN_S)

	local panel      = wxPanel(parent, wxID_ANY)
	local sizerPanel = wxBoxSizer(wxHORIZONTAL)

	local storageCheckbox = wxCheckBox(panel, wxID_ANY, T"label_storage"..":")
	storageCheckbox:SetSizeHints(80, getHeight(storageCheckbox))
	storageCheckbox:SetToolTip(T"label_storage_tip")
	storageCheckbox.Value = (valuesCurrent ~= nil and valuesCurrent.storage ~= nil)
	sizerPanel:Add(storageCheckbox, 0, wxGROW)

	local storageInput = wxTextCtrl(panel, wxID_ANY, (valuesCurrent and valuesCurrent.storage or ""))
	storageInput:SetSizeHints(220, getHeight(storageInput))
	storageInput.MaxLength = MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH
	storageInput:SetToolTip(storageCheckbox.ToolTip.Tip)
	sizerPanel:Add(storageInput, 0, wxGROW)

	if not (valuesCurrent and valuesCurrent.storage) then
		storageInput:Enable(false)
	end
	if not valuesCurrent and mylistEntry and mylistEntry.storage then
		storageInput.Value = mylistEntry.storage
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

	panel.AutoLayout = true
	panel.Sizer      = sizerPanel
	sizerParent:Add(panel, 0, wxGROW)

	-- Other.
	----------------------------------------------------------------

	sizerParent:AddSpacer(MARGIN_M)

	local panel      = wxPanel(parent, wxID_ANY)
	local sizerPanel = wxBoxSizer(wxHORIZONTAL)

	local otherCheckbox = wxCheckBox(panel, wxID_ANY, T"label_note"..":")
	otherCheckbox:SetSizeHints(80, getHeight(otherCheckbox))
	otherCheckbox.Value = (valuesCurrent ~= nil and valuesCurrent.other ~= nil)
	sizerPanel:Add(otherCheckbox)

	local otherInput = wxTextCtrl(
		panel, wxID_ANY, (valuesCurrent and valuesCurrent.other or ""),
		wxDEFAULT_POSITION, wxSize(220, 100), wxTE_MULTILINE
	)
	local colorOn  = otherInput.BackgroundColour
	local colorOff = wxSystemSettings.GetColour(wxSYS_COLOUR_3DFACE)
	otherInput.MaxLength = MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH
	sizerPanel:Add(otherInput, 0, wxGROW)

	if not (valuesCurrent and valuesCurrent.other) then
		otherInput:Enable(false)
		otherInput.BackgroundColour = colorOff
	end
	if not valuesCurrent and mylistEntry and mylistEntry.other then
		otherInput.Value = mylistEntry.other
	end

	on(otherCheckbox, "COMMAND_CHECKBOX_CLICKED", function(e)
		otherInput:Enable(e:IsChecked())
		otherInput.BackgroundColour = e:IsChecked() and colorOn or colorOff
		otherInput:SetFocus()
	end)

	on(otherInput, "KEY_DOWN", function(e, kc)
		if kc == KC_A and e.Modifiers == wxMOD_CONTROL then
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

	panel.AutoLayout = true
	panel.Sizer      = sizerPanel
	sizerParent:Add(panel, 0, wxGROW)

	----------------------------------------------------------------

	return
		viewedRadio,     viewDateInput,
		mylistStateRadio,
		storageCheckbox, storageInput,
		sourceCheckbox,  sourceInput,
		otherCheckbox,   otherInput
end

--==============================================================
--==============================================================
--==============================================================



function dialogs.about()
	local title
		= "MyHappyList "..APP_VERSION

	local copyright
		= F("Copyright © 2018-%s Marcus 'ReFreezed' Thunström. MIT license.", os.date"%Y")

	local desciption
		= "MyHappyList is made using Lua, wxLua, LuaSocket, LuaZip, LuaSec and rhash. "
		.."The executable is built using srlua, ResourceHacker and ImageMagick."

	local dialog = wxDialog(topFrame, wxID_ANY, T"label_aboutApp")
	local sizer  = wxBoxSizer(wxVERTICAL)

	-- Icon.
	local bm = wxBitmap()
	bm:CopyFromIcon(appIcons:GetIcon(32))
	local bmObj = wxStaticBitmap(dialog, wxID_ANY, bm)
	sizer:Add(bmObj, 0, wxALIGN_CENTRE_HORIZONTAL)

	sizer:AddSpacer(MARGIN_M)

	-- Title.
	local textObj = wxStaticText(dialog, wxID_ANY, title, wxDEFAULT_POSITION, wxDEFAULT_SIZE, wxALIGN_CENTRE_HORIZONTAL)
	textObj.Font = fontTitle
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
	local button = newButton(dialog, wxID_OK, T"label_close")
	button:SetSizeHints(100, getHeight(button)+2*3)
	sizer:Add(button, 0, wxALIGN_CENTRE_HORIZONTAL)

	local sizerWrapper = wxBoxSizer(wxHORIZONTAL)
	sizerWrapper:Add(sizer, 0, wxGROW_ALL, MARGIN_L)

	dialog.AutoLayout = true
	dialog.Sizer      = sizerWrapper

	dialog:Fit()
	dialog:Centre()

	showModalAndDestroy(dialog)
end



function dialogs.addmylist(fileInfosToAddOrEdit)
	local fileInfoFirst = fileInfosToAddOrEdit[1]
	if not fileInfoFirst then  return  end

	local mylistEntry = nil
	if not fileInfosToAddOrEdit[2] and fileInfoFirst.lid ~= -1 then
		mylistEntry = anidb:getCacheMylist(fileInfoFirst.lid)
	end

	local dialog       = wxDialog(topFrame, wxID_ANY, T"label_addToOrEditMylist")
	local sizerDialog  = wxBoxSizer(wxVERTICAL)

	-- File count text.
	----------------------------------------------------------------

	local textObj = newText(dialog, T(
		"message_editingNumFiles"..(#fileInfosToAddOrEdit == 1 and "_single" or ""),
		{n=#fileInfosToAddOrEdit}
	))
	sizerDialog:Add(textObj)

	sizerDialog:AddSpacer(MARGIN_S)

	local line = wxStaticLine(dialog, wxID_ANY)
	sizerDialog:Add(line, 0, wxGROW)

	-- Mylist fields.
	----------------------------------------------------------------

	sizerDialog:AddSpacer(MARGIN_S)

	local
		viewedRadio,     viewDateInput,
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

	local button = newButton(dialog, wxID_OK, T"label_addOrEdit", function(e)
		local viewed      = VIEWED_STATES[viewedRadio.Selection+1].value
		local viewdateStr = viewDateInput.Value
		local state       = MYLIST_STATES[mylistStateRadio.Selection+1].value
		local storage     = storageCheckbox:IsChecked() and storageInput.Value or nil
		local source      = sourceCheckbox:IsChecked()  and sourceInput.Value  or nil
		local other       = otherCheckbox:IsChecked()   and otherInput.Value   or nil

		local totalStrLen = #(storage or "") + #(source or "") + #(other or ""):gsub("\n", "<br />")

		if APPROX_BASE_MESSAGE_LENGTH + totalStrLen > MAX_UDP_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH then
			showWarning(
				T("error_tooLongTexts"),
				T("error_tooLongTexts_text", {
					maxChars = MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH
				})
			)
			return -- Don't close the dialog.
		end

		local viewdate = nil

		if viewed and VIEWED_STATES[viewedRadio.Selection+1].separateDate and viewdateStr then
			viewdateStr = trim(viewdateStr)

			local year, month, day, hour, min, sec        = viewdateStr:match"^(%d%d%d%d)[-/](%d%d?)[-/](%d%d?) +(%d%d?):(%d%d?):(%d%d?)$"
			if not year then  year, month, day, hour, min = viewdateStr:match"^(%d%d%d%d)[-/](%d%d?)[-/](%d%d?) +(%d%d?):(%d%d?)$"  end
			if not year then  year, month, day            = viewdateStr:match"^(%d%d%d%d)[-/](%d%d?)[-/](%d%d?)$"                   end
			if not year then  year, month                 = viewdateStr:match"^(%d%d%d%d)[-/](%d%d?)$"                              end
			if not year then  year                        = viewdateStr:match"^(%d%d%d%d)$"                                         end

			if not year then
				showWarning(T"label_viewDate", "Error: "..T"error_dateInvalid")
				viewDateInput:SetFocus()
				return -- Don't close the dialog.
			end

			year  = tonumber(year)
			month = tonumber(month) or 1
			day   = tonumber(day)   or 1
			hour  = tonumber(hour)  or 0
			min   = tonumber(min)   or 0
			sec   = tonumber(sec)   or 0

			viewdate = os.time{year=year, month=month, day=day, hour=hour, min=min, sec=sec}

			if os.date("%Y%m%d%H%M%S", viewdate) ~= F("%04d%02d%02d%02d%02d%02d", year,month,day,hour,min,sec) then
				showWarning(T"label_viewDate", "Error: "..T"error_dateOutOfRange")
				viewDateInput:SetFocus()
				return -- Don't close the dialog.
			end
		end

		local values = {
			viewed   = viewed,
			viewdate = viewdate,
			state    = state,
			storage  = storage,
			source   = source,
			other    = other,
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
	sizerButtons.AffirmativeButton = button

	local button = newButton(dialog, wxID_CANCEL, T"label_cancel")
	sizerButtons.CancelButton = button

	sizerButtons:Realize()
	sizerDialog:Add(sizerButtons, 0, wxGROW)

	----------------------------------------------------------------

	local sizerWrapper = wxBoxSizer(wxHORIZONTAL)
	sizerWrapper:Add(sizerDialog, 0, wxGROW_ALL, MARGIN_M)

	dialog.AutoLayout = true
	dialog.Sizer      = sizerWrapper

	dialog:Fit()
	dialog:Centre()

	showModalAndDestroy(dialog)
end



function dialogs.credentials()
	local dialog       = wxDialog(topFrame, wxID_ANY, T"label_anidbCredentials")
	local sizerDialog  = wxBoxSizer(wxVERTICAL)

	-- Inputs.
	----------------------------------------------------------------

	local user, pass = anidb:getCredentials()

	-- Username. 3-16 characters. A-Z, a-z, 0-9, - and _ only.
	local sizerSection = wxBoxSizer(wxHORIZONTAL)

	local textObj = wxStaticText(dialog, wxID_ANY, T"label_username"..":")
	textObj:SetSizeHints(90, getHeight(textObj))
	sizerSection:Add(textObj)

	local userInput = wxTextCtrl(dialog, wxID_ANY, (user or ""))
	userInput.MaxLength = 16
	sizerSection:Add(userInput, 1, wxGROW)

	sizerDialog:Add(sizerSection, 1, wxGROW)

	sizerDialog:AddSpacer(MARGIN_XS)

	-- Password. 4-64 characters. ASCII only.
	local sizerSection = wxBoxSizer(wxHORIZONTAL)

	local textObj = wxStaticText(dialog, wxID_ANY, T"label_password"..":")
	textObj:SetSizeHints(90, getHeight(textObj))
	sizerSection:Add(textObj)

	local passInput = wxTextCtrl(dialog, wxID_ANY, (pass or ""), wxDEFAULT_POSITION, wxDEFAULT_SIZE, wxTE_PASSWORD)
	passInput.MaxLength = 64
	sizerSection:Add(passInput, 1, wxGROW)

	sizerDialog:Add(sizerSection, 1, wxGROW)

	-- Text.
	----------------------------------------------------------------

	sizerDialog:AddSpacer(MARGIN_M)

	local textObj = wxStaticText(dialog, wxID_ANY, F("%s:\n%s/login", T"message_anidbCredentialsLocation", DIR_CONFIG))
	sizerDialog:Add(textObj, 0, wxGROW)

	-- Buttons.
	----------------------------------------------------------------

	sizerDialog:AddSpacer(MARGIN_M)

	local sizerButtons = wxStdDialogButtonSizer()

	local button = newButton(dialog, wxID_OK, T"label_save", function(e)
		local user = userInput.Value
		local pass = passInput.Value

		-- Username. 3-16 characters. A-Z, a-z, 0-9, - and _ only.
		if #user < 3 or #user > 16 or user:find"[^-%w_]" then
			showMessage(T"label_username", T"error_badUsername")
			userInput:SetFocus()

		-- Password. 4-64 characters. ASCII only.
		elseif #pass < 4 or #pass > 64 or pass:find"[%z\1-\31\128-\255]" then
			showMessage(T"label_password", T"error_badPassword")
			passInput:SetFocus()

		else
			anidb:setCredentials(user, pass)
			hide(loginButton, topPanel)
			e:Skip()
		end
	end)
	sizerButtons.AffirmativeButton = button

	local button = newButton(dialog, wxID_CANCEL, T"label_cancel")
	sizerButtons.CancelButton = button

	sizerButtons:Realize()
	sizerDialog:Add(sizerButtons, 0, wxGROW)

	----------------------------------------------------------------

	local sizerWrapper = wxBoxSizer(wxHORIZONTAL)
	sizerWrapper:Add(sizerDialog, 0, wxGROW_ALL, MARGIN_M)

	dialog.AutoLayout = true
	dialog.Sizer      = sizerWrapper

	dialog:Fit()
	dialog:Centre()

	show(loginButton, topPanel)

	pause("credentials")
	showModalAndDestroy(dialog)
	unpause("credentials")
end



local FILE_EXTENSIONS_INPUT_HEIGHT = 120

function dialogs.settings()
	local dialog       = wxDialog(topFrame, wxID_ANY, T"label_settings")
	local sizerDialog  = wxBoxSizer(wxVERTICAL)
	local sizerGrid    = wxGridBagSizer(MARGIN_L, MARGIN_L) -- 2x3

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

	local sizerBox = wxStaticBoxSizer(wxVERTICAL, dialog, T"label_general")
	sizerBox.StaticBox.Font = fontTitle

	------ Language.
	local translations     = getTranslations()
	local currentLangTitle = itemWith(translations, "code", appSettings.language).title

	local sizerRow = wxBoxSizer(wxHORIZONTAL)

	local textObj = wxStaticText(dialog, wxID_ANY, T"label_language"..":")
	sizerRow:Add(textObj, 0, wxALIGN_CENTRE_VERTICAL + wxRIGHT, MARGIN_XS)

	local languageList = wxComboBox(
		dialog,
		wxID_ANY,
		currentLangTitle,
		wxDEFAULT_POSITION,
		wxDEFAULT_SIZE,
		getColumn(translations, "title"),
		wxCB_DROPDOWN + wxCB_READONLY
	)
	languageList:SetSizeHints(140, getHeight(languageList))
	sizerRow:Add(languageList, 0, wxGROW)

	sizerBox:Add(sizerRow, 0, wxGROW)
	------

	local autoHashCheckbox = wxCheckBox(dialog, wxID_ANY, T"label_autoHashFiles")
	autoHashCheckbox.Value = appSettings.autoHash
	sizerBox:Add(autoHashCheckbox, 0, wxTOP, MARGIN_S)

	local autoAddToMylistCheckbox = wxCheckBox(dialog, wxID_ANY, T"label_autoAddFilesToMylist")
	autoAddToMylistCheckbox.Value = appSettings.autoAddToMylist
	sizerBox:Add(autoAddToMylistCheckbox, 0, wxTOP, MARGIN_S)

	local autoRemoveDeletedFilesCheckbox = wxCheckBox(dialog, wxID_ANY, T"label_autoRemoveFilesFromList")
	autoRemoveDeletedFilesCheckbox.Value = appSettings.autoRemoveDeletedFiles
	sizerBox:Add(autoRemoveDeletedFilesCheckbox, 0, wxTOP, MARGIN_S)

	local truncateFoldersCheckbox = wxCheckBox(dialog, wxID_ANY, T"label_truncateFolders")
	truncateFoldersCheckbox.Value = appSettings.truncateFolders
	sizerBox:Add(truncateFoldersCheckbox, 0, wxTOP, MARGIN_M)

	sizerGrid:Add(sizerBox, wxGBPosition(0, 0), wxGBSpan(1, 1), wxGROW)

	-- Advanced.
	----------------------------------------------------------------

	local sizerBox = wxStaticBoxSizer(wxVERTICAL, dialog, T"label_advanced")
	sizerBox.StaticBox.Font = fontTitle

	------ Timeout.
	local sizerRow = wxBoxSizer(wxHORIZONTAL)

	local textObj = wxStaticText(dialog, wxID_ANY, T"label_serverResponseTimeout"..":")
	textObj:SetToolTip(T("label_serverResponseTimeout_tip", {n=DEFAULT_SERVER_RESPONSE_TIMEOUT}))
	sizerRow:Add(textObj, 0, wxALIGN_CENTRE_VERTICAL + wxRIGHT, MARGIN_XS)

	local validator = wxTextValidator(wxFILTER_INCLUDE_CHAR_LIST)
	validator:SetIncludes{"0","1","2","3","4","5","6","7","8","9"}

	local timeoutInput = wxTextCtrl(
		dialog, wxID_ANY,
		F("%d", appSettings.serverResponseTimeout),
		wxDEFAULT_POSITION, wxDEFAULT_SIZE, 0, validator
	)
	timeoutInput:SetSizeHints(40, getHeight(timeoutInput))

	-- Highest number is 999 means almost 17 minutes which should be enough for any situation, I think.
	timeoutInput.MaxLength = 3

	timeoutInput:SetToolTip(textObj.ToolTip.Tip)
	sizerRow:Add(timeoutInput, 0, wxRIGHT, MARGIN_XS)

	local textObj = wxStaticText(dialog, wxID_ANY, T"label_seconds")
	sizerRow:Add(textObj, 0, wxALIGN_CENTRE_VERTICAL)

	sizerBox:Add(sizerRow, 0, wxGROW)
	------

	sizerGrid:Add(sizerBox, wxGBPosition(1, 0), wxGBSpan(1, 1), wxGROW)

	-- File extensions.
	----------------------------------------------------------------

	local sizerBox = wxStaticBoxSizer(wxVERTICAL, dialog, T"label_fileExtensions")
	sizerBox.StaticBox.Font = fontTitle

	local textObj = wxStaticText(dialog, wxID_ANY, T"message_fileExtensionsInfo")
	textObj:Wrap(250)
	sizerBox:Add(textObj, 0, wxGROW_ALL, MARGIN_S)

	local textObj = wxStaticText(dialog, wxID_ANY, T"message_oneFileExtensionPerLine")
	textObj:Wrap(250)
	sizerBox:Add(textObj, 0, wxGROW_ALL, MARGIN_S)

	local extensionsInput = wxTextCtrl(
		dialog, wxID_ANY, table.concat(appSettings.movieExtensions, "\n"),
		wxDEFAULT_POSITION, wxSize(100, FILE_EXTENSIONS_INPUT_HEIGHT), wxTE_MULTILINE
	)
	sizerBox:Add(extensionsInput, 0, wxGROW)

	sizerGrid:Add(sizerBox, wxGBPosition(2, 0), wxGBSpan(1, 1), wxGROW)

	-- MyList defaults.
	----------------------------------------------------------------

	local sizerBox = wxStaticBoxSizer(wxVERTICAL, dialog, T"label_mylistDefaults")
	sizerBox.StaticBox.Font = fontTitle

	local
		viewedRadio,     viewDateInput,
		mylistStateRadio,
		storageCheckbox, storageInput,
		sourceCheckbox,  sourceInput,
		otherCheckbox,   otherInput
		= addMylistaddFields(dialog, sizerBox, appSettings.mylistDefaults, nil)

	sizerGrid:Add(sizerBox, wxGBPosition(0, 1), wxGBSpan(3, 1), wxGROW)

	----------------------------------------------------------------

	sizerDialog:Add(sizerGrid, 1, wxGROW)

	-- Buttons.
	----------------------------------------------------------------

	sizerDialog:AddSpacer(MARGIN_L)

	local sizerButtons = wxStdDialogButtonSizer()

	local button = newButton(dialog, wxID_OK, T"label_save", function(e)
		local viewed  = VIEWED_STATES[viewedRadio.Selection+1].value
		local state   = MYLIST_STATES[mylistStateRadio.Selection+1].value
		local storage = storageCheckbox:IsChecked() and storageInput.Value or nil
		local source  = sourceCheckbox:IsChecked()  and sourceInput.Value  or nil
		local other   = otherCheckbox:IsChecked()   and otherInput.Value   or nil

		local totalStrLen = #(storage or "") + #(source or "") + #(other or ""):gsub("\n", "<br />")

		if APPROX_BASE_MESSAGE_LENGTH + totalStrLen > MAX_UDP_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH then
			showWarning(
				T("error_tooLongTexts"),
				T("error_tooLongTexts_text", {
					maxChars = MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH
				})
			)
			return -- Don't close the dialog.
		end

		local langCode        = itemWith(translations, "title", languageList:GetValue()).code
		local languageChanged = langCode ~= appSettings.language

		local timeout         = clamp((tonumber(timeoutInput.Value) or DEFAULT_SERVER_RESPONSE_TIMEOUT), 10, 999)

		local mylistDefaults = {
			viewed  = viewed,
			state   = state,
			storage = storage,
			source  = source,
			other   = other,
		}

		local exts        = splitString(extensionsInput.Value, "\n", 1, true)
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

		setSetting("language",               langCode)
		setSetting("serverResponseTimeout",  timeout)

		setSetting("movieExtensions",        exts)
		setSetting("mylistDefaults",         mylistDefaults)

		if languageChanged then
			-- This message should be in the newly chosen language.
			showMessage(T"label_language", T"message_restartAfterLanguageChange")
		end

		checkFileInfos()
		updateFileList()
		e:Skip()
	end)
	sizerButtons.AffirmativeButton = button

	local button = newButton(dialog, wxID_CANCEL, T"label_cancel")
	sizerButtons.CancelButton = button

	local button = newButton(dialog, wxID_RESET, T"label_restoreDefaultSettings", function(e)
		if not confirm(
			T"label_restoreDefaultSettings", T"message_restoreDefaultSettings",
			T"label_restoreDefaultSettings", nil, wxICON_EXCLAMATION
		) then
			return
		end

		restoreDefaultSettings()

		showMessage(T"label_restoreDefaultSettings", T"message_restartForChangesToTakeEffect")
		dialog:Close()
	end)
	sizerButtons.NegativeButton = button

	sizerButtons:Realize()
	sizerDialog:Add(sizerButtons, 0, wxGROW)

	----------------------------------------------------------------

	local sizerWrapper = wxBoxSizer(wxHORIZONTAL)
	sizerWrapper:Add(sizerDialog, 0, wxGROW_ALL, MARGIN_L)

	dialog.AutoLayout = true
	dialog.Sizer      = sizerWrapper

	dialog:Fit()
	dialog:Centre()

	showModalAndDestroy(dialog)
end



-- newPath, setMylistToDeleted = dialogs.missingFile( path [, showMylistOptions=false ] )
-- newPath == string -- Chosen new path.
-- newPath == ""     -- Remove file from list.
-- newPath == nil    -- No new path chosen / Abort.
function dialogs.missingFile(path, showMylistOptions)
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
			wxFILE_SELECTOR_PROMPT_STR,
			topmostExistingDir,
			getFilename(path),
			F(
				"*.%s|*.%s|%s (%s)|%s|%s (*.*)|*.*",
				ext, ext, T"label_files_movie", movieExtensionList, movieExtensionList, T"label_files_all"
			),
			wxDEFAULT_DIALOG_STYLE + wxRESIZE_BORDER + wxFILE_MUST_EXIST
		)

		local id = showModalAndDestroy(dialog)

		if id == wxID_CANCEL then
			cast(e.EventObject):SetFocus() -- Fixes the dialog not getting back focus.
			return
		end

		pathNew = toNormalPath(dialog.Path)
		e:Skip() -- Continue closing the dialog.
	end

	local idRemoveAndUpdateMylist = wxNewId()

	local labels = {
		wxID_OK,                 T"label_chooseNewLocation",             chooseNewLocation,
		wxID_REMOVE,             T"label_removeFromList",                --
		idRemoveAndUpdateMylist, T"label_removeFromListAndUpdateMylist", showMylistOptions,
		wxID_CANCEL,             T"label_cancel",                        --
	}

	local id = showButtonDialog(T"label_fileIsMissing", F("%s:\n\n%s", T"message_fileMovedOrDeleted", path), labels)

	if     id == wxID_OK                 then  return pathNew, false
	elseif id == wxID_REMOVE             then  return "",      false
	elseif id == idRemoveAndUpdateMylist then  return "",      true
	else                                       return nil,     false  end
end



function dialogs.changelog()
	local dialog = wxDialog(topFrame, wxID_ANY, T"label_changelog")
	local sizer  = wxBoxSizer(wxVERTICAL)

	local changelog = getFileContents"Changelog.txt":gsub("\r", "")

	local textCtrl = wxTextCtrl(
		dialog, wxID_ANY, changelog, wxDEFAULT_POSITION, wxSize(500, 300),
		wxTE_MULTILINE + wxTE_READONLY
	)
	sizer:Add(textCtrl, 0, wxGROW)

	local button = newButton(dialog, wxID_OK, T"label_close")
	button:SetSizeHints(100, getHeight(button)+2*3)
	sizer:Add(button, 0, wxALIGN_CENTRE_HORIZONTAL + wxALL, MARGIN_M)

	dialog.AutoLayout = true
	dialog.Sizer      = sizer

	dialog:Fit()
	dialog:Centre()

	showModalAndDestroy(dialog)
end


do
	local latestVersion = ""
	local downloadUrl   = ""

	--[[ DEBUG
	latestVersion = "99.0.0"
	downloadUrl   = "https://api.github.com/repos/ReFreezed/MyHappyList/releases/assets/8247018"
	--]]

	-- success = maybeGetLatestVersionNumber( )
	local function maybeGetLatestVersionNumber()
		if latestVersion ~= "" then
			if latestVersion ~= APP_VERSION or DEBUG_NEVER_UP_TO_DATE then
				eventQueue:addEvent("git:version_new_available", latestVersion, downloadUrl)
			else
				eventQueue:addEvent("git:version_up_to_date")
			end
			return true
		end

		if isScriptRunning"getLatestVersionNumber" then  return true  end

		local ok = scriptCaptureAsync("getLatestVersionNumber", function(output)
			local status, body = matchLines(output, 1, true)

			if status == ":version" then
				local _latestVersion, _downloadUrl = matchLines(body, 2)

				if not _latestVersion then
					logprinterror("getLatestVersionNumber", output)
					eventQueue:addEvent("git:version_fail", "getLatestVersionNumber: "..T"error_script_internal")
					return
				end

				latestVersion = _latestVersion
				downloadUrl   = _downloadUrl

				if latestVersion ~= APP_VERSION or DEBUG_NEVER_UP_TO_DATE then
					eventQueue:addEvent("git:version_new_available", latestVersion, downloadUrl)
				else
					eventQueue:addEvent("git:version_up_to_date")
				end

			else
				local err

				if status == ":error_request" then
					err = trim(body)
					eventQueue:addEvent("git:version_fail", F("%s: %s", T"error_github_request", err))

				elseif status == ":error_http" then
					local statusCode, statusText = matchLines(body, 2)
					err = F("%s: %s", T"error_github_badResponse", statusText)

				elseif status == ":error_malformed_response" then
					err = trim(body)
					if err == "" then  err = "?"  end
					err = F("%s: %s", T"error_github_malformedResponse", err)

				else
					err = trim(output)
					if err == "" then  err = "?"  end
					err = F("%s: %s", T"error_github_unknown", err)
				end

				logprinterror("getLatestVersionNumber", output)
				eventQueue:addEvent("git:version_fail", err)
			end
		end)

		if not ok then
			showError("Error", "getLatestVersionNumber: "..T"error_script_failedRun")
			return false
		end

		return true
	end

	local function listenStart(dialog, textObj, updateButton)
		local eventHandlers = require"eventHandlers"

		eventHandlers["git:version_up_to_date"] = function()
			textObj.Label = T"message_haveLatestVersion"
			dialog:Fit()
			dialog:Layout()
		end

		eventHandlers["git:version_new_available"] = function(_latestVersion, _downloadUrl)
			textObj.Label = T("message_newVersionAvailable_numbers", {newVersion=_latestVersion, currentVersion=APP_VERSION})
			updateButton:Enable(true)
			dialog:Fit()
			dialog:Layout()
		end

		eventHandlers["git:version_fail"] = function(userMessage)
			textObj.Label = "Error: "..userMessage
			dialog:Fit()
			dialog:Layout()
		end
	end

	local function listenStop()
		local eventHandlers = require"eventHandlers"
		eventHandlers["git:version_up_to_date"]    = nil
		eventHandlers["git:version_new_available"] = nil
		eventHandlers["git:version_fail"]          = nil
	end

	function dialogs.updateApp()
		if not maybeGetLatestVersionNumber() then  return  end

		local dialog       = wxDialog(topFrame, wxID_ANY, T"label_updateApp")
		local sizerDialog  = wxBoxSizer(wxVERTICAL)

		local updateButton, cancelButton

		local isDownloading = false

		on(dialog, wxID_CANCEL, "COMMAND_BUTTON_CLICKED", function(e)
			if isDownloading then  return  end -- Abort closing.

			e:Skip() -- Proceed with closing.
		end)

		-- Text.
		----------------------------------------------------------------

		local textObj = wxStaticText(
			dialog, wxID_ANY, T"message_checkingVersion",
			wxDEFAULT_POSITION, wxDEFAULT_SIZE, wxTE_CENTRE
		)
		textObj:SetSizeHints(300, getHeight(textObj))
		sizerDialog:Add(textObj, 0, wxGROW)

		-- Buttons.
		----------------------------------------------------------------

		local sizerButtons = wxStdDialogButtonSizer()

		updateButton = newButton(dialog, wxID_OK, T"label_update", function(e)
			local path = DIR_TEMP.."/LatestVersion.zip"

			local ok = scriptCaptureAsync("download", function(output)
				isDownloading = false

				local status, rest = matchLines(output, 1, true)

				if status ~= ":success" then
					logprinterror("download", "Could not download '%s' to '%s':\n%s", downloadUrl, path, output)
					dialog:EndModal(wxID_CANCEL)
					showError("Error", T"error_updater_download")
					return
				end

				if not cmdDetached("misc/Update/wlua5.1.exe", "misc/Update/update.lua", path, wxGetProcessId()) then
					dialog:EndModal(wxID_CANCEL)
					showError("Error", T"error_updater_run")
					return
				end

				-- Don't remove the downloaded file!
				clearTempDirOnExit = false

				-- Should we force quit here? Surely no one would update while
				-- AniDB messages are in transit or anything. Surely. <_<
				quit()
			end, downloadUrl, path)

			if not ok then
				showError("Error", "download: "..T"error_script_failedRun")
				e:Skip()
				return
			end

			isDownloading = true
			updateButton.Label = T"label_updating" -- @Incomplete: Show an animated working indicator when updating.
			updateButton:Enable(false)
			cancelButton:Enable(false)
			-- pause("updating") -- Bad! We need events to flow!
		end)
		updateButton:Enable(false)
		sizerButtons.AffirmativeButton = updateButton

		cancelButton = newButton(dialog, wxID_CANCEL, T"label_cancel")
		sizerButtons.CancelButton = cancelButton

		sizerButtons:Realize()
		sizerDialog:Add(sizerButtons, 0, wxTOP + wxALIGN_CENTRE_HORIZONTAL, MARGIN_M)

		----------------------------------------------------------------

		local sizerWrapper = wxBoxSizer(wxHORIZONTAL)
		sizerWrapper:Add(sizerDialog, 0, wxGROW_ALL, MARGIN_M)

		dialog.AutoLayout = true
		dialog.Sizer      = sizerWrapper

		dialog:Fit()
		dialog:Centre()

		listenStart(dialog, textObj, updateButton)
		showModalAndDestroy(dialog)
		listenStop()
	end
end



return dialogs
