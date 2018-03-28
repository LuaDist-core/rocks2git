# Rocks2Git

_Automatic LuaRocks to Git repo import utility_

- Author: Martin Šrank, [hello@smasty.net](mailto:hello@smasty.net)
- License: MIT
- **Part of the [LuaDist project](http://luadist.org)**

Downloads all modules from LuaRocks and creates Git repositories with correct tags, branches and commit history for each module.

## Requirements

### System
- `luarocks` >= 2.2.0
- `git` >= 2.0.0

### Lua
- `penlight` >= 1.3.2
- `lualogging`

## Installation

You need to have a LuaRocks mirror repository cloned and linked from config.
Run this in your `mirror_dir` directory:

```sh
$ git clone https://github.com/rocks-moonscript-org/moonrocks-mirror.git ./
```

## Configuration

Rocks2Git can be configured by specifying several environment variables described below.

### Paths

All paths specified in the configuration file (`rocks2git/config.lua`) need to exist before the utility is run.

- `ROCKS2GIT_BASE_DIR` - the base directory where everything else is located (defaults to the working directory)
- `ROCKS2GIT_DATA_DIR` - the base directory for all the generated data (defaults to `${ROCKS2GIT_BASE_DIR}/data`)

- `ROCKS2GIT_MIRROR_DIR` - directory containing the LuaRocks rockspec mirror repository (defaults to `${ROCKS2GIT_DATA_DIR}/luarocks-mirror`)
- `ROCKS2GIT_REPO_DIR` - base path for module repositories (defaults to `${ROCKS2GIT_DATA_DIR}/repos`)
- `ROCKS2GIT_TEMP_DIR` - temporary directory for LuaRocks downloaded modules (defaults to `${ROCKS2GIT_DATA_DIR}/tmp`)

- `ROCKS2GIT_MANIFEST_FILE` - manifest file with module dependencies (defaults to `${ROCKS2GIT_DATA_DIR}/manifest-file`)
- `ROCKS2GIT_BLACKLIST_FILE` - module blacklist file (defaults to `${ROCKS2GIT_DATA_DIR}/module-blacklist`)

- `ROCKS2GIT_TRAVIS_FILE` - Travis configuration template (defaults to `${ROCKS2GIT_BASE_DIR}/travis_file.yml`)

### Travis script URLs

These are URLs for bash scripts which will be run by the Travis CI after wiring everything together.
The names of the environment variables correspond to the names of the Travis CI events.

- `ROCKS2GIT_TRAVIS_BEFORE_INSTALL` - defaults to `https://gist.githubusercontent.com/MilanVasko/c7fe4400d4f0bbe29e243cdc140036e4/raw`
- `ROCKS2GIT_TRAVIS_SCRIPT` - defaults to `https://gist.githubusercontent.com/MilanVasko/e3dd16f4295c767e6a42f56f1c3c8b4d/raw`
- `ROCKS2GIT_TRAVIS_AFTER_SCRIPT` - defaults to `https://gist.githubusercontent.com/MilanVasko/4d2e2fcc6ef88d2daaad179ff09f4ad7/raw`

`ROCKS2GIT_LOG_FILE` - log output file path - use %s in place of date (defaults to `${ROCKS2GIT_BASE_DIR}/logs/rocks2git-%s.log`)

### Git configuration

- `ROCKS2GIT_GIT_USER_NAME` - author of the Git commits (defaults to `LunaCI`)
- `ROCKS2GIT_GIT_USER_MAIL` - author's e-mail (defaults to `lunaci@luadist.org`)
- `ROCKS2GIT_GIT_MODULE_SOURCE` - module source endpoint - use %s in place of the module name (defaults to `git://github.com/LuaDist2/%s.git`)

## Usage

This utility can be used in either _batch_ or _single_ mode.

### Batch mode

In this mode, the utility processes all the modules from the LuaRocks mirror repository. Output is logged into a log file,
which can be specified in config. You can also specify the level of logging.

```sh
$ lua ./rocks2git.lua
```

### Single mode

In this mode, only the module given on command line is processed. Output is logged to the console output on all levels.

```sh
$ lua ./rocks2git.lua module_name
```

### Pushing to GitHub

To push the generated Git repositories to Github, use the **GitHub Pusher** LuaDist utility.
