--[[============================================================
--=
--=  Get Latest Version Number Script
--=
--=  Args: none
--=
--=  Outputs:
--=    :version
--=    <version>
--=    <downloadUrl>
--=
--=    :error_request
--=    <errorMessage>
--=
--=    :error_http
--=    <statusCode>
--=    <statusText>
--=
--=    :error_malformed_response
--=    <errorMessage>
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

local t = {}

local ok, statusCodeOrErr, headers, statusText = require"ssl.https".request{
	method  = "GET",
	url     = "https://api.github.com/repos/ReFreezed/MyHappyList/releases/latest",
	sink    = require"ltn12".sink.table(t),
	headers = {
		["accept"] = "application/vnd.github.v3+json",
	},
}

ok = not not ok

if not ok then
	print(":error_request")
	print(statusCodeOrErr)
	os.exit(1)
end
if statusCodeOrErr ~= 200 then
	print(":error_http")
	print(statusCodeOrErr)
	print(statusText)
	os.exit(1)
end

local ok, responseOrErr = pcall(require"json".decode, table.concat(t))

if not ok then
	print(":error_malformed_response")
	print(responseOrErr)
	os.exit(1)
end

local response = responseOrErr
if type(response) ~= "table" then
	print(":error_malformed_response")
	os.exit(1)
end

local version     = tablePathGet(response, "tag_name")
local downloadUrl = tablePathGet(response, "assets", 1, "url")

if not (version and downloadUrl) then
	print(":error_malformed_response")
	os.exit(1)
end

print(":version")
print(version)
print(downloadUrl)
