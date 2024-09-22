-- A logging class. Redefines print() so that will print to both stdout and it
-- a logfile in the script's data directory. Includes useful logging functions
-- that output time and debug info as appropriate:
--   log.debug()
--   log.debug() and log.enable_debug()
--   log.error()
--
-- Include it via:
--  log = require "nornsLib/loggingExt"


-- load the nornsLib  mod to setup system hooks
local nornsLib = require "nornsLib/nornsLib"

local LoggingExt = {
  debug_print_enabled = false,
  original_print_function,
  logfile
}


-- Like global print(), but puts the epoch time in front. Really nice for understanding
-- what parts of your code are taking a long time to execute and need to be 
-- optimized. The time is shortened to only show 4 digits to left of decimal point,
-- and 4 digits to the right. Showing more would just be kind of ugly. 
function LoggingExt.print(obj)
  time_str = string.format("%09.4f", util.time() % 10000)
  
  print(time_str .. " - " .. tostring(obj))
end


-- For adding log.debug() in order to make it easy to have debug logging statements. 
-- The info is only output if enabled by first calling log.enable_print().
-- Not only is the passed in string output, but function name, source file, and line number are
-- as well. Sort of a light weight traceback that can be easily enabled and disabled.

-- This function needs to be called if want log.debug() functions to actually output
-- info. To enable can call log.enable_print(true) or simply log.enable_print(). To
-- disable use log.enable_print(false).
function LoggingExt.enable_debug(value) 
  LoggingExt.debug_print_enabled = (value == true or value == nil)
end


-- If should do debug printing as indicated by log.debug_print_enabled then will do so.
local function debug_print_enabled()
  return LoggingExt.debug_print_enabled == true 
end


-- Provides context of when the debug print statement was called.
-- The parameter called_by_print will usually be nil to indicate that the
-- print statement was called directly. But if the print statement was called
-- by another print statement then should pass in an object such as true. 
local function debugging_info(called_by_print)
  -- Number of levels that need to go up when calling log.getinfo() depends
  -- on whether an extra layer of print() functions used.
  local levels_up = called_by_print == nil and 3 or 4

  local debug_info = debug.getinfo(levels_up, "Sln")

  local function_name = debug_info.name
  if function_name ~= nil then
    function_name = function_name .. "() "
  else
    function_name = ""
  end

  return function_name .. util.get_filename(debug_info.short_src) ..
    " line:"..debug_info.currentline
end


-- Does a log.tprint(), but only if debug_print_enabled() returns true.
-- Great for debugging. Parameter called_by_print should be set to non nil
-- if this function was called by another debug.print() function. This is
-- needed so that the proper function will be displayed in the message.
function LoggingExt.debug(obj, called_by_print)
  -- Don't do anything if not in debug mode
  if not debug_print_enabled() then return end

  -- Output the info
  LoggingExt.print("DEBUG: " .. tostring(obj)..
    "\n            "..debugging_info(called_by_print))
end


-- Does a log.print() but adds ERROR: and also debugging info on the next line.
function LoggingExt.error(obj, called_by_print)
  -- Output the info
  LoggingExt.print("ERROR: " .. tostring(obj)..
    "\n            "..debugging_info(called_by_print))
end


-- The overriden print function that both writes to stdout but also logs it 
-- to the logfile
local function _new_print(obj)
  local str = tostring(obj).."\n"

  -- Write using original print function. Could also just write to stdout
  -- but then sometimes wouldn't see the ouput until it was flushed.
  -- Apparently print() does the necessary flushing.
  LoggingExt.original_print_function(tostring(obj))
  
  -- Output to the logfile. 
  -- Note: might not appear until logfile is flushed.
  LoggingExt.logfile:write(str)  
end


-- This function will be called before init() is done via magic of hooks.
local function _initialize_logger()
  -- If NornsLib not enabled for this app then don't do anything
  if not nornsLib.enabled() then return end
  
  -- Open in append mode the logfile in the scripts data directory
  local logfile_name = norns.state.data .. "logfile.txt"
  LoggingExt.logfile = io.open (logfile_name, "a")
  
  -- Keep track of original print() function and then override.
  -- Only do this if print not already updated. This way eliminate possibility 
  -- of infinite recursion.
  if print ~= _new_print then
    LoggingExt.original_print_function = print
    print = _new_print
  end  
  
  -- Nice to show when script truly starts
  LoggingExt.print("=============== Initializing " .. norns.state.shortname .. "================")
end


-- Will be called by script_post_cleanup hook when script is being shut down.
-- Closes the log file and also restore the print function back to its original.
local function _finalize_logger()
  -- If NornsLib not enabled for this app then don't do anything
  if not nornsLib.enabled() then return end

  -- Flush and close the logfile
  if LoggingExt.logfile ~= nil then 
    LoggingExt.flush_logfile()
    LoggingExt.logfile:close() 
  end
  
  -- Restore the original print() function
  print = LoggingExt.original_print_function
end


-- Globally accessible function for flushing log file
function LoggingExt.flush_logfile()
  LoggingExt.logfile:flush()
end


-- Configure the module hooks so that any extension can have a pre-init and a post-cleanup
-- hook in order to modify system code before init() and then to reset the code while
-- doing cleanup.
local hooks = require 'core/hook'
hooks["script_pre_init"]:register("pre init for NornsLib logging extension", 
  _initialize_logger)
hooks["script_post_cleanup"]:register("post cleanup for NornsLib logging extension",
  _finalize_logger)


-- Allow script to access this class
return LoggingExt
