-- Go language handler for sharpie.nvim
-- Provides Go-specific symbol detection and type handling

local M = {}

-- Map Go type name to icon type
function M.map_type_to_icon_key(type_name)
    if not type_name then
        return "object"
    end

    -- Remove whitespace and make lowercase for comparison
    local clean_type = type_name:gsub("%s+", ""):lower()

    -- Remove pointer indicator for type matching
    clean_type = clean_type:gsub("^%*+", "")

    -- Integer types
    if clean_type == "int" or clean_type == "int8" or clean_type == "int16" or
       clean_type == "int32" or clean_type == "int64" or
       clean_type == "uint" or clean_type == "uint8" or clean_type == "uint16" or
       clean_type == "uint32" or clean_type == "uint64" or
       clean_type == "byte" or clean_type == "rune" then
        return "integer"
    -- Floating point types
    elseif clean_type == "float32" or clean_type == "float64" then
        return "number"
    -- String type
    elseif clean_type == "string" then
        return "string"
    -- Boolean type
    elseif clean_type == "bool" then
        return "boolean"
    -- Slice types
    elseif clean_type:match("^%[%]") then
        return "go_slice"
    -- Array types
    elseif clean_type:match("^%[%d+%]") then
        return "array"
    -- Map types
    elseif clean_type:match("^map%[") then
        return "go_map"
    -- Channel types
    elseif clean_type:match("chan") then
        return "go_channel"
    -- Interface types
    elseif clean_type == "interface{}" or clean_type == "any" then
        return "go_interface"
    -- Error type
    elseif clean_type == "error" then
        return "go_error"
    -- Struct or custom types
    else
        return "go_struct"
    end
end

-- Parse channel direction from type
-- Returns: "send", "receive", "bidirectional", or nil
function M.get_channel_direction(type_str)
    if not type_str then
        return nil
    end

    -- Check for send-only channel: chan<- Type
    if type_str:match("chan%s*<%-%s") then
        return "send"
    end

    -- Check for receive-only channel: <-chan Type
    if type_str:match("<%-%s*chan%s") then
        return "receive"
    end

    -- Check for bidirectional channel: chan Type
    if type_str:match("chan%s") then
        return "bidirectional"
    end

    return nil
end

-- Check if symbol is exported (starts with uppercase)
function M.is_exported(symbol_name)
    if not symbol_name then
        return false
    end

    local first_char = symbol_name:sub(1, 1)
    return first_char == first_char:upper() and first_char ~= first_char:lower()
end

-- Extract method receiver from detail string
-- Example: "func (r *Receiver) Method()" -> { name = "r", type = "*Receiver" }
function M.get_method_receiver(symbol)
    if not symbol.detail then
        return nil
    end

    local detail = symbol.detail

    -- Match pattern: func (receiver Type) or func (receiver *Type)
    local receiver_name, receiver_type = detail:match("func%s+%((%w+)%s+(%*?%w+)%)")

    if receiver_name and receiver_type then
        return {
            name = receiver_name,
            type = receiver_type,
            is_pointer = receiver_type:match("^%*") ~= nil
        }
    end

    return nil
end

-- Parse return types from Go function signature
-- Handles multiple return values: (Type1, Type2, error)
function M.get_return_types(symbol)
    if not symbol.detail then
        return nil
    end

    local detail = symbol.detail

    -- Match return types after closing parenthesis of parameters
    -- Pattern 1: func Name() Type
    local single_return = detail:match("%)%s+([^%s{]+)")
    if single_return and not single_return:match("^%(") then
        return { single_return }
    end

    -- Pattern 2: func Name() (Type1, Type2, error)
    local multiple_returns = detail:match("%)%s+%(([^)]+)%)")
    if multiple_returns then
        local types = {}
        for type_str in multiple_returns:gmatch("[^,]+") do
            table.insert(types, vim.trim(type_str))
        end
        return types
    end

    return nil
end

-- Check if function returns error as last return value
function M.returns_error(symbol)
    local return_types = M.get_return_types(symbol)
    if not return_types or #return_types == 0 then
        return false
    end

    local last_type = return_types[#return_types]
    return last_type == "error"
end

-- Check if symbol is likely used with goroutines
-- (This is heuristic-based since LSP doesn't directly tell us)
function M.is_goroutine_func(symbol)
    if not symbol.name then
        return false
    end

    local name_lower = symbol.name:lower()

    -- Common patterns in goroutine function names
    local goroutine_patterns = {
        "^run",
        "^start",
        "^worker",
        "^process",
        "^handle",
        "async$",
        "background$",
        "goroutine",
    }

    for _, pattern in ipairs(goroutine_patterns) do
        if name_lower:match(pattern) then
            return true
        end
    end

    return false
end

-- Check if symbol is an interface
function M.is_interface(symbol)
    if not symbol.kind then
        return false
    end

    local kind = type(symbol.kind) == "string" and symbol.kind:lower() or ""
    return kind == "interface"
end

-- Check if symbol is a struct
function M.is_struct(symbol)
    if not symbol.kind then
        return false
    end

    local kind = type(symbol.kind) == "string" and symbol.kind:lower() or ""
    return kind == "struct"
end

-- Get the appropriate icon for a Go symbol
function M.get_symbol_icon(symbol, config)
    local icon_set = config.style.icon_set

    -- Special case: Interfaces
    if M.is_interface(symbol) then
        return icon_set.go_interface or icon_set.interface or ""
    end

    -- Special case: Structs
    if M.is_struct(symbol) then
        return icon_set.go_struct or icon_set.struct or ""
    end

    -- Special case: Functions that return error
    if M.returns_error(symbol) then
        local return_types = M.get_return_types(symbol)
        if return_types and #return_types > 1 then
            -- Map the first return type to an icon
            local icon_key = M.map_type_to_icon_key(return_types[1])
            local icon = icon_set[icon_key]
            if icon then
                return icon
            end
        end
    end

    -- Special case: Channel types
    if symbol.detail and symbol.detail:match("chan") then
        return icon_set.go_channel or "󰘖"
    end

    -- Default: use the kind-based icon
    return require('sharpie.config').get_icon(symbol.kind)
end

-- Get Go-specific indicators for a symbol
function M.get_indicators(symbol)
    local indicators = {}

    if not symbol.detail and not symbol.name then
        return indicators
    end

    -- Check for exported/unexported
    if symbol.name and not M.is_exported(symbol.name) then
        table.insert(indicators, "")  -- Lock icon for unexported
    end

    -- Check for method receiver (methods vs functions)
    local receiver = M.get_method_receiver(symbol)
    if receiver then
        if receiver.is_pointer then
            table.insert(indicators, "")  -- Pointer receiver
        end
    end

    -- Check for goroutine-related functions
    if M.is_goroutine_func(symbol) then
        table.insert(indicators, "󰟓")  -- Goroutine indicator
    end

    -- Check for channel direction
    if symbol.detail then
        local chan_dir = M.get_channel_direction(symbol.detail)
        if chan_dir == "send" then
            table.insert(indicators, "")  -- Send-only channel
        elseif chan_dir == "receive" then
            table.insert(indicators, "")  -- Receive-only channel
        elseif chan_dir == "bidirectional" then
            table.insert(indicators, "󰘖")  -- Bidirectional channel
        end
    end

    -- Check for error returns
    if M.returns_error(symbol) then
        table.insert(indicators, "")  -- Warning for error returns
    end

    return indicators
end

-- Format method receiver for display
function M.format_receiver(receiver)
    if not receiver then
        return ""
    end

    return string.format("(%s %s)", receiver.name, receiver.type)
end

return M
