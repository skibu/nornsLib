-- Extensions for making it easier for user to set parameters. 
-- Key improvements are:
--   * If have a selector with a value and a label, this extension will make 
--     sure they don't overlap.
--   * When user hits key1 they are automatically brought to the parameters page
--     so that they don't have to go through complicated key and encoder sequence
--     to get there.

------------------------------------------------------------------------------------------

print("Loading nornsLib/parameterExt.lua")

-- load the nornsLib  mod to setup system hooks
local nornsLib = require "nornsLib/nornsLib"

-- Get access to the PARAMS menu class. 
local params_menu = require "core/menu/params"

-- For logging
local log = require "nornsLib/loggingExt"

-- So can be used with require and as a module
local ParameterExt = {}

------------------------------------------------------------------------------------------
------------- Local functions that had to be copied from core/menu/params.lua ------------
------------------------------------------------------------------------------------------

-- mEDIT is a local in lua/core/menu/params.lua so needs to be duplicated here
local mEDIT = 1

  
---------------------------------------------------------------------------------------  
-- These functions need to be loaded everytime since it is a global function. Therefore
-- it is defined before the code that returns from this script if was read in before.
-------------------------------------------------------------------------------------

local first_time_jumping_to_edit_params = true

-- Jumps from the application screen to the script's Params Edit screen so that user can 
-- easily change app params. For when k1 pressed from within the script. Really nice
-- feature since it makes param changes easier. This function should be called in the
-- script's key() method for key1 is released. 
function ParameterExt.jump_to_edit_params_screen()
  log.debug("Jumping to parameter menu screen")
  
  -- Change to menu mode 
  _menu.set_mode(true) 

  -- Remember current mode so that can return to it if k2 pressed
  params_menu.mode_prev = params_menu.mode

  -- Go to EDIT screen of the PARAMS menu. Needed in case user was at another PARAMS 
  -- screen, like PSET.
  params_menu.mode = mEDIT

  -- tSEPARATOR and tTEXT are locals in paramset.lua so get them from metatable
  local params_metatable = getmetatable(params)
  local tSEPARATOR = params_metatable.tSEPARATOR
  local tTEXT = params_metatable.tTEXT
  
  -- Set to first settable item if the first time jumping to edit params menu.
  -- But if have already done this then should just keep the user's previous
  -- selection.
  if first_time_jumping_to_edit_params then
    first_time_jumping_to_edit_params = false
    
    params_menu.pos = 0 -- For if don't find appropriate one
    for idx=1,#params.params do
      if params:visible(idx) and params:t(idx) ~= tSEPARATOR and params:t(idx) ~= tTEXT then
        params_menu.pos = idx - 1 -- oddly the index for parameters is zero based
        break
      end
    end
  end
  
  -- Change to PARAMS menu screen
  _menu.set_page("PARAMS")

  -- Initialize the params page in case haven't done so previously
  params_menu.init()
end

---------------------------------------------------------------------------------------
----------------------------- So can determine what caused a bang() -------------------
---------------------------------------------------------------------------------------

-- Turns out that it can be really useful to know for an Option if a bang() originated 
-- by user turning encoder on the mEDIT parameters menu page, or due to all the options
-- being set at once due to a preset being loaded or some other reason. By understanding
-- the source of the bang the action callback can determine whether other parameters
-- need to be updated as well. This function returns true if user currently on the
-- mEDIT parameter editing menu page, which indicates that a bang() came from user 
-- updating parameter using encoder.
function params.in_param_edit_menu()
  return _menu.mode == true and _menu.page == "PARAMS" and params_menu.mode == mEDIT
end

---------------------------------------------------------------------------------------
----------------------------- fix for ParamSet:bang() --------------------------------
---------------------------------------------------------------------------------------

