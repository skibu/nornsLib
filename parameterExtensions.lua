-- Extensions for making it easier for user to set parameters. 
-- Key improvements are:
--   * If have a selector with a value and a label, this extension will make 
--     sure they don't overlap.
--   * When user hits key1 they are automatically brought to the parameters page
--     so that they don't have to go through complicated key and encoder sequence
--     to get there.

-- Need screen extensions to get current font values when redrawing
include "nornsLib/screenExtensions"

-- The menu that contains the params. This is the one that needs to be modified
local params_menu = require "core/menu/params"

-- For keeping track of current font values so that they can be restored after drawing
local original_text_right_func
local original_redraw_function = params_menu.redraw
local possible_label

-- The new redraw() function. Temporarily witches to using special screen.text() 
-- and screen.text_right() functions that allow output_value_without_overlap() to
-- be called instead of screen.text_right. This way can make sure that the option
-- label and values don't overlap. 
params_menu.redraw = function()
  -- Switch to using special screen.text() and screen.text_right() functions
  local original_text_func = screen.text
  screen.text = function(str)
    possible_label = str
    original_text_func(str)
  end
  
  original_text_right_func = screen.text_right
  screen.text_right = function(value) 
    -- If the value and label are short such that there could not be overlap 
    -- then just use original simple text_right() function 
    if string.len(value) + string.len(possible_label) < 24 then
      original_text_right_func(value)
    else
      -- Longish labels so make sure they don't overlap
      output_value_without_overlap(value, possible_label)
    end
  end

  -- Call the original redraw function
  original_redraw_function()
  
  -- Restore the screen.text() and screen.text_right() functions
  screen.text = original_text_func
  screen.text_right = original_text_right_func
end


-- Display current selector value for param param_idx. 
-- For norns/lua/core/menu/params.lua
function output_value_without_overlap(value_str, label_str)
  local label_width = screen.text_extents(label_str)
  local value_width = screen.text_extents(value_str)
  local orig_font_size = screen.current_font_size()
  local orig_font_face = screen.current_font_face()
  local orig_aa = screen.current_aa()

  if label_width + value_width + 2 > 127 then
    -- The value text is too long. First try using smaller font. Found that
    -- best somewhat smaller font is index 5 Roboto-Regular at size 7.
    -- Anything smaller is simply not readable. And it is important to make
    -- sure that anti-aliasing is off because it screws up some fonts like Robot.
    -- If want another smaller font can try 25 size 6, though it is actually wider
    -- than Roboto-Regular size 7. The font for the edit params page is set in 
    -- core/menu.lua _menu.set_mode(). Default font size is 8 and default font 
    -- face is 1.
    screen.aa(0)
    screen.font_face(5)
    screen.font_size(7)
    value_width = screen.text_extents(value_str)
    if label_width + value_width + 2 > 127 then
      -- Still too long. Don't want to try even smaller font so
      -- move the value further to right so there is no overlap
      local needed_width = label_width + value_width + 2
      screen.move_rel(needed_width - 128, 0)
    end
  end

  -- Actually draw the value text, and use the original text_right() function
  original_text_right_func(value_str)

  -- If font size, face, or anti-aliasing were changed, restore them
  if screen.current_font_size() ~= orig_font_size then screen.font_size(orig_font_size) end
  if screen.current_font_face() ~= orig_font_face then screen.font_face(orig_font_face) end
  if screen.current_aa() ~= orig_aa then screen.aa(orig_aa) end
end
