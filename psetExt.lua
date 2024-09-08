-- For making the PSET menu screen easier to use. 

-- Get access to the PARAMS menu class. Also use the name "m" since that is what
-- is used in the original code.
local params_menu = require "core/menu/params"
local m = params_menu


------------------------------------------------------------------------------------------
------------- Local functions that had to be copied from core/menu/params.lua ------------
------------------------------------------------------------------------------------------

-- mSELECT and others are locals in lua/core/menu/params.lua so need to be duplicated here
local mSELECT = 0
local mEDIT = 1
local mPSET = 2
local mPSETDELETE = 3

-- Process the PSET files and puts them into the pset local.
-- Needed to copy this code directly from core/menu/params.lua since it is a local 
-- and it sets the pset local.
local pset = {}
local function pset_list(results)
  pset = {}
  m.ps_n = 0 -- which pset currently selected
 
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
    pset[n] = {file=file,name=name}
    m.ps_n = math.max(n, m.ps_n)
  end
  
  -- Set selected pset m.pos to 1
  if m.ps_n >= 1 then m.pos = 1 else m.pos = 0 end
end


-- This function reads stored PSET files and calls pset_list() on the data so it is 
-- put into the local pset. Needed to copy directly from core/menu/params.lua since 
-- it is a local there and it sets the pset local. This function is not made local
-- here so that it can be accessed by parameterExt.lua
local function init_pset()
  util.dprint("Modified scanning psets...")
  norns.system_cmd('ls -1 '..norns.state.data..norns.state.shortname..'*.pset | sort', 
    pset_list)
end

-------------------- Functions being overwritten to specially handle PSET Menu --------------

-- Returns displayable name of the specified PSET
local function get_pset_name(index)
  if index == 0 then return "INDEX WAS 0" end -- FIXME
  
  print("====== #pset="..#pset.." index="..index)
  return "#"..index..(pset[index].name ~= nill and " - "..pset[index].name or "")
end


-- Replacement pset menu redrawing code. Replaces what is from core/menu/params.lua    
local function pset_menu_redraw()
  screen.clear()
  
  -- Header for the menu
  screen.level(4)
  screen.move(0,10)
  screen.text("Parameters Storage (PSET)")
  
  -- Display the current list of PSETs
  for i=1,6 do
    local n = i+m.ps_pos-2
    if (i > 2 - m.ps_pos) and (i < m.ps_n - m.ps_pos + 3) then
      local line = "-"
      if pset[n] then line = pset[n].name end
      if(i==3) then
        screen.level(15)
      else
        screen.level(4)
      end
      screen.move(50,10*i)
      local num = (n == m.ps_last) and "*"..n or n
      screen.text_right(num)
      screen.move(56,10*i)
      screen.text(line)
    end
  end
  
  -- PSET menu actions
  screen.move(0,30)
  local v = (m.ps_action == 1) and 15 or 4
  screen.level(v)
  screen.text("Save with name")
  
  screen.move(0,40)
  v = (m.ps_action == 2) and 15 or 4
  screen.level(v)
  screen.text("Load")
  
  screen.move(0,50)
  v = (m.ps_action == 3) and 15 or 4
  screen.level(v)
  screen.text("Delete")
  
  screen.update()
end


-- Replacement pset delete menu redrawing code. Replaces what is from core/menu/params.lua    
local function pset_delete_menu_redraw()
  screen.clear()
  
  screen.move(63, 40)
  screen.level(15)
  screen.text_center("Delete "..get_pset_name(m.ps_pos).." ?")

  screen.level(2)
  screen.move(63, 61)
  screen.text_center("Key3 for yes, Key2 for no")
  
  screen.update()
end


-- So that app can have a "PSET >" toggle parameter in the parameter list that takes
-- the user directly to the PSET page. This makes it easier for user to save/load/delete
-- parameters.
--
-- To use, can setup the following parameter:
--    params:add_separator("Store or load parameters")
--    params:add_trigger("pset", "PSET >") 
--    params:set_action("pset", jump_to_pset_screen )
function jump_to_pset_screen()
  util.debug_tprint("Jumping to parameter save/load/delete menu screen")
  
  -- Most likely already in menu mode, but explicitly change to it just to be safe 
  _menu.set_mode(true) 
  
  -- Remember current mode so that can return to it if k2 pressed
  params_menu.mode_prev = params_menu.mode
  util.dprint("FIXME set params_menu.mode_prev to "..params_menu.mode_prev..
    " where mSELECT="..mSELECT.." mEDIT="..mEDIT.." mPSET="..mPSET)
  
  -- Since had to have a local version of init_pset(), can call it directly. This 
  -- means that can just set params_menu.mode to mPSET in order to go to that window,
  -- and call init_pset()
  params_menu.mode = mPSET
  init_pset()
end


----------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------

-- Make sure this portion of file only loaded once. This prevents infinite recursion  
-- when overriding system functions. Bit complicated because need to use something
-- that lasts across script restarts. The solution is to use add a boolean to
-- the object whose function is getting overloaded.

-- params_menu is the menu that contains the params. This is the one that needs to have 
-- function ptrs modified. So this is where should store the already_included boolean.

-- If the special variable already set then return and don't process this file further
if params_menu["pset_already_included"] ~= nil then 
  print("psetExt.lua already included so not doing so again")
  return 
end
  
-- Need to process this file
params_menu["pset_already_included"] = true
print("psetExt.lua not yet loaded so loading now...")


local original_params_menu_redraw_func = params_menu.redraw

params_menu.redraw = function()
  -- If drawing the PSET menu then use the new PSET functions
  if params_menu.mode == mPSET then
    pset_menu_redraw()
    return
  elseif params_menu.mode == mPSETDELETE then
    pset_delete_menu_redraw()
    return
  end
  
  -- Was not a special PSET menu request so call the original redraw
  util.dprint("In psetExt params_menu.redraw() but calling orig redraw()")
  original_params_menu_redraw_func()
end


local original_params_menu_key_func = params_menu.key

params_menu.key = function(n, z)
  if z == 1 then
    util.dprint("In modified params_menu.key and n="..n.." z="..z)
    --json.print(_menu.m.PARAMS)
    util.dprint("m.mode="..m.mode.." m.mode_prev="..m.mode_prev.." m.mode_pos="..m.mode_pos)
    util.dprint("m.pos="..m.pos)
  end
  
  -- If on PSET menu page then handle specially
  if params_menu.mode == mPSET then
    -- k2 means go back to previous menu screen
    if n == 2 then
      -- Only deal with button presses, not releases
      if z == 0 then return end
      
      if params_menu.mode == mPSETDELETE then
        -- Go back to PSET menu without actually deleting
        util.dprint("Going back to mPSET screen")
        params_menu.mode = mPSET
      else
        if params_menu.mode_prev == mEDIT then
          -- Go back to the edit params page
          util.dprint("Going back to mEDIT screen")
          params_menu.mode = mEDIT
        else
          -- Go back to the parameters mSELECT menu page
          util.dprint("Going back to mSELECT screen")
          params_menu.mode = mSELECT
        end
      end
      
      return 
    end
    
    -- ps_action is which command selected in PSET menu: SAVE, LOAD, or DELETE
    if n == 3 and params_menu.ps_action == 3 then
      util.dprint("K3 hit for Delete option so going to PSETDELETE menu screen")
      params_menu.mode = mPSETDELETE
      return
    end
  else  
    -- Do not need to handle specially so just call the original key function
    util.dprint("Calling original menu key function")
    original_params_menu_key_func(n, z)
  end
end  

