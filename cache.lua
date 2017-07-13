--
-- Lua bytecode compiler and cache
--

local M = {}
local cache = {}

local open = io.open
local dump = string.dump
local time = os.time
local loadstring = loadstring or load -- Lua 5.1 compat

M.loadfile = function (filename, tag, modname)
    tag = tag or ''
    modname = modname or filename:match('([^\\/]+)$')

    if cache[tag] and cache[tag][modname] then
        return cache[tag][modname].func
    end

    local fh = open(filename, 'rb')
    if fh then
        local s = fh:read('*a')
        fh:close()

        if lwp and filename:match('.lwp$') then
            print('Cache: detected Lua Web Pages file, pre-processing')
            local success
            success, s = pcall(lwp.compile, s)
            if not success then
                print('Cache: failed to compile LWP: ' .. s)
                return nil, e
            end
        else
            -- comment shebang if exists
            s = s:gsub('^#!', '-- #!', 1)
        end

        local f,e = loadstring(s, modname)
        if f then
            print('Cache: +' .. tag .. '[' .. modname .. ']')
            cache[tag] = cache[tag] or {}
            cache[tag][modname] = {
                func = dump(f),
                time = time()
            }
            return cache[tag][modname].func
        end

        return nil, e
    end 

    return nil, 'Failed to open "' .. filename .. '" for reading'
end

M.load = function (modname, paths, tag, strip)
    tag = tag or ''

    if cache[tag] and cache[tag][modname] then
        return cache[tag][modname].func
    end

    paths = paths or package.path

    if not cache[tag] or not cache[tag][modname] then
        local t = paths:gsub('?', (modname:gsub('%.', '/'))):gmatch('[^;]+')

        for path in t do
            local fh = open(path, 'rb')
            if fh then
                fh:close()
                return M.loadfile(path, tag, modname) 
            end
        end
    end
end

M.gc = function(timeout)
    local now = time()

    for tag,mods in pairs(cache) do
        for modname,entry in pairs(mods) do
            if entry.time + timeout < now then
                print('Cache: -' .. tag .. '[' .. modname .. ']')
                mods[modname] = nil
            end
        end
    end
end

return M
