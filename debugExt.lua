-- For adding debug.print(), debug.tprint(), and debug.log() in order to make it easy to have debug
-- logging statements. The info is only output if enabled by first calling debug.enable_print().
-- Not only is the passed in string output, but function name, source file, and line number are
-- as well. Sort of a light weight traceback that can be easily enabled and disabled.

-- This function needs to be called if want debug.print() functions to actually output
-- info. To enable can call debug.enable_print(true) or simply debug.enable_print(). To
-- disable use debug.enable_print(false).
function debug.enable_print(value) 
  if value == true or value == nil then
    _norns.debug_print_enabled = true
  else
    _norns_debug_print_enabled = false
  end
end


-- If should do debug printing as indicated by _norns.debug_print_enabled then will do so.
local function debug_print_enabled()
  return _norns.debug_print_enabled == true 
end


-- Provides context of when the debug print statement was called.
-- The parameter called_by_print will usually be nil to indicate that the
-- print statement was called directly. But if the print statement was called
-- by another print statement then should pass in an object such as true. 
local function debugging_info(called_by_print)
  -- Number of levels that need to go up when calling debug.getinfo() depends
  -- on whether an extra layer of print() functions used.
  local levels_up = called_by_print == nil and 3 or 4

  local debug_info = debug.getinfo(levels_up, "Sln")

  local function_name = debug_info.name
  if function_name ~= nil then
    function_name = function_name .. "() "
  else
    function_name = ""
  end

  return "DEBUG " .. function_name .. util.get_filename(debug_info.short_src) ..
    " line:"..debug_info.currentline
end


-- Does a util.tprint(), but only if debug_print_enabled() returns true.
-- Great for debugging. Parameter called_by_print should be set to non nil
-- if this function was called by another debug.print() function. This is
-- needed so that the proper function will be displayed in the message.
function debug.tprint(obj, called_by_print)
  -- Don't do anything if not in debug mode
  if not debug_print_enabled() then return end

  -- Output the info
  util.tprint(debugging_info(called_by_print).."\n            "..obj)
end


-- Since debug.tprint(obj) is so useful here is a shorter name for it
function debug.log(obj)
  -- Note: setting called_by_print to true since calling an extra layer of print func>
  debug.tprint(obj, true)
end


-- Does a regular print(), but only if the global debug_mode is set to true.
-- Great for debugging.
function debug.print(obj)
  -- Don't do anything if not in debug mode
  if not debug_print_enabled() then return end

  -- Output the info
  print(debugging_info().."\n"..obj)
end
