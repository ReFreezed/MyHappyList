--[[============================================================
--=
--=  Global Functions - wxWidgets
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--==============================================================

	cast, is, isClass
	eachChild
	getSize, getWidth, getHeight
	newMenuItem, newMenuItemLabel, newMenuItemSeparator, newButton, newText
	newTimer
	on, onAccelerator, off
	setAccelerators
	setBoxSizer, setBoxSizerWithSpace
	showButtonDialog, showMessage, showWarning, showError, confirm

	checkBoxClick

	clipboardSetText

	listCtrlGetSelectedRows, listCtrlGetFirstSelectedRow
	listCtrlInsertColumn
	listCtrlInsertRow
	listCtrlPopupMenu
	listCtrlSelectRows
	listCtrlSetItem
	listCtrlSort

	statusBarInitFields
	statusBarSetField

	textCtrlSelectAll

--============================================================]]



-- wxObject:className = cast( wxObject [, className=actualClassOfWxObject ] )
local classNameSubstitutes = {
	["wxGauge95"] = "wxGauge",
}
function cast(obj, className)
	-- print(obj:GetClassInfo():GetClassName())
	className = className or obj:GetClassInfo():GetClassName()
	className = classNameSubstitutes[className] or className
	return obj:DynamicCast(className)
end

do
	local windowClassInfo = nil

	function is(a, b)
		windowClassInfo = windowClassInfo or wx.wxClassInfo.FindClass"wxWindow"

		return
			wxlua.istrackedobject(a) and
			wxlua.istrackedobject(b) and
			a:IsKindOf(windowClassInfo) and
			b:IsKindOf(windowClassInfo) and
			a:GetHandle() == b:GetHandle()
	end

	function isClass(v, className)
		return wxlua.istrackedobject(v) and v:IsKindOf(wx.wxClassInfo.FindClass(className))
	end
end



-- for index, child in eachChild( window ) do
function eachChild(window)
	local childList = isClass(window, "wxMenu") and window:GetMenuItems() or window:GetChildren()
	local wxRow     = -1
	local childNode

	return function()
		wxRow   = wxRow+1
		childNode = childList:Item(wxRow)

		if childNode then
			return wxRow+1, cast(childNode:GetData())
		end
	end
end



-- wxColumn = listCtrlInsertColumn( listCtrl [, wxColumn=end ], heading [, width=auto ] )
function listCtrlInsertColumn(listCtrl, wxCol, heading, w)
	if type(wxCol) == "string" then
		wxCol, heading, w = listCtrl:GetColumnCount(), wxCol, heading
	end

	wxCol = listCtrl:InsertColumn(wxCol, heading, wxLIST_FORMAT_LEFT, w or -1)
	return wxCol
end

-- wxRow = listCtrlInsertRow( listCtrl [, wxRow=end ], item1, ... )
-- Note: At least one item must be specified.
function listCtrlInsertRow(listCtrl, wxRow, ...)
	if type(wxRow) ~= "number" then
		return listCtrlInsertRow(listCtrl, listCtrl:GetItemCount(), wxRow, ...)
	end

	wxRow = listCtrl:InsertItem(wxRow, (...))
	-- Note: wxRow will have changed if the list sorts automatically.

	if wxRow == -1 then  return nil  end

	for i = 2, select("#", ...) do
		local item = select(i, ...)

		if listCtrl:SetItem(wxRow, i-1, item) == 0 then
			logprinterror("WX", "ListCtrl: Trying to add more items than there are columns.")
			break
		end
	end

	return wxRow
end

-- success = listCtrlSetItem( listCtrl, wxRow [, wxColumn=0 ], item )
function listCtrlSetItem(listCtrl, wxRow, col, item)
	if type(col) ~= "number" then
		col, item = 0, col
	end

	return listCtrl:SetItem(wxRow, col, item) == 1
end

function listCtrlGetSelectedRows(listCtrl)
	local wxIndices = {}
	local wxRow     = -1

	while true do
		wxRow = listCtrl:GetNextItem(wxRow, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED)
		if wxRow == -1 then break end

		table.insert(wxIndices, wxRow)
	end

	return wxIndices
end

