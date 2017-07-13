-- this was never finished, it's supposed to be a bootstrap for LWP

local vars = {
    'GATEWAY_INTERFACE',
    'SERVER_ADDR',
    'SERVER_NAME',
    'SERVER_SOFTWARE',
    'SERVER_PROTOCOL',
    'REQUEST_METHOD',
    'DOCUMENT_ROOT',
    'QUERY_STRING',
    'SCRIPT_NAME',
    'SCRIPT_FILENAME',
    'HTTP_HOST',
    'REMOTE_ADDR',
}

_GET = {}
_POST = {}

-- build _SERVER from env
_SERVER = {}
for i,k in ipairs(vars) do
    _SERVER[k] = os.getenv(k)
end

local path = _SERVER['SCRIPT_FILENAME']

package.path = package.path .. ';' .. _SERVER['DOCUMENT_ROOT'] .. '/?.lwp'

local f, e = loadfile(path, 't')

if not f then
    io.stderr:write('cgi.lua: failed to load script: ' .. tostring(e) .. '\n')
    return
end

io.write('Content-type: text/plain\r\n\r\n')
local ok, e = pcall(f)
if not ok then
    io.stderr:write('cgi.lua: failed to pcall script: ' .. tostring(e) .. '\n')
end
