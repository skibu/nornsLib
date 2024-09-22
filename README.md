# NornsLib
Useful Lua libraries for Norns synth to make it easier to create scripts that are user friendly. There are currently two separate library files. You only need to include what you want to actually use. The initial motivation was to help in creating the `https://github.com/skibu/nornsLib/taweeet` Norns script.

See bottom of this doc on full [instructions](https://github.com/skibu/nornsLib/blob/main/README.md#using-nornslib-in-your-script) on how to include the library.

# `json = require "nornsLib/jsonExt"`
Ever gotten frustrated trying to understand what is in a table because `tab.print(tbl)` is just way too limited?? Ever want to read or write data in a human readable format so that you can actually understand the data? Well, the JSON extension can really help. Not only does it enable easily converting from table objects to json and visa versa, but you can also print out a table in json format. Handles non-standard JSON values including Infinity, -Infinity, NaN, and null. Also handles function pointers well for encoding, though cannot handle them when decoding.

### json_str = json.encode(tbl, indent)
Returns a table as a JSON string. Great way to see what is inside a complicated table. The indent parameter specifies how much each level should be indented, which makes for much more readable results. Default indent is 2 spaces. Use 0 if you want to minimize file size.

### tbl = json.decode(json_str)
Converts a JSON string into a Lua table. 

### json.print(tbl)
A great replacement for `tab.pring()`. This function prints the table in JSON format, and can show all levels. Worth the price of admission!

### json.write(tbl, filename)
Writes table object to a file in json format

### tbl = json.read(filename)
Reads json file and converts the json into a table object and returns it. If the file
doesn't exist then returns nil.

### tbl = json.get(url, custom_headers)
Does a json api call to the specified url and converts the JSON 
to a Lua table. This is done via a curl call. Allows compressed
data to be provided. You can optionally provide custom headers
by passing in a table with key/value pairs, as in {["API-KEY"]="827382736"}

# `parameterExt = require "nornsLib/parameterExt"`
The parameter extensions library does several things: 1) prevents overlap for option parameters;  2) makes navigation to parameter setting menu much simpler because user just has to press key1;  3) parameters (mEDIT) screen doesn't highlight separators since they cannot be modified, and better title; and 4) fixed params:bang(id) to optionally take a parameter id.

### Preventing overlap for parameter option
This feature makes sure that option parameters don't overlap the label and the value, since that makes the text unreadable. To use this feature you only need to include the parameterExtensions library. Everything else is taken care of by changing some of the low-level code. If overlap for an option parameter is found, a narrower font will be used. And if there would still be overlap with the narrower font, then the right portion of the text will be trimmed off. If you happen to ever have overlapping text in a parameter option this provides a great and simple solution. 

### Left align parameter values
The default of having the parameter values being right justified makes them look quitei jumbly. But now they can be left aligned. One simply needs to call `set_left_align_parameter_values(true)` at initialization to do so.

Left alignment of parameter values works especially well if the right sides of the parameter labels are aligned. This can be done by padding the left of the parameter labels by spaces of various widths, until they align. Note: while a normal space char " " is 5 pixels wide, one can use a half space char "\u{2009}" of 3 pixels or and even skinnier hair space "\u{200A}" that is just a single pixel wide.

### Easier navigation to the script's parameter page
One of the great thing about a Norns is that the application scripts can have lots of parameters, allowing the user to finely control things. But the default method for getting to the parameters is quite clunky and dissuades users.