function listCtrlGetFirstSelectedRow(listCtrl)
	local wxRow = listCtrl:GetNextItem(-1, wxLIST_NEXT_ALL, wxLIST_STATE_SELECTED)

	return wxRow >= 1 and wxRow or nil
end

-- listCtrlPopupMenu( listCtrl, menu, wxRow, point )
-- listCtrlPopupMenu( listCtrl, menu, wxRow, x, y )
function listCtrlPopupMenu(listCtrl, menu, wxRow, x, y)
	if type(x) == "userdata" then
		x, y = x:GetXY()
	end

	if not (x == -1 and y == -1) then
		popupMenu(listCtrl, menu)
		return
	end

	local rect = wx.wxRect()
	if listCtrl:GetItemRect(wxRow, rect) then
		x = rect:GetLeft()
		y = rect:GetBottom()
	else
		rect = listCtrl:GetRect()
		x = rect:GetLeft()
		y = rect:GetTop()
	end

	popupMenu(listCtrl, menu, x, y)
end

-- anyRowWasSelected = listCtrlSelectRows( listCtrl [, wxIndices, fallbackWxIndex ] )
-- anyRowWasSelected = listCtrlSelectRows( listCtrl [, wxIndices, fallbackToLastRow=false ] )
function listCtrlSelectRows(listCtrl, wxIndices, fallback)
	local count = listCtrl:GetItemCount()
	if count == 0 then  return false  end

	local flags = wxLIST_STATE_SELECTED + wxLIST_STATE_FOCUSED
	local anyStatesWereSet = false

	for wxRow = 0, count-1 do
		if wxIndices and indexOf(wxIndices, wxRow) then
			listCtrl:SetItemState(
				wxRow,
				flags-(anyStatesWereSet and wxLIST_STATE_FOCUSED or 0),
				flags
			)
			anyStatesWereSet = true
		else
			listCtrl:SetItemState(wxRow, 0, flags)
		end
	end

	if anyStatesWereSet then  return true  end

	if type(fallback) == "number" then
		return listCtrl:SetItemState(fallback, flags, flags)
	elseif fallback == true then
		return listCtrl:SetItemState(count-1, flags, flags)
	end
end



-- item = newMenuItem( menu, eventHandler [, id ], caption [, helpText ] [, onPress ] )
-- item = newMenuItem( menu, eventHandler [, id ], caption [, helpText ] [, submenu ] )
function newMenuItem(menu, eHandler, id, caption, helpText, onPressOrSubmenu)
	if type(id) == "string" then
		id, caption, helpText, onPressOrSubmenu = nil, id, caption, helpText
	end
	if isAny(type(helpText), "function","userdata") then
		helpText, onPressOrSubmenu = nil, helpText
	end

	id       = id or wx.wxNewId()
	helpText = helpText or ""

	local item

	if type(onPressOrSubmenu) == "function" then
		local onPress = onPressOrSubmenu
		item = wx.wxMenuItem(menu, id, caption, helpText)

		local cb = on(eHandler, id, "COMMAND_MENU_SELECTED", onPress)
		storeEventCallbacks(menu, "COMMAND_MENU_SELECTED", id, cb)

	elseif type(onPressOrSubmenu) == "userdata" then
		local submenu = onPressOrSubmenu
		item = wx.wxMenuItem(menu, id, caption, helpText, wxITEM_NORMAL, submenu)

	else
		item = wx.wxMenuItem(menu, id, caption, helpText)
	end

	item = menu:Append(item)

	return item
end

-- item = newMenuItemLabel( menu, caption )
function newMenuItemLabel(menu, caption)
	local item = menu:Append(wx.wxMenuItem(menu, wx.wxNewId(), caption))
	item:Enable(false)
	return item
end

-- item = newMenuItemSeparator( menu )
function newMenuItemSeparator(menu)
	return menu:AppendSeparator()
end

-- button = newButton( parent, [ id, ] caption, [ position, size, ] onPress )
function newButton(parent, id, caption, pos, size, onPress)
	if type(id) == "string" then
		id, caption, pos, size, onPress = nil, id, caption, pos, size
	end
	if type(pos) == "function" then
		pos, size, onPress = nil, nil, pos
	elseif type(size) == "function" then
		size, onPress = nil, size
	end

	id   = id   or wxID_ANY
	pos  = pos  or wxDEFAULT_POSITION
	size = size or wxDEFAULT_SIZE

	local button = wx.wxButton(parent, id, caption, pos, size)

	if onPress then
		on(button, "COMMAND_BUTTON_CLICKED", onPress)
	end

	return button
