local M = {}
local vim = vim

local function send_to_socket(timeout)
    if timeout > 1000 then
        error("Can't connect to crabix_desktop")
    end

    local lines = vim.api.nvim_buf_get_lines(0, 0, -1, true)
    local success, chan = pcall(vim.api.nvim_call_function, 'sockconnect', { 'pipe', '/tmp/crabix' })
    if not success then
        vim.defer_fn(function() send_to_socket(timeout + 50) end, 50)
        return
    end

    local cursor_line_number = vim.fn.line('.')
    lines[1] = cursor_line_number .. " " .. lines[1]
    vim.api.nvim_call_function('chansend', { chan, lines })
    vim.api.nvim_call_function('chanclose', { chan })
end

local function interval_callback()
    send_to_socket(0)
end

local previous_time_render = vim.loop.now()
local interval_timer = vim.loop.new_timer()
local function send_text_to_preview()
    local t = vim.loop.now();
    local diff = t - previous_time_render;
    if diff > 300 then
        send_to_socket(0)
        previous_time_render = t;
        interval_timer:stop()
    else
        interval_timer:start(300, 0, vim.schedule_wrap(interval_callback))
    end
end

local job_id = nil
local function stop_crabix_desktop()
    local group = vim.api.nvim_create_augroup("crabix_desktop", {
        clear = true
    })
    vim.api.nvim_del_augroup_by_id(group)

    if job_id ~= nil then
        vim.fn.jobstop(job_id)
        job_id = nil
    end
end

local function start_crabix_desktop()
    local cmd = "crabix_desktop"
    job_id = vim.fn.jobstart(cmd, { on_exit = stop_crabix_desktop })
    send_text_to_preview()
end

M.markdown_preview = function()
    if job_id ~= nil then
        print("Buffer is already previewing o_O")
    end

    start_crabix_desktop()
    local current_buf = vim.api.nvim_get_current_buf()

    -- When I'll make comunication by RPC
    -- I expected to have at least two different endpoint:
    -- 1. Just scroll to content
    -- 2. Render and scroll

    -- vim.api.nvim_create_autocmd("TextChanged", {
    --     buffer = current_buf,
    --     callback = send_text_to_preview,
    -- })
    -- vim.api.nvim_create_autocmd("TextChangedI", {
    --     buffer = current_buf,
    --     callback = send_text_to_preview,
    -- })
    -- vim.api.nvim_create_autocmd("TextChangedP", {
    --     buffer = current_buf,
    --     callback = send_text_to_preview,
    -- })

    local group = vim.api.nvim_create_augroup("crabix_desktop", {
        clear = true
    })

    vim.api.nvim_create_autocmd("CursorMoved", {
        group = group,
        buffer = current_buf,
        callback = send_text_to_preview,
    })

    vim.api.nvim_create_autocmd("CursorMovedI", {
        group = group,
        buffer = current_buf,
        callback = send_text_to_preview,
    })

    vim.api.nvim_create_autocmd("BufWinLeave ", {
        group = group,
        buffer = current_buf,
        callback = stop_crabix_desktop,
    })
end

return M

