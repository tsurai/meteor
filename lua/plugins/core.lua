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

function Core.listen(from, to, input)
  if string.match(input:lower(), "list plugins") ~= nil then
    out = "My current plugins are: "
    for name, plugin in pairs(plugin_list) do
      out = out..string.lower(plugin.name())..", "
    end

    return string.sub(out, 1, string.len(out)-2)

  --[[else
    match = string.match(input, "show commands for (.*)")
    if match ~= nil then
    if
    return true
  ]]--
  elseif string.match(input:lower(), "reload plugins") ~= nil then
    Manager.unload_plugins()
    if Manager.initialize() ~= nil then
      return "Plugins have been reloaded"
    end
  elseif string.match(input:lower(), "who are you%??") ~= nil then
    return "I'm a meteor bot v0.1 powered by Rust and Lua"
  end

  return nil
end

return Core