end

-- textObject = newText( parent, [ id, ] label [, position, size ] )
function newText(parent, id, label, pos, size)
	if type(id) == "string" then
		id, label, pos, size = nil, id, label, pos
	end

	id   = id   or wxID_ANY
	pos  = pos  or wxDEFAULT_POSITION
	size = size or wxDEFAULT_SIZE

	local textObj = wx.wxStaticText(parent, id, label, pos, size)
	return textObj
end



-- callbackWrapper = on( eventHandler, [ id, ] eventType, callback )  -- @Cleanup: Move id to after eventType.
-- callback( event, eventSpecificArgument1, ... )
do
	local eventExpanders = {
		["CHAR_HOOK"] = function(e)
			return e:GetKeyCode()
		end,
		["COMMAND_LIST_ITEM_ACTIVATED"] = function(e)
			return e:GetIndex()--, e:GetColumn()
		end,
		["DROP_FILES"] = function(e)
			return e:GetFiles()
		end,
		["KEY_DOWN"] = function(e)
			return e:GetKeyCode()
		end,
		["SIZE"] = function(e)
			local size = e:GetSize()
			return size:GetWidth(), size:GetHeight()
		end,
	}

	function on(eHandler, id, eType, cb)
		if type(id) == "string" then
			id, eType, cb = nil, id, eType
		end

		local k     = "wxEVT_"..eType
		local eCode = wx[k] or wxlua[k] or wxaui[k] or wxstc[k] or errorf(2, "Unknown event type '%s'.", eType)

		local expander = eventExpanders[eType] or NOOP

		local cbWrapper = wrapCall(function(e)
			return cb(e, expander(e))
		end)

		if id then
			eHandler:Connect(id, eCode, cbWrapper)
		else
			eHandler:Connect(eCode, cbWrapper)
		end

		return cbWrapper
	end
end

-- id = onAccelerator( eventHandler, accelerators, modKeys, keyCode, onPress )
function onAccelerator(eHandler, accelerators, modKeys, kc, onPress)
	assertarg(1, eHandler,     "userdata")
	assertarg(2, accelerators, "table")
	assertarg(3, modKeys,      "string")
	assertarg(4, kc,           "number")
	assertarg(5, onPress,      "function")

	local id    = wx.wxNewId()
	local flags = 0

	if modKeys:find("a", 1, true) then  flags = flags+wxACCEL_ALT    end
	if modKeys:find("c", 1, true) then  flags = flags+wxACCEL_CTRL   end
	if modKeys:find("s", 1, true) then  flags = flags+wxACCEL_SHIFT  end

	on(eHandler, id, "COMMAND_MENU_SELECTED", onPress)
	table.insert(accelerators, {flags, kc, id})

	return id
end

-- off( eventHandler, eventType, id )
-- off( eventHandler, eventType, eventHolder )
function off(eHandler, eType, ...)
	local k     = "wxEVT_"..eType
	local eCode = wx[k] or wxlua[k] or wxaui[k] or wxstc[k] or errorf(2, "Unknown event type '%s'.", eType)

	if type(...) == "number" then
		local id = ...
		eHandler:Disconnect(id, eCode)

	else
		local eHolder = ...
		local cbs     = getStoredEventCallbackAll(eHolder, eType)
		if not cbs then return end

		for id in pairs(cbs) do
			eHandler:Disconnect(id, eCode)
			cbs[id] = nil
		end
	end
end



function setAccelerators(window, accelerators)
	window:SetAcceleratorTable(wx.wxAcceleratorTable(accelerators))
end



-- timer = newTimer( [ milliseconds, oneShot=false, ] callback )
function newTimer(milliseconds, oneShot, cb)
	if type(milliseconds) ~= "number" then
		milliseconds, oneShot, cb = nil, milliseconds, oneShot
	end
	if type(oneShot) ~= "boolean" then
		oneShot, cb = false, oneShot
	end

	local timer = wx.wxTimer(topFrame)
	timer:SetOwner(timer)

	on(timer, "TIMER", cb)

	if milliseconds then
		timer:Start(milliseconds, oneShot)
	end

	return timer
