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
	credentials

--============================================================]]

local dialogs = {}



function dialogs.about()
	local title     = "MyHappyList "..APP_VERSION
	local copyright = "Copyright © 2018 Marcus 'ReFreezed' Thunström. MIT license."
	local desciption
		= "MyHappyList is made using Lua, wxLua, LuaSocket and rhash. "
		.."The executable is built using srlua, ResourceHacker and ImageMagick."

	local dialog = wx.wxDialog(topPanel, wxID_ANY, "About MyHappyList")
	local sizer  = wx.wxBoxSizer(wxVERTICAL)

	on(dialog, "CHAR_HOOK", function(e, kc)
		if kc == KC_ESCAPE then
			dialog:EndModal(wxID_CANCEL)
		else
			e:Skip()
		end
	end)

	-- Icon.
	local bm = wx.wxBitmap()
	bm:CopyFromIcon(appIcons:GetIcon(32))
	local bmObj = wx.wxStaticBitmap(dialog, wxID_ANY, bm)
	sizer:Add(bmObj, 0, wxALIGN_CENTRE_HORIZONTAL)

	sizer:AddSpacer(8)

	-- Title.
	local textObj = wx.wxStaticText(dialog, wxID_ANY, title, wxDEFAULT_POSITION, wxDEFAULT_SIZE, wxALIGN_CENTRE_HORIZONTAL)
	textObj:SetFont(fontTitle)
	sizer:Add(textObj, 0, wxGROW_ALL)

	sizer:AddSpacer(8)

	-- Copyright.
	local textObj = wx.wxStaticText(dialog, wxID_ANY, copyright, wxDEFAULT_POSITION, wxDEFAULT_SIZE, wxALIGN_CENTRE_HORIZONTAL)
	sizer:Add(textObj, 0, wxGROW_ALL)

	sizer:AddSpacer(8)

	-- Description.
	local textObj = wx.wxStaticText(dialog, wxID_ANY, desciption)
	textObj:Wrap(400)
	sizer:Add(textObj, 0, wxGROW_ALL)

	sizer:AddSpacer(20)

	-- Close button.
	local button = newButton(dialog, wxID_OK, "Close", function(e)
		dialog:EndModal(e:GetId())
	end)
	button:SetSizeHints(100, getHeight(button)+2*3)
	sizer:Add(button, 0, wxALIGN_CENTRE_HORIZONTAL)

	local sizerWrapper = wx.wxBoxSizer(wxHORIZONTAL)
	sizerWrapper:Add(sizer, 0, wxGROW_ALL, 20)

	dialog:SetAutoLayout(true)
	dialog:SetSizer(sizerWrapper)

	dialog:Fit()
	dialog:Centre()

	dialog:ShowModal()
end



