--- An alternative to the standard textentry UI from norns/lua/lib/textentry.lua
--- Goal is to provide same functionality, a way for user to enter a text string
--- like a file name, but easier to use. For example, the standard text entry 
--- requires one to twiddle enc3 to get to DEL OK line, which is quite confusing.
---
--- This textentry just handle a single line of chars to select from. One of them 
--- is DEL for erasing the last character. There is no OK option. Instead, user
--- simply hits key2 to get to previous screen, which saves the name. Plus the 
--- chars are simplified and ordered in a more logical way: capital letters, lower
--- case letters, numbers, special characters. And the title and the current
--- value of the string is better indicated.
---
--- This code works by substituting in new functions for the textentry te object.

print("Loading nornsLib/textentryExt.lua")

-- load the nornsLib mod to setup system hooks
local nornsLib = require "nornsLib/nornsLib"

-- For logging
local log = require "nornsLib/loggingExt"

local te_kbd_cb = require 'lib/textentry_kbd'
local keyboard = require 'core/keyboard'
local te = require "textentry"


-- The characters that user can select from. First one is backspace char, 0x08
local backspace_key = "\u{0008}"
local enter_key = "\u{000D}"
te.available_chars = enter_key..backspace_key..
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890.,-_=+#$%*<>"


-- Called whenever any key is pressed or released. For handling just special
-- keys ESC, ENTER, and BACKSPACE.
local function keycode(c, value)
  log.debug("In keycode() c="..c.." value="..value)
  if keyboard.state.ESC then
    -- Restore text to original value and exit
    te.txt = te.initial_value
    te.exit()
  elseif keyboard.state.ENTER then
    -- Done, so exit
    te.exit()
  elseif keyboard.state.BACKSPACE then
    -- Do the backspace
    te.txt = string.sub(te.txt, 1, -2)
    if te.check then
      te.warn = te.check(te.txt)
    end
     
    -- Highlight the backspace char
    local new_pos = string.find(te.available_chars, backspace_key)
    if new_pos ~= nill then te.pos = new_pos end
    
    te.redraw()
  end
end


-- Called when regular character is typed
local function keychar(a)
  log.debug("In keychar() a="..a)
  
  -- Determine which position the char is at so that it will be highlighted
  local new_pos = string.find(te.available_chars, a)
  if new_pos ~= nill then te.pos = new_pos end

  -- Add the new character
  te.txt = te.txt .. a
  if te.check then
    te.warn = te.check(te.txt)
  end
  
  te.redraw()
end


-- Used if no check() callback specified when te.enter() is called.
-- Warning message returned if name is longer than 15 chars.
local function standard_check(txt)
  if string.len(txt) > 15 then
    return "Name too long"
  else
    return nil
  end
end


--- Called to setup and enter textentry screen.
-- @tparam callback: function to be called when user finished editing text
-- @tparam default: the initial value of the text
-- @tparam heading: text to be displayed at top of screen to explain context
-- @tparam check: function for takes in current text and returns a warning str if there is a problem
local function modified_enter_function(callback, default, heading, check)
  log.debug("Using modified textentry. default="..default.." heading="..heading)
  te.txt = default or ""
  te.initial_value = default or "" -- For if esc hit
  te.heading = heading or ""
  -- Index of current char. Initially select the OK button so can easily store by hitting key3
  te.pos = 1 
  te.callback = callback
  te.check = check and check or standard_check
  te.warn = nil
  te_kbd_cb.code = keycode
  te_kbd_cb.char = keychar
  
  -- Remember original font
  te.font_size_original = screen.current_font_size()
  te.font_face_original = screen.current_font_face()
  te.aa_original = screen.current_aa()

  if norns.menu.status() == false then
    -- Not coming from a menu screen.
    -- Store current key, enc, redraw, and refresh functions so can be restored later
    te.key_restore = key
    te.enc_restore = enc
    te.redraw_restore = redraw
    te.refresh_restore = refresh
    
    -- Switch to textentry key, enc, and redraw functions
    key = te.key
    enc = te.enc
    norns.menu.init()
    redraw = norns.none
  else
    -- Coming from a menu screen.
    -- Store current key, enc, redraw, and refresh functions so can be restored later
    te.key_restore = norns.menu.get_key()
    te.enc_restore = norns.menu.get_enc()
    te.redraw_restore = norns.menu.get_redraw()
    te.refresh_restore = norns.menu.get_refresh()
    
    -- Switch to textentry key, enc, and redraw functions
    norns.menu.set(te.enc, te.key, te.redraw, te.refresh)
  end
  
  te.redraw()
end


-- Called when user done with text entry. Calls the callback that was setup.
-- The differene of this function from the original source code is that it
-- also restores font info since the modified text entry mucks around with the font. 
local function modified_exit_function()
  te_kbd_cb.code = nil
  te_kbd_cb.char = nil

  -- Restore the key, enc, redraw, and refresh functions
  if norns.menu.status() == false then
    -- Was in the app (not in a menu) so manually restore the functions
    key = te.key_restore
    enc = te.enc_restore
    redraw = te.redraw_restore
    refresh = te.refresh_restore
    norns.menu.init()
  else
    -- Was in a menu so use menu.set() to restare the functions
    norns.menu.set(te.enc_restore, te.key_restore, te.redraw_restore, te.refresh_restore)
  end
  
  -- Restore font
  screen.font_size(te.font_size_original)
  screen.font_face(te.font_face_original)
  screen.aa(te.aa_original)
  
  -- Call the callback
  if te.txt then 
    log.debug("Textentry exiting and calling callback for text="..te.txt)
    te.callback(te.txt)
  else 
    te.callback(nil) 
  end
