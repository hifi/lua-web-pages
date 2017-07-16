-- FastCGI I/O redirection

return function (fcgi_read_stdin, fcgi_write_stdout, fcgi_write_stderr)
    -- prevent using real stdio handles
    io.stdin = {}
    io.stdout = {}
    io.stderr = {}

    setmetatable(io.stdin, io.stdin)
    setmetatable(io.stdout, io.stdout)
    setmetatable(io.stderr, io.stderr)

    io.stdin.read = function(...)
        if type(fmt) == 'number' then
            return fcgi_read_stdin(fmt)
        elseif fmt == 'a' then
            local t = {}
            local l

            repeat
                l = fcgi_read_stdin(4096)
                t[#t + 1] = l
            until l == '' 

            return table.concat(t)
        else
            error('io.read() currently does not support given format on CGI')
        end
    end

    io.stdout.write = function(...)
        for i=2, select('#', ...) do
            fcgi_write_stdout(select(i, ...))
        end
    end

    io.stderr.write = function(...)
        for i=2, select('#', ...) do
            fcgi_write_stderr(select(i, ...))
        end
    end

    io.input = function()
        return io.stdin
    end

    io.output = function()
        return io.stdout
    end

    io.lines = function()
        error('io.lines() is currently not supported on CGI')
    end

    io.read = function(fmt, ...)
        if type(fmt) == 'number' then
            return fcgi_read_stdin(fmt)
        elseif fmt == 'a' then
            local t = {}
            local l

            repeat
                l = fcgi_read_stdin(4096)
                t[#t + 1] = l
            until l == '' 

            return table.concat(t)
        else
            error('io.read() currently does not support given format on CGI')
        end
    end

    io.write = function(...)
        for i=1, select('#', ...) do
            fcgi_write_stdout(select(i, ...))
        end
    end

    print = function(...)
        for i=1, select('#', ...) do
            if i > 1 then
                fcgi_write_stdout("\t")
            end
            fcgi_write_stdout(tostring(select(i, ...)))
        end

        fcgi_write_stdout("\n")
    end
end