function dialogs.addmylist()
	local fileInfosSelected = getSelectedFileInfos(true)
	if not fileInfosSelected[1] then  return  end

	-- Max length of UDP packages (over PPPoE) is 1400 bytes. Let's try to
	-- stay within the bounds before attempting to send anything.
	--
	-- https://wiki.anidb.net/w/UDP_API_Definition#General
	--
	-- UDP message example when adding:
	--    MYLISTADD ed2k=4b7e0f1101fb3ef95e187f6f086cf6b3&other=&s=GM3Fz97&size=3669066876&source=&state=2&storage=&tag=#a01340e&viewdate=1333248804&viewed=1
	--
	local MAX_UDP_MESSAGE_LENGTH     = 1400
	local APPROX_BASE_MESSAGE_LENGTH = 150
	local SAFETY_MESSAGE_LENGTH      = 20

	local dialog = wx.wxDialog(topPanel, wxID_ANY, "Add to / Edit MyList")

	on(dialog, "CHAR_HOOK", function(e, kc)
		if kc == KC_ESCAPE then
			dialog:EndModal(wxID_CANCEL)
		else
			e:Skip()
		end
	end)

	-- File count text.
	----------------------------------------------------------------

	newText(dialog, F("Adding/editing %d files.", #fileInfosSelected))

	wx.wxStaticLine(dialog, wxID_ANY)

	-- Viewed.
	----------------------------------------------------------------

	local VIEWED_STATES = {
		{value=nil,   title="Don't change"},
		{value=true,  title="Yes"}, -- @Incomplete: Allow direct editing of viewdate.
		{value=false, title="No"},
	}

	local viewedRadio = wx.wxRadioBox(
		dialog, wxID_ANY, "Watched", wxDEFAULT_POSITION, wxDEFAULT_SIZE,
		getColumn(VIEWED_STATES, "title"), 0, wxRA_SPECIFY_ROWS
	)

	-- MyList state.
	----------------------------------------------------------------

	local MYLIST_STATES = {
		{value=nil,                           title="Don't change"},
		{value=MYLIST_STATE_UNKNOWN,          title="Unknown / unspecified"},
		{value=MYLIST_STATE_INTERNAL_STORAGE, title="Internal storage (HDD/SSD)"},
		{value=MYLIST_STATE_EXTERNAL_STORAGE, title="External storage (CD, DVD etc.)"},
		-- {value=MYLIST_STATE_REMOTE_STORAGE,   title="Remote storage (NAS, cloud etc.)"}, -- AniDB complains! :/
		{value=MYLIST_STATE_DELETED,          title="Deleted"},
	}

	local mylistStateRadio = wx.wxRadioBox(
		dialog, wxID_ANY, "State", wxDEFAULT_POSITION, wxDEFAULT_SIZE,
		getColumn(MYLIST_STATES, "title"), 0, wxRA_SPECIFY_ROWS
	)

	-- Source.
	----------------------------------------------------------------

	local panel = wx.wxPanel(dialog, wx.wxID_ANY)

	local sourceCheckbox = wx.wxCheckBox(panel, wxID_ANY, "Source:")
	sourceCheckbox:SetSizeHints(60, getHeight(sourceCheckbox))
	sourceCheckbox:SetToolTip("Source: i.e. ed2k, DC, FTP or IRC")

	local sourceInput = wx.wxTextCtrl(panel, wxID_ANY)
	sourceInput:SetSizeHints(200, getHeight(sourceInput))
	sourceInput:SetMaxLength(MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH)
	sourceInput:SetToolTip(sourceCheckbox:GetToolTip():GetTip())
	sourceInput:Enable(false)

	on(sourceCheckbox, "COMMAND_CHECKBOX_CLICKED", function(e)
		sourceInput:Enable(e:IsChecked())
		sourceInput:SetFocus()
	end)

	on(panel, "LEFT_DOWN", function(e)
		if not sourceCheckbox:IsChecked() then
			checkBoxClick(sourceCheckbox)
		end
	end)

	setBoxSizer(panel, wxHORIZONTAL, 0, wxALIGN_CENTER_VERTICAL)

	-- Storage.
	----------------------------------------------------------------

	local panel = wx.wxPanel(dialog, wx.wxID_ANY)

	local storageCheckbox = wx.wxCheckBox(panel, wxID_ANY, "Storage:")
	storageCheckbox:SetSizeHints(60, getHeight(storageCheckbox))
	storageCheckbox:SetToolTip("Storage: i.e. the label of the CD with this file")

	local storageInput = wx.wxTextCtrl(panel, wxID_ANY)
	storageInput:SetSizeHints(200, getHeight(storageInput))
	storageInput:SetMaxLength(MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH)
	storageInput:SetToolTip(storageCheckbox:GetToolTip():GetTip())
	storageInput:Enable(false)

	on(storageCheckbox, "COMMAND_CHECKBOX_CLICKED", function(e)
		storageInput:Enable(e:IsChecked())
		storageInput:SetFocus()
	end)

	on(panel, "LEFT_DOWN", function(e)
		if not storageCheckbox:IsChecked() then
			checkBoxClick(storageCheckbox)
		end
	end)

	setBoxSizer(panel, wxHORIZONTAL, 0, wxALIGN_CENTER_VERTICAL)

	-- Other.
	----------------------------------------------------------------

	local panel = wx.wxPanel(dialog, wx.wxID_ANY)

	local otherCheckbox = wx.wxCheckBox(panel, wxID_ANY, "Note:")
	otherCheckbox:SetSizeHints(60, getHeight(otherCheckbox))

	local otherInput = wx.wxTextCtrl(panel, wxID_ANY, "", wxDEFAULT_POSITION, WxSize(200, 100), wxTE_MULTILINE)
	local colorOn  = otherInput:GetBackgroundColour()
	local colorOff = wx.wxSystemSettings.GetColour(wxSYS_COLOUR_3DFACE)
	otherInput:SetMaxLength(MAX_UDP_MESSAGE_LENGTH - APPROX_BASE_MESSAGE_LENGTH - SAFETY_MESSAGE_LENGTH)
	otherInput:Enable(false)
	otherInput:SetBackgroundColour(colorOff)

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

	setBoxSizer(panel, wxHORIZONTAL)

	-- Buttons.
	----------------------------------------------------------------

	wx.wxStaticLine(dialog, wxID_ANY)

	local panel = wx.wxPanel(dialog, wx.wxID_ANY)

	newButton(panel, wxID_OK, "Add / Edit", function(e)
		dialog:EndModal(e:GetId())
	end)

	newButton(panel, wxID_CANCEL, "Cancel", function(e)
		dialog:EndModal(e:GetId())
	end)

	setBoxSizer(panel, wxHORIZONTAL):PrependStretchSpacer()

	----------------------------------------------------------------

	setBoxSizerWithSpace(dialog, wxVERTICAL, 10, 4, 0, wxGROW)
	dialog:Fit()
	dialog:Centre()

	local viewed, state, storage, source, other

	while true do
		local id = dialog:ShowModal()
		if id ~= wxID_OK then  return  end

		viewed  = VIEWED_STATES[viewedRadio:GetSelection()+1].value
		state   = MYLIST_STATES[mylistStateRadio:GetSelection()+1].value
		storage = storageCheckbox:IsChecked() and storageInput:GetValue() or nil
		source  = sourceCheckbox:IsChecked()  and sourceInput:GetValue()  or nil
		other   = otherCheckbox:IsChecked()   and otherInput:GetValue()   or nil

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
			-- Loop back and show the dialog again.

		else
			break -- Continue.
		end
	end

	local values = {
		viewed  = viewed,
		state   = state,
		storage = storage,
		source  = source,
		other   = other,
	}

	for _, fileInfo in ipairs(fileInfosSelected) do
		if fileInfo.lid ~= -1 then
			if next(values) then
				anidb:editMylist(fileInfo.lid, values)
			end

		elseif fileInfo.ed2k ~= "" then
			anidb:addMylistByEd2k(fileInfo.ed2k, fileInfo.size, values)
		end
	end
end



function dialogs.credentials()
	local dialog       = wx.wxDialog(topPanel, wxID_ANY, "Credentials to AniDB")
	local sizerDialog  = wx.wxBoxSizer(wxVERTICAL)

	on(dialog, "CHAR_HOOK", function(e, kc)
		if kc == KC_ESCAPE then
			dialog:EndModal(wxID_CANCEL)
		else
			e:Skip()
		end
	end)

	-- Inputs.
	----------------------------------------------------------------

	local user, pass = anidb:getCredentials()

	-- Username. 3-16 characters. A-Z, a-z, 0-9, - and _ only.
	local sizerSection = wx.wxBoxSizer(wxHORIZONTAL)

	local textObj = wx.wxStaticText(dialog, wxID_ANY, "Username:")
	textObj:SetSizeHints(60, getHeight(textObj))
	sizerSection:Add(textObj)

	local userInput = wx.wxTextCtrl(dialog, wxID_ANY, (user or ""))
	userInput:SetMaxLength(16)
	sizerSection:Add(userInput, 1, wxGROW_ALL)

	sizerDialog:Add(sizerSection, 1, wxGROW_ALL)

	sizerDialog:AddSpacer(2)

	-- Password. 4-64 characters. ASCII only.
	local sizerSection = wx.wxBoxSizer(wxHORIZONTAL)

	local textObj = wx.wxStaticText(dialog, wxID_ANY, "Password:")
	textObj:SetSizeHints(60, getHeight(textObj))
	sizerSection:Add(textObj)

	local passInput = wx.wxTextCtrl(dialog, wxID_ANY, (pass or ""), wxDEFAULT_POSITION, wxDEFAULT_SIZE, wxTE_PASSWORD)
	passInput:SetMaxLength(64)
	sizerSection:Add(passInput, 1, wxGROW_ALL)

	sizerDialog:Add(sizerSection, 1, wxGROW_ALL)

	-- Text.
	----------------------------------------------------------------

	sizerDialog:AddSpacer(8)

	local textObj = wx.wxStaticText(dialog, wxID_ANY, "Note: These credentials will be saved in 'local/login'.")
	sizerDialog:Add(textObj, 0, wxGROW_ALL)

	-- Buttons.
	----------------------------------------------------------------

	sizerDialog:AddSpacer(8)

	local sizerSection = wx.wxBoxSizer(wxHORIZONTAL)
	sizerSection:AddStretchSpacer()

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
	sizerSection:Add(button)

	sizerSection:AddSpacer(8)

	local button = newButton(dialog, wxID_CANCEL, "Cancel", function(e)
		e:Skip()
	end)
	sizerSection:Add(button)

	sizerDialog:Add(sizerSection, 0, wxGROW_ALL)

	-- local button = newButton(dialog, wxID_OK, "Close", function(e)
	-- 	dialog:EndModal(e:GetId())
	-- end)
	-- button:SetSizeHints(100, getHeight(button)+2*3)
	-- sizerDialog:Add(button, 0, wxALIGN_CENTRE_HORIZONTAL)

	----------------------------------------------------------------

	local sizerWrapper = wx.wxBoxSizer(wxHORIZONTAL)
	sizerWrapper:Add(sizerDialog, 0, wxGROW_ALL, 8)

	dialog:SetAutoLayout(true)
	dialog:SetSizer(sizerWrapper)

	dialog:Fit()
	dialog:Centre()

	show(loginButton, topPanel)
	dialog:ShowModal()
end



return dialogs