-- Turns out that in lua/core/clock.lua that params:bang("clock_tempo") is called to
-- bang just the single parameter. But the standard bang() function bangs *ALL* 
-- parameters, which is not desired. So this definition overrides the bang function
-- so that only a single param can be banged. If id not specified then all all banged.
function params:bang(id)
  log.debug("doing ParamSet:bang() for param id="..tostring(id))
  for _,v in pairs(self.params) do
    if (id == nil or id == v.id) and v.t ~= self.tTRIGGER and 
       not (v.t == self.tBINARY and v.behavior == 'trigger' and v.value == 0) then
      v:bang()
    end
  end
end


---------------------------------------------------------------------------------------  
------------------ Helper functions for preventing overlapping text--------------------
---------------------------------------------------------------------------------------  

-- An option for specifying a function that can shorten the string when it is too long.
-- This function will only be called when a parameter value is too long to fit without
-- overlapping. The function should take in the string parameter value and return the
-- possibly shorter version. A way this might be done to remove spaces after commas
-- is: function shorten() return param:gsub(", ", ",") end
local _shortener_function = nil
function ParameterExt.set_selector_shortener(shortener_function)
  _shortener_function = shortener_function
end


-- Normally the value text for menu parameters are displayed right justified. But it
-- can look better to have them be left justified and thereby line up visually.
local _left_align = false
function ParameterExt.set_left_align_parameter_values(should_left_align)
  _left_align = should_left_align
end


-- Remember the original functions so they can be used in output_value_without_overlap()
local _original_text_right_func = screen.text_right
local _original_text_func = screen.text


-- Display current selector value for param param_idx. But do so without the
-- value overlapping the label.
-- Replacement for code in norns/lua/core/menu/params.lua
local function output_value_without_overlap(value_str, label_str)
  -- If value is nil don't try to process it
  if value_str == nil then return end
  
  local label_width = screen.text_untrimmed_extents(label_str)
  local value_width = screen.text_untrimmed_extents(value_str)
  local orig_font_size = screen.current_font_size()
  local orig_font_face = screen.current_font_face()
  local orig_aa = screen.current_aa()
  
  -- If label & value combined is too wide then adjust
  if label_width + value_width + 0 > 128 then
    -- The value text is too long. First try shortening the text if a shortener 
    -- function was specified
    if _shortener_function ~= nil then
      -- Get possibly shorter value_str and see if now narrow enough
      value_str = _shortener_function(value_str)
      value_width = screen.text_untrimmed_extents(value_str)
    end
    
    -- If still too wide try using narrower font
    if label_width + value_width + 0 > 128 then
      -- The value text is too long. Try using smaller font. It is important to make
      -- sure that anti-aliasing is off because it screws up some small fonts like Roboto.
      -- The font for the edit params page is set in core/menu.lua _menu.set_mode(). 
      -- Default font size is 8 and default font face is 1. 
      --
      -- To understand the fonts really need to use nornsFun/bestFont.lua script. 
      -- 
      -- Font 1 Norns size 8 get 28 chars - default. Looks good, but would like to get more chars.
      -- Font 1 Norns size 7 get 28 1/2 chars - readable but not really any narrower
      -- Font 2 Liquid size 8 get 34 1/2 chars - pretty readable chars, but looks really funny
      -- Font 5 Roboto-Regular size 7 get 37 chars - really narrow, but just not readable enough
      -- font 25 bmp size 6 get 31 chars - quite readable. Not much more narrow, but seems like best
      screen.aa(0)
      screen.font_face(25)
      screen.font_size(6)
      value_width = screen.text_untrimmed_extents(value_str)
    end
  end    
      
  -- Now need to draw the value. If should left align, which also is true if text is still too
  -- wide, then simply left align
  if _left_align or label_width + value_width + 0 > 128 then
    -- Output text left aligned
    current_x, current_y = screen.current_point()
    screen.move(label_width + 2, current_y)
    _original_text_func(value_str)
  else
    -- Output text right aligned. Don't need to move the drawing point since this was original plan
    _original_text_right_func(value_str)
  end

  -- If font size, face, or anti-aliasing were changed, restore them
  if screen.current_font_size() ~= orig_font_size then screen.font_size(orig_font_size) end
  if screen.current_font_face() ~= orig_font_face then screen.font_face(orig_font_face) end
  if screen.current_aa() ~= orig_aa then screen.aa(orig_aa) end
