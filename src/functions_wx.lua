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
	setBoxSizer, setBoxSizerWithSpace, getSizerSpace
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

	processReadEnded
	processStart, processStop, processStopAll

	statusBarInitFields
	statusBarSetField

	streamRead

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
		windowClassInfo = windowClassInfo or wxClassInfo.FindClass"wxWindow"

		return
			wxlua.istrackedobject(a) and
			wxlua.istrackedobject(b) and
			a:IsKindOf(windowClassInfo) and
			b:IsKindOf(windowClassInfo) and
			a:GetHandle() == b:GetHandle()
	end

	function isClass(v, className)
		return wxlua.istrackedobject(v) and v:IsKindOf(wxClassInfo.FindClass(className))
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
			logprinterror("Gui", "ListCtrl: Trying to add more items than there are columns.")
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

	local rect = wxRect()
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

	id       = id or wxNewId()
	helpText = helpText or ""

	local item

	if type(onPressOrSubmenu) == "function" then
		local onPress = onPressOrSubmenu
		item = wxMenuItem(menu, id, caption, helpText)

		local cb = on(eHandler, id, "COMMAND_MENU_SELECTED", onPress)
		storeEventCallbacks(menu, "COMMAND_MENU_SELECTED", id, cb)

	elseif type(onPressOrSubmenu) == "userdata" then
		local submenu = onPressOrSubmenu
		item = wxMenuItem(menu, id, caption, helpText, wxITEM_NORMAL, submenu)

	else
		item = wxMenuItem(menu, id, caption, helpText)
	end

	item = menu:Append(item)

	return item
end

-- item = newMenuItemLabel( menu, caption )
function newMenuItemLabel(menu, caption)
	local item = menu:Append(wxMenuItem(menu, wxNewId(), caption))
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

	local button = wxButton(parent, id, caption, pos, size)

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

	local textObj = wxStaticText(parent, id, label, pos, size)
	return textObj
end



-- callbackWrapper = on( eventHandler, [ id, ] eventType, callback )  -- @Cleanup: Move id to after eventType.
-- callback( event, eventSpecificArgument1, ... )
do
	local EVENT_EXPANDERS = {
		["CHAR_HOOK"] -- keycode
		= function(e)  return e:GetKeyCode()  end,
		["COMMAND_LIST_COL_END_DRAG"] -- wxColumn, width
		= function(e)  return e:GetColumn(), e:GetItem():GetWidth()  end,
		["COMMAND_LIST_ITEM_ACTIVATED"] -- wxRow
		= function(e)  return e:GetIndex()  end,
		["DROP_FILES"] -- filePaths
		= function(e)  return e:GetFiles()  end,
		["END_PROCESS"] -- exitCode, pid
		= function(e)  return e:GetExitCode(), e:GetPid()  end,
		["GRID_COL_SIZE"] -- wxColumn, x
		= function(e)  return e:GetRowOrCol(), e:GetPosition():GetX()  end,
		["GRID_ROW_SIZE"] -- wxRow, y
		= function(e)  return e:GetRowOrCol(), e:GetPosition():GetY()  end,
		["KEY_DOWN"] -- keycode
		= function(e)  return e:GetKeyCode()  end,
		["MOVE"] -- x, y
		= function(e)  return e:GetPosition():GetXY()  end,
		["MOVING"] -- x, y
		= function(e)  return e:GetPosition():GetXY()  end,
		["SIZE"] -- width, height
		= function(e)  local size = e:GetSize()  return size:GetWidth(), size:GetHeight()  end,
	}

	function on(eHandler, id, eType, cb)
		if type(id) == "string" then
			id, eType, cb = nil, id, eType
		end

		local k     = "wxEVT_"..eType
		local eCode = wx[k] or wxlua[k] or wxaui[k] or wxstc[k] or errorf(2, "Unknown event type '%s'.", eType)

		local expander = EVENT_EXPANDERS[eType] or NOOP

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

	local id    = wxNewId()
	local flags = 0

	if modKeys:find("a", 1, true) then  flags = flags+wxACCEL_ALT    end
	if modKeys:find("c", 1, true) then  flags = flags+wxACCEL_CTRL   end
	if modKeys:find("s", 1, true) then  flags = flags+wxACCEL_SHIFT  end

	on(eHandler, id, "COMMAND_MENU_SELECTED", onPress)
	table.insert(accelerators, {flags, kc, id})

	return id
