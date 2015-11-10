-- Rocks2Git configuration
-- Part of the LuaDist project - http://luadist.org
-- Author: Martin Srank, martin@smasty.net
-- License: MIT

module("rocks2git.config", package.seeall)

local path = require "pl.path"
local file = require "pl.file"


-- Main data directory. All other data files should be relative to this.
data_dir = path.abspath("data")

-- Path to the LuaRocks rockspec mirror repository
mirror_repo = path.join(data_dir, "luarocks-mirror")

-- Base path for Git repositories
git_base = path.join(data_dir, "repos")

-- Path to the temporary directory, where LuaRocks unpacks downloaded modules
temp_dir = path.join(data_dir, "tmp")


-- Module blacklist file
blacklist_file = path.join(data_dir, "module-blacklist")

-- Log output file path - Use %s in place of date
log_file = path.join(data_dir, "log/rocks2git%s.log")


-- Timeout (in seconds) for LuaRocks downloads
luarocks_timeout = 10


-- Author of the Git commits.
git_user_name = "LuaCI"
git_user_mail = "luaci@luadist.org"
-- TODO email is incorrect


-- Module source endpoint - Use %s in place of module name
git_module_source = "git://github.com/LuaDist2/%s.git"


---------------------------------------------------


blacklist = file.read(blacklist_file):split()