end


----------------------------------------------------------------------------------
------------------------- Make sure selector text doesn't overlap ----------------
----------------------------------------------------------------------------------

-- Need screen extensions to get current font values when redrawing
require "nornsLib/screenExt"


-- For keeping track of original text() and text_right() functions so they can be called
local original_text_func
local original_text_right_func

-- For keeping track of labels. Set in special_screen_text
local possible_label

-- So can temporarily switch to using special screen.text() function that stores the last
-- text written using screen.text(value)
local function special_screen_text(value)
  possible_label = value
  original_text_func(value)
end
  
-- If the value and label are short such that there could not be overlap 
-- then just use original simple text_right() function 
local function special_screen_text_right(value)
  if value ~= nill and possible_label ~= nil and 
      string.len(value) + string.len(possible_label) < 24 and 
      not _left_align then
    original_text_right_func(value)
  else
    -- Either need to left align value or longish labels so make sure they don't overlap
    output_value_without_overlap(value, possible_label)
  end
end


-- This code copied directly from core/menu/params.lua
local page = nil

local function build_page()
  page = {}
  local i = 1
  repeat
    if params:visible(i) then table.insert(page, i) end
    if params:t(i) == params.tGROUP then
      i = i + params:get(i) + 1
    else i = i + 1 end
  until i > params.count
end