end

-- off( eventHandler, eventType [, id=wxID_ANY ] )
-- off( eventHandler, eventType, eventHolder )
function off(eHandler, eType, ...)
	local k     = "wxEVT_"..eType
	local eCode = wx[k] or wxlua[k] or wxaui[k] or wxstc[k] or errorf(2, "Unknown event type '%s'.", eType)

	if type((...)) == "userdata" then
		local eHolder = ...
		local cbs     = getStoredEventCallbackAll(eHolder, eType)
		if not cbs then return end

		for id in pairs(cbs) do
			eHandler:Disconnect(id, eCode)
			cbs[id] = nil
		end

	else
		local id = ... or wxID_ANY
		eHandler:Disconnect(id, eCode)
	end
end



function setAccelerators(window, accelerators)
	window:SetAcceleratorTable(wxAcceleratorTable(accelerators))
end



-- timer = newTimer( [ milliseconds, oneShot=false, ] callback )
function newTimer(milliseconds, oneShot, cb)
	if type(milliseconds) ~= "number" then
		milliseconds, oneShot, cb = nil, milliseconds, oneShot
	end
	if type(oneShot) ~= "boolean" then
		oneShot, cb = false, oneShot
	end

	local timer = wxTimer(topFrame)
	timer:SetOwner(timer)

	on(timer, "TIMER", cb)

	if milliseconds then
		timer:Start(milliseconds, oneShot)
	end

	return timer
end



-- showButtonDialog
--
-- Method 1:
--    index = showButtonDialog( caption, message, buttonInfo [, icon=wxART_INFORMATION ] )
--    buttonInfo = { label1, [ onPress1, ] ... }
--
-- Method 2:
--    id    = showButtonDialog( caption, message, buttonInfo [, icon=wxART_INFORMATION ] )
--    buttonInfo = { id1, label1, [ onPress1, ] ... }
--
-- onPress = function( event )
-- Call event:Skip() to prevent the dialog from closing.
--
-- Returns nil if no button was pressed.
--
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
function showButtonDialog(caption, message, infos, icon)
	assertarg(1, caption, "string")
	assertarg(2, message, "string")
	assertarg(3, infos,   "table")
	assertarg(4, icon,    "number","nil")
	assert(infos[1])

	local dialog      = wxDialog(topFrame, wxID_ANY, caption)
	local sizerDialog = wxBoxSizer(wxVERTICAL)

	on(dialog, "CHAR_HOOK", function(e, kc)
		if kc == KC_ESCAPE then
			dialog:EndModal(wxID_CANCEL)
		else
			e:Skip()
		end
	end)

	----------------------------------------------------------------

	local panel = wxPanel(dialog, wxID_ANY)
	panel:SetBackgroundColour(wxColour(255, 255, 255))

	local sizer = wxBoxSizer(wxHORIZONTAL)

	-- Icon.
	local iconName = ICONS[icon] or ICONS[wxICON_INFORMATION]
	if iconName ~= "" then
		local bm    = wxArtProvider.GetBitmap(iconName)
		local bmObj = wxStaticBitmap(panel, wxID_ANY, bm)
		sizer:Add(bmObj, 0, wxRIGHT, MARGIN_M) -- wxALIGN_CENTRE_VERTICAL
	end

	-- Message.
	local textObj = wxStaticText(panel, wxID_ANY, message)
	textObj:Wrap(300)
	sizer:Add(textObj)--, 0, wxALIGN_CENTRE_VERTICAL)

	local sizerWrapper = wxBoxSizer(wxHORIZONTAL)
	sizerWrapper:Add(sizer, 0, wxGROW_ALL, 24)

	panel:SetAutoLayout(true)
	panel:SetSizer(sizerWrapper)

	sizerDialog:Add(panel, 0, wxGROW)

	----------------------------------------------------------------

	local sizer = wxBoxSizer(wxHORIZONTAL) -- @Incomplete: Use wxStdDialogButtonSizer(). [LOW]
	sizer:AddStretchSpacer()

	local createIds    = type(infos[1]) == "string"
	local i            = 1
	local buttonIndex  = 0
	local returnValues = {}

	-- Buttons.
	while infos[i] do
		buttonIndex = buttonIndex+1
		local id, label
		local cb = nil

		if createIds then
			id               = wxNewId()
			label            = infos[i]
			returnValues[id] = buttonIndex
			i                = i+1
		else
			id               = infos[i]
			label            = infos[i+1] or "{NO_BUTTON_LABEL}"
			returnValues[id] = id
			i                = i+2
		end

		if type(infos[i]) == "function" then
			cb = infos[i]
			i  = i+1
		end

		local button = newButton(dialog, id, label, function(e)
			if cb then cb(e) end

			if not cb or e:GetSkipped() then
				dialog:EndModal(id)
			end

			e:Skip(false)
		end)

		sizer:Add(button, 0, wxLEFT + wxRIGHT, 3)
	end

	sizerDialog:Add(sizer, 0, wxGROW_ALL, MARGIN_M)

	----------------------------------------------------------------

	dialog:SetAutoLayout(true)
	dialog:SetSizer(sizerDialog)

	dialog:Fit()
	dialog:Centre()

	local id = dialog:ShowModal()
	return returnValues[id]
