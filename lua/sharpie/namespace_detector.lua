-- Namespace and package detection for sharpie.nvim
local M = {}

local logger = require('sharpie.logger')

-- Main dispatcher for namespace detection
-- @param bufnr number: Buffer number
-- @param language_config table: Language configuration from language.detect_language()
-- @return string|nil: Detected namespace/package name or nil if not found
function M.detect_namespace(bufnr, language_config)
    if not language_config then
        logger.warn("namespace_detector", "No language config provided")
        return nil
    end

    logger.debug("namespace_detector", "Detecting namespace", {
        language = language_config.name,
        bufnr = bufnr
    })

    if language_config.name == "csharp" then
        -- Try treesitter first, fall back to regex
        local namespace = M.detect_csharp_namespace_treesitter(bufnr)
        if namespace then
            logger.info("namespace_detector", "Detected C# namespace via treesitter", { namespace = namespace })
            return namespace
        end

        namespace = M.detect_csharp_namespace_regex(bufnr)
        if namespace then
            logger.info("namespace_detector", "Detected C# namespace via regex", { namespace = namespace })
            return namespace
        end
    elseif language_config.name == "go" then
        local package = M.detect_go_package(bufnr)
        if package then
            logger.info("namespace_detector", "Detected Go package", { package = package })
            return package
        end
    end

    logger.warn("namespace_detector", "No namespace/package detected", { language = language_config.name })
    return nil
end

-- Detect C# namespace using treesitter
-- @param bufnr number: Buffer number
-- @return string|nil: Namespace name or nil
function M.detect_csharp_namespace_treesitter(bufnr)
    -- Check if treesitter is available
    local ok, ts = pcall(require, 'nvim-treesitter')
    if not ok then
        logger.debug("namespace_detector", "Treesitter not available")
        return nil
    end

    -- Get parser for C#
    local ok_parser, parser = pcall(vim.treesitter.get_parser, bufnr, 'c_sharp')
    if not ok_parser or not parser then
        logger.debug("namespace_detector", "C# treesitter parser not available")
        return nil
    end

    -- Parse the buffer
    local ok_parse, trees = pcall(parser.parse, parser)
    if not ok_parse or not trees or #trees == 0 then
        logger.debug("namespace_detector", "Failed to parse buffer with treesitter")
        return nil
    end

    local tree = trees[1]
    local root = tree:root()

    -- Query for namespace declarations
    local query_str = [[
        (namespace_declaration
            name: (qualified_name) @namespace.qualified)
        (namespace_declaration
            name: (identifier) @namespace.simple)
        (file_scoped_namespace_declaration
            name: (qualified_name) @namespace.qualified)
        (file_scoped_namespace_declaration
            name: (identifier) @namespace.simple)
    ]]

    local ok_query, query = pcall(vim.treesitter.query.parse, 'c_sharp', query_str)
    if not ok_query then
        logger.debug("namespace_detector", "Failed to parse treesitter query")
        return nil
    end

    -- Find the first namespace declaration
    for id, node in query:iter_captures(root, bufnr, 0, -1) do
        local capture_name = query.captures[id]
        if capture_name == "namespace.qualified" or capture_name == "namespace.simple" then
            local namespace_name = vim.treesitter.get_node_text(node, bufnr)
            if namespace_name and namespace_name ~= "" then
                return namespace_name
            end
        end
    end

    return nil
end

-- Detect C# namespace using regex (fallback)
-- Supports both file-scoped (C# 10+) and block-scoped namespaces
-- @param bufnr number: Buffer number
-- @return string|nil: Namespace name or nil
function M.detect_csharp_namespace_regex(bufnr)
    -- Read first 50 lines (namespaces are typically at the top)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 50, false)

    for _, line in ipairs(lines) do
        -- Match file-scoped namespace: "namespace MyApp.Services;"
        local namespace = line:match("^%s*namespace%s+([%w%.]+)%s*;")
        if namespace then
            return namespace
        end

        -- Match block-scoped namespace: "namespace MyApp.Services {"
        namespace = line:match("^%s*namespace%s+([%w%.]+)%s*{")
        if namespace then
            return namespace
        end

        -- Match block-scoped namespace without opening brace on same line
        namespace = line:match("^%s*namespace%s+([%w%.]+)%s*$")
        if namespace then
            return namespace
        end
    end

    return nil
end

-- Detect Go package name
-- @param bufnr number: Buffer number
-- @return string|nil: Package name or nil
function M.detect_go_package(bufnr)
    -- Read first 20 lines (package declarations are at the top)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, 20, false)

    for _, line in ipairs(lines) do
        -- Match package declaration: "package mypackage"
        local package = line:match("^%s*package%s+([%w_]+)")
        if package then
            return package
        end
    end

    return nil
end

-- Extract namespace from a fully qualified symbol name
-- Useful for filtering workspace symbols by namespace
-- @param symbol_name string: Fully qualified symbol name (e.g., "MyApp.Services.UserService")
-- @param namespace string: Target namespace (e.g., "MyApp.Services")
-- @return boolean: Whether the symbol belongs to the namespace
function M.symbol_matches_namespace(symbol_name, namespace)
    if not symbol_name or not namespace then
        return false
    end

    -- Check if symbol name starts with namespace prefix
    -- Use "." as boundary to avoid partial matches
    -- Example: "MyApp.Services" should match "MyApp.Services.UserService"
    --          but not "MyApp.ServicesHelper.SomeClass"
    local pattern = "^" .. vim.pesc(namespace) .. "%."
    if symbol_name:match(pattern) then
        return true
    end

    -- Also match if symbol name equals namespace exactly
    -- (e.g., the namespace itself as a symbol)
    if symbol_name == namespace then
        return true
    end

    return false
end

-- Extract the root namespace from a fully qualified namespace
-- Example: "MyApp.Services.Data" -> "MyApp"
-- @param namespace string: Fully qualified namespace
-- @return string: Root namespace
function M.get_root_namespace(namespace)
    if not namespace then
        return nil
    end

    local parts = vim.split(namespace, ".", { plain = true })
    return parts[1]
end

-- Check if a namespace is a sub-namespace of another
-- Example: "MyApp.Services.Data" is a sub-namespace of "MyApp.Services"
-- @param sub_namespace string: Potential sub-namespace
-- @param parent_namespace string: Parent namespace
-- @return boolean: Whether sub_namespace is under parent_namespace
function M.is_sub_namespace(sub_namespace, parent_namespace)
    if not sub_namespace or not parent_namespace then
        return false
    end

    if sub_namespace == parent_namespace then
        return true
    end

    local pattern = "^" .. vim.pesc(parent_namespace) .. "%."
    return sub_namespace:match(pattern) ~= nil
end

return M
