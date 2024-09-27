-- Extension to augment the Norns Screen functions

print("Loading nornsLib/screenExt.lua")


--------------------------- screen.draw_to() ------------------------------

-- Overriding screen.draw_to() so that it can pass arguments to func.
-- This makes drawing to images, controlled by args, possible.
function screen.draw_to(image, func, ...)
  image:_context_focus()
  local ok, result = pcall(func, ...)
  image:_context_defocus()
  if not ok then print(result) else return result end
end


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
  

------------------------ screen.current_font_size() -------------------

-- Modify font_size() so that it stores the font size
local function screen_font_size_modified(size)
  screen._current_font_size = size
  screen._original_font_size_function(size)
end


-- Since screen_font_face_modified() calls the original screen.font_face() need to make sure
-- that only change it once in order to avoid infinite recursion.
if screen._original_font_size_function == nil then
  screen._original_font_size_function = screen.font_size
  screen.font_size = screen_font_size_modified
end


-- Extension. Returns the current font size
screen.current_font_size = function()
  return screen._current_font_size
end

------------------------ screen.current_font_face() -------------------

-- Modify font_face() so that it stores the font face
local function screen_font_face_modified(face)
  screen._current_font_face = face
  screen._original_font_face_function(face)
end


-- Since screen_font_face_modified() calls the original screen.font_face() need to make sure
-- that only change it once in order to avoid infinite recursion.
if screen._original_font_face_function == nil then
  screen._original_font_face_function = screen.font_face
  screen.font_face = screen_font_face_modified
end


-- Extension. Returns the current font face
screen.current_font_face = function()
  return screen._current_font_face
end

----------------------- screen.aa() anti-aliasing ---------------------

-- Modify font_aa() so that it stores the anti-aliasing state
local function screen_aa_modified(on)
  screen._current_aa = on
  screen._original_aa_function(on)
end


-- Since screen_aa_modified() calls the original screen.aa() need to make sure
-- that only change it once in order to avoid infinite recursion.
if screen._original_aa_function == nil then
  screen._original_aa_function = screen.aa
  screen.aa = screen_aa_modified
end

-- Extension. Returns the current anti-aliasing
screen.current_aa = function()
  return screen._current_aa
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
-- screen_display_image(),  screen_display_image_region(), and screen_context_set() which 
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


local function screen_draw_to_modified(...)
  -- This line retrieves data using a queued command so will make sure that the
  -- original screen clear function has fully finished before this function returns.
  screen.current_point()

  -- Call original function to do the actual work
  screen._original_draw_to_function(...)
end


-- Since the modified functions call the original ones, need to make sure
-- that only change them once in order to avoid infinite recursion.
if screen._original_display_image_function == nil then
  screen._original_display_image_function = screen.display_image
  screen.display_image = screen_display_image_modified
  
  screen._original_display_image_region_function = screen.display_image_region
  screen.display_image_region = screen_display_image_region_modified
  
  screen._original_draw_to_function = screen.draw_to
  screen.draw_to = screen_draw_to_modified
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