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


local te_kbd_cb = require 'lib/textentry_kbd'
local keyboard = require 'core/keyboard'
local te = require "textentry"


-- Something to do with keyboard, but not sure what
local function keycode(c, value)
  if keyboard.state.ESC then
    te.txt = nil
    te.exit()
  elseif keyboard.state.ENTER then
    te.exit()
  elseif keyboard.state.BACKSPACE then
    te.row = 1
    te.delok = 0
    te.txt = string.sub(te.txt,0,-2)
    if te.check then
      te.warn = te.check(te.txt)
    end
    te.redraw()
  end
end

-- Not sure what this is for
local function keychar(a)
  te.row = 0
  te.pos = string.byte(a) - 5 - 32
  te.txt = te.txt .. a
  if te.check then
    te.warn = te.check(te.txt)
  end
  te.redraw()
end

-- The characters that user can select from. First one is backspace char, 0x08
local backspace = "\u{0008}"
local available_chars = 
  backspace.."abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890.,-_=+#$%*<>"

-- Called to setup and enter textentry screen.
-- @param callback: function to be called when user finished editing text
-- @param default: the initial value of the text
-- @param heading: text to be displayed at top of screen to explain context
-- @param check: function for takes in current text and returns a warning str if there is a problem
te.enter = function(callback, default, heading, check)
  util.debug_tprint("Using modified textentry. default="..default.." heading="..heading)
  te.txt = default or ""
  te.heading = heading or ""
  te.pos = 2 -- Index of current char. Initially select the 2nd char, which is letter 'a'
  te.callback = callback
  te.check = check
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
te.exit = function()
  te_kbd_cb.code = nil
  te_kbd_cb.char = nil

  -- Restore the key, enc, redraw, and refresh functions
  if norns.menu.status() == false then
    key = te.key_restore
    enc = te.enc_restore
    redraw = te.redraw_restore
    refresh = te.refresh_restore
    norns.menu.init()
  else
    norns.menu.set(te.enc_restore, te.key_restore, te.redraw_restore, te.refresh_restore)
  end
  
  -- Restore font
  screen.font_size(te.font_size_original)
  screen.font_face(te.font_face_original)
  screen.aa(te.aa_original)
  
  -- Call the callback
  if te.txt then 
    util.dprint("Textentry exiting and calling callback for text="..te.txt)
    te.callback(te.txt)
  else 
    te.callback(nil) 
  end
end


-- Called when key hit when in textentry screen
te.key = function(n,z)
  -- If key2 pressed then done. Exit and go back to previous screen
  if n==2 and z==1 then
    te.exit()
    return
  end
  
  -- If key3 pressed then add selected character to the string
  if n==3 and z==1 then
    local ch = string.sub(available_chars, te.pos, te.pos)
    
    if ch ~= backspace then
      -- Append the new character
      te.txt = te.txt .. ch
    else
      -- Backspace, so remove last character
      te.txt = string.sub(te.txt, 1, -2)
    end 
    
    -- Since the text has changed, redraw
    te.redraw()
  end
end


-- Called when encoder turned when in textentry screen. Can use enc2 or enc3.
te.enc = function(n,delta)
  -- If neither encoder 2 or 3 then ignore
  if n==1 then return end
  
  -- Determine position of character now selected. 
  te.pos = te.pos + delta
  
  -- Make sure not beyond the limits
  te.pos = math.max(te.pos, 1)
  te.pos = math.min(te.pos, string.len(available_chars))
  
  -- Now that te.pos has been determined, redraw to update display
  te.redraw()
end


-- Draws the text entry screen
te.redraw = function()
  screen.clear()
  
  -- Draw heading (specified when te.enter() called)
  screen.font_face(1) -- Standard Norns font
  screen.aa(0)
  screen.font_size(8)
  screen.level(5)
  screen.move(0,16)
  screen.text(te.heading)
  
  -- Draw the current text string
  screen.font_face(1) -- Standard Norns font
  screen.font_size(8)
  screen.level(5)
  screen.move(0, 32)
  local label = "Name: "
  screen.text(label)
  
  screen.font_face(5) -- Roboto Regular
  screen.aa(1)
  screen.move(screen.text_untrimmed_extents(label), 32)
  screen.font_size(11)
  screen.level(15)
  screen.text(te.txt)
  
  -- If warning text specified then draw it on the right side
  if te.check then
    te.warn = te.check(te.txt)
	end
  if te.warn ~= nil then
    screen.font_face(1) -- Standard Norns font
    screen.font_size(8)
    screen.level(7)
    screen.move(128,32)
    screen.text_right(te.warn)
  end
  
  -- Draw 16 of the characters that can be entered
  screen.font_face(1) -- Standard Norns font
  screen.font_size(8)
  local index_of_selected = 5
  for i=0, 15 do
    -- If selected character (the index_of_selected one) then highlight it with level 15. 
    -- Otherwise use level 3.
    if i == index_of_selected then screen.level(15) else screen.level(3) end

    -- Determine the index of the character in the string. te.pos indicates which is 
    -- the selected one
    local char_index = te.pos + i - 4
      
    -- Draw the current character in the proper place. Each char gets 8 pixels width
    if char_index > 0 and char_index <= string.len(available_chars) then
      screen.move(i*8, 46)
      local ch = string.sub(available_chars, char_index, char_index)
      if ch ~= backspace then
        -- Regular character so simply output it
        screen.text(ch)
      else
        -- Special backspace character so show something special
        screen.text("<-")
      end
    end
  end
  
  -- Draw instructions
  screen.font_face(1) -- Standard Norns font
  screen.level(2)
  screen.move(0, 64)
  screen.text("k3 to add char, k2 when done")
  
  screen.update()
end
