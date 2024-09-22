-- For making the PSET menu screen easier to use. 

-- load the nornsLib  mod to setup system hooks
local nornsLib = require "nornsLib/nornsLib"

-- Get access to the PARAMS menu class. Also use the name "m" since that is what
-- is used in the original code.
local params_menu = require "core/menu/params"
local m = params_menu

-- For logging
local log = require "nornsLib/loggingExt"

local textentry = require "textentry"

-- So can be used as module using require instead of include
local PsetExt = {}

------------------------------------------------------------------------------------------
------------- Local functions that had to be copied from core/menu/params.lua ------------
------------------------------------------------------------------------------------------

-- mSELECT and others are locals in lua/core/menu/params.lua so need to be duplicated here
local mSELECT = 0
local mEDIT = 1
local mPSET = 2
local mPSETDELETE = 3

-- Process the PSET files and puts them into the pset member of _menu.m.PARAMS so easily
-- accessible. Needed to copy some of this code directly from core/menu/params.lua since  
-- pset is a local there.
m.pset = {}

-- Duplication of the original code, which was needed to be done since it was
-- declared local.
local function pset_list(results)
  m.pset = {}
  m.ps_n = 0
 
  local t = {}
  for filename in results:gmatch("[^\r\n]+") do
    table.insert(t,filename)
  end

  for _,file in pairs(t) do
    local n = tonumber(file:match"(%d+).pset$")
    if not n then n=1 end
    --print(file,n)
    local name = norns.state.shortname
    local f = io.open(file,"r")
    io.input(file)
    local line = io.read("*line")
    if util.string_starts(line, "-- ") then
      name = string.sub(line,4,-1)
    end
    io.close(f)
    m.pset[n] = {file=file,name=name}
    m.ps_n = math.max(n, m.ps_n)
  end
  
  m.ps_n = m.ps_n + 1
  
  -- Set ps_pos to point to first pset, if there is one
  m.ps_pos = #m.pset >= 1 and 1 or 0
  
  _menu.redraw()
end


-- This function reads stored PSET files and calls pset_list() on the data so it is 
-- put into the local pset. Needed to copy directly from core/menu/params.lua since 
-- it is a local there and it sets the pset local. This function is not made local
-- here so that it can be accessed by parameterExt.lua
local function init_pset()
  log.debug("psetExt scanning all psets...")
  norns.system_cmd('ls -1 '..norns.state.data..norns.state.shortname..'*.pset | sort', 
    pset_list)
end


-- Deletes the current pset specified by m.ps_pos. This was not actually from 
-- lua/menu/params.lua, but should have been. Note: in params.lua was using
-- zero indexed ps_pos but here using 1 based ps_pos for consistency with lua.
local function delete_pset(ps_pos)
  -- Delete the file
  params:delete(m.pset[ps_pos].file,
    m.pset[ps_pos].name,
    string.format("%02d", ps_pos))
  
  init_pset()
end


-- Writes the index of the param set to the file dust/data/<app-name>/pset-last.txt .
-- Note: the pset-last.txt file is read in in script.lua in Script.load(). Since
-- the read is hardcoded, can't change the name of the file. It is stored in
-- norns.state.pset_last at startup and when changes are made. But it doesn't 
-- appear to be automatically used to load pset at startup of app. Need to call
-- params:read(norns.state.pset_last) or simply params:read() or simplest 
-- params:default() to do that.
local function write_pset_last(ps_pos)
  log.debug("In write_pset_last() and ps_pos="..ps_pos)
  local file = norns.state.data.."pset-last.txt"
  local f = io.open(file,"w")
  io.output(f)
  io.write(ps_pos)
  io.close(f)
  norns.state.pset_last = ps_pos
end


-- Need to define function before it is used in write_pset()
local pset_save_redraw

-- Writes the specified param set, and also writes it as the last one. Called
-- when user finishes with the textentry window.
local function write_pset(name)
  log.debug("In write_pset() and name="..tostring(name).." and m.ps_pos="..m.ps_pos)

  -- Do nothing if name is nil
  if name == nil then return end
  
  -- Original code uses the secret params.name, the name of the preset, if name is empty string
  if name == "" then name = params.name end
  
  -- Write the preset file
  params:write(m.ps_pos, name)
  
  -- Remember that the past preset used is ps_pos, and then store that info in the pset_last file
  m.ps_last = m.ps_pos
  write_pset_last(m.ps_pos) -- save last pset loaded
  
  -- since change was made need to reload param sets
  init_pset()
  
  -- write parameter map file too
  norns.pmap.write()        
  
  -- Display that saving the param set
  pset_save_redraw()
end


-- This function didn't exist in params.lua but it should have
local function load_pset(ps_pos)
  if ps_pos <= #m.pset then
    log.debug("Loading param set #"..ps_pos)
    params:read(ps_pos)
    m.ps_last = ps_pos
    write_pset_last(ps_pos) -- save last pset loaded
  end
