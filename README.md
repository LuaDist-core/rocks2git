# Rocks2Git

_Automatic LuaRocks to Git repo import utility_

- Author: Martin Šrank, [martin@smasty.net](mailto:martin@smasty.net)
- License: MIT
- **Part of the [LuaDist project](http://luadist.org)**

Downloads all modules from LuaRocks and creates Git repositories with correct tags, branches and commit history for each module.

## Requirements

### System
- `luarocks` command line utility
- `git` >= 2.0.0

### Lua
- `penlight` >= 1.3.2
- `lualogging`

## Installation and configuration

You need to have a LuaRocks mirror repository cloned and linked from config.
Run this in your `mirror_dir` directory:

```sh
$ git clone git@github.com:rocks-moonscript-org/moonrocks-mirror.git ./
```

All paths specified in the configuration file (`rocks2git/config.lua`) need to be created before the utility is run.

## Usage

This utility can be used in either _batch_ or _single_ mode.

### Batch mode

In this mode, the utility processes all the modules from the LuaRocks mirror repository. Output is logged into a log file, which can be specified in config. You can also specify the level of logging.

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
