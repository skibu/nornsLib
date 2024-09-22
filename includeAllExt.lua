-- Includes all extensions. This file should be included, not required, so that NornsLib
-- will be automatically enabled for the currently running script. Otherwise will need
-- to call nornsLib.enable() elsewhere.

-- Enable the NornsLib for this particular script
local nornsLib = require "nornsLib/nornsLib"
nornsLib.enable()

log = require "nornsLib/loggingExt"
require "nornsLib/utilExt"
require "nornsLib/screenExt"
parameterExt = require "nornsLib/parameterExt"
psetExt = require "nornsLib/psetExt"
json = require "nornsLib/jsonExt"
require "nornsLib/textentryExt"