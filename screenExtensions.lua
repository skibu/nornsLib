-- Extension to augment the Norns Screen functions

-- Make sure this file only loaded once. This prevents infinite recursion when 
-- overriding system functions.
if screen_extensions_loaded ~= nil then return end
screen_extensions_loaded = true

------------------------ screen.current_font_size() -------------------

-- Modify font_size() so that it stores the font size
local _original_font_size_function = screen.font_size
local _current_font_size

screen.font_size = function(size)
  _current_font_size = size
  _original_font_size_function(size)
end

-- Extension. Returns the current font size
screen.current_font_size = function()
  return _current_font_size
end

------------------------ screen.current_font_face() -------------------

-- Modify font_face() so that it stores the font face
local _original_font_face_function = screen.font_face
local _current_font_face

screen.font_face = function(face)
  _current_font_face = face
  _original_font_face_function(face)
end

-- Extension. Returns the current font face
screen.current_font_face = function()
  return _current_font_face
end

----------------------- screen.aa() anti-aliasing ---------------------

-- Modify font_aa() so that it stores the anti-aliasing state
local _original_aa_function = screen.aa
local _current_aa

screen.aa = function(on)
  _current_aa = on
  _original_aa_function(on)
end

-- Extension. Returns the current anti-aliasing
screen.current_aa = function()
  return _current_aa
end

------------------------ screen.extents() ----------------------------------

-- Wacky useful function that returns extents of specified image buffer.
-- This was quite difficult to figure out because had to search
-- around to find out about userdata objects and getmetatable(),
-- and then look at the weaver.c source code to find out about
-- what info is available from an image buffer. 
screen.extents = function(image_buffer)
  -- Image buffer is of type userdata, which means it is a C object.
  -- But by searching around I found that getmetatable() returns a lua table
  -- that contains information about the C object.
  local meta_table =  getmetatable(image_buffer)
  
  -- By looking at weaver.c can see that one of the things the meta table
  -- contains is __index, which has info about the lua functions that can
  -- be called.
  local __index_subtable = meta_table["__index"]
  
  -- And now can get pointer to the extents() function
  local extents_function = __index_subtable["extents"]
  
  -- Now can just call the extents function on the image buffer and return the results
  return extents_function(image_buffer)
end  

--------------------------- screen.clear() -------------------------------

-- In the 240424 there is a bug when writing an image buffer after screen.clear() is 
-- called. The screen.display_image() call is not queued and therefore can execute
-- before the screen is fully cleared, resulting in the image not be displayed correctly
-- or even at all. This is being fixed in the next release of Norns, but if you are 
-- using screen.display_image() then you will want to include this library since it
-- is a good temporary fix for the problem.

local _original_clear_function = screen.clear

screen.clear = function()
  _original_clear_function()
  
  -- This line retrieves data using a queued command so will make sure that the
  -- original screen clear function has fully finished before this function returns.
  screen.current_point()
end
