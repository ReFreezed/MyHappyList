--[[============================================================
--=
--=  Initial Loading (assumes loadBasic has been loaded)
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

local ok, zipLib = pcall(require, "zip")
if ok then  _G.appZip = zipLib.open"app"  end

if appZip then
	table.insert(package.loaders, 1, function(moduleName)
		local modulePath = moduleName:gsub("%.", "/")

		for pathPat in package.path:gmatch"[^;]+" do
			local path = pathPat:gsub("%?", modulePath):gsub("^%./", "")
			local file = appZip:open(path)

			if file then
				file:close()

				return function()
					file = assert(appZip:open(path))

					local contents = file:read"*a"
					file:close()

					local chunk = assert(loadstring(contents, path))
					return chunk(moduleName)
				end
			end
		end
	end)
end

local ok, _socket = pcall(require, "socket")
math.randomseed(ok and _socket.gettime()*1000 or os.time())
math.random() -- Gotta kickstart the randomness.

require"globals"
require"functions"

if socket then
	socket.http.USERAGENT = "MyHappyList/"..APP_VERSION
end

wxPleaseJustStop = wxLogNull() -- Ugh.
