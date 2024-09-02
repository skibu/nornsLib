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
  
  
-- Make sure this file only loaded once. This prevents infinite recursion when 
-- overriding system functions. Bit complicated because need to use something
-- that lasts across script restarts. The solution is to use add a boolean to
-- the object whose function is getting overloaded.

-- If the special variable already set then return and don't process this file further
if screen["already_included"] ~= nil then 
  print("screenExtensions.lua already included so not doing so again")
  return 
end
  
-- Need to process this file
screen["already_included"] = true
print("screenExtensions.lua not yet loaded so loading now...")

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

-- Quite a useful function that returns extents of specified image buffer.
-- Can also pass in a file name instead of an image buffer.
-- This was quite difficult to figure out because had to search
-- around to find out about userdata objects and getmetatable(),
-- and then look at the weaver.c source code to find out about
-- what info is available from an image buffer. 
screen.extents = function(image_buffer)
  -- If a file name provided then read in image buffer
  local file_name_provided = false
  if type(image_buffer) == "string" then
    file_name_provided = true
    image_buffer = screen.load_png(image_buffer)
  end
  
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
  
  -- Now can just call the extents function on the image buffer
  local width, height = extents_function(image_buffer)
  
  -- Free temporary image buffer if file name was passed in
  if file_name_provided then
    screen.free(image_buffer)
  end
  
  -- Return the results
  return width, height
end  


--------------------------- screen.free(image_buffer) -----------------------------

-- Garbage collects the specified image buffer.
-- Note: you definitely can only call this function once on an image buffer.
-- If you do so again the system can easily crash.
screen.free = function(image_buffer)
  getmetatable(image_buffer)["__gc"](image_buffer)
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