end

-- showMessage( caption, message )
function showMessage(caption, message)
	wxMessageBox(message, caption, wxOK + wxCENTRE + wxICON_INFORMATION, topFrame)
end

-- showWarning( caption, message )
function showWarning(caption, message)
	wxMessageBox(message, caption, wxOK + wxCENTRE + wxICON_WARNING, topFrame)
end

-- showError( caption, message )
function showError(caption, message)
	wxMessageBox(message, caption, wxOK + wxCENTRE + wxICON_ERROR, topFrame)
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



--[[
-- sizer = setBoxSizer( wxWindow, direction [, proportion=0, flags, border=0 ] )
-- direction = wxHORIZONTAL|wxVERTICAL
function setBoxSizer(window, direction, ...)
	local sizer = wxBoxSizer(direction)

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
	local sizer = wxBoxSizer(direction)

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
--]]



function checkBoxClick(checkbox)
	local state = not checkbox:IsChecked()

	checkbox:SetValue(state)

	local e = wxCommandEvent(wxEVT_COMMAND_CHECKBOX_CLICKED, checkbox:GetId())
	e:SetEventObject(checkbox)
	e:SetInt(state and 1 or 0)

	checkbox:ProcessEvent(e)
end



function textCtrlSelectAll(textCtrl)
	textCtrl:SetSelection(0, textCtrl:GetLastPosition())
end



function clipboardSetText(s)
	local data      = wxTextDataObject(s)
	local clipboard = wxClipboard.Get()
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



-- string = streamRead( stream [, isText=false ] )
function streamRead(stream, isText)
	assertarg(1, stream, "userdata")
	assertarg(2, isText, "boolean","nil")

	if not stream:CanRead() then  return ""  end

	local len = stream:GetLength()
	if len ~= wxSEEK_MODE_INVALID_OFFSET then
		local s = stream:Read(len)
		if isText then
			s = s:gsub("\r\n", "\n")
		end
		return s
	end

	local chars = {}
	local i     = 0
	local c     = ""
	local cLast = ""

	repeat
		local c = stream:Read(1)

		if not (isText and c == "\n" and cLast == "\r") then
			i = i+1
		end

		chars[i] = c
		cLast    = c
	until not stream:CanRead()

	return table.concat(chars)
end



