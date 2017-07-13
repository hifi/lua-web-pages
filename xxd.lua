#!/bin/lua

-- portable and slow xxd for embedding luac output

local fh

if #arg < 1 then
    io.stderr:write('usage: xxd.lua <var>\n')
    return 1
end

print('unsigned char ' .. arg[1] .. '[] = {')

local i = 0

while true do
    local c = io.stdin:read(1)
    if c == nil then
        break
    end

    if i > 0 then
        io.write(', ')
    end

    io.write(string.format('0x%02x', string.byte(c)))

    i = i + 1
end

print('};')
print('unsigned int ' .. arg[1] .. '_len = ' .. i .. ';')
