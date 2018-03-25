function bold(input)
  return "\002"..input.."\002"
end

function underlined(input)
  return "\031"..input.."\031"
end

function italic(input)
  return "\016"..input.."\016"
end

function get_plugin(plugin_name, plugin_list)
    for name, plugin in pairs(plugin_list) do
        if name:lower() == plugin_name then
            return plugin
        end
    end
    return nil
end
