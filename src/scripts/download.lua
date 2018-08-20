--[[============================================================
--=
--=  Download Script
--=
--=  Args: url pathToSaveRequestBodyTo
--=
--=  Outputs:
--=    :success
--=    <statusCode>
--=    <statusText>
--=
--=    <error>
--=
--=-------------------------------------------------------------
--=
--=  MyHappyList - manage your AniDB MyList
--=  - Written by Marcus 'ReFreezed' Thunström
--=  - MIT License (See main.lua)
--=
--============================================================]]

local url, path = unpack(args)
assert(url,  "no url")
assert(path, "no path")

local urlObj  = socket.url.parse(url)
local request = urlObj.scheme == "https" and require"ssl.https".request or socket.http.request

local headersToSend = {}
if isHost(urlObj.host, "github.com") then
	headersToSend["accept"] = "application/octet-stream"
end

local file = assert(openFile(path, "wb"))

local ok, statusCodeOrErr, headers, statusText = request{
	method  = "GET",
	url     = url,
	sink    = require"ltn12".sink.file(file),
	headers = headersToSend,
}

file:close()

ok = not not ok

if not ok then
	local err = statusCodeOrErr
	deleteFile(path) -- Could fail.
	errorf("Could not send request to '%s': %s", url, err)
end

local statusCode = statusCodeOrErr
print(":success")
print(statusCode)
print(statusText)
