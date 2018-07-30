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

	cast, is
	eachChild
	newMenuItem, newMenuItemLabel, newMenuItemSeparator, newButton, newText
	newTimer, setTimerDummyOwner
	on, onAccelerator
	setAccelerators
	showMessage, showError

	listCtrlGetSelectedRows, listCtrlGetFirstSelectedRow
	listCtrlInsertColumn
	listCtrlInsertRow
	listCtrlPopupMenu
	listCtrlSelectRows
	listCtrlSetItem

--============================================================]]



-- wxObject:className = cast( wxObject [, className=actualClassOfWxObject ] )
function cast(obj, className)
	className = className or obj:GetClassInfo():GetClassName()
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
end



-- for index, child in eachChild( window ) do
function eachChild(window)
	local childList = window:GetChildren()
	local wxRow   = -1
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

	wxCol = listCtrl:InsertColumn(wxCol, heading, WX_LIST_FORMAT_LEFT, w or -1)
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
		wxRow = listCtrl:GetNextItem(wxRow, WX_LIST_NEXT_ALL, WX_LIST_STATE_SELECTED)
		if wxRow == -1 then break end

		table.insert(wxIndices, wxRow)
	end

	return wxIndices
end

function listCtrlGetFirstSelectedRow(listCtrl)
	local wxRow = listCtrl:GetNextItem(-1, WX_LIST_NEXT_ALL, WX_LIST_STATE_SELECTED)

	return wxRow >= 1 and wxRow or nil
end

-- listCtrlPopupMenu( listCtrl, menu, wxRow, point )
-- listCtrlPopupMenu( listCtrl, menu, wxRow, x, y )
function listCtrlPopupMenu(listCtrl, menu, wxRow, x, y)
	if type(x) == "userdata" then
		x, y = x:GetXY()
	end

	if not (x == -1 and y == -1) then
		listCtrl:PopupMenu(menu)
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

	listCtrl:PopupMenu(menu, x, y)
end

-- anyRowWasSelected = listCtrlSelectRows( listCtrl, wxIndices [, fallbackWxIndex ] )
-- anyRowWasSelected = listCtrlSelectRows( listCtrl, wxIndices [, fallbackToLastRow=false ] )
function listCtrlSelectRows(listCtrl, wxIndices, fallback)
	local count = listCtrl:GetItemCount()
	if count == 0 then  return false  end

	local flags = WX_LIST_STATE_SELECTED + WX_LIST_STATE_FOCUSED
	local anyStatesWereSet = false

	for wxRow = 0, count-1 do
		if indexOf(wxIndices, wxRow) then
			listCtrl:SetItemState(
				wxRow,
				flags-(anyStatesWereSet and WX_LIST_STATE_FOCUSED or 0),
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
function newMenuItem(menu, eHandler, id, caption, helpText, onPress)
	if type(id) == "string" then
		id, caption, helpText, onPress = nil, id, caption, helpText
	end
	if type(helpText) == "function" then
		helpText, onPress = nil, helpText
	end

	id       = id or wx.wxNewId()
	helpText = helpText or ""

	local item = menu:Append(wx.wxMenuItem(menu, id, caption, helpText))

	if onPress then
		on(eHandler, id, "COMMAND_MENU_SELECTED", onPress)
	end

	return item
end

-- item = newMenuItemLabel( menu, caption )
function newMenuItemLabel(menu, caption)
	local item = menu:Append(wx.wxMenuItem(menu, wx.wxNewId(), caption))
	item:Enable(false)
	return item
end

function newMenuItemSeparator(menu)
	menu:Append(wx.wxMenuItem())
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

	id   = id   or WX_ID_ANY
	pos  = pos  or WX_DEFAULT_POSITION
	size = size or WX_DEFAULT_SIZE

	local button = wx.wxButton(parent, id, caption, pos, size)
	on(button, "COMMAND_BUTTON_CLICKED", onPress)

	return button
end

-- textObject = newText( parent, [ id, ] label [, position, size ] )
function newText(parent, id, label, pos, size)
	if type(id) == "string" then
		id, label, pos, size = nil, id, label, pos
	end

	id   = id   or WX_ID_ANY
	pos  = pos  or WX_DEFAULT_POSITION
	size = size or WX_DEFAULT_SIZE

	local textObj = wx.wxStaticText(parent, id, label, pos, size)
	return textObj
end



-- on( wxObject, [ id, ] eventType, callback )
do
	local eventExpanders = {
		["DROP_FILES"] = function(e)
			return e:GetFiles()
		end,
		["KEY_DOWN"] = function(e)
			return e:GetKeyCode()
		end,
		["COMMAND_LIST_ITEM_ACTIVATED"] = function(e)
			return e:GetIndex()--, e:GetColumn()
		end,
	}

	function on(obj, id, eType, cb)
		if type(id) == "string" then
			id, eType, cb = nil, id, eType
		end

		local k     = "wxEVT_"..eType
		local eCode = wx[k] or wxlua[k] or wxaui[k] or wxstc[k] or errorf("Unknown event type '%s'.", eType)

		local expander = eventExpanders[eType] or NOOP

		if id then
			obj:Connect(id, eCode, wrapCall(function(e)  cb(e, expander(e))  end))
		else
			obj:Connect(    eCode, wrapCall(function(e)  cb(e, expander(e))  end))
		end
	end
end

-- id = onAccelerator( wxObject, accelerators, modKeys, keyCode, onPress )
function onAccelerator(obj, accelerators, modKeys, kc, onPress)
	assertarg(1, obj,          "userdata")
	assertarg(2, accelerators, "table")
	assertarg(3, modKeys,      "string")
	assertarg(4, kc,           "number")
	assertarg(5, onPress,      "function")

	local id    = wx.wxNewId()
	local flags = 0

	if modKeys:find("a", 1, true) then  flags = flags+WX_ACCEL_ALT    end
	if modKeys:find("c", 1, true) then  flags = flags+WX_ACCEL_CTRL   end
	if modKeys:find("s", 1, true) then  flags = flags+WX_ACCEL_SHIFT  end

	on(obj, id, "COMMAND_MENU_SELECTED", onPress)
	table.insert(accelerators, {flags, kc, id})

	return id
end



function setAccelerators(window, accelerators)
	window:SetAcceleratorTable(wx.wxAcceleratorTable(accelerators))
end



do
	local dummyOwner = nil

	-- timer = newTimer( [ milliseconds, oneShot=false, ] callback )
	function newTimer(milliseconds, oneShot, cb)
		if type(milliseconds) ~= "number" then
			milliseconds, oneShot, cb = nil, milliseconds, oneShot
		end
		if type(oneShot) ~= "boolean" then
			oneShot, cb = false, oneShot
		end

		local timer = wx.wxTimer(dummyOwner)
		timer:SetOwner(timer)

		on(timer, "TIMER", cb)

		if milliseconds then
			timer:Start(milliseconds, oneShot)
		end

		return timer
	end

	function setTimerDummyOwner(obj)
		dummyOwner = obj
	end
end



function showMessage(window, caption, message)
	wx.wxMessageBox(message, caption, WX_OK + WX_ICON_INFORMATION + WX_CENTRE, window)
end

function showError(window, caption, message)
	wx.wxMessageBox(message, caption, WX_OK + WX_ICON_ERROR + WX_CENTRE, window)
end