The current method is a rather magical sequence of a short key1 press to get to Menus (but a long key press of greater than 0.25 won't work!), then turn encoder1 to get to PARAMETERS menu, then turn encoder2 to select Edit >, and then click on key3 to get to the script's param page, and then use encoder2 to actually get to a param. That is simply too convoluted.

This library makes it so that the user can simply hit key1, with a long or short press, and they will be brought automatically to the script's parameter page and the first parameter will already be selected. And to get back the script page the user can simply hit key1 again with a long or short press. No more wondering why can navigate the menus due to hitting key1 just a bit longer than 0.25 sec!

To enable this functionality the script needs to add `parameterExt = require "nornsLib/parameterExt"` and call the library function `parameterExt.jump_to_edit_params_screen()` when the desired key sequence is hit. For example, for your script to have key1, long or short press, jump right to the parameters page one can do something like the following:
```
parameterExt = require "nornsLib/parameterExt"

function key(n, down)
  if n == 1 and down == 0 then
    -- Key1 up so jump to edit params directly. Don't require it
    -- to be a short press so that it is easier. And use key up
    -- event because if used key down then the subsequent key1 up would 
    -- switch back from edit params menu to the application screen.
    parameterExt.jump_to_edit_params_screen()
  end

  ...
end
```

### Improved look of Parameters menu screen
Parameters (mEDIT) screen doesn't highlight separators since they cannot be modified. Improved the title

### Fixed params:bang(id) to handle single parameter
Turns out that in lua/core/clock.lua that params:bang("clock_tempo") is called to
bang just the single parameter. But the standard bang() function bangs *ALL* 
parameters, which is not desired in this situation. So this definition overrides the 
bang function so that optionally only a single param can be banged. If id not specified 
then all all banged.


# `psetExt = require "nornsLib/psetExt"` (presets screen)
The original PSET (Presets) menu screen has a different UI than other situations.  The list of presets is simply not clear. And "pset" is a really confusing term since it stands for "preset", not "parameter set". Therefore with psetExt the presets are provided in a single line, as is done with other parameters. Also, switched from using upper case. 

But a truly nice feature is that the parameters menu can be setup so that the user can jump directly from that screen to the preset page.

### `psetExt.jump_to_pset_screen()`
When setting up the script's parameters can use something like `params:set_action("pset", psetExt.jump_to_pset_screen )` to allow the user to jump directly to the preset screen, making navigation much more simple.


# `require "nornsLib/textentryExt"`

The original text entry screen can be a bit cumbersome. By simply including the textentryExt library the UI of the text entry screen is replaced. The text entered is presented in a larger font to make it clear what is happening. And a "_" is added to the end to further clarify where characters are entered. 

Additionaly, the list of characters was changed to present the SAVE option, and the backspace "<-" option clearly. Also, instead of presenting the characters in ascii order, which is not intended for a UI, first lower case characters, then upper case characters, then numbers, and then just a few symbols are provided. This seems to make it easier to find desired character. Also, one doesn't have to figure out how to switch focus from the characters line to the BS OK line since those options are available right in the character list.

# `require "nornsLib/screenExt"`
The screen extensions library provides three functions that allow one to get current values for a font. This can be very useful if one wants to use multiple reasonably sized functions for drawing text. A higher level function might set font parameters and then call a lower level function to do more work. If the lower level function needs to change the font params then it should reset them to the original values so that the higher level function can continue to draw.

All the library screen functions are in the `screen` object, so they are accessed just like all the other ones. 

These functions are:
* screen.current_font_size()
* screen.current_font_face()
* screen.current_aa()

Also, the standard screen.text_extents() function has a notable flaw. It doesn't provide 
the proper width of a string if the string is padded by spaces. Somewhere the string
is inappropriately trimmed. This is a problem even if padding with a half space \u{2009}
or a hair space \u{200A}. Could not determine where the string is getting inappropriately
trimmed so cannot fix the code directly. Instead, screen.text_untrimmed_extents(str)
should be used instead of screen.text_extents(str) if the string might be padded. Don't
want to use this for every situation though because this function actually makes two
calls to the original screen_text_extents(), which slows things down a bit, especially
since they are blocking calls. Therefore this function should only be used when the 
string in question actually might be padded.
* screen.text_untrimmed_extents(str)

There is also a new  function for determining the size of an image buffer called `screen.extents()`. One can pass in either an existing image buffer or a file name of a PNG file. This function is quite handy for if you want to do something like center a PNG image on the screen. The function is:
* screen.extents(image_buffer) and it returns the `width, height` of the image buffer or PNG file.

And there is a function for freeing an image buffer when you are done with it. Make sure you only call this once on an image buffer. Otherwise the system will likely crash.
* screen.free(image_buffer)

And lastly, screen.clear() is overriden to deal with a bug when writing an image buffer to the screen. In the 240424 there is a bug when writing an image buffer after screen.clear() is called. The screen.display_image() call is not queued and therefore can execute before the screen is fully cleared, resulting in the image not be displayed correctly or even at all. This is being fixed in the next release of Norns, but if you are using screen.display_image() then you will want to include this library since it is a good temporary fix for the problem. Once everyone is on new version of Norns code this can go away, but that might take a while.
* screen.clear() - fixes existing function


# `require "nornsLib/utilExt"`

### util.sleep(seconds)
Sleeps specified fraction number of seconds. Implemented by doing a system call.
Note that this will lock out the UI for the specified amount of time, so should
be used judiciously.

### util.epochtime_str()
Retuns epoch time string with with nanosecond precision, by doing a system 
call. Note that because the number of characters one cannot just convert this
to a number via tonumber() because would then loose resolution. And yes, it
is doubtful that nono second resolution will be useful since doing a system
call, which takes a while. Therefore util.time() will usually be sufficient.

### util.get_filename(full_filename)
For getting just the filename from full directory path. Returns what is after
the last slash of the full filename. If full filename doesn't have any slashes
then full_filename is returned.

### util.get_dir(full_filename)
For finding the directory of a file. Useful for creating file in a directory that
doesn't already exist

### util.make_dir_for_file(full_filename)
If dir doesn't already exist, creates directory for a file that is about
to be written. Different from `util.make_dir()` in that `util.make_dir_for_file()`
can take in file name and determine the directory from it. 

### encoded = util.urlencode(url)
For encoding a url that has special characters.

### util.urldecode(url)
For decoding a url with special characters

### util.execute_command(command)
Like os.execute() but returns the result string from the command. And different
from util.os_capture() by having a more clear name, and by only filtering out
last character if a newline. This means it works well for both shell commands
like 'date' and also accessing APIs that can provide binary data, such as using
curl to get an binary file.


# `log = require "nornsLib/loggingExt"`
For logging statements. Each statement is prepended with timestamp so can easily determine what is taking so long to process. They are also written to file at `dust/data/<app>/logfile.txt` .  Debug statements can be enabled or disabled, and contain useful debugging info such as function name, source code, and line number where called from. 

### log.print(obj)
Like print(), but puts the epoch time in front. Really nice for understanding what
parts of your code are taking a long time to execute and need to be 
optimized. The time is shortened to only show 4 digits to left of decimal point,
and 6 digits to the right. Showing more would just be kind of ugly. Nano seconds
are just truncated instead of rounded because that level of precision is not
actually useful for print statements.

### log.error(obj)
Uses log.print(), but preceeds the text with "ERROR: "
 
### log.enable_debug(value) 
This function needs to be called if want log.debug() functions to actually output
info. To enable, call log.enable_debug(true) or simply log.enable_debug(). To
disable use log.enable_debug(false). This is like a condensed traceback.

### log.debug(obj)
If enabled via log.enable_debug(value), outputs the object using log.print(), prefixed by "DEBUG: ", and with a second line that shows the context of function name, source code file name, and line number. Great for debugging!


# Using NornsLib in your script
The NornsLib library can easily be included in your script. Since nornsLib is a separate repo from your script you need to make sure that the nornsLib files are not just included, but that the whole library is cloned to the user's Norns device. To make this simple you can just copy and paste the following Lua file into your script repo. 

### fullNornsLibInclude.lua:
You can copy and paste the script below or do a `wget https://raw.githubusercontent.com/skibu/nornsLib/main/fullNornsLibInclude.lua`. And then just include this nornsLib script from your application script using something like `include "appLib/fullNornsLibInclude"`. And of course feel free to make needed changes to your copy of this file. For example, you might want to include just particular nornsLib extension files, e.g. `include "nornsLib/utilExt"` instead of all the extensions via `include "nornsLib/includeAllExt"`
```
-- This file shows how nornsLib can be included. It is recommended that the 
-- application developer copy this file to their application, modify as needed,
-- and then include it. 

-- If nornsLib doesn't exist on user's Norns device then clone it from GitHub
if not util.file_exists(_path.code.."nornsLib") then
  os.execute("git clone https://github.com/skibu/nornsLib.git ".._path.code.."nornsLib")
end

-- Include this file if app should auto update nornsLib to pick up the latest
-- greatest version. Now that we know that at least an old verison nornsLib 
-- already installed we can include it from the nornsLib directory.
include "nornsLib/updateLib"

-- Include the appropriate nornsLib extensions. Or more easily, just load all of them
-- at once using includeAllExt.
include "nornsLib/includeAllExt"
```
