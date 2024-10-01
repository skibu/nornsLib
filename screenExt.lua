-- Extension to augment the Norns Screen functions

print("Loading nornsLib/screenExt.lua")

-- load the nornsLib mod to setup system hooks
local nornsLib = require "nornsLib/nornsLib"

--------------------------- screen.text_untrimmed_extents(str) --------------

-- The standard screen.text_extents() function has a notable flaw. It doesn't provide 
-- the proper width of a string if the string is padded by spaces. Somewhere the string
-- is inappropriately trimmed. This is a problem even if padding with a half space \u{2009}
-- or a hair space \u{200A}. Could not determine where the string is getting inappropriately
-- trimmed so cannot fix the code directly. Instead, screen.text_untrimmed_extents(str)
-- should be used instead of screen.text_extents(str) if the string might be padded. Don't
-- want to use this for every situation though because this function actually makes two
-- calls to the original screen_text_extents(), which slows things down a bit, especially
-- since they are blocking calls. Therefore this function should only be used when the 
-- string in question actually might be padded.
-- This is a additional screen function instead of a replacement one. Therefore it can 
-- be loaded multiple times and does not needed to be protected by screen["already_included"].
function screen.text_untrimmed_extents(str)
  local width_with_extra_chars, height = screen.text_extents("x"..str.."x")
  local width_of_extra_chars = screen.text_extents("x".."x")
  return width_with_extra_chars - width_of_extra_chars, height
end  


-------------------------- screen.level() ---------------------------------

-- Modification of screen.level() that accepts floating point level instead
-- of generating an error.
local function screen_level_modified(level)
  -- Be able to handle floating point level
  level = math.floor(level + 0.5)
  
  screen._current_level = level
  screen._original_level_function(level)
end


if screen._original_level_function == nil then
  screen._original_level_function = screen.level
  screen.level = screen_level_modified
end


------------------------ screen.extents() ----------------------------------

-- Quite a useful function that returns extents of specified image buffer or png file.
-- Can also pass in a file name instead of an image buffer.
screen.extents = function(image_buffer_or_filename)
  -- If a file name provided then read in image buffer
  local image_buffer
  if type(image_buffer_or_filename) == "string" then
    image_buffer = screen.load_png(image_buffer)
  else 
    image_buffer = image_buffer_or_filename
  end
  
  -- Return the results
  return image_buffer.extents(image_buffer)
end  


--------------------------- writing image buffers not synced -------------------------------

-- In Norns version 240424 there is a bug when writing an image buffer after other event
-- driven screen calls are made, like after screen.clear(). The problem is with C functions
-- screen_display_image(), screen_display_image_region(), and screen_context_set() which 
-- is called by screen.draw_to(). These functions are not event driven, but instead
-- happen immediately, even if there are still some drawing events in the queue. 
--
-- An example is with calling screen.display_image() after screen.clear(). 
-- screen.display_image() is not queued and therefore can execute before the screen
-- is fully cleared, resulting in the image not be displayed correctly
-- or even at all. 
--
-- To address this problem the problem functions are rewritten here to first call 
-- screen.current_point(), which does a return trip to Cairo. Since it is event driven
-- yet returns a value, it causes the queue of events to be processed before returning
-- the value. This syncs up things correctly.
--
-- This is being fixed in future release of Norns, but if you are using 
-- screen.display_image(), display_image_region(), or screen.draw_to() then 
-- you will want to include this library since it is a good temporary fix for the problem.

local function screen_display_image_modified(...)
  -- This line retrieves data using a queued command so will make sure that the
  -- original screen clear function has fully finished before this function returns.
  screen.current_point()

  -- Call original function to do the actual work
  screen._original_display_image_function(...)
end


local function screen_display_image_region_modified(...)
  -- This line retrieves data using a queued command so will make sure that the
  -- original screen clear function has fully finished before this function returns.
  screen.current_point()

  -- Call original function to do the actual work
  screen._original_display_image_region_function(...)
end


-- Since the modified functions call the original ones, need to make sure
-- that only change them once in order to avoid infinite recursion.
if screen._original_display_image_function == nil then
  screen._original_display_image_function = screen.display_image
  screen.display_image = screen_display_image_modified
  
  screen._original_display_image_region_function = screen.display_image_region
  screen.display_image_region = screen_display_image_region_modified
end


-- draw_to() has to be replaced completely. This is due to image:_context_focus() and
-- image:_context_defocus() not being queue commands. Therefore need to, for now, do a
-- call to current_point() before each one in order to synch things up.
-- Also, overriding screen.draw_to() so that it can pass arguments to func.
-- This makes drawing to images, controlled by args, possible.
screen.draw_to = function(image, func, ...)
  -- Sync up drawing before _context_focus() called
  screen.current_point()
   
  image:_context_focus()
  local ok, result = pcall(func, ...)

  -- Sync up drawing before _context_defocus() called
  screen.current_point()
   
  image:_context_defocus()
  if not ok then print(result) else return result end
end


-------------------------- screen.blend_mode(index) ------------------

-- Up to at least the September 2024 release, Screen.BLEND_MODES in screen.lua was missing
-- ['SATURATE'] = 3. This meant that if tried using a blend mode 3 or greater one got the 
-- wrong mode!! This was a problem whether used the name or the index. Fix is to simply 
-- use a corrected BLEND_MODES array shown below. When this is addressed in the main Norms
-- also need to make a change to screen.c:598 to increase upper limit by one. and change 
-- weaver.c _screen_set_operator(lua_State *l) so that upper limit is 29.

screen.BLEND_MODES = {
  ['NONE'] = 0,
  ['DEFAULT'] = 0,
  ['OVER'] = 0,
  ['XOR'] = 1,
  ['ADD'] = 2,
  ['SATURATE'] = 3,
  ['MULTIPLY'] = 4,
  ['SCREEN'] = 5,
  ['OVERLAY'] = 6,
  ['DARKEN'] = 7,
  ['LIGHTEN'] = 8,
  ['COLOR_DODGE'] = 9,
  ['COLOR_BURN'] = 10,
  ['HARD_LIGHT'] = 11,
  ['SOFT_LIGHT'] = 12,
  ['DIFFERENCE'] = 13,
  ['EXCLUSION'] = 14,
  ['CLEAR'] = 15,
  ['SOURCE'] = 16,
  ['IN'] = 17,
  ['OUT'] = 18,
  ['ATOP'] = 19,
  ['DEST'] = 20,
  ['DEST_OVER'] = 21,
  ['DEST_IN'] = 22,
  ['DEST_OUT'] = 23,
  ['DEST_ATOP'] = 24,
  ['SATURATE'] = 25,
  ['HSL_HUE'] = 26,
  ['HSL_SATURATION'] = 27,
  ['HSL_COLOR'] = 28,
  ['HSL_LUMINOSITY'] = 29,
}

------------------------------------ do screen.ping() at init ----------------------

-- Turns out that in the Norns code a screen.ping() is only done when user interacts with 
-- a key or an encoder. This is usually sufficient to wake up the screen if has gone asleep.
-- But if the script is started within matron while the screen is asleep, then the screen
-- won't be woken up! Therefore a hook is used to do a ping at startup, and thereby always
-- make sure that the screen is awake.
function initialize_screen()
  -- If NornsLib not enabled for this app then don't do anything
  if not nornsLib.enabled() then return end

  log.debug("Doing screen.ping() at startup")
  screen.ping()
end


local hooks = require 'core/hook'
hooks["script_pre_init"]:register("pre init for NornsLib screen extension", 
  initialize_screen)