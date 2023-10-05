local mp = require 'mp'
local utils = require 'mp.utils'
local script_name = mp.get_script_name()

-- split str into a table
-- example: local t = split(s, "\n")
-- plain: whether pat is a plain string (default false - pat is a pattern)
local function split(str, pat, plain)
    local init = 1
    local r, i, find, sub = {}, 1, string.find, string.sub
    repeat
        local f0, f1 = find(str, pat, init, plain)
        r[i], i = sub(str, init, f0 and f0 - 1), i + 1
        init = f0 and f1 + 1 or 0
    until f0 == nil
    return r
end

local function get_current_subtitle()
    local start = mp.get_property_number('sub-start')
    local stop = mp.get_property_number('sub-end')
    local text = mp.get_property('sub-text')
    local lines = text and text:match('^[%s\n]*(.-)[%s\n]*$') or ''
    return start, stop, text, split(lines, '\n', true)
end

local function same_time(t1, t2)
    return math.abs(t1 - t2) < 0.01
end

---Merge lines with already collected subtitles
---returns lines that haven't been merged
---@param subtitles {start:number;stop:number;line:string}[]
---@param start number
---@param stop number
---@param lines string[]
---@return string[]
local function merge_subtitle_lines(subtitles, start, stop, lines)
    -- merge identical lines that are right after each other
    local merged_line_pos = {}
    for _, subtitle in ipairs(subtitles) do
        if same_time(subtitle.stop, start) then
            for l, line in ipairs(lines) do
                if line == subtitle.line then
                    merged_line_pos[#merged_line_pos + 1] = l
                    if start < subtitle.start then subtitle.start = start end
                    if stop > subtitle.stop then subtitle.stop = stop end
                end
            end
            for j = #merged_line_pos, 1, -1 do
                table.remove(lines, merged_line_pos[j])
                merged_line_pos[j] = nil
            end
        end
    end
    return lines
end

---Get lines form current subtitle track
---@return {start:number;stop:number;line:string}[]
local function acquire_subtitles()
    local sub_delay = mp.get_property_number('sub-delay')
    local sub_visibility = mp.get_property_bool('sub-visibility')
    mp.set_property_bool('sub-visibility', false)

    -- ensure we're at some subtitle
    mp.commandv('sub-step', 1, 'primary')
    mp.commandv('sub-step', -1, 'primary')

    -- find first one
    local start_time = mp.get_property_number('sub-start')
    local old_start_time = start_time
    local retry = 0
    -- if we're not at the very beginning
    -- this missies the first subtitle for some reason
    repeat
        mp.commandv('sub-step', -1, 'primary')
        old_start_time = start_time
        start_time = mp.get_property_number('sub-start')
        if old_start_time == start_time then retry = retry + 1
        else retry = 0 end
    until retry > 10

    ---@type {start:number;stop:number;line:string}[]
    local subtitles = {}
    local i = 0
    local prev_start = -1
    local prev_stop = -1
    local prev_text = nil

    retry = 0
    repeat
        local start, stop, text, lines = get_current_subtitle()
        mp.commandv('sub-step', 1, 'primary')
        if start and (text ~= prev_text or not same_time(start, prev_start) or not same_time(stop, prev_stop)) then
            -- remove empty lines
            for j = #lines, 1, -1 do
                if not lines[j]:find('[^%s]') then
                    table.remove(lines, j)
                end
            end
            if #lines > 0 then
                lines = merge_subtitle_lines(subtitles, start, stop, lines)
                for _, line in ipairs(lines) do
                    i = i + 1
                    subtitles[i] = { start = start, stop = stop, line = line }
                end
            end
            prev_start = start
            prev_stop = stop
            prev_text = text
            retry = 0
        else
            retry = retry + 1
        end
    until retry > 10

    mp.set_property_number('sub-delay', sub_delay)
    mp.set_property_bool('sub-visibility', sub_visibility)
    return subtitles
end

local function show_loading_indicator()
    local menu = {
        title = 'Subtitle lines',
        items = { {
            title = 'Loading...',
            icon = 'spinner',
            italic = true,
            muted = true,
            selectable = false,
            value = 'ignore',
        } },
        type = 'subtitle-lines-loading',
    }

    local json = utils.format_json(menu)
    mp.commandv('script-message-to', 'uosc', 'open-menu', json)
end

local menu_open = false
local function show_subtitle_list(subtitles)
    local menu = {
        title = 'Subtitle lines',
        items = {},
        type = 'subtitle-lines-list',
        on_close = {
            'script-message-to',
            script_name,
            'uosc-menu-closed',
        }
    }

    local time = mp.get_property_number('time-pos')
    for _, subtitle in ipairs(subtitles) do
        menu.items[#menu.items + 1] = {
            title = subtitle.line,
            hint = mp.format_time(subtitle.start) .. '-' .. mp.format_time(subtitle.stop),
            active = subtitle.start <= time and time <= subtitle.stop,
            value = {
                'seek',
                subtitle.start,
                'absolute+exact',
            }
        }
    end

    local json = utils.format_json(menu)
    if menu_open then mp.commandv('script-message-to', 'uosc', 'update-menu', json)
    else mp.commandv('script-message-to', 'uosc', 'open-menu', json) end
    menu_open = true
end


---@type {start:number;stop:number;line:string}[]|nil
local subtitles = nil

local function sub_text_update()
    show_subtitle_list(subtitles)
end

mp.add_key_binding(nil, 'list_subtitles', function()
    if menu_open then
        mp.commandv('script-message-to', 'uosc', 'close-menu', 'subtitle-lines-list')
        return
    end

    show_loading_indicator()

    if not subtitles or true then
        subtitles = acquire_subtitles()
    end

    mp.observe_property('sub-text', 'string', sub_text_update)
end)

mp.register_script_message('uosc-menu-closed', function()
    subtitles = nil
    menu_open = false
    mp.unobserve_property(sub_text_update)
end)

mp.register_event('end-file', function()
    subtitles = nil
end)
