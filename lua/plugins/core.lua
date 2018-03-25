package.path = package.path .. ";./lua/?.lua"
require('utils')

local Core = {}

local plugin_list = {}
local Manager = {}

function Core.init(manager, plugins)
    Manager = manager
    plugin_list = plugins
end

function Core.cleanup()

end

function Core.name()
    return "core"
end

function Core.description()
    return "no description"
end

function Core.help()
    return "My commands are: !plugins, !help, !help <plugin>, !about, !about <plugin>"
end

function Core.listen(from, to, input)
    local input = input:lower()

    if input == "!plugins" or input == "list plugins" then
        out = "My current plugins are: "
        for name, plugin in pairs(plugin_list) do
            out = out..string.lower(plugin.name())..", "
        end

        return string.sub(out, 1, string.len(out)-2)
    elseif input == "!about" or string.match(input, "who are you%??") ~= nil then
        return "I'm a meteor bot v0.1 powered by Rust and Lua"
    elseif input == "!help" or input == "list all commands" then
        return Core.help()
    else
        local cmd, plugin_name, args = string.match(input, "!([^%s]*) ([^%s]*)%s?(%g*)")
        if cmd == nil or plugin_name == nil then
            return nil
        end

        local plugin = get_plugin(plugin_name, plugin_list)
        if plugin == nil then
            return "No plugin named "..plugin_name.." found"
        end

        if cmd == "about" and args == "" then
            return plugin.description()
        elseif cmd == "help" then
            if args == "" then
                return plugin.help()
            else
                return ""
            end
        end
    end
    return nil
end

return Core
