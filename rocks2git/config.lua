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
luarocks_timeout = tonumber(os.getenv("ROCKS2GIT_LUAROCKS_TIMEOUT")) or 10 -- Timeout (in sec) for LuaRocks downloads


-- Directories -----------------------------------------------------------------
local base_dir = os.getenv("ROCKS2GIT_BASE_DIR") or path.abspath("")
local data_dir = os.getenv("ROCKS2GIT_DATA_DIR") or path.join(base_dir, "data")

mirror_dir = os.getenv("ROCKS2GIT_MIRROR_DIR") or path.join(data_dir, "luarocks-mirror")      -- LuaRocks rockspec mirror repository
repo_dir   = os.getenv("ROCKS2GIT_REPO_DIR")   or path.join(data_dir, "repos")                -- Base path for module repositories
temp_dir   = os.getenv("ROCKS2GIT_TEMP_DIR")   or path.join(data_dir, "tmp")                  -- Temp dir for LuaRocks downloaded modules

manifest_file = os.getenv("ROCKS2GIT_MANIFEST_FILE") or path.join(data_dir, "manifest-file")     -- Manifest file with module dependencies


-- Blacklist -------------------------------------------------------------------
blacklist_file = os.getenv("ROCKS2GIT_BLACKLIST_FILE") or path.join(data_dir, "module-blacklist") -- Module blacklist file
blacklist      = stringx.split(file.read(blacklist_file))

-- Travis ----------------------------------------------------------------------
travis_file = os.getenv("ROCKS2GIT_TRAVIS_FILE") or path.join(base_dir, "travis_file.yml") -- Travis configuration template

travis_before_install = os.getenv("ROCKS2GIT_TRAVIS_BEFORE_INSTALL") or "https://raw.githubusercontent.com/LuaDist-core/travis-scripts/master/before_install.sh"
travis_script         = os.getenv("ROCKS2GIT_TRAVIS_SCRIPT")         or "https://raw.githubusercontent.com/LuaDist-core/travis-scripts/master/script.sh"
travis_after_script   = os.getenv("ROCKS2GIT_TRAVIS_AFTER_SCRIPT")   or "https://raw.githubusercontent.com/LuaDist-core/travis-scripts/master/after_script.sh"

-- Logging ---------------------------------------------------------------------
log_level       = logging.DEBUG                                 -- Logging level.
log_dir         = os.getenv("ROCKS2GIT_LOG_DIR") or path.join(base_dir, 'logs') -- Log directory


-- Git configuration -----------------------------------------------------------
git_user_name     = os.getenv("ROCKS2GIT_GIT_USER_NAME")     or "LunaCI"                             -- Author of the Git commits.
git_user_mail     = os.getenv("ROCKS2GIT_GIT_USER_MAIL")     or "lunaci@luadist.org"                 -- Author's e-mail
git_module_source = os.getenv("ROCKS2GIT_GIT_MODULE_SOURCE") or "git://github.com/LuaDist2/%s.git"   -- Module source endpoint - Use %s in place of module name
