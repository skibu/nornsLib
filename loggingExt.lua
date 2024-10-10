-- A logging class. Redefines print() so that will print to both stdout and it
-- a logfile in the script's data directory. Includes useful logging functions
-- that output time and debug info as appropriate:
--   log.debug()
--   log.debug() and log.enable_debug()
--   log.error()
--
-- Include it via:
--  log = require "nornsLib/loggingExt"


print("Loading nornsLib/loggingExt.lua")

-- load the nornsLib mod to setup system hooks
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
function LoggingExt.debug_enabled()
  return LoggingExt.debug_print_enabled == true 
end


-- Provides context of when the debug print statement was called.
-- The parameter called_by_print will usually be nil to indicate that the
-- print statement was called directly. But if the print statement was called
-- by another print statement then should pass in an object such as true. 
-- Returns string containing debug context.
local function debugging_info(called_by_print)
  -- Number of levels that need to go up when calling log.getinfo() depends
  -- on whether an extra layer of print() functions used.
  local levels_up = called_by_print == nil and 3 or 4

  local debug_info = debug.getinfo(levels_up, "Sln")

  -- debug_info can be null if used in REPL. Therefore handle that case.
  if debug_info == nil then return "" end
    
  local function_name = debug_info.name
  if function_name ~= nil then
    function_name = function_name .. "() "
  else
    function_name = ""
  end

  return function_name .. util.get_filename(debug_info.short_src) ..
    " line:"..debug_info.currentline
end


-- Takes in variable number of args, including nils, and returns concatinated string
-- that can be output.
local function concat_var_args(...)
  -- Using variable number of args is complicated due to any argument can be nil.
  -- To handle, convert the variable arguments into a packed table.
  args_table = table.pack(...)

  -- Take variable args and concat them into a single tab separated string called concatinated_args
  local concatinated_args = ""
  for i = 1, args_table.n do
    local v = args_table[i]
    concatinated_args = concatinated_args .. (i ~= 1 and "\t" or "") .. tostring(v)
  end
  
  return concatinated_args
end


-- Does a log.print(), but only if debug_enabled() returns true.
-- Great for debugging. 
function LoggingExt.debug(...)
  -- Don't do anything if not in debug mode
  if not LoggingExt.debug_enabled() then return end

  local concatinated_args = concat_var_args(...)
    
  -- Output the info
  LoggingExt.print("DEBUG: " .. concatinated_args ..
    "\n            "..debugging_info())

  -- Debug statements are important and it doesn't matter if they are a bit slow. 
  -- They are for debugging! Therefore worthwhile to flush logfile so that user
  -- will definitely see the error.
  LoggingExt.flush_logfile()
end


-- Does a log.print() but adds ERROR: and also debugging info on the next line.
function LoggingExt.error(...)
  local concatinated_args = concat_var_args(...)
    
  -- Output the info
  LoggingExt.print("ERROR: " .. concatinated_args ..
    "\n            "..debugging_info())
  
  -- Errors are rare but important. Therefore worthwhile to flush logfile so that user
  -- will definitely see the error.
  LoggingExt.flush_logfile()
end


-- The overriden print function that both writes to stdout but also logs it 
-- to the logfile
local function _new_print(...)
  local concatinated_args = concat_var_args(...)
  
  -- Write using original print function. Could also just write to stdout
  -- but then sometimes wouldn't see the ouput until it was flushed.
  -- Apparently print() does the necessary flushing.
  LoggingExt.original_print_function(...)
  
  -- Output to the logfile. 
  -- Note: might not appear until logfile is flushed.
  LoggingExt.logfile:write(concatinated_args .. "\n")  
end


-- Globally accessible function for flushing log file
function LoggingExt.flush_logfile()
  LoggingExt.logfile:flush()
end


-- Just a shorter namem for function flush_logfile()
function  LoggingExt.flush()
  LoggingExt.flush_logfile()
end


-- This function will be called before init() is done via magic of hooks.
local function initialize_logger()
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
local function finalize_logger()
  -- If NornsLib not enabled for this app then don't do anything
  if not nornsLib.enabled() then return end

  -- Flush and close the logfile
  if LoggingExt.logfile ~= nil then 
    LoggingExt.flush_logfile()
    LoggingExt.logfile:close() 
  end
  
  -- Restore the original print() function
  print = LoggingExt.original_print_function
  
  -- Turn off debugging in case it was on. This way other apps won't display 
  -- debugging messages from the nornsLib.
  LoggingExt.enable_debug(false)
end


-- Configure the module hooks so that any extension can have a pre-init and a post-cleanup
-- hook in order to modify system code before init() and then to reset the code while
-- doing cleanup.
local hooks = require 'core/hook'
hooks["script_pre_init"]:register("pre init for NornsLib logging extension", 
  initialize_logger)
hooks["script_post_cleanup"]:register("post cleanup for NornsLib logging extension",
  finalize_logger)


-- Allow script to access this class
return LoggingExt