-- processStarted = processStart( cmd, method [, callback ] )
-- callback       = function( process, exitCode )
-- method         = PROCESS_METHOD_ASYNC|PROCESS_METHOD_SYNC|PROCESS_METHOD_DETACHED
-- Note: PROCESS_METHOD_ASYNC does not use the callback in any way.
function processStart(cmd, method, cb)
	assertarg(1, cmd,    "string")
	assertarg(2, method, "number")
	assertarg(3, cb,     "function","nil")

	-- Async.
	if method == PROCESS_METHOD_ASYNC then
		local process = wxProcess(topFrame or wxNULL)
		process:Redirect()

		local pid = wxExecute(cmd, wxEXEC_ASYNC, process)
		if pid == 0  then  return false  end

		if cb then
			on(process, "END_PROCESS", function(e, exitCode, pid)
				processes[pid] = nil
				process:Detach()
				off(process, "END_PROCESS")

				cb(process, exitCode)
			end)

			-- pid being able to be -1 is unfortunate, but will probably not happen for this app I think.
			-- http://docs.wxwidgets.org/2.9/group__group__funcmacro__procctrl.html#gaa276e9e676e26bafeec3141b73399b33
			if pid ~= -1 then
				processes[pid] = process
			end

		else
			process:Detach()
		end

		return true

	-- Sync.
	elseif method == PROCESS_METHOD_SYNC then
		local process = wxProcess(topFrame or wxNULL)
		process:Redirect()

		local exitCode = wxExecute(cmd, wxEXEC_SYNC, process)

		if cb then  cb(process, exitCode)  end

		return exitCode ~= -1

	-- Detached.
	elseif method == PROCESS_METHOD_DETACHED then
		local pid = wxExecute(cmd, wxEXEC_ASYNC + wxEXEC_NOHIDE)
		return pid ~= 0

	else
		errorf("Bad process method '%d'.", method)
	end
end

-- success = processStop( pid [, force=false ] )
do
	local KILL_MESSAGES = {
		[wxKILL_OK]            = "OK",
		[wxKILL_BAD_SIGNAL]    = "BAD_SIGNAL",
		[wxKILL_ACCESS_DENIED] = "ACCESS_DENIED",
		[wxKILL_NO_PROCESS]    = "NO_PROCESS",
		[wxKILL_ERROR]         = "ERROR",
	}
	function processStop(pid, force)
		if pid == 0                     then  return true   end
		if pid == -1                    then  return false  end -- Don't allow harakiri. This is so silly.
		if not wxProcess.Exists(pid) then  return true   end

		local process = processes[pid]
		if process then
			processes[pid] = nil
			process:Detach()
			off(process, "END_PROCESS")
		end

		local errCode = wxProcess.Kill(pid, wxSIGTERM, wxKILL_CHILDREN)
		if isAny(errCode, wxKILL_OK, wxKILL_NO_PROCESS) then  return true   end

		if not force or not isAny(errCode, wxKILL_ERROR, wxKILL_BAD_SIGNAL) then
			logprinterror("Process", "Process %d did not end gracefully. (%s)", pid, KILL_MESSAGES[errCode])
			return false
		end

		logprinterror("Process", "Process %d did not end gracefully. Killing. (%s)", pid, KILL_MESSAGES[errCode])

		errCode = wxProcess.Kill(pid, wxSIGKILL, wxKILL_CHILDREN)
		if errCode == wxKILL_OK then
			return true
		else
			logprinterror("Process", "Process %d could not get killed. (%s)", pid, KILL_MESSAGES[errCode])
			return false
		end
	end
end

-- processStopAll( [ force=false ] )
function processStopAll(force)
	for pid, process in pairs(processes) do
		process:Detach()
		off(process, "END_PROCESS")
	end

	for pid in pairs(processes) do
		processes[pid] = nil
		processStop(pid, force)
	end
end



-- string = processReadEnded( process, exitCode [, isText=false ] )
function processReadEnded(process, exitCode, isText)
	assertarg(1, process,  "userdata")
	assertarg(2, exitCode, "number")
	assertarg(3, isText,   "boolean","nil")

	local stream = exitCode == 0 and process:IsErrorAvailable() and process:GetErrorStream() or process:GetInputStream()
	local s      = streamRead(stream, isText)

	return s
end


