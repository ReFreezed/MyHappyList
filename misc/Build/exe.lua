local function getExeFolderPath()
	for pathTemplate in package.cpath:gmatch"[^;]+" do
		pathTemplate = pathTemplate:gsub("\\", "/")

		if not pathTemplate:find"^%./" then
			-- Assume the first path here is something like "X:\Whatever\MyHappyList\?.dll".
			local dir, gsubCount = pathTemplate:gsub("/%?%.dll$", "")

			if gsubCount == 0 then
				return nil, "package.cpath contains an unexpected first path template."
			end

			return dir
		end
	end

	return nil, "package.cpath contains unexpected path templates."
end

-- DIR_EXE tries to solve CWD being "C:/Windows" if the 'Open' button is used in Windows Explorer.
DIR_EXE = assert(getExeFolderPath())

--[=[
os.execute([[echo "%cd%">C:\lua_cd.txt]])
local file = assert(io.open("C:/lua_path.txt", "w"))
file:write("relpath ", package.relpath, "\n")
file:write("path    ", package.path,    "\n")
file:write("cpath   ", package.cpath,   "\n")
file:write("DIR_EXE ", DIR_EXE,         "\n")
file:close()
--]=]

args = {...}
require"main"
