-- this is mostly based on ideas from etlua but works a bit differently
local M = {}

-- shamelessly as-is from compiled etlua MoonScript, needs a rewrite in pure Lua
local in_string = function(str, start, stop)
  local in_string = false
  local end_delim = nil
  local escape = false
  local pos = 0
  local skip_until = nil
  local chunk = str:sub(start, stop)
  for char in chunk:gmatch(".") do
    local _continue_0 = false
    repeat
      pos = pos + 1
      if skip_until then
        if pos <= skip_until then
          _continue_0 = true
          break
        end
        skip_until = nil
      end
      if end_delim then
        if end_delim == char and not escape then
          in_string = false
          end_delim = nil
        end
      else
        if char == "'" or char == '"' then
          end_delim = char
          in_string = true
        end
        if char == "[" then
          do
            local lstring = chunk:match("^%[=*%[", pos)
            if lstring then
              local lstring_end = lstring:gsub("%[", "]")
              local lstring_p1, lstring_p2 = chunk:find(lstring_end, pos, true)
              if not (lstring_p1) then
                return true
              end
              skip_until = lstring_p2
            end
          end
        end
      end
      escape = char == "\\"
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  return in_string
end

-- quotes a multi-line string for inlining in Lua code
local function quote(s)
    local c = '='
    local rep = 0
    local sq, eq

    repeat
        sq = '[' .. c:rep(rep) .. '['
        eq = ']' .. c:rep(rep) .. ']'
        rep = rep + 1
    until s:find(eq, 1, true) == nil

    return sq .. s .. eq
end

local htmlents = {
    ['&'] = '&amp;',
    ['<'] = '&lt;',
    ['>'] = '&gt;',
    ['"'] = '&quot;',
    ["'"] = '&#039;'
}

function _htmlescape(s)
    s:gsub([=[["><'&]]=], ents)
end

function M.compile(tpl)
    local chunks = {}
    local start, stop, trim, mod
    local p = 1
    local out = {}

    while p < #tpl do
        start, stop = tpl:find('<%', p, true)
        trim = false
        mod = nil

        -- trailing text
        if not start then
            chunks[#chunks + 1] = { text = tpl:sub(p, #tpl) }
            break
        end

        -- leading text
        if start ~= p then
            chunks[#chunks + 1] = { text = tpl:sub(p, start - 1) }
        end

        p = stop + 1

        -- pull modifiers
        if tpl:match('^[=-]', p) then
            mod = tpl:sub(p, p)
            p = p + 1
        end

        -- find non-quoted closing tag
        repeat
            start, stop = tpl:find('%>', p, true)
        until start == nil or not in_string(tpl, p, start)

        -- pull postfix (trim) modifier
        if tpl:sub(start - 1, start - 1) == '-' then
            start = start - 1
            trim = true
        end

        chunks[#chunks + 1] = { code = tpl:sub(p, start - 1), mod = mod, trim = trim }
        p = stop + 1
    end

    for i=1, #chunks do
        local chunk = chunks[i]

        if chunk.text and #chunk.text > 0 then
            out[#out + 1] = ';io.write(' .. quote(chunk.text) .. ');'
        else
            -- FIXME: trim is currently ignored
            if chunk.mod == '=' then
                out[#out + 1] = ';io.write(' .. chunk.code:gsub([=[["><'&]]=], htmlents) .. ');'
            elseif chunk.mod == '-' then
                out[#out + 1] = ';io.write(' .. chunk.code .. ');'
            else
                out[#out + 1] = chunk.code
            end
        end
    end

    return table.concat(out)
end

function M.loadfile(tpl, env)
    local fh, err = io.open(tpl, 'rb')

    if not fh then
        return nil, err
    end

    local tpl = fh:read('a')
    fh:close()

    return load(M.compile(tpl), 'template', 't', env or _ENV)
end

function M.include(tpl, env)
    return M.load(tpl, env)()
end

return M
