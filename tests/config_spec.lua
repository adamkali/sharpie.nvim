-- Tests for sharpie.nvim config module
describe("config module", function()
    local config

    before_each(function()
        -- Clear package cache to get fresh module
        package.loaded['sharpie.config'] = nil
        config = require('sharpie.config')
    end)

    describe("defaults", function()
        it("should have default configuration", function()
            assert.is_not_nil(config.defaults)
            assert.equals("telescope", config.defaults.fuzzy_finder)
            assert.equals("bottom", config.defaults.display.style)
            assert.equals(60, config.defaults.display.width)
            assert.equals(20, config.defaults.display.height)
        end)

        it("should have default icon set", function()
            assert.is_not_nil(config.defaults.style.icon_set)
            assert.is_string(config.defaults.style.icon_set.class)
            assert.is_string(config.defaults.style.icon_set.method)
        end)

        it("should have default keybindings", function()
            assert.is_not_nil(config.defaults.keybindings)
            assert.equals("+", config.defaults.keybindings.sharpie_local_leader)
            assert.is_false(config.defaults.keybindings.disable_default_keybindings)
        end)
    end)

    describe("setup", function()
        it("should merge user config with defaults", function()
            local user_config = {
                fuzzy_finder = "fzf",
                display = {
                    style = "float",
                }
            }

            local result = config.setup(user_config)

            assert.equals("fzf", result.fuzzy_finder)
            assert.equals("float", result.display.style)
            -- Should preserve default values not overridden
            assert.equals(60, result.display.width)
        end)

        it("should handle empty config", function()
            local result = config.setup({})
            assert.equals("telescope", result.fuzzy_finder)
        end)

        it("should handle nil config", function()
            local result = config.setup(nil)
            assert.equals("telescope", result.fuzzy_finder)
        end)
    end)

    describe("get", function()
        it("should return current configuration", function()
            config.setup({ fuzzy_finder = "fzf" })
            local result = config.get()
            assert.equals("fzf", result.fuzzy_finder)
        end)
    end)

    describe("get_icon", function()
        it("should return icon for known symbol kind", function()
            local icon = config.get_icon("class")
            assert.is_string(icon)
        end)

        it("should return icon for case-insensitive kind", function()
            local icon1 = config.get_icon("Class")
            local icon2 = config.get_icon("class")
            assert.equals(icon1, icon2)
        end)

        it("should return default icon for unknown kind", function()
            local icon = config.get_icon("unknown_kind")
            assert.is_string(icon)
        end)
    end)
end)
