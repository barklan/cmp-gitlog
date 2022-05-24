local source = {}

source.new = function()
    local json_decode = vim.fn.json_decode
    return setmetatable({
        running_job_id = 0,
        timer = vim.loop.new_timer(),
        json_decode = json_decode,
    }, { __index = source })
end

source.complete = function(self, request, callback)
    local q = string.sub(request.context.cursor_before_line, request.offset)
    local pattern = request.option.pattern or ".+"
    local seen = {}
    local items = {}

    local function on_event(_, data, event)
        if event == "stdout" then
            for _, entry in ipairs(data) do
                if entry ~= "" then
                    local ok, result = pcall(self.json_decode, entry)
                    if
                        not ok
                        or result.type == "end"
                        or (
                            vim.tbl_contains(
                                { "context", "match" },
                                result.type
                            )
                            and not result.data.lines.text
                        )
                    then
                        do
                        end
                    elseif result.type == "match" then
                        local label = result.data.submatches[1].match.text
                        if label and not seen[label] then
                            local documentation = {}
                            local match_line = result.data.lines.text:gsub(
                                "\n",
                                ""
                            )
                            table.insert(documentation, match_line)
                            table.insert(items, {
                                label = label,
                                documentation = documentation,
                            })
                            seen[label] = true
                        end
                    end
                end
            end
            callback({ items = items, isIncomplete = true })
        end

        if event == "stderr" and request.option.debug then
            vim.cmd("echohl Error")
            vim.cmd('echomsg "' .. table.concat(data, "") .. '"')
            vim.cmd("echohl None")
        end

        if event == "exit" then
            callback({ items = items, isIncomplete = false })
        end
    end

    self.timer:stop()
    self.timer:start(
        request.option.debounce or 500,
        0,
        vim.schedule_wrap(function()
            vim.fn.jobstop(self.running_job_id)
            self.running_job_id = vim.fn.jobstart(
                string.format(
                    "git log -p --raw --no-indent-heuristic --word-diff=porcelain -n 50  -- %s | rg -r '$1' '^-(.+)' | rg -v --color never '(^-- [ab]/.+)|(^-- /dev/null)' | rg --heading --json --color never '%s%s'",
                    vim.fn.expand("%", nil, nil),
                    q,
                    pattern
                ),
                {
                    on_stderr = on_event,
                    on_stdout = on_event,
                    on_exit = on_event,
                    cwd = request.option.cwd or vim.fn.getcwd(),
                }
            )
        end)
    )
end

return source
