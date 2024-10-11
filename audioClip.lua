-- Provides UI so that user can change the start and stop time of a looping
-- soundclip. The UI provides a display of the amplitude of the sound clip
-- versus time.


local AudioClip = {
  -- Set via enable()
  is_enabled = false,  
  -- Which softcut voice channels to use when sampling the audio data . Set via enable()
  softcut_voices = {}, 
  -- Length of voices in softcut. Set via enable()
  voice_duration = nil,
  -- How much space to reserve above the audio clip display. Set via enable()
  graph_y_pos = nil,
  -- Begin time of the loop.  Set via enable() and modified via encoders
  loop_begin,
  -- End time of the loop.  Set via enable() and modified via encoders
  loop_end,
  -- When audio clip is exited this callback is called to provide user adjust loop begin and end times
  final_loop_times_callback = nil,
  -- voice1 data = {start, duration, sec_per_sample, samples, normalized_samples, largest_sample}
  data_v1 = nil,
  -- voice2 data = {start, duration, sec_per_sample, samples, normalized_samples, largest_sample}
  data_v2 = nil,
  
  -- Following are values that can be changed by a script, though the default values will generally be finet
  
  -- Minimum length in seconds of the audio loop
  MIN_LOOP_DURATION,
  -- defines where in pixels the audio display starts
  LEFT_PX,
  -- defines width in pixels of the audioi display
  WIDTH_PX,
  -- screen level for smallest amplitude 
  LEVEL_MIN,
  -- screen level for largest amplitude
  LEVEL_MAX,
  -- Update rate for showing current position. In seconds
  SHOW_POS_UPDATE_RATE,
  -- Brightness level of the vertical lines indicating begin and end of audio loop
  BEGIN_END_LINES_LEVEL,
  -- For drawing position indicator
  POSITION_LINE_LEVEL,
  -- For drawing wider position indicator
  POSITION_LINE_LEVEL2
}

-- At startup of script, using the pre-init hook, the values in AudioClip will be set to 
-- these defaults. This way if a script changes the values, which is completely legit, 
-- when the next script is run the values in AudioClip will be reset to these values.
local default_values = {
  -- Minimum length in seconds of the audio loop
  MIN_LOOP_DURATION = 0.05,
  -- defines where in pixels the audio display starts
  LEFT_PX = 14,
  -- defines width in pixels of the audioi display
  WIDTH_PX = 100,
  -- screen level for smallest amplitude
  LEVEL_MIN = 5,
  -- screen level for largest amplitude
  LEVEL_MAX = 11,
  -- Update rate for showing current position. In seconds. 0.05 makes it move quite smoothly, though may be resource intense
  SHOW_POS_UPDATE_RATE = 0.05,
  -- Brightness level of the vertical lines indicating begin and end of audio loop
  BEGIN_END_LINES_LEVEL = 2,
  -- For drawing position indicator
  POSITION_LINE_LEVEL = 3,
  -- For drawing wider position indicator. A zero level means it won't be drawn at all
  POSITION_LINE_LEVEL2 = 0
}


-- Keeping track of when drawing audio position so that can erase it before
-- drawing it at its new location.
local last_x_for_audio_position = nil

-------------------------------------------------------------------------------

