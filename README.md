# Rocks2Git

_Automatic LuaRocks to Git repo conversion tool._

Downloads all modules from LuaRocks and creates Git repositories with correct tags, branches and history for each module.

## Todo

- Update rockspec
- Create `data_dir` structure if not exist
- Refactor version comparator
- Proper logging on all levels (debug -> fatal)
- Stats after completion -> list of new/updated modules, list of failed modules

- Handling of non-SemVer packages?
- Split logs into log and errors?
- Handle versions starting with "v" prefix?
- Proper sorting of release_version?

- Docker container
