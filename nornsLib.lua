-- The common code for the NornsLib library

print("Loading nornsLib/nornsLib.lua")

-- Put everything in the NornsLib namespace
local NornsLib = {
  scripts_enabled_for_list = {}
}


-- Stores that the current script is enabled for NornsLib
NornsLib.enable = function()
  local script_name = norns.state.shortname
  NornsLib.scripts_enabled_for_list[script_name] = true
end


-- Returns true if the currently script is enabled for NornsLib
NornsLib.enabled = function()
  local script_name = norns.state.shortname
  return NornsLib.scripts_enabled_for_list[script_name] or false
end
  
return NornsLib