-- Extension to augment the Norns Screen functions

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


--------------------------- screen.clear() -------------------------------

-- In norns version 240424 there is a bug when writing an image buffer after screen.clear()
-- is called. The screen.display_image() call is not queued and therefore can execute
-- before the screen is fully cleared, resulting in the image not be displayed correctly
-- or even at all. This is being fixed in the next release of Norns, but if you are 
-- using screen.display_image() then you will want to include this library since it
-- is a good temporary fix for the problem.
--
local function screen_clear_modified()
  screen._original_clear_function()
  
  -- This line retrieves data using a queued command so will make sure that the
  -- original screen clear function has fully finished before this function returns.
  screen.current_point()
end

-- Since screen_clear_modified() calls the original screen.clear() need to make sure
-- that only change it once in order to avoid infinite recursion.
if screen._original_clear_function == nil then
  screen._original_clear_function = screen.clear
  screen.clear = screen_clear_modified
end

