-- manager.lua
dofile("lua/db.lua")
dofile("lua/utils.lua")

local Manager = {
    plugin_list = {},
    plugin_path = ""
}

local function is_valid_plugin(plugin)
    ret = true
    function_names = {"init", "cleanup", "name", "description", "listen"}

    for i, fn in ipairs(function_names) do
        if type(plugin[fn]) ~= "function" then
            err("plugin " .. plugin.name() .. " is missing function: " .. fn)
            ret = false
        end
    end

    return ret
end

function Manager.initialize(path)
    info("initializing lua plugin host")

    Manager.plugin_path = path
    Manager.load_plugins()

    return Manager.process_plugins
end

function Manager.reload_plugins()
    info("reloading plugins")

    Manager.unload_plugins()
    Manager.load_plugins()

    info("plugins successfully reloaded")
end

function Manager.load_plugins()
    -- load all plugins
    info("loading plugins")
    local path = Manager.plugin_path

    for filename in io.popen("ls "..path):lines() do
        if string.find(filename, "%.lua$") then
            info("loading plugin " .. filename)

            filepath = path.."/"..filename
            plugin, e = loadfile(filepath)

            if plugin ~= nil then
                plugin = plugin()

                if is_valid_plugin(plugin) then
                    Manager.plugin_list[plugin.name()] = plugin
                end
            else
                err("failed to load plugin. " .. e)
            end
        end
    end

    -- initialize plugins
    for name, plugin in pairs(Manager.plugin_list) do
        info("initializing plugin " .. name)
        if name == "core" then
            plugin.init(Manager, Manager.plugin_list)
        else
            plugin.init()
        end
    end
end

function Manager.unload_plugins()
    info("unloading all plugins")

    for name, plugin in pairs(Manager.plugin_list) do
        plugin.cleanup()
        Manager.plugin_list[name] = nil
    end
end

function Manager.process_plugins(from, to, input)
    for name, plugin in pairs(Manager.plugin_list) do
        local ok, resp = pcall(plugin.listen, from, to, input)

        if not ok then
            err(resp)
            local e = resp:gsub("(.*):(%d*): ", "")
            return e
        elseif resp ~= nil then
            return resp
        end
    end

    return "I don't know that command " .. from
end

return Manager.initialize
