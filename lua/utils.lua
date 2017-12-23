function bold(input)
  return "\002"..input.."\002"
end

function underlined(input)
  return "\031"..input.."\031"
end

function italic(input)
  return "\016"..input.."\016"
end