end


-- Called when key hit when in textentry screen
local function modified_key_function(n,z)
  -- If key2 pressed then done. Exit and go back to previous screen
  if n==2 and z==1 then
    te.exit()
    return
  end
  
  -- If key3 pressed then add selected character to the string
  if n==3 and z==1 then
    local ch = string.sub(te.available_chars, te.pos, te.pos)
    
    if ch == backspace_key then
      -- Backspace, so remove last character
      te.txt = string.sub(te.txt, 1, -2)
    elseif ch == enter_key then
      -- Enter key so done
      te.exit()
      return
    else
      -- Regular character so append simply append it
      te.txt = te.txt .. ch
    end 
    
    -- Since the text has changed, redraw
    te.redraw()
  end
end


-- Called when encoder turned when in textentry screen. Can use enc2 or enc3.
local function modified_enc_function(n,delta)
  -- If neither encoder 2 or 3 then ignore
  if n==1 then return end
  
  -- Determine position of character now selected. 
  te.pos = te.pos + delta
  
  -- Make sure not beyond the limits
  te.pos = math.max(te.pos, 1)
  te.pos = math.min(te.pos, string.len(te.available_chars))
  
  -- Now that te.pos has been determined, redraw to update display
  te.redraw()
end


-- Draws the text entry screen
local function modified_redraw_function()
  screen.clear()
  
  -- Draw heading (specified when te.enter() called)
  screen.font_face(1) -- Standard Norns font
  screen.aa(0)
  screen.font_size(8)
  screen.level(5)
  screen.move(0,16)
  screen.text(te.heading)

  -- Draw the label  
  screen.font_face(1) -- Standard Norns font
  screen.font_size(8)
  screen.level(5)
  screen.move(0, 32)
  local label = "Name: "
  screen.text(label)
  
  -- Draw the current text string
  screen.font_face(4) -- Roboto Regular Light (Thin lower case chars were hard to read)
  screen.aa(0)
  local label_width = screen.text_untrimmed_extents(label)
  screen.move(label_width, 32)
  screen.font_size(10)
  screen.level(15)
  screen.text(te.txt)
  
  -- Draw cursor at end to show where text will be added
  local text_width = screen.text_untrimmed_extents(te.txt)
  screen.move(label_width + text_width, 32)
  screen.level(2)
  screen.text("_") -- The cursor
  
  -- If warning text specified then draw it below name being entered.
  -- Nice that it isn't inline so that the name can take up more space.
  if te.check then
    te.warn = te.check(te.txt)
	end
  if te.warn ~= nil then
    screen.font_face(1) -- Standard Norns font
    screen.font_size(8)
    screen.level(3)
    screen.move(label_width, 39)
    screen.text(te.warn)
  end
  
  -- Draw 16 of the characters that can be entered
  screen.font_face(1) -- Standard Norns font
  screen.font_size(8)
  local index_of_selected = 5
  local needed_extra_horiz_space = 0 -- For when outputing more than just single char
  for i=0, 15 do
    -- If selected character (the index_of_selected one) then highlight it with level 15. 
    -- Otherwise use level 3.
    if i == index_of_selected then screen.level(15) else screen.level(3) end

    -- Determine the index of the character in the string. te.pos indicates which is 
    -- the selected one
    local char_index = te.pos + i - index_of_selected
      
    -- Draw the current character in the proper place. Each char gets 8 pixels width
    if char_index > 0 and char_index <= string.len(te.available_chars) then
      screen.move(i*8 + needed_extra_horiz_space, 48)
      local ch = string.sub(te.available_chars, char_index, char_index)
      if ch == backspace_key then
        -- Special backspace character so show something special
        screen.text("<-")
        needed_extra_horiz_space = needed_extra_horiz_space + 5
      elseif ch == enter_key then
        -- Enter key. Display as SAVE
        screen.text("SAVE")
        needed_extra_horiz_space = needed_extra_horiz_space + 14
      else
        -- Regular character so simply draw it
        screen.text(ch)
      end
    end
  end
  
  -- Draw instructions
  screen.font_face(1) -- Standard Norns font
  screen.level(2)
  screen.move(0, 64)
  screen.text("Use k3 to SAVE or add char")
  
  screen.update()
end


-- This function will be called before init() is done via magic of hooks.
-- Stores original function pointers and switches to use the modified functions.
local function initialize_textentry()
  -- If NornsLib not enabled for this app then don't do anything
  if not nornsLib.enabled() then return end
  
  te._original_redraw_function = te.redraw
  te.redraw = modified_redraw_function
  
  te._original_enc_function = te.enc
  te.enc = modified_enc_function
  
  te._original_key_function = te.key
  te.key = modified_key_function
  
  te._original_enter_function = te.enter
  te.enter = modified_enter_function
  
  te._original_exit_function = te.exit
  te.exit = modified_exit_function
end


-- Will be called by script_post_cleanup hook when script is being shut down.
-- Restores the textentry functions to their originals
local function finalize_textentry()
  -- If NornsLib not enabled for this app then don't do anything
  if not nornsLib.enabled() then return end
  
  te.redraw = te._original_redraw_function
  
  te.enc = te._original_enc_function
  
  te.key = te._original_key_function
  
  te.enter = te._original_enter_function
  
  te.exit = te._original_exit_function
end


-- Configure the pre-init and a post-cleanup hooks in order to modify system 
-- code before init() and then to reset the code while doing cleanup.
local hooks = require 'core/hook'
hooks["script_pre_init"]:register("pre init for NornsLib textentry extension", 
  initialize_textentry)
hooks["script_post_cleanup"]:register("post cleanup for NornsLib textentry extension",
  finalize_textentry)