end



-- index = showButtonDialog( caption, message, buttonLabels [, icon=wxART_INFORMATION ] )
-- Returns nil if no button was pressed.
local ICONS = {
	[wxICON_NONE]        = "",
	[wxICON_ERROR]       = wxART_ERROR,
	[wxICON_WARNING]     = wxART_WARNING,
	[wxICON_QUESTION]    = wxART_QUESTION,
	[wxICON_INFORMATION] = wxART_INFORMATION,
	[wxICON_EXCLAMATION] = wxART_WARNING,
	[wxICON_HAND]        = wxART_ERROR,
	-- [wxICON_AUTH_NEEDED] = ?,
}
function showButtonDialog(caption, message, labels, icon)
	local dialog      = wx.wxDialog(topFrame, wxID_ANY, caption)
	local sizerDialog = wx.wxBoxSizer(wxVERTICAL)

	on(dialog, "CHAR_HOOK", function(e, kc)
		if kc == KC_ESCAPE then
			dialog:EndModal(wxID_CANCEL)
		else
			e:Skip()
		end
	end)

	----------------------------------------------------------------

	local panel = wx.wxPanel(dialog, wx.wxID_ANY)
	panel:SetBackgroundColour(wx.wxColour(255, 255, 255))

	local sizer = wx.wxBoxSizer(wxHORIZONTAL)

	-- Icon.
	local iconName = ICONS[icon] or ICONS[wxICON_INFORMATION]
	if iconName ~= "" then
		local bm    = wx.wxArtProvider.GetBitmap(iconName)
		local bmObj = wx.wxStaticBitmap(panel, wxID_ANY, bm)
		sizer:Add(bmObj, 0, wxALIGN_CENTRE_VERTICAL)

		sizer:AddSpacer(8)
	end

	-- Message.
	local textObj = wx.wxStaticText(panel, wxID_ANY, message)
	textObj:Wrap(300)
	sizer:Add(textObj, 0, wxALIGN_CENTRE_VERTICAL)

	local sizerWrapper = wx.wxBoxSizer(wxHORIZONTAL)
	sizerWrapper:Add(sizer, 0, wxGROW_ALL, 24)

	panel:SetAutoLayout(true)
	panel:SetSizer(sizerWrapper)

	sizerDialog:Add(panel, 0, wxGROW_ALL)

	----------------------------------------------------------------

	local sizer = wx.wxBoxSizer(wxHORIZONTAL)
	sizer:AddStretchSpacer()

	local buttonIds = {}

	-- Buttons.
	for i, label in ipairs(labels) do
		if i > 1 then  sizer:AddSpacer(8)  end

		local id = wx.wxNewId()
		table.insert(buttonIds, id)

		local button = newButton(dialog, id, label, function(e)
			dialog:EndModal(id)
		end)

		sizer:Add(button)
	end

	sizerDialog:Add(sizer, 0, wxGROW_ALL, 8)

	----------------------------------------------------------------

	dialog:SetAutoLayout(true)
	dialog:SetSizer(sizerDialog)

	dialog:Fit()
	dialog:Centre()

	local id = dialog:ShowModal()
	return indexOf(buttonIds, id)
end

-- showMessage( caption, message )
function showMessage(caption, message)
	wx.wxMessageBox(message, caption, wxOK + wxCENTRE + wxICON_INFORMATION, topFrame)
end

-- showWarning( caption, message )
function showWarning(caption, message)
	wx.wxMessageBox(message, caption, wxOK + wxCENTRE + wxICON_WARNING, topFrame)
end

-- showError( caption, message )
function showError(caption, message)
	wx.wxMessageBox(message, caption, wxOK + wxCENTRE + wxICON_ERROR, topFrame)
end

