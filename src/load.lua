--[[============================================================
--=
--=  Initial Loading
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

package.cpath
	= "./bin/?.dll;"
	.."./bin/?51.dll;"

package.path
	= "./src/?.lua;"
	.."./lib/?.lua;"
	.."./lib/?/init.lua;"

_G.appZip = require"zip".open"app"

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

math.randomseed(require"socket".gettime()*1000)
math.random() -- Gotta kickstart the randomness.

io.stdout:setvbuf("no")
io.stderr:setvbuf("no")

require"globals"
require"functions"

wxPleaseJustStop = wxLogNull() -- Ugh.
