-- Miscellaneous utility extensions. All functions are put into the util object.


-- Like os.execute() but returns the result string from the command. And different
-- from util.os_capture() by having a more clear name, and by only filtering out
-- last character if a newline. This means it works well for both shell commands
-- like 'date' and also accessing APIs that can provide binary data, such as using
-- curl to get an binary file.
function util.execute_command(command)
  -- Execute command and get result
  local handle = io.popen(command)
  local result = handle:read("*a")
  handle:close()

  -- trim off trailing \n if there is one
  if string.sub(result, -1, -1) == "\n" then
    result = string.sub(result, 1, -2)
  end

  return result
end


-- Sleeps specified fraction number of seconds. Implemented by doing a system call.
-- Note that this will lock out the UI for the specified amount of time, so should
-- be used judiciously.
function util.sleep(seconds)
  os.execute("sleep "..seconds)
end


-- Retuns epoch time string with with nanosecond precision, by doing a system 
-- call. Note that because the number of characters one cannot just convert this
-- to a number via tonumber() because would then lose resolution. And yes, it
-- is doubtful that nono second resolution will be useful since doing a system
-- call, which takes a while. Therefore util.time() will usually be sufficient.
function util.epochtime_str()
  return util.execute_command("date +%s.%N")
end


-- print(), but puts the epoch time in front. Really nice for understanding what
-- parts of your code are taking a long time to execute and need to be 
-- optimized. The time is shortened to only show 4 digits to left of decimal point,
-- and 4 digits to the right. Showing more would just be kind of ugly. 
function util.tprint(obj)
  time_str = string.format("%.4f", util.time() % 10000)
  
  print(time_str .. " - " .. tostring(obj))
end


-- Does a util.tprint(), but only if the global debug_mode is set to true.
-- Great for debugging.
function util.debug_tprint(obj)
  if debug_mode then util.tprint("Debug: "..obj) end
end


-- Does a regular print(), but only if the global debug_mode is set to true.
-- Great for debugging.
function util.debug_print(obj)
  if debug_mode then print("Debug: "..obj) end
end


-- For getting just the filename from full directory path. Returns what is after
-- the last slash of the full filename. If full filename doesn't have any slashes
-- then full_filename is returned.
function util.get_filename(full_filename)
  local last_slash = (full_filename:reverse()):find("/")
  if last_slash == nil then
    return full_filename
  else
    return full_filename:sub(-last_slash+1)
  end
end


-- For finding the directory of a file. Useful for creating file in a directory that
-- doesn't already exist
function util.get_dir(full_filename)
    local last_slash = (full_filename:reverse()):find("/")
    return (full_filename:sub(1, -last_slash))
end


-- If dir doesn't already exist, creates directory for a file that is about
-- to be written. Different from util.make_dir() in that make_dir_for_file() 
-- can take in file name and determine the directory from it. 
function util.make_dir_for_file(full_filename)
  -- Determine directory that needs to exist
  local dir = util.get_dir(full_filename)

  -- If directory already exists then don't need to create it
  if util.file_exists(dir) then return end

  -- Directory didn't exist so create it
  os.execute("mkdir "..dir)
end


-- From https://gist.github.com/liukun/f9ce7d6d14fa45fe9b924a3eed5c3d99
local function char_to_hex(c)
  return string.format("%%%02X", string.byte(c))
end

local function hex_to_char(x)
  return string.char(tonumber(x, 16))
end


-- For encoding a url that has special characters.
function util.urlencode(url)
  if url == nil then
    return
  end
  url = url:gsub("\n", "\r\n")
  url = url:gsub("([^%w ])", char_to_hex)
  url = url:gsub(" ", "+")
  return url
end


-- For decoding a url with special characters
function util.urldecode(url)
  if url == nil then
    return
  end
  url = url:gsub("+", " ")
  url = url:gsub("%%(%x%x)", hex_to_char)
  return url
end


-------------------- For waiting for file to be loaded -----------------------

-- Modifying standard _norns.metro() so that it also passes in the metro timer
-- to the callback function. This way the callback function can do things like
-- release the timer.
_norns.metro = function(idx, stage)
  local m = metro.metros[idx]  -- Lower case metro because being accessed outside of metro.lua
  if m then
    if m.event then
      m.event(stage, m)
    end
    if m.count > -1 then
      if (stage > m.count) then
        m.is_running = false
      end
    end
  end
end


-- Called every clock tick when waiting for a file to be ready
local function _wait_for_file_callback(stage, mtro)
  local filename = mtro._file

  -- Can get extra ticks after already called the callback. If so, just
  -- ignore since already done.
  if mtro._done then return end
  
  -- See if file exists and has stopped growing
  if util.file_exists(filename) then
    current_size = util.file_size(filename)
    if current_size == mtro._prev_file_size then
      -- File exists and is no longer changing size. Done so wrap things up
      util.tprint("File fully loaded so calling callback. ".. util.get_filename(filename))

      -- Done waiting so done with timer
      mtro:stop()
      metro.free(mtro.id)
      
      -- Even though stopped timer it turns out that might still get a few more ticks.
      -- Therefore mark the metro as being done with it.
      mtro["_done"] = true
    
      -- Call the callback
      mtro._file_available_callback(filename)
    else
      -- File still changing size so not ready yet
      util.debug_tprint("File still changing size so waiting. ".. util.get_filename(filename) .." size=" .. current_size) 
      mtro._prev_file_size = current_size
    end
  else
    -- File doesn't even exist yet
    mtro._prev_file_size = 0
    --util.debug_tprint("Waiting for file to exist ".. util.get_filename(filename)) 
  end
  
  -- If exceeded allowable counts then give up. Free the timer
  if mtro.count > -1 and stage >= mtro.count then
    util.tprint("Exceeded count so giving up waiting for file=" .. filename)
    metro.free(mtro.id)
  end
end


-- Waits until the file specified exists and is not changing in size. At that
-- point the callback is called. Uses an available metro timer, and frees it
-- once done. Recommend a tick_time of 0.1 to 0.2 seconds. 
-- max_time specifies how long should wait. Must be at least 1.0 second.
function util.wait(full_filename, file_available_callback, tick_time, max_time)
  -- If file already exists and is not empty then call the callback immediately
  if util.file_exists(full_filename) and util.file_size(full_filename) > 0 then
    util.debug_tprint("File already available. file="..full_filename)
    file_available_callback(full_filename)
    return
  end
  
  local count = max_time / tick_time
  
  wait_metro = metro.init(_wait_for_file_callback, tick_time, count)
  
  -- Add filename to be waited for to the metro object
  wait_metro["_file"] = full_filename
  
  -- Store the callback in the metro
  wait_metro["_file_available_callback"] = file_available_callback
  
  -- Init _prev_file_size
  wait_metro["_prev_file_size"] = 0
  
  wait_metro["_done"] = false
  
  -- And start that timer!
  wait_metro:start()
end