end        

-------------------- Functions being overwritten to specially handle PSET Menu --------------

-- Returns displayable name of the specified PSET
local function get_pset_name(index)
  if index == 0 then return "(None specified)" end
  
  -- Determine name to be displayed
  local name
  if index <= #m.pset and m.pset[index].name ~= nill then
    name = m.pset[index].name
  else
    name = "(unnamed)"
  end  
  
  return index..") " .. name
end


-- Replacement pset menu redrawing code. Replaces what is from core/menu/params.lua    
local function pset_menu_redraw()
  screen.clear()
  
  -- Header for the menu
  screen.level(4)
  screen.move(0,10)
  screen.text("Presets Storage (PSET)")
  
  -- Display the current parameter set. First display the label
  local top = 24
  screen.move(0, top)
  screen.level(9)
  local pset_label = "Preset: "
  screen.text(pset_label)
  
  -- Display the selected preset
  screen.move(screen.text_untrimmed_extents(pset_label), top)
  screen.level(15)
  local pset_name = (m.ps_pos == m.ps_last and "*" or "") ..get_pset_name(m.ps_pos)
  screen.text(pset_name)

  -- Draw separator since the param set selector and the actions are such different things
  screen.level(6)
  screen.line_width(1.0)
  screen.aa(0)
  screen.move(14, top+6)
  screen.line(70, top+6)
  screen.stroke()
  
  -- Draw PSET menu actions
  screen.move(0, top+15)
  local v = (m.ps_action == 1) and 15 or 4
  screen.level(v)
  screen.text("Save with Name >")
  
  screen.move(0, top+25)
  v = (m.ps_action == 2 and m.ps_pos <= #m.pset) and 15 or 4
  screen.level(v)
  screen.text("Load >")
  
  screen.move(0, top+35)
  v = (m.ps_action == 3 and m.ps_pos <= #m.pset) and 15 or 4
  screen.level(v)
  screen.text("Delete >")
  
  screen.update()
end


-- Replacement pset delete menu redrawing code. Replaces what is from core/menu/params.lua    
local function pset_delete_menu_redraw()
  screen.clear()
  
  screen.move(63, 30)
  screen.level(15)
  screen.text_center("Delete "..get_pset_name(m.ps_pos).." ?")

  screen.level(2)
  screen.move(63, 61)
  screen.text_center("Key3 for yes, Key2 for no")
  
  screen.update()
end


-- Need to define pset_save_redraw this way since it is used above before it is set
pset_save_redraw = function()
  screen.clear()
  
  screen.move(63, 30)
  screen.level(15)
  screen.text_center("Saving...")
  
  screen.update()
  
  util.sleep(0.6)
end


local function pset_load_redraw()
  screen.clear()
  
  screen.move(63, 30)
  screen.level(15)
  screen.text_center("Loading...")
  
  screen.update()
  
  util.sleep(0.6)
end


-- For telling user that the item being deleted. Displays "Deleting..." and then pauses
-- fraction of a second.
local function pset_delete_redraw()
  screen.clear()
  
  screen.move(63, 30)
  screen.level(15)
  screen.text_center("Deleting...")
  
  screen.update()
  
  util.sleep(0.6)
end


-- So that app can have a "PSET >" toggle parameter in the parameter list that takes
-- the user directly to the PSET page. This makes it easier for user to save/load/delete
-- parameters.
--
-- To use, can setup the following parameter:
--    params:add_separator("Save or load presets")
--    params:add_trigger("pset", "PSET >") 
--    params:set_action("pset", jump_to_pset_screen )
function PsetExt.jump_to_pset_screen()
  log.debug("Jumping to parameter save/load/delete menu screen")
  
  -- Most likely already in menu mode, but explicitly change to it just to be safe 
  _menu.set_mode(true) 
  
  -- Remember current mode so that can return to it if k2 pressed
  params_menu.mode_prev = params_menu.mode
  
  -- Since had to have a local version of init_pset(), can call it directly. This 
  -- means that can just set params_menu.mode to mPSET in order to go to that window,
  -- and call init_pset()
  params_menu.mode = mPSET
  init_pset()
end


----------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------

-- params_menu is the menu that contains the params. This is the one that needs to have 
-- function ptrs modified. Therefore using hooks to store the original functions at init
-- and then restore them back to the original when finalizing script.

local function modified_redraw_function()
  -- If drawing the PSET menu then use the new PSET functions
  if params_menu.mode == mPSET then
    pset_menu_redraw()
    return
  elseif params_menu.mode == mPSETDELETE then
    pset_delete_menu_redraw()
    return
  end
  
  -- Was not a special PSET menu request so call the original redraw
  params_menu._original_redraw_function()
end


local function modified_key_function(n, z)
  if z == 1 then
    log.debug("In modified params_menu.key and n="..n.." z="..z)
    --json.print(_menu.m.PARAMS)
    log.debug("m.mode="..m.mode.." m.mode_prev="..m.mode_prev.." m.mode_pos="..m.mode_pos..
      " m.pos="..m.pos)
  end
  
  -- If on PSET menu page then handle specially, as long as not key1 press (since key1
  -- means jump from menu back to app page, which is handled elsewhere)
  if (params_menu.mode == mPSET or params_menu.mode == mPSETDELETE) and n ~= 1 then
    -- Only deal with button presses, not releases
    if z == 0 then return end

    if n == 2 then
      -- key2 means go back to previous menu screen
      if params_menu.mode == mPSETDELETE then
        -- Go back to PSET menu without actually deleting
        log.debug("Going back to mPSET screen")
        params_menu.mode = mPSET
      else
        if params_menu.mode_prev == mEDIT then
          -- Go back to the edit params page
          log.debug("Going back to mEDIT screen")
          params_menu.mode = mEDIT
        else
          -- Go back to the parameters mSELECT menu page
          log.debug("Going back to mSELECT screen")
          params_menu.mode = mSELECT
        end
      end
    elseif n == 3 then
      -- key3 means execute the action
      if params_menu.mode == mPSETDELETE then
        -- Do the delete
        delete_pset(m.ps_pos)
        pset_delete_redraw()
        
        -- Go back to PSET menu screen
        params_menu.mode = mPSET
      elseif params_menu.mode == mPSET then
        -- In mPSET menu so jump execute action depending on params_menu.ps_action.
        -- ps_action is which command selected in PSET menu: SAVE, LOAD, or DELETE
        if params_menu.ps_action == 1 then
          -- SAVE action
          log.debug("K3 hit for Save & Name option")
          local initial_name = m.ps_pos <= #m.pset and m.pset[m.ps_pos].name or ""
          textentry.enter(write_pset, initial_name, "Name the Preset #"..m.ps_pos.." and Save")
        elseif params_menu.ps_action == 2 and m.ps_pos <= #m.pset then
          -- LOAD action
          log.debug("K3 hit for Load option")
          load_pset(m.ps_pos)
          pset_load_redraw()
        elseif params_menu.ps_action == 3 and m.ps_pos <= #m.pset then
          -- DELETE action
          log.debug("K3 hit for Delete option so going to PSETDELETE menu screen")
          params_menu.mode = mPSETDELETE
        end

      end
      m.redraw()
      return
    end -- of n==3
  else  
    -- The original key() function doesn't set mode_prev. Therefore set it here
    -- so that if changing to another menu will know where came from.
    if params_menu.mode == mSELECT then
      params_menu.mode_prev = params_menu.mode
      log.debug("In psetExt.key() and setting params_menu.mode_prev to "..params_menu.mode_prev)
    end
    
    -- Do not need to handle specially so just call the original key function
    log.debug("Calling original menu key function")
    params_menu._original_key_function(n, z)
  end
end  


-- For when encoder changed
local function modified_enc_function(n, d)
  if m.mode == mPSET then
    -- On PSET menu screen so handle selection of action or pset
    if n==2 then
      m.ps_action = util.clamp(m.ps_action + d, 1, 3)
    elseif n==3 then
      m.ps_pos = util.clamp(m.ps_pos + d, 1, m.ps_n)
    end
    _menu.redraw()
    return
  end
  
  -- Not handled specially, so call original handler
  params_menu._original_enc_function(n, d)
end


-- Will be called by script_post_cleanup hook when script is being shut down.
-- Restores the pset functions to their originals
local function _initialize_pset()
  -- If NornsLib not enabled for this app then don't do anything
  if not nornsLib.enabled() then return end
  
  params_menu._original_enc_function = params_menu.enc
  params_menu.enc = modified_enc_function

  params_menu._original_key_function = params_menu.key
  params_menu.key = modified_key_function

  params_menu._original_redraw_function = params_menu.redraw
  params_menu.redraw = modified_redraw_function
end


-- Will be called by script_post_cleanup hook when script is being shut down.
-- Restores the pset functions to their originals
local function _finalize_pset()
  -- If NornsLib not enabled for this app then don't do anything
  if not nornsLib.enabled() then return end
  
  params_menu.enc = params_menu._original_enc_function
  
  params_menu.key = params_menu._original_key_function
  
  params_menu.redraw = params_menu._original_redraw_function
end


-- Configure the pre-init and a post-cleanup hooks in order to modify system 
-- code before init() and then to reset the code while doing cleanup.
-- Note: the numbers in the names are so that the hooks for parameterExt and
-- psetExt are called in proper order, which is done alphabetically. Needed to
-- make sure that since params_menu.redraw() is modified in both, that the
-- init order is the oppose of the finalize order.
local hooks = require 'core/hook'
hooks["script_pre_init"]:register("(1) pre init for NornsLib pset extension", 
  _initialize_pset)
hooks["script_post_cleanup"]:register("(2) post cleanup for NornsLib pset extension",
  _finalize_pset)

return PsetExt