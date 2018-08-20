--[[============================================================
--=
--=  EventQueue Class
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--==============================================================

	addEvent, addOrReplaceEvent, clearEvents
	events

--============================================================]]

local EventQueue = {
	theEvents = nil,
}
EventQueue.__index = EventQueue



--==============================================================
--==============================================================
--==============================================================



function EventQueue:init()
	self.theEvents = {}
end



function EventQueue:addEvent(eName, ...)
	assertarg(1, eName, "string")

	table.insert(self.theEvents, {eName, ...})
end

function EventQueue:addOrReplaceEvent(eName, ...)
	assertarg(1, eName, "string")

	local i = indexWith(self.theEvents, 1, eName)
	if i then
		self.theEvents[i] = {eName, ...}
	else
		table.insert(self.theEvents, {eName, ...})
	end
end

function EventQueue:clearEvents(eName)
	assertarg(1, eName, "string")

	for i, eventData in ipairsr(self.theEvents) do
		if eventData[1] == eName then
			table.remove(self.theEvents, i)
		end
	end
end



-- for eventName, value1, ... in events( ) do
function EventQueue:events()
	local es = self.theEvents
	return function()
		if isPaused() then  return  end
		if es[1]      then  return unpack(table.remove(es, 1))  end
	end
end



--==============================================================
--==============================================================
--==============================================================

return function(...)
	local queue = setmetatable({}, EventQueue)
	queue:init(...)
	return queue
end