--- Actually draws on the screen one of the channels of the audio clip.
-- @tparam table channel_data the audio data obtrained via softcut
-- @tparam boolean up true if should draw channel up from the center line
local function draw_audio_channel(channel_data, up)
  local duration_per_pixel = (AudioClip.loop_end - AudioClip.loop_begin) / AudioClip.WIDTH_PX
  local y_height_per_channel = math.floor((screen.HEIGHT - AudioClip.graph_y_pos) / 2)
  local up_or_down = up and -1 or 1
  screen.line_width(1)
  screen.aa(0)
  
  log.debug("In draw_audio_channel() and duration_per_pixel="..duration_per_pixel..
    " up_or_down="..up_or_down.." y_height_per_channel="..y_height_per_channel)
  
  -- For each vertical line (which corresponds to a time range). But start all the way 
  -- left and go all the way right in order to show the audio graph for where it is 
  -- beyond the loop and therefore not active. For these inactive parts the line_x_cnt
  -- will be less than 1 or greater than AudioClip.WIDTH_PX.
  for line_x_cnt = 1-AudioClip.LEFT_PX, screen.WIDTH-AudioClip.LEFT_PX do
    -- Determine begin and end time of what is to be drawn. Note: this can be beyond the 
    -- limits of the active part of the loop.
    local ampl_line_end_time = AudioClip.loop_begin + line_x_cnt*duration_per_pixel
    local ampl_line_begin_time = ampl_line_end_time - duration_per_pixel
    
    -- Determine which samples should be included in the timeslot for the pixel.
    -- Note: these indixes can be before or after the active part of the voice 
    -- data, in which case there is no audio amplitude line to draw.
    local sample_index_begin = math.floor(ampl_line_begin_time / channel_data.sec_per_sample) + 1
    local sample_index_end = math.floor(ampl_line_end_time / channel_data.sec_per_sample)
    
    -- If sample indexes are beyond the range of the data then cannot draw amplitude line
    if sample_index_end < 1 then
      goto continue
    end
    if sample_index_begin > #channel_data.normalized_samples then 
      break 
    end
    
    local max_amplitude = 0 -- will be between 0 and 1.0
    local number_of_samples = 0
    for sample_index = sample_index_begin, sample_index_end do
      local amplitude = channel_data.normalized_samples[sample_index]
      if amplitude ~= nil then
        if amplitude > max_amplitude then max_amplitude = amplitude end
        number_of_samples = number_of_samples + 1
      else
        --log.debug("No data for sample_index="..sample_index .. " so skipping")
      end
    end
    
    -- Determine location of the amplitude line
    local x = AudioClip.LEFT_PX + line_x_cnt
    local y = screen.HEIGHT - y_height_per_channel
    
    -- Determine color/level for the amplitude line. The idea is to use the ability to
    -- have different levels to highlight the larger amplitudes.
    local level_for_amplitude = math.floor(AudioClip.LEVEL_MIN + 
      max_amplitude * (AudioClip.LEVEL_MAX - AudioClip.LEVEL_MIN) + 0.5)
    -- But if beyond active part of loop then draw the amplitude quite dimmly. Just want 
    -- to show user that there is data beyond the extent of the active loop.
    if line_x_cnt < 1 or line_x_cnt > AudioClip.WIDTH_PX then
      level_for_amplitude = 2
    end
    
    local length_of_line = max_amplitude * y_height_per_channel
    local length_of_line_in_pixels = math.floor(length_of_line)
    local remainder = length_of_line - length_of_line_in_pixels
    local end_of_line_y = y + up_or_down*length_of_line_in_pixels
    -- Draw max amplitude line if it is at least 1 pixel long
    if length_of_line_in_pixels >= 1 then
      -- Actually draw the amplitude line
      screen.level(level_for_amplitude)
      screen.move(x, y)
      screen.line(x, end_of_line_y)
      screen.stroke()
    end
    
    -- Draw single pixel at end of line, using level to indicate how much beyond the 
    -- line it should go. The pixel should be at a level proportional to the fractional
    -- value of the average amplitude. 
    local pixel_level = level_for_amplitude * remainder
    local pixel_x
    local pixel_y
    if pixel_level > 1.0 then
      screen.level(pixel_level)
      -- Note: for pixel() pixel_x, pixel_y are the actual pixel coordinate
      pixel_x = x - 1
      pixel_y = end_of_line_y
      if up then pixel_y = pixel_y -1 end
      screen.pixel(pixel_x, pixel_y) 
      screen.fill()
    end
    
    -- If at beginning or end of the active audio area then draw vertical line as a y axis.
    -- The line starts just above the audio amplitude line, with a 1 pixel gap to indicate
    -- the difference.
    if line_x_cnt == 1 or line_x_cnt == AudioClip.WIDTH_PX then
      screen.level(AudioClip.BEGIN_END_LINES_LEVEL)
      screen.move(x, end_of_line_y + 2*up_or_down)
      screen.line(x, y + up_or_down*y_height_per_channel)
      screen.stroke()
    end
    
    -- For debugging
    --log.print("=== line_x_cnt="..line_x_cnt.." max_amplitude="..string.format("%.4f", max_amplitude).." length_of_line="..string.format("%.2f", length_of_line) .." length_of_line_in_pixels="..length_of_line_in_pixels.." number_of_samples="..number_of_samples.." level_for_amplitude="..level_for_amplitude)
    --log.print("--- x="..x.." y="..y.." end_of_line_y="..end_of_line_y.." pixel_level="..string.format("%.2f", pixel_level).." pixel_x="..tostring(pixel_x).." pixel_y="..tostring(pixel_y))
    
    -- Using an ugly goto because Lua doesn't have a continue statement 
    ::continue::
  end
