-- TEST
-- For including libs from nornsLib repo. Similar to include(), but downloads 
-- nornsLib if haven’t done so previously to the user's device. And if NornsLib
-- already downloaded then this will automatically load updates via git checkout.
-- @tparam name - just the name of the particulae lib to include. Don't need
-- directory nor the .lua suffix.
function include_norns_lib(name)
  -- Where to find the github github_repo
  local github_repo_owner = "skibu"
  local github_repo = "nornsLib"

  -- Update or download the library
  if util.file_exists(_path.code..github_repo) then
    -- Norns lib already exists so just update it. 
    -- NOTE: user made changes to the lib will be lost!
    local command = "git -C ".._path.code..github_repo.." checkout ."
    print("Updating NornsLib using command:\n"..command)
    os.execute(command)
  else
    -- Norns lib hasn't yet been downloaded so clone it
    local command = "git clone https://github.com/"..github_repo_owner.."/"..github_repo..".git ".._path.code..github_repo
    print("Downloading NornsLib using command:\n"..command)
    os.execute(command)
  end
  
  -- Now try including the lib again
  return include(github_repo.."/"..name)
end

-- Then can include lib files vie something like:
include_norns_lib("parameterExtensions")
