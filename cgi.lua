-- in-progress CGI bootstrap

cgi = {}

local vars = {
    'GATEWAY_INTERFACE',
    'SERVER_NAME',
    'SERVER_SOFTWARE',
    'SERVER_PROTOCOL',
    'SERVER_PORT',
    'REQUEST_METHOD',
    'PATH_INFO',
    'SCRIPT_NAME',
    'SCRIPT_FILENAME', -- FastCGI
    'QUERY_STRING',
    'REMOTE_HOST',
    'REMOTE_ADDR',
    'DOCUMENT_ROOT',
    'CONTENT_TYPE',
    'CONTENT_LENGTH',
    'HTTP_HOST',
    'HTTP_ACCEPT',
    'HTTP_USER_AGENT',
    'HTTP_REFERER',
}

cgi.urldecode = function(s)
    return (s:gsub('+', ' '):gsub('%%(%x%x)', function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

-- XXX: handle nesting[][]
cgi.parsequery = function(qs)
    local ret = {}

    for frag in qs:gmatch('[^&]+') do
        local k,v = frag:match('([^=]+)=(.*)')
        ret[k] = cgi.urldecode(v)
    end

    return ret
end

cgi.env = {}
for i,k in ipairs(vars) do
    cgi.env[k] = os.getenv(k)
end

cgi.get = cgi.parsequery(cgi.env['QUERY_STRING'] or '')

-- parse POST if it's in the correct format
if cgi.env['REQUEST_METHOD'] == 'POST' and cgi.env['CONTENT_TYPE'] == 'application/x-www-form-urlencoded' then
    cgi.post = cgi.parsequery(io.read('a'))
else
    cgi.post = {}
end

local normalize_header = function(name)
    local parts = {}

    for p in name:gmatch('[^-]+') do
        parts[#parts + 1] = p:sub(1, 1):upper() .. p:sub(2):lower()
    end

    return table.concat(parts, '-')
end

cgi.self = cgi.env['SCRIPT_FILENAME'] or ''
cgi.basename = (cgi.self:match('([^/]+)$')) or ''
cgi.basedir = (cgi.self:match('(.*)/[^/]+$')) or ''

cgi.headers = { }
local headers_order = {}

setmetatable(cgi.headers, {
    __index = function(t,k)
        return t[normalize_header(k)]
    end,

    __newindex = function(t,k,v)
        local k = normalize_header(k)
        if rawget(t, k) == nil then
            headers_order[#headers_order + 1] = k
        end
        return rawset(t, k, v)
    end,

    __tostring = function(t)
        local ret = {}

        for i,k in ipairs(headers_order) do
            ret[#ret + 1] = k .. ': ' .. tostring(rawget(t, k)) .. '\r\n'
        end

        return table.concat(ret) .. '\r\n'
    end
})


local _write = io.write
local _swrite = io.stdout.write
local _print = print

local headers_sent = false
local function send_headers()
    if not headers_sent then
        _write(tostring(cgi.headers))
        headers_sent = true
    end
end

-- hook io.write, io.stdout:write and print for sending headers
io.stdout.write = function(...)
    send_headers()
    _swrite(...)
end

io.write = function(...)
    send_headers()
    return _write(...)
end

print = function(...)
    send_headers()
    return _print(...)
end

-- default headers
cgi.headers['Status'] = 200
cgi.headers['Content-Type'] = 'text/html'

-- always push the script directory into path
package.path = package.path .. ';' .. cgi.basedir .. '/?.lua;' .. cgi.basedir .. '/?.lwp'

local f, e = loadfile(cgi.self)

if f then
    local ok, e = pcall(f)

    if not ok then
        cgi.headers['Status'] = 500
        io.stderr:write('CGI: failed to pcall script: ' .. tostring(e) .. '\n')
    end
else
    cgi.headers['Status'] = 500
    io.stderr:write('CGI: failed to load script: ' .. tostring(e) .. '\n')
end

-- if we had no output, send headers anyway
send_headers()