-- For displaying the parameter list. Mostly copied directly from core/menu/params.lua, 
-- but modified to not highlight separators since user can't change them. Also, the
-- header modified. To be called when m.mode == mEDIT.
local function params_list_redraw()
  screen.clear()
  
  -- Since the original redraw() uses "m"
  local m = params_menu
  
  -- Need to create the page local variable
  build_page()
  
  if m.pos == 0 then
    -- Modified to display a nicer title for the menu screen
    local title = m.group and "Parameters / " .. m.groupname or "Parameters for " .. norns.state.shortname
    screen.level(4)
    screen.move(0,10)
    screen.text(title)
  end
  for i=1,6 do
    if (i > 2 - m.pos) and (i < #page - m.pos + 3) then
      local p = page[i+m.pos-2]
      local t = params:t(p)
      if i==3 and t ~= params.tSEPARATOR then screen.level(15) else screen.level(4) end
      if t == params.tSEPARATOR then
        screen.move(0,10*i+2.5)
        screen.line_rel(127,0)
        screen.stroke()
        screen.move(63,10*i)
        screen.text_center(params:get_name(p))
      elseif t == params.tGROUP then
        screen.move(0,10*i)
        screen.text(params:get_name(p) .. " >")
      else
        screen.move(0,10*i)
        screen.text(params:get_name(p))
        screen.move(127,10*i)
        if t ==  params.tTRIGGER then
          if _menu.binarystates.triggered[p] and _menu.binarystates.triggered[p] > 0 then
            screen.rect(124, 10 * i - 4, 3, 3)
            screen.fill()
          end
        elseif t == params.tBINARY then
          fill = _menu.binarystates.on[p] or _menu.binarystates.triggered[p]
          if fill and fill > 0 then
            screen.rect(124, 10 * i - 4, 3, 3)
            screen.fill()
          end
        else
          screen.text_right(params:string(p))
        end
      end
    end
  end
  
  screen.update()
end


-- The modified redraw() function. Temporarily switches to using special screen.text() 
-- and screen.text_right() functions that allow output_value_without_overlap() to
-- be called instead of screen.text_right. This way can make sure that the option
-- label and values don't overlap. 
local function modified_params_menu_redraw()
  -- Temporarily switch to using special screen.text() function that stores the last
  -- text written using screen.text(str)
  original_text_func = screen.text
  screen.text = special_screen_text
  
  -- Temporarily switch to using special screen.text_right() function that if text too
  -- wide it draws it smaller so that it won't overlap with the label text written to
  -- the left.
  original_text_right_func = screen.text_right
  screen.text_right = special_screen_text_right

  if params_menu.mode == mEDIT then
    -- Since on mEDIT screen display it using special function
    params_list_redraw()
  else
  -- Call the original redraw function, which will in turn use the temporary 
  -- screen.text() and screen.text_right() functions
    params_menu._original_params_menu_parameter_redraw()
  end
  
  -- Restore the screen.text() and screen.text_right() functions
  screen.text = original_text_func
  screen.text_right = original_text_right_func
end


----------------------------------------------------------------------------------
---------- Handle key1 better and be able to jump straight to params page --------
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


-- This was copied verbatim from original code
t.event = function(_)
  _menu.key(1,1)
  pending = false
  if _menu.mode == true then _menu.redraw() end
end


-- Overriding the key() function in lua/core/menu.lua to better handle key1 inputs.
local function modified_norns_key(n, z)
  log.debug("In overriden _norns.key() and n="..n.. " z="..z)
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


-- Will be called by script_post_cleanup hook when script is being shut down.
-- Restores the pset functions to their originals
local function _initialize_parameters()
  -- If NornsLib not enabled for this app then don't do anything
  if not nornsLib.enabled() then return end
  
  _norns._original_key_function = _norns.key
  _norns.key = modified_norns_key
  
  params_menu._original_params_menu_parameter_redraw = params_menu.redraw
  params_menu.redraw = modified_params_menu_redraw
end


-- Will be called by script_post_cleanup hook when script is being shut down.
-- Restores the pset functions to their originals
local function _finalize_parameters()
  -- If NornsLib not enabled for this app then don't do anything
  if not nornsLib.enabled() then return end
  
  _norns.key = _norns._original_key_function
  
  params_menu.redraw = params_menu._original_params_menu_parameter_redraw
end

-- Configure the pre-init and a post-cleanup hooks in order to modify system 
-- code before init() and then to reset the code while doing cleanup.
-- Note: the numbers in the names are so that the hooks for parameterExt and
-- psetExt are called in proper order, which is done alphabetically. Needed to
-- make sure that since params_menu.redraw() is modified in both, that the
-- init order is the oppose of the finalize order.
local hooks = require 'core/hook'
hooks["script_pre_init"]:register("(2) pre init for NornsLib parameter extension", 
  _initialize_parameters)
hooks["script_post_cleanup"]:register("(1) post cleanup for NornsLib parameter extension",
  _finalize_parameters)


-----------------------------------------------------------------------------------------
-------------------- Have Option parameter store string instead of index ----------------
-----------------------------------------------------------------------------------------

local option = require 'core/params/option'

-- Remember the original get() function by adding it to the Option class
if option.get ~= option._original_get_function then
  option._original_get_function = option.get
end  

-- Overriding get() so that it instead returns string(). This way when writing preset
-- get the value instead of the index.
function option:get()
  -- If the parameter is not to be saved then it is a special system param like 
  -- "clock_source". In this case, or if tweaking encoders or keys in parameter 
  -- editor menu, should return the usual index value.
  if not self.save or params.in_param_edit_menu() then 
    return option._original_get_function(self)
  end
  
  str = self:string()
  log.debug("In modified Option:get() for option id="..self.id.." return value="..str)
  return str
end


-- Remember the original set() function by adding it to the Option class
if option.set ~= option._original_set_function then
  option._original_set_function = option.set
end  

--- Overriding set so that can take a string value or an integer value. 
-- Used when reading presets. This just adds functionality so don't need
-- to restore the original function at the end.
-- @tparam str
-- @tparam silent if true then won't bang the parameter
function option:set(str, silent)
  -- Convert str to index
  local index = tonumber(str)
  -- If str is not an integer so determine the index of the str in the Option
  if index == nil or math.floor(index) ~= index then
    -- str is not an integer so find the index where it is the option
    for k, v in ipairs(self.options) do
      if v == str then 
        index = k 
        break 
      end
    end
  end
  
  log.debug("In modified Option:set() id="..self.id.." index="..tostring(index).." str="..str)
  
  -- Call original set function using index
  option._original_set_function(self, index, silent)
end


return ParameterExt