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


-- Retuns epoch time string with with nanosecond precision, by doing a system 
-- call. Note that because the number of characters one cannot just convert this
-- to a number via tonumber() because would then loose resolution.
function util.epochtime_str()
  return util.execute_command("date +%s.%N")
end


-- print(), but puts the epoch time in front. Really nice for understanding what
-- parts of your code are taking a long time to execute and need to be 
-- optimized. The time is shortened to only show 4 digits to left of decimal point,
-- and 6 digits to the right. Showing more would just be kind of ugly. Nano seconds
-- are just truncated instead of rounded because that level of precision is not
-- actually useful for print statements.
function util.tprint(obj)
  local time_str = util.epochtime_str()
  decimal_loc = string.find(time_str, "%.")
  local truncated_time_str = string.sub(time_str, decimal_loc-4, decimal_loc+6)
  print(truncated_time_str .. " - " .. tostring(obj))
end
