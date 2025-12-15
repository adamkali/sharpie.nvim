-- Symbol utility functions for sharpie.nvim
-- Provides enhanced symbol detection and categorization

local M = {}

-- Extract the generic type from Task<T>, ValueTask<T>, etc.
function M.extract_task_generic_type(detail)
    if not detail then
        return nil
    end

    -- Match Task<Type> or ValueTask<Type>
    local generic_type = detail:match("Task%s*<%s*([^>]+)%s*>")
    if not generic_type then
        generic_type = detail:match("ValueTask%s*<%s*([^>]+)%s*>")
    end

    return generic_type
end

-- Check if a symbol returns a Task type (async method)
function M.returns_task(symbol)
    if not symbol.detail then
        return false
    end

    local detail = symbol.detail

    -- Check for Task, Task<T>, ValueTask, ValueTask<T>
    if detail:match("Task%s*<") or detail:match("Task%s*$") or
       detail:match("ValueTask%s*<") or detail:match("ValueTask%s*$") then
        return true
    end

    -- Check for async keyword (methods declared with async usually return Task)
    if detail:match("%s*async%s+") then
        return true
    end

    return false
end

-- Check if a symbol is a class or object type
function M.is_class_or_object(symbol)
    local kind = symbol.kind
    if type(kind) == "string" then
        kind = kind:lower()
        return kind == "class" or kind == "object" or kind == "struct" or kind == "interface"
    end
    return false
end

-- Map C# type name to icon type
function M.map_type_to_icon_key(type_name)
    if not type_name then
        return "task"
    end

    -- Remove whitespace and make lowercase for comparison
    local clean_type = type_name:gsub("%s+", ""):lower()

    -- Primitive types
    if clean_type == "int" or clean_type == "int32" or clean_type == "int64" or
       clean_type == "long" or clean_type == "short" or clean_type == "byte" or
       clean_type == "uint" or clean_type == "ulong" or clean_type == "ushort" then
        return "integer"
    elseif clean_type == "string" then
        return "string"
    elseif clean_type == "bool" or clean_type == "boolean" then
        return "boolean"
    elseif clean_type == "float" or clean_type == "double" or clean_type == "decimal" then
        return "number"
    elseif clean_type == "void" then
        return "void"
    -- Collection types
    elseif clean_type:match("^list<") or clean_type:match("^ienumerable<") or
           clean_type:match("^icollection<") or clean_type:match("%[%]$") then
        return "array"
    elseif clean_type:match("^dictionary<") or clean_type:match("^idictionary<") then
        return "dictionary"
    -- Object types
    else
        -- Anything else is likely a class/object
        return "class"
    end
end

-- Get the appropriate icon for a symbol, considering special cases
function M.get_symbol_icon(symbol, config)
    -- Special case: Task return types
    if M.returns_task(symbol) then
        -- Extract the generic type from Task<T>
        local generic_type = M.extract_task_generic_type(symbol.detail)

        if generic_type then
            -- Map the generic type to an icon
            local icon_key = M.map_type_to_icon_key(generic_type)
            local icon = config.style.icon_set[icon_key]

            if icon then
                return icon
            end
        end

        -- Fallback to task icon for non-generic Task or if we couldn't determine type
        return config.style.icon_set.task or "⏳"
    end

    -- Special case: If kind is unclear but it's class-like, use class icon
    if symbol.kind and (symbol.kind:lower() == "object" or symbol.kind:lower() == "unknown") then
        if symbol.detail and (
            symbol.detail:match("class") or
            symbol.detail:match("interface") or
            symbol.detail:match("struct")
        ) then
            return config.style.icon_set.class or ""
        end
    end

    -- Default: use the kind-based icon
    return require('sharpie.config').get_icon(symbol.kind)
end

-- Parse return type from method detail
function M.get_return_type(symbol)
    if not symbol.detail then
        return nil
    end

    -- Try to extract return type from detail
    -- Common patterns:
    -- "public Task<User> GetUserAsync()"
    -- "private async Task DoSomethingAsync()"
    -- "public string GetName()"

    local detail = symbol.detail

    -- Remove access modifiers and async keyword
    detail = detail:gsub("^%s*public%s+", "")
    detail = detail:gsub("^%s*private%s+", "")
    detail = detail:gsub("^%s*protected%s+", "")
    detail = detail:gsub("^%s*internal%s+", "")
    detail = detail:gsub("^%s*async%s+", "")
    detail = detail:gsub("^%s*static%s+", "")
    detail = detail:gsub("^%s*virtual%s+", "")
    detail = detail:gsub("^%s*override%s+", "")

    -- Extract the return type (first word/type before the method name)
    local return_type = detail:match("^([^%s%(]+)")

    return return_type
end

-- Check if a return type is a known Task type
function M.is_task_type(return_type)
    if not return_type then
        return false
    end

    return return_type:match("^Task") or
           return_type:match("^ValueTask") or
           return_type:match("^IAsyncEnumerable")
end

return M
