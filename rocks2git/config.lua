-- Rocks2Git configuration
-- Part of the LuaDist project - http://luadist.org
-- Author: Martin Srank, hello@smasty.net
-- License: MIT

module("rocks2git.config", package.seeall)

local path = require "pl.path"
local file = require "pl.file"
local stringx = require "pl.stringx"
local logging = require "logging"


-- Configuration ---------------------------------------------------------------
luarocks_timeout = 10 -- Timeout (in sec) for LuaRocks downloads


-- Directories -----------------------------------------------------------------
local data_dir = path.abspath("data")

mirror_dir = path.join(data_dir, "luarocks-mirror")      -- LuaRocks rockspec mirror repository
repo_dir   = path.join(data_dir, "repos")                -- Base path for module repositories
temp_dir   = path.join(data_dir, "tmp")                  -- Temp dir for LuaRocks downloaded modules

manifest_file = path.join(data_dir, "manifest-file")     -- Manifest file with module dependencies


-- Blacklist -------------------------------------------------------------------
blacklist_file = path.join(data_dir, "module-blacklist") -- Module blacklist file
blacklist      = stringx.split(file.read(blacklist_file))


-- Logging ---------------------------------------------------------------------
log_level       = logging.WARN                                 -- Logging level.
log_file        = path.join(data_dir, "logs/rocks2git-%s.log") -- Log output file path - %s in place of date
log_date_format = "%Y-%m-%d"                                   -- Log date format


-- Git configuration -----------------------------------------------------------
git_user_name     = "LunaCI"                             -- Author of the Git commits.
git_user_mail     = "lunaci@luadist.org"                 -- Author's e-mail
git_module_source = "git://github.com/LuaDist2/%s.git"   -- Module source endpoint - Use %s in place of module name
