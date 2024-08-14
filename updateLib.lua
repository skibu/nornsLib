-- update_lib() is for optionally downloading or updating a Norns library from a git 
-- repository. If the library doesn't already exist then it is cloned from the repo. 
-- If it already exists then the library is updated. By using this function the user
-- will get any updates to the library.
--
-- If you are just dealing with nornsLib you can simply call update_nornsLib().
--
-- Of course NornsLib must already have been downloaded for these function
-- to be available. This means that if a script wants to use NornsLib it
-- must first execute code that downloads this file. To do so the script
-- should manually include the download NornsLib command. Then this update_lib()
-- script can be optionally called.
--
-- The code for manually downloading NornsLib is simply:
--   if not util.file_exists(_path.code.."nornsLib") then
--     os.execute("git clone https://github.com/skibu/nornsLib.git ".._path.code.."nornsLib")
--   end
function update_lib(github_repo_owner, github_repo)
  -- Update or download the library
  if not util.file_exists(_path.code..github_repo) then
    -- Lib hasn't yet been downloaded so clone it
    local command = "git clone https://github.com/"..github_repo_owner.."/"..github_repo..".git "
      .._path.code..github_repo
    print("Downloading "..github_repo.." using command:\n"..command)
    os.execute(command)
  else
    -- Library already exists, so just update it. Need to do a "checkout ."
    -- to get missing files and a "pull" to get modifications.
    local checkout_command = "git -C ".._path.code..github_repo.." checkout ."
    local pull_command = "git -C ".._path.code..github_repo.." pull --ff-only"
    print("Updating "..github_repo.." using commands:\n"..checkout_command..
      "\nand\n"..pull_command)
    os.execute(checkout_command)
    os.execute(pull_command)
  end
end  


-- For updating nornsLib specifically
function update_nornsLib()
  update_lib("skibu", "nornsLib")
end

  
