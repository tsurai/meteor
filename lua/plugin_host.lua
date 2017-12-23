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
      print("Error: no " .. fn .. " function found")
       ret = false
    end
  end

  return ret
end

function Manager.initialize(path)
    print("[lua] initializing lua plugin host")
    Manager.plugin_path = path
    Manager.load_plugins()

    return Manager.process_plugins
end

function Manager.reload_plugins()
   print("[lua] reloading plugins")
   Manager.unload_plugins()
   Manager.load_plugins()
   print("[lua] plugins successfully reloaded")
end

function Manager.load_plugins()
  -- load all plugins
  print("[lua] loading plugins")
  local path = Manager.plugin_path

  for filename in io.popen("ls "..path):lines() do
    if string.find(filename, "%.lua$") then
      print("[lua] loading plugin " .. filename)

      filepath = path.."/"..filename
      plugin, err = loadfile(filepath)

      if plugin ~= nil then
        plugin = plugin()

        if is_valid_plugin(plugin) then
          Manager.plugin_list[plugin.name()] = plugin
        end
      else
        print("Error: failed to load plugin.", err)
      end
    end
  end

  -- initialize plugins
  for name, plugin in pairs(Manager.plugin_list) do
    if name == "core" then
      plugin.init(Manager, Manager.plugin_list)
    else
      plugin.init()
    end
  end

end

function Manager.unload_plugins()
  print("[lua] unloading all plugins")
  for name, plugin in pairs(Manager.plugin_list) do
    plugin.cleanup()
    Manager.plugin_list[name] = nil
  end
end

function Manager.process_plugins(from, to, input)
    for name, plugin in pairs(Manager.plugin_list) do
        local ok, resp = pcall(plugin.listen, from, to, input)

        if not ok then
            print("[lua] error: "..resp)
            local err = resp:gsub("./(.*):(%d*): ", "")
            return err
        elseif resp ~= nil then
            return resp
        end
    end

    return "I don't know that command " .. from
end

return Manager.initialize
