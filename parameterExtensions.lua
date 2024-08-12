-- Extensions for making it easier for user to set parameters. 
-- Key improvements are:
--   * If have a selector with a value and a label, this extension will make 
--     sure they don't overlap.
--   * When user hits key1 they are automatically brought to the parameters page
--     so that they don't have to go through complicated key and encoder sequence
--     to get there.

------------------------------------------------------------------------------------------

-- This two functions need to be loaded everytime since it is a global function. Therefore
-- it is defined before the code that returns from this script if was read in before.

-- Jumps from the application screen to the script's Params Edit screen so that user can 
-- easily change app params. For when k1 pressed from within the script. Really nice
-- feature since it makes param changes easier. This function should be called in the
-- script's key() method for key1 is released. 
function jump_to_edit_params_screen()
  -- Change to menu mode 
  _menu.set_mode(true) 

  -- Get access to the PARAMS menu class
  local params_class = require "core/menu/params"

  -- Go to EDIT screen of the PARAMS menu. Needed in case user was at another PARAMS 
  -- screen, like PSET. mEdit is a local in lua/core/menu/params.lua so needs to
  -- be duplicated here.
  local mEDIT = 1
  params_class.mode = mEDIT

  -- tSEPARATOR and tTEXT are locals in paramset.lua so get them from metatable
  local params_metatable = getmetatable(params)
  local tSEPARATOR = params_metatable.tSEPARATOR
  local tTEXT = params_metatable.tTEXT
  
  -- Set to first settable item
  params_class.pos = 0 -- For if don't find appropriate one
  for idx=1,#params.params do
    if params:visible(idx) and params:t(idx) ~= tSEPARATOR and params:t(idx) ~= tTEXT then
      params_class.pos = idx - 1 -- oddly the index for parameters is zero based
      break
    end
  end
  
  -- Change to PARAMS menu screen
  _menu.set_page("PARAMS")

  -- Initialize the params page in case haven't done so previously
  params_class.init()
end


-- Display current selector value for param param_idx. 
-- For norns/lua/core/menu/params.lua
function output_value_without_overlap(value_str, label_str, original_text_right_func)
  -- If value is nil don't try to process it
  if value_str == nil then return end
  
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

---------------------------------------------------------------------------------------------

-- Make sure this file only loaded once. This prevents infinite recursion when 
-- overriding system functions. Bit complicated because need to use something
-- that lasts across script restarts. The solution is to use add a boolean to
-- the object whose function is getting overloaded.

-- The menu that contains the params. This is the one that needs to have function
-- ptrs modified. So this is where should store the already_included boolean.
local params_menu = require "core/menu/params"

-- If the special variable already set then return and don't process this file further
if params_menu["already_included"] ~= nil then 
  print("parameterExtensions.lua already included so not doing so again")
  return 
end
  
-- Need to process this file
params_menu["already_included"] = true
print("parameterExtensions.lua not yet loaded so loading now...")

----------------------------------------------------------------------------------
------------------------- Make sure selector text doesn't overlap ----------------
----------------------------------------------------------------------------------

-- Need screen extensions to get current font values when redrawing
include "nornsLib/screenExtensions"

-- For keeping track of original redraw() so that it can be used within the modified code
local original_redraw_function = params_menu.redraw
local possible_label

-- The new redraw() function. Temporarily witches to using special screen.text() 
-- and screen.text_right() functions that allow output_value_without_overlap() to
-- be called instead of screen.text_right. This way can make sure that the option
-- label and values don't overlap. 
params_menu.redraw = function()
  -- Switch to using special screen.text() function that stores the last text
  -- written using screen.text(str)
  local original_text_func = screen.text
  screen.text = function(str)
    possible_label = str
    original_text_func(str)
  end
  
  -- Switch to using special screen.text_right() function that if text too wide
  -- it draws it smaller so that it won't overlap with the label text written to
  -- the left.
  local original_text_right_func = screen.text_right
  screen.text_right = function(value) 
    -- If the value and label are short such that there could not be overlap 
    -- then just use original simple text_right() function 
    if value ~= nill and possible_label ~= nil and 
        string.len(value) + string.len(possible_label) < 24 then
      original_text_right_func(value)
    else
      -- Longish labels so make sure they don't overlap
      output_value_without_overlap(value, possible_label, original_text_right_func)
    end
  end

  -- Call the original redraw function
  original_redraw_function()
  
  -- Restore the screen.text() and screen.text_right() functions
  screen.text = original_text_func
  screen.text_right = original_text_right_func
end


----------------------------------------------------------------------------------
---------- Hnadle key1 better and be able to jump straight to params page --------
----------------------------------------------------------------------------------

-- Override _norns.key function. This modified function handles all button presses 
-- both for the script and for the menus. It is how short presses on key1 are 
-- detected and handled. But it is modified here so that a key1 short press is
-- still sent to the script. This way the script can do something special, like
-- jump directly to the PARAMS menu whether it is a short press or a long press.

-- In the original _norns.key function in lua/core/menu.lua the global variables
-- pending and t are local and therefore cannot be accessed. But pending is only
-- used within _norns.key() and in the timer event function. Therefore can just
-- declare a new pending variable here. And the t timer is easy to access from
-- core/metro.
local pending = false
local metro = require 'core/metro'
local t = metro[31]


t.event = function(_)
  _menu.key(1,1)
  pending = false
  if _menu.mode == true then _menu.redraw() end
end


-- Overriding the key() function in lua/core/menu.lua
_norns.key = function(n, z)
  -- key 1 detect for short press
  if n == 1 then
    if z == 1 then
      -- key 1 pressed so start timer
      _menu.alt = true
      pending = true
      t:start()
    elseif pending == true then
      -- Key 1 released within the timer's allowed time so was short press.
      _menu.alt = false

      -- Toggle menu mode. If was in menu mode will go to app script mode,
      -- and visa versa.
      if _menu.mode == true and _menu.locked == false then
        -- Go to application mode
        _menu.set_mode(false)
      else
        -- Tell app script that button 1 was released, even though was a short press
        _menu.key(n,z) -- always 1,0

        -- Go to menu mode
        _menu.set_mode(true)
      end

      -- Done with short press timer so clear it
      t:stop()
      pending = false
    else
      -- key 1 released but not within allowed short time so pass event to script
      _menu.alt = false
      if _menu.mode == true and _menu.locked == false then
        -- In menu mode. Should treat long k1 press same as short press and get out
        -- of menu mode. This avoids user getting confused with hitting k1 and it
        -- not working because it was down a bit too long.
        _menu.set_mode(false)
      else
        -- Not in menu mode so simply pass through the k1 up info to the script app
        _menu.key(n,z) -- always 1,0
      end
    end
  else
    -- key 2 or 3 so pass through to menu key handler
    _menu.key(n,z)
  end

  -- Restart screen saver timer
  screen.ping()
end


