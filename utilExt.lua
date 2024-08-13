-- Miscellaneous extensions


-- Likek os.execute() but returns the result string from the command
function os.execute_with_results(command)
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
function os.epochtime_str()
  return os.execute_with_results("date +%s.%N")
end


-- print(), but puts the epoch time in front. Really nice for understanding what
-- parts of your code are taking a long time to execute and need to be 
-- optimized. The time is shortened to only show 4 digits to left of decimal point,
-- and 6 digits to the right. Showing more would just be kind of ugly. Nano seconds
-- are just truncated instead of rounded because that level of precision is not
-- actually useful for print statements.
function util.tprint(obj)
  local time_str = os.epochtime_str()
  decimal_loc = string.find(time_str, "%.")
  local truncated_time_str = string.sub(time_str, decimal_loc-4, decimal_loc+6)
  print(truncated_time_str .. " - " .. tostring(obj))
end
