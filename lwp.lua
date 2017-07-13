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

function M.compile(tpl)
    local chunks = {}
    local out = {}

    local ostart, ostop = nil, 0
    local cstart, cstop = nil, 0

    while cstop ~= nil and cstop < #tpl do
        ostart = cstop + 1
        ostart, ostop = tpl:find('<%', ostart, true)
        local trim = false
        local mod = nil

        -- trailing text
        if not ostart then
            chunks[#chunks + 1] = { text = tpl:sub(cstop + 1, #tpl) }
            break
        end

        -- leading text
        if ostart > cstop + 1 then
            chunks[#chunks + 1] = { text = tpl:sub(cstop + 1, ostart - 1) }
        end

        -- pull modifiers
        if tpl:match('^[=-]', ostop + 1) then
            mod = tpl:sub(ostop + 1, ostop + 1)
            ostop = ostop + 1
        end

        -- find non-quoted closing tag
        repeat
            cstart = cstop + 1
            cstart, cstop = tpl:find('%>', cstart, true)
        until cstart == nil or not in_string(tpl, ostop + 1, cstart - 1)

        if cstart then
            -- pull postfix (trim) modifier (if not EOF)
            if tpl:sub(cstart - 1, cstart - 1) == '-' then
                cstart = cstart - 1
                trim = true
            end
        else
            -- allow EOF to close
            cstart = #tpl
        end

        chunks[#chunks + 1] = { code = tpl:sub(ostop + 1, cstart - 1), mod = mod, trim = trim }
    end

    local trim = false
    for i=1, #chunks do
        local chunk = chunks[i]

        if chunk.text and #chunk.text > 0 then
            if not trim and chunk.text:sub(1,1) == '\n' then
                out[#out + 1] = ';print();'
            end
            -- plain new lines are ignored anyway
            if (chunk.text ~= '\n') then
                out[#out + 1] = ';io.write(' .. quote(chunk.text) .. ');'
            end
            trim = false
        else
            if chunk.mod == '=' then
                out[#out + 1] = ';io.write(((' .. chunk.code .. '):gsub([=[["><\'&]]=],{["&"]="&amp;",["<"]="&lt;",[">"]="&gt;",["\\""]="&quot;",["\'"]="&#039;"})));'
            elseif chunk.mod == '-' then
                out[#out + 1] = ';io.write(' .. chunk.code .. ');'
            else
                out[#out + 1] = chunk.code
            end

            trim = chunk.trim
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