-- bool = confirm( caption, message [, okLabel="OK", cancelLabel="Cancel", icon=wxICON_QUESTION ] )
function confirm(caption, message, okLabel, cancelLabel, icon)
	okLabel     = okLabel     or "OK"
	cancelLabel = cancelLabel or "Cancel"
	icon        = icon        or wxICON_QUESTION

	local i = showButtonDialog(caption, message, {okLabel, cancelLabel}, icon)
	return i == 1
end



-- listCtrlSort( listCtrl, cb [, dataInt=0 ] )
function listCtrlSort(listCtrl, cb, dataInt)
	listCtrl:SortItems(wrapCall(cb), (dataInt or 0))
end



-- width, height = getSize( wxObject )
function getSize(obj)
	local size = obj:GetSize()
	return size:GetWidth(), size:GetHeight()
end

function getWidth(obj)
	return obj:GetSize():GetWidth()
end

function getHeight(obj)
	return obj:GetSize():GetHeight()
end



function statusBarInitFields(statusBar, widths)
	statusBar:SetFieldsCount(#widths)
	statusBar:SetStatusWidths(widths)
end



-- statusBarSetField( statusBar, wxIndex, text )
-- statusBarSetField( statusBar, wxIndex, format, ... )
function statusBarSetField(statusBar, wxIndex, s, ...)
	if select("#", ...) > 0 then
		s = s:format(...)
	end
	statusBar:PushStatusText(s, wxIndex)
end



-- sizer = setBoxSizer( wxWindow, direction [, proportion=0, flags, border=0 ] )
-- direction = wxHORIZONTAL|wxVERTICAL
function setBoxSizer(window, direction, ...)
	local sizer = wx.wxBoxSizer(direction)

	for _, child in eachChild(window) do
		sizer:Add(child, ...)
	end

	window:SetAutoLayout(true)
	window:SetSizer(sizer)

	return sizer
end

-- sizer = setBoxSizerWithSpace( wxWindow, direction, spaceOutside, spaceBetween [, proportion=0, flags ] )
-- direction = wxHORIZONTAL|wxVERTICAL
-- Note: wxALL gets added to the flags automatically.
function setBoxSizerWithSpace(window, direction, spaceOutside, spaceBetween, proportion, flags)
	local sizer = wx.wxBoxSizer(direction)

	for i, child in eachChild(window) do
		if i > 1 then
			sizer:AddSpacer(spaceBetween-2*spaceOutside)
		end
		sizer:Add(child, (proportion or 0), (flags or 0)+wxALL, spaceOutside)
	end

	window:SetAutoLayout(true)
	window:SetSizer(sizer)

	return sizer
end

-- spacer, border = getSizerSpace( spaceOutside, spaceBetween )
function getSizerSpace(spaceOutside, spaceBetween)
	return spaceBetween-2*spaceOutside, spaceOutside
end



function checkBoxClick(checkbox)
	local state = not checkbox:IsChecked()

	checkbox:SetValue(state)

	local e = wx.wxCommandEvent(wx.wxEVT_COMMAND_CHECKBOX_CLICKED, checkbox:GetId())
	e:SetEventObject(checkbox)
	e:SetInt(state and 1 or 0)

	checkbox:ProcessEvent(e)
end



function textCtrlSelectAll(textCtrl)
	textCtrl:SetSelection(0, textCtrl:GetLastPosition())
end



function clipboardSetText(s)
	local data      = wx.wxTextDataObject(s)
	local clipboard = wx.wxClipboard.Get()
	clipboard:SetData(data)
end



-- Warning: The menu is expected to NOT be reused!
function popupMenu(eHandler, menu, ...)
	local bool = eHandler:PopupMenu(menu, ...)

	-- Clean up event callbacks. Not sure if this is needed, but let's make sure memory is freed.
	off(eHandler, "COMMAND_MENU_SELECTED", menu)

	-- Fix crash when using submenus in popups.
	-- http://docs.wxwidgets.org/trunk/classwx_menu.html#menu_allocation
	for _, item in eachChild(menu) do
		if item:IsSubMenu() then
			menu:Delete(item)
		end
	end

	return bool
end



function show(window, containerToUpdate)
	window:Show(true)
	containerToUpdate:Layout()
	containerToUpdate:Refresh()
end

function hide(window, containerToUpdate)
	window:Show(false)
	containerToUpdate:Layout()
	containerToUpdate:Refresh()
end


