-- Rocks2git configuration.

data_dir = path.abspath("data")

mirror_repo =    path.join(data_dir, "luarocks-mirror")
git_base =       path.join(data_dir, "repos")
temp_dir =       path.join(data_dir, "tmp")
blacklist_file = path.join(data_dir, "module-blacklist")

blacklist =   file.read(blacklist_file):split()

log_file =    path.join(data_dir, "log/rocks2git%s.log")

return _ENV
