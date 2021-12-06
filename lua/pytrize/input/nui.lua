local M = {}
local handler = {}
local Menu
local event

M.load = function()
    local has_nui
    has_nui, Menu = pcall(require, "nui.menu")
    if has_nui then
        event = require("nui.utils.autocmd").event
        return handler
    else
        return nil
    end
end

handler.prompt_files = function(prompt, files)
    local lines = {}
    for file in ipairs(files) do
        table.insert(lines, Menu.item(file))
    end
    local choice
    local menu = Menu({
        relative = "cursor",
        position = {row=1, col=0},
        size = {
            width = 71,
            height = #files,
        },
        border = {
            highlight = "MyHighlightGroup",
            style = "rounded",
            text = {
                top = prompt,
                top_align = "center",
            },
        },
        win_options = {
            winblend = 10,
            winhighlight = "Normal:Normal",
        },
    }, {
        lines = lines,
        max_width = 100,
        separator = {
            char = "-",
            text_align = "right",
        },
        keymap = {
            focus_next = { "j", "<Down>", "<Tab>" },
            focus_prev = { "k", "<Up>", "<S-Tab>" },
            close = { "<Esc>", "<C-c>" },
            submit = { "<CR>", "<Space>" },
        },
        -- on_close = function()
        -- end,
        on_submit = function(item)
            choice = item.text
        end,
    })

    -- mount the component
    menu:mount()

    -- close menu when cursor leaves buffer
    menu:on(event.BufLeave, menu.menu_props.on_close, { once = true })

    return choice
end

return M
