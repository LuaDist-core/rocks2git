-- Clone rockspecs mirror repo
--[[
require 'git'

local repo = 'git://github.com/rocks-moonscript-org/moonrocks-mirror.git'
local ref = 'refs/heads/master'

RockspecRepo = git.repo.create('tmp/rockspecs.git')
local _, sha = git.protocol.fetch(repo, RockspecRepo, ref)
RockspecRepo:checkout(sha, 'tmp/rockspecs')
]]

local pl = {}
pl.dir = require 'pl.dir'
pl.path = require 'pl.path'

local dist = require 'dist'
local sys = dist.sys


-- Iterate over a table in key order.
function sortedPairs(t, f)
    local a = {}
    for n in pairs(t) do table.insert(a, n)
    end
    table.sort(a, f)
    local i = 0
    local iter = function()
        i = i + 1
        if a[i] == nil then return nil
        else return a[i], t[a[i]]
        end
    end
    return iter
end


-- Downloads a luarocks package, returning path relative to given target_dir.
function luarocks_download(spec_file, target_dir)

    local spec_file = sys.abs_path(spec_file)

    local ok, pwd = sys.change_dir(target_dir)
    if not ok then error('Failed to change working directory') end

    -- run luarocks capturing the output
    local luarocks_out = sys.capture_output('luarocks unpack ' .. sys.quote(spec_file))

    if luarocks_out:match('Error') then error('Luarocks failed') end

    -- extract module location from luarocks output
    i = string.find(luarocks_out, '\n', 2);
    j = string.find(luarocks_out, '\n', i+1);
    local location = string.sub(luarocks_out, i+1, j-1)

    local ok = sys.change_dir(pwd)
    if not ok then error('Failed to change working directory') end

    return location
end


-- A secure loadfile function
-- If file code chunk has upvalues, the first upvalue is set to the given
-- environement, if that parameter is given, or to the value of the global environment.
-- Copied from original luadist-git.
function secure_loadfile(file, env)
    assert(type(file) == "string", "secure_loadfile: Argument 'file' is not a string.")

    -- use the given (or create a new) restricted environment
    local env = env or {}

    -- load the file and run in a protected call with the restricted env
    -- setfenv is deprecated in lua 5.2 in favor of giving env in arguments
    -- the additional loadfile arguments are simply ignored for previous lua versions
    local f, err = loadfile(file, 'bt', env)
    if f then
        if setfenv ~= nil then
            setfenv(f, env)
        end
        return pcall(f)
    else
        return nil, err
    end
end


function git_command(repo, cmd)
    local ok, pwd = sys.change_dir(sys.abs_path(repo))
    if not ok then error('Failed to change working directory') end

    local res = sys.exec(cmd, true)

    local ok = sys.change_dir(pwd)
    if not ok then error('Failed to change working directory') end

    return res
end



-- Get all modules and parse them
local specs = pl.dir.getfiles('tmp/rockspecs/', '*.rockspec')

modules = {}

for i = 1, #specs do
    local f = pl.path.splitext(pl.path.basename(specs[i]))

    name, version, rev = f:match('(.+)%-(.+)%-(%d+)')

    if not modules[name] then modules[name] = {} end
    modules[name][version .. '-' .. rev] = specs[i]
end



-- Test with redis-lua

local mod_name = 'redis-lua'
local mod = modules[mod_name]

local target_dir = sys.abs_path('tmp/modules/')
local repo_base_dir = sys.abs_path('repos/')

local last_major = 0

print('Module: ' .. mod_name)
for version, spec_file in sortedPairs(mod) do

    -- load rockspec file
    local spec_file = sys.abs_path(spec_file)
    local rockspec = {}
    secure_loadfile(spec_file, rockspec)

    -- download module from luarocks
    module_dir = sys.make_path(target_dir, luarocks_download(spec_file, target_dir))
    repo_dir = sys.make_path(repo_base_dir, mod_name)

    -- init git repo if needed
    if not sys.exists(repo_dir) then
        sys.make_dir(repo_dir)
        git_command(repo_dir, 'git init')
    end

    -- new major version?
    local major = version:match('^(%d+)%.')
    if tonumber(major) > last_major and last_major ~= 0 then
        git_command(repo_dir, 'git checkout -b ' .. mod_name .. '-' .. last_major)
        git_command(repo_dir, 'git checkout master')
    end

    -- cleanup repo
    for f in sys.get_directory(repo_dir) do
        if f ~= '.' and f ~= '..' and f ~= '.git' then
            sys.delete(sys.make_path(repo_dir, f))
        end
    end

    -- move module to repo
    for f in sys.get_directory(module_dir) do
        if f ~= '.' and f ~= '..' then
            sys.move_to(sys.make_path(module_dir, f), repo_dir)
        end
    end

    -- add rockspec file
    sys.copy(spec_file, repo_dir)

    -- commit changes
    git_command(repo_dir, 'git add .')
    git_command(repo_dir, 'git commit -m ' .. sys.quote("Update to version " .. version .. " [rocks2git-bot]"))

    -- tag version in git
    git_command(repo_dir, 'git tag -a ' .. sys.quote(version) .. ' -m ' .. sys.quote("Update to version " .. version .. " [rocks2git-bot]"))

    -- cleanup tmp directory.
    for f in sys.get_directory(target_dir) do
        if f ~= '.' and f ~= '..' and f ~= '.git' then
            sys.delete(sys.make_path(target_dir, f))
        end
    end

    last_major = tonumber(major)

end

print('\n\n No more versions. Done.')
