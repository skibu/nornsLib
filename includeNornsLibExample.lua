-- The code for manually downloading NornsLib is shown below. This is for when an
-- application script wants to make sure that nornsLib is available. That means
-- that this script will not be available if it hasn't yet been downloaded. 
-- Therefore an application script should copy this function into their code and
-- then call it before trying to include any of the nornsLib utilities.

function download_nornsLib()
  if not util.file_exists(_path.code.."nornsLib") then
    os.execute("git clone https://github.com/skibu/nornsLib.git ".._path.code.."nornsLib")
  end
end