end


--- Does the actual drawing of the audio clip. Separate from AudioClip.redraw() in 
-- case script wants to create other buttons in the interface. Does not do 
-- screen.clear() nor screen.update(). Those need to be done by the custom redraw()
-- function that draws the other UI elements on the screen.
function AudioClip.draw_audio_graph()
  log.debug("In draw_audio_graph() and AudioClip.graph_y_pos="..AudioClip.graph_y_pos)
  
    -- data = {start, duration, sec_per_sample, samples}
  local d1 = AudioClip.data_v1
  if d1 ~= nil and log.debug_enabled() then
    log.debug("d1.start="..d1.start.." d1.duration="..string.format("%.2f", d1.duration)..
      " #d1.samples="..#d1.samples.." d1.largest_sample="..string.format("%.2f", d1.largest_sample))
  end
  
  local d2 = AudioClip.data_v2
  if d2 ~= nil and log.debug_enabled() then
    log.debug("d2.start="..d2.start.." d2.duration="..string.format("%.2f", d2.duration)..
      " #d2.samples="..#d2.samples.." d2.largest_sample="..string.format("%.2f", d2.largest_sample))
  end
  
  -- Since redrawing the whole audio screen the audio position marker will not have
  -- have been drawn. It is instead drawn in new_audio_position_callback()
  last_x_for_audio_position = nil
    
  -- Draw each channel, if have data for them
  if d1 ~= nil then draw_audio_channel(d1, true) end
  if d2 ~= nil then draw_audio_channel(d2, false) end
  
  -- Display the duration at top of audio display, just below the custom display area
  screen.move(screen.WIDTH/2, AudioClip.graph_y_pos + 6)
  screen.level(8)
  screen.font_face(1)
  screen.font_size(8)
  screen.aa(0)
  screen.text_center(string.format("<- %.2fs ->", AudioClip.loop_end - AudioClip.loop_begin))
  
  -- Display loop begin time in lower left corner
  screen.text_rotate(AudioClip.LEFT_PX-2, screen.HEIGHT, string.format("%.2fs", AudioClip.loop_begin), -90)

  -- Display loop end time in lower right corner
  screen.text_rotate(AudioClip.LEFT_PX + AudioClip.WIDTH_PX + 7, screen.HEIGHT, 
    string.format("%.2fs", AudioClip.loop_end), -90)
  
  -- Add help info to bottom
  screen.move(screen.WIDTH/2, screen.HEIGHT-2)
  screen.level(screen.levels.HELP)
  screen.font_face(1)
  screen.font_size(8)
  screen.aa(0)
  screen.text_center("Press Key2 to exit")
end


-- Returns duration of the wav file in seconds
function AudioClip.wav_file_duration(filename)
  -- Determine and return audio length
  local ch, samples, samplerate = audio.file_info(filename)
  local duration = samples/samplerate
  log.debug("In wav_file_duration() and duration="..duration.." for filename="..filename)
  return duration
end


-- For drawing a single position indicator line
local function draw_position_indicator_line(x)
  screen.move(x, screen.HEIGHT)
  screen.line(x, AudioClip.graph_y_pos)
  screen.stroke()
end


-- Draws the entire position indicator line
local function draw_position_indicator(x)
  -- Setup for drawing
  screen.line_width(1)
  screen.aa(0)
  
  -- Draw the main indicator line
  screen.level(AudioClip.POSITION_LINE_LEVEL)
  draw_position_indicator_line(x)

  -- If adjacent lines are configured to be drawn to make indicator thicker, then draw those as well
  if AudioClip.POSITION_LINE_LEVEL2 ~= nil and AudioClip.POSITION_LINE_LEVEL2 > 0 then
    screen.level(AudioClip.POSITION_LINE_LEVEL2)
    draw_position_indicator_line(x-1)
    draw_position_indicator_line(x+1)
  end
end


--- Called via softcut.event_phase(callback) at the update rate specified by 
-- softcut.phase_quant(rate). Draws a graphical element on the audio clip that
-- indicates where currently playing.
-- @tparam number voice which voice
-- @tparam number position the current position in the voice, in seconds
local function new_audio_position_callback(voice, position)
  --log.print("New audio position. voice="..voice.." position="..position)
  
  -- Erase old indicator if it was drawn
  if last_x_for_audio_position ~= nil then
    -- Use subtract mode so can just draw the position indicator again in order to erase it
    screen.blend_mode("difference")

    -- Draw the indicator at the old position in order to erase it
    draw_position_indicator(last_x_for_audio_position)
  end

  -- Draw the position indicator at the new position
  local duration_per_pixel = (AudioClip.loop_end - AudioClip.loop_begin) / AudioClip.WIDTH_PX
  local x = AudioClip.LEFT_PX+1 + (position - AudioClip.loop_begin)/duration_per_pixel
  -- Use add mode so that can erase just by using subtract mode
  screen.blend_mode("add")
  draw_position_indicator(x)
  
  -- Remember where drew the indicator so that it can be erased later
  last_x_for_audio_position = x
  
  -- Actually make the changes visible
  screen.update()

  -- Restore drawning mode to the standard one
  screen.blend_mode("default")
end


--- Called via softcut.event_render(callback) when softcut.render_buffer() is called
-- and the data has been processed. Used to convert a voice into a smaller sample rate
-- so that the data can be used to visualize the amplitude of the audio clip.
local function buffer_content_processed_callback(ch, start, sec_per_sample, samples)
  log.debug("In buffer_content_processed_callback() ch="..ch.." start="..start..
    " sec_per_sample="..string.format("%.6f", sec_per_sample).." #samples="..#samples)

  -- Want to normalize the samples so that the largest absolute value is 1.0.
  -- This way the audio graph will be as tall as possible.
  local largest_sample = 0
  for _, sample in ipairs(samples) do
    if math.abs(sample) > largest_sample then largest_sample = math.abs(sample) end
  end
  
  local normalized_samples = {}
  for _, sample in ipairs(samples) do
    table.insert(normalized_samples, math.abs(sample) / largest_sample)
  end

  -- Store the data so that it can be drawn
  local data = {
    start = start,
    duration = sec_per_sample * #samples,
    sec_per_sample = sec_per_sample,
    samples = samples,
    normalized_samples = normalized_samples,
    largest_sample = largest_sample
  }
  
  if ch == 1 then
    AudioClip.data_v1 = data
  else
    AudioClip.data_v2 = data
  end
  
  -- Since have processed data should draw the audio graphs
  AudioClip.draw_audio_graph()
  screen.update()
end


-- Converts the audio in Softcut buffer into data arrays that can be graphed. 
-- buffer_content_processed_callback() is called when the data has finished
-- being processed.
-- @tparam number voice_duration length in seconds of the voice
function AudioClip.initiate_audio_data_processing(voice_duration)
  log.debug("Processing audio data and voice_duration="..tostring(voice_duration))
  
  -- register callbacks that handles the resampled audio data.
  -- And then initiate the resampling
  softcut.event_render(buffer_content_processed_callback)
  for _, voice in ipairs(AudioClip.softcut_voices) do
    local start = 0
    local max_samples = 200 * voice_duration -- 200 samples per second
    softcut.render_buffer(voice, start, voice_duration, max_samples)
  end
  
  -- Configure so that new_audio_position_callback() is called every update_rate
  -- seconds. This allows an indicator to be drawn that shows where in clip we are.
  for _, voice in ipairs(AudioClip.softcut_voices) do
    softcut.phase_quant(voice, AudioClip.SHOW_POS_UPDATE_RATE)
  end
  softcut.event_phase(new_audio_position_callback)
  softcut.poll_start_phase()
end


-- Updates begin and end time of the audio loop
local function set_audio_loop_params()
  for _, voice in ipairs(AudioClip.softcut_voices) do
    log.debug("Setting audio params for voice="..voice..
      " loop_begin="..string.format("%.2f", AudioClip.loop_begin)..
      " loop_end="..string.format("%.2f", AudioClip.loop_end))
    
    -- Start loop at AudioClip.loop_begin
    softcut.loop_start(voice, AudioClip.loop_begin)
  
    -- Play till AudioClip.loop_end
    softcut.loop_end(voice, AudioClip.loop_end)
    
    -- Enable looping in case it has not yet been enabled
    softcut.loop(voice, 1)
  end
end


-- Resets values for Audio Clip. Should be called when Audio Clip exited
-- and at startup
function AudioClip.reset()
  -- Stop polling of audio phase since it takes resources
  softcut.poll_stop_phase()
  
  -- Don't need to worry about displaying audio position anymore
  last_x_for_audio_position = nil
  
  -- Mark as disabled
  AudioClip.disable()
  
  -- Clear the other params
  AudioClip.data_v1 = nil
  AudioClip.data_v2 = nil
  AudioClip.voice_duration = nil
  AudioClip.graph_y_pos = nil
end


--- Called when key2 is hit by user to exit the audio clip screen
function AudioClip.exit()
  log.debug("Exiting clip audio UI")
  
  -- Reset params for Audio Clip 
  AudioClip.reset()
  
  -- Call callback to alert main script that begin and end times might have been changed
  if AudioClip.final_loop_times_callback ~= nil then
    AudioClip.final_loop_times_callback(AudioClip.loop_begin, AudioClip.loop_end)
  end
  
  -- Call the app's redraw since exiting the audio graph screen
  redraw() 
end


function AudioClip.disable()
  log.debug("In AudioClip.disable()")
  AudioClip.is_enabled = false
end


--- Used to setup audio clip screen and switch to it.
-- @tparam number voice1 which voice in softcut to use
-- @tparam number voice2 second voice in softcut to use. Can be set to nil.
-- @tparam number voice_duration length of the voice in seconds
-- @tparam number graph_y_pos y pixel value, below which can be used for displaying audio
-- @tparam number loop_begin Where in voice the loop begin is. If nil then will use beginning of voice
-- @tparam number loop_end Where in voice the loop ends. If nil then will use end of voice
-- @tparam function final_loop_times_callback When audio clip is exited this callback is called to provide user adjust loop begin and end times
function AudioClip.enable(voice1, voice2, voice_duration, graph_y_pos, loop_begin, loop_end, final_loop_times_callback)
  log.debug("In AudioClip.enable() and graph_y_pos="..tostring(graph_y_pos)..
    " voice_duration="..tostring(voice_duration))
  
  -- Keep track of params
  AudioClip.is_enabled = true
  AudioClip.softcut_voices = {voice1, voice2}
  AudioClip.graph_y_pos = graph_y_pos
  AudioClip.voice_duration = voice_duration
  AudioClip.loop_begin = loop_begin or 0
  AudioClip.loop_end = loop_end or voice_duration
  AudioClip.final_loop_times_callback = final_loop_times_callback
  
  -- Loop the voices using proper begin and end times
  set_audio_loop_params()
  
  -- Get the raw data from softcut buffer
  AudioClip.initiate_audio_data_processing(voice_duration)
    
  -- Call redraw to display the special audio clip screen
  redraw()
end


--- Returns true if clipAudio screen is currently enabled
function AudioClip.enabled()
  return AudioClip.is_enabled ~= nil and AudioClip.is_enabled
end


-- If k3 is down then use fine resolution mode for ehcoders
local k3_down = false

local function encoder_increment()
  return k3_down and 0.01 or 0.2
end


-- Handles key presses for the audio clip screen. When k2 is hit the audio
-- clip screen is exited. And when k3 is hit the variable k3_down is updated
-- so that the encoders can have fine resolution.
function AudioClip.key(n, down)
  log.debug("AudioClip key pressed n=" .. n .. " delta=" .. down)
  
  -- If key2 hit then exit clip audio mode
  if n == 2 then
    AudioClip.exit()
  end
  
  -- If it is key3 then update variable k3_down
  if n == 3 then
    k3_down = (down == 1)
  end
end


-- Handles encoder turns for the audio clip screen. Adjusts the loop begin and end times.
function AudioClip.enc(n, delta)
  log.debug("AudioClip encoder changed n=" .. n .. " delta=" .. delta)
  
  if n == 2 then
    -- encoder 2 turned so adjust loop begin time
    AudioClip.loop_begin = util.clamp(AudioClip.loop_begin + encoder_increment() * delta, 
      0, AudioClip.voice_duration - AudioClip.MIN_LOOP_DURATION)
    log.debug("AudioClip.loop_begin=" .. string.format("%.2f", AudioClip.loop_begin))
    
    -- Make sure the loop_end is still valid
    if AudioClip.loop_end < AudioClip.loop_begin + AudioClip.MIN_LOOP_DURATION then
      AudioClip.loop_end = AudioClip.loop_begin + AudioClip.MIN_LOOP_DURATION
      log.debug("Also adjusted AudioClip.loop_end=" .. string.format("%.2f", AudioClip.loop_end))
    end
    
    set_audio_loop_params()
    
    redraw()
  elseif n ==3 then
    -- encoder 3 turned so adjust loop end
    AudioClip.loop_end = util.clamp(AudioClip.loop_end + encoder_increment() * delta, 
      AudioClip.MIN_LOOP_DURATION, AudioClip.voice_duration)
    log.debug("AudioClip.loop_end=" .. string.format("%.2f", AudioClip.loop_end))

    -- Make sure the loop_begin is still valid
    if AudioClip.loop_begin > AudioClip.loop_end - AudioClip.MIN_LOOP_DURATION then
      AudioClip.loop_begin = AudioClip.loop_end - AudioClip.MIN_LOOP_DURATION
      log.debug("Also adjusted AudioClip.loop_begin=" .. string.format("%.2f", AudioClip.loop_begin))
    end

    set_audio_loop_params()
  
    redraw()
  end
end


-- Use pre-init hook to initialize parameters within AudioClip. This way, if a script changes
-- the parameters then they will be reset to their default values before the script uses the
-- values.
local function initialize_audio_clip()
  -- Copy all elements from default_values into AudioClip table
  for i, v in pairs(default_values) do
    AudioClip[i] = v
  end
  
  -- Need to disable audio clip in case the last script run had it enabled
  reset()
end


local hooks = require 'core/hook'
hooks["script_pre_init"]:register("Pre init hook for audioClip to initialize values", 
  initialize_audio_clip)

return AudioClip