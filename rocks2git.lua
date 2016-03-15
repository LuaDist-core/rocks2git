-- Rocks2Git - Automatic LuaRocks to Git repo import utility
-- Part of the LuaDist project - http://luadist.org
-- Author: Martin Srank, hello@smasty.net
-- License: MIT

module("rocks2git", package.seeall)

local config = require "rocks2git.config"
local constraints = require "rocks2git.constraints"

local lfs = require "lfs"

require "pl"
stringx.import()

local logging = require "logging"
require "logging.file"
require "logging.console"



-- Change working directory.
-- Returns success and previous working directory or failure and error message.
function change_dir(dir_name)
    local prev_dir, err = lfs.currentdir()
    if not prev_dir then
        return nil, err
    end

    local ok, err = lfs.chdir(dir_name)
    if ok then
        return ok, prev_dir
    else
        return nil, err
    end
end


-- Create a table of modules from the LuaRocks mirror repository.
-- Only returns modules with correct name, version and revision info.
function get_luarocks_modules()
    local modules = {}
    local specs = dir.getfiles(config.mirror_dir, "*.rockspec")

    tablex.foreachi(specs, function(spec, i)
        local f = path.splitext(path.basename(spec))

        local name, version, rev = f:match("(.+)%-(.+)%-(%d+)")

        -- Check correct rockspec filename
        if not(name and version and rev) then
            log:error("Incorrect rockspec file: %s", path.basename(spec))
            return
        end

        -- Add version to table
        if not modules[name] then modules[name] = {} end
        modules[name][version .. "-" .. rev] = spec

    end
    )

    return modules
end


-- Update source in the rockspec to new LuaDist github repo.
-- If possible, original source is commented out.
function update_rockspec_source(spec_file, name, version)
    local contents = file.read(spec_file)
    local lines = contents:splitlines()
    local source_start, source_end

    -- Prepare new source definition
    local new_source = {
        url = config.git_module_source:format(name),
        tag = version
    }

    local headline = "-- This file was automatically generated for the LuaDist project.\n\n"

    -- Find source definition line numbers
    for i = 1, #lines do
        local l = lines[i]
        if l:match("^%s*source%s*=%s{") or (l:match("^%s*source%s*=") and l:match("^%s*{")) then
            source_start = i
        end
        if source_start and i >= source_start and lines[i]:match("^%s*}") then
            source_end = i
            break
        end
    end

    -- Load as table and change source, if cannot parse as text.
    if not source_start or not source_end then
        local spec_table = pretty.load(contents, nil, true)
        spec_table['source'] = new_source
        return headline .. pretty.write(spec_table):strip("{}")
    end

    -- Comment out old source definition
    for i = source_start, source_end do
        lines[i] = "-- " .. lines[i]
    end
    source_string = "-- LuaDist source\nsource = " .. pretty.write(new_source) .. "\n"
                 .. "-- Original source\n"
    lines[source_start] = source_string .. lines[source_start]

    return headline .. ("\n"):join(lines)
end


-- Execute a command in a given working directory.
-- Returns success/failure, actual return code, stdout and stderr outputs.
function dir_exec(dir, cmd)
    local ok, pwd = change_dir(dir)
    if not ok then error("Could not change directory.") end

    log:debug("Running command: " .. cmd)

    local ok, code, out, err = utils.executeex(cmd)

    local okk = change_dir(pwd)
    if not okk then error("Could not change directory.") end

    return ok, code, out, err
end


-- List of all tagged versions, sorted.
-- If argument 'major' is specified, only versions with that major are returned, sorted by commit date newest-first.
function get_module_versions(repo, major)
    if major then
        local ok, code, out, err = dir_exec(repo, "git for-each-ref --sort=-taggerdate --format '%(refname:short)' refs/tags | grep '^"
            .. major .. "[.-]'")

        if err ~= "" then
            return nil, err
        end
        return out ~= "" and out:splitlines() or {}
    end

    local ok, code, out, err = dir_exec(repo, "git tag --sort='v:refname'")

    if code ~= 0 then
        return nil, err
    end
    return out:splitlines()
end


-- Prepare module's repository, creating it if one doesn't exist.
-- If remote is specified, all branches and tags are updated to match the remote.
function prepare_module_repo(module)
    local repo_path = path.join(config.repo_dir, module)

    if path.exists(repo_path) and path.isdir(repo_path) then

        -- Check if remote is defined
        local ok, _, remote = dir_exec(repo_path, "git remote")
        if ok and remote ~= "" then
            -- Fetch all remote branches and tags
            local st = dir_exec(repo_path, "git fetch -q --all --tags")
            if not st then return nil end
            local st, code, out = dir_exec(repo_path, "git branch -r")
            local branches = out ~= "" and out:splitlines() or {}

            -- For every remote branch, checkout respective local branch and set it to mirror the remote
            for i = 1, #branches do
                local name = branches[i]:strip():gsub("origin/", "")
                local st = dir_exec(repo_path, "git checkout -f -B "..name.." origin/"..name)
                if not st then return nil end
            end
        end
        return repo_path
    end

    log:info("New module - %s", module)

    dir.makepath(repo_path)
    dir_exec(repo_path, "git init")
    dir_exec(repo_path, "git config --local user.name '"  .. config.git_user_name .. "'")
    dir_exec(repo_path, "git config --local user.email '" .. config.git_user_mail .. "'")
    return repo_path
end


-- Download a module using LuaRocks executable.
-- Returns path to the unpacked module, or nil and error message on failure.
function luarocks_download_module(spec_file, target_dir)

    local ok, code, out, err = dir_exec(target_dir, "luarocks unpack --force '" .. spec_file .. "' --timeout=" .. config.luarocks_timeout)

    if err:match("Error") or out == "" or code ~= 0 then
        return nil, err
    end

    -- Extract module location from luarocks output
    local output = out:splitlines()
    return target_dir .. "/" .. output[#output-1]

end


-- Remove all files and directories in a given path, except for ".git" directory.
function cleanup_dir(repo)
    local files = dir.getfiles(repo)
    for i = 1, #files do
        file.delete(files[i])
    end
    local dirs = dir.getdirectories(repo)
    for i = 1, #dirs do
        if path.basename(dirs[i]) ~= ".git" then
            dir.rmtree(dirs[i])
        end
    end
end


-- Move all files and directories in a given path, except for ".git" directory.
function move_module(module_dir, repo)
    local files = dir.getfiles(module_dir)
    for i = 1, #files do
        dir.movefile(files[i], path.join(repo, path.basename(files[i])))
    end
    local dirs = dir.getdirectories(module_dir)
    for i = 1, #dirs do
        if path.basename(dirs[i]) ~= ".git" then
            dir.movefile(dirs[i], path.join(repo, path.basename(dirs[i])))
        end
    end
end


-- Process given module version.
function process_module_version(name, version, repo, spec_file)
    -- Get processed versions
    local tagged_versions = get_module_versions(repo)

    -- Get latest major version
    local last_major = tonumber(#tagged_versions and tagged_versions[#tagged_versions]:match("^v?(%d+)[%.%-]") or nil)

    -- Version already processed
    if tablex.find(tagged_versions, version) ~= nil then
        return
    end

    -- Download module from LuaRocks
    local module_dir = luarocks_download_module(spec_file, config.temp_dir)

    -- Try to find src.rock in the mirror repo
    local src_file = path.join(config.mirror_dir, name .. "-" .. version .. ".src.rock")
    if not module_dir and path.exists(src_file) and path.isfile(src_file) then
        module_dir = luarocks_download_module(src_file, config.temp_dir)
    end

    if not module_dir or not (path.exists(module_dir) and path.isdir(module_dir)) then
        log:error("Module %s-%s could not be downloaded.", name, version)
        return
    end

    log:info("Updating module %s-%s", name, version)

    -- Some modules have version prefixes - we allow v, a, b, r (version, alpha, beta, RC).
    local major = tonumber(version:match("^[vabr]?(%d+)[%.%-]"))

    if not major then
        log:error("Module %s-%s: Could not determine major version.", name, version)
        return
    end

    -- Create major branch for last major and checkout master
    if last_major and major > last_major then
        dir_exec(repo, "git checkout -b " .. name .. "-" .. last_major)
        dir_exec(repo, "git checkout master")

    -- Checkout correct major branch
    elseif last_major and major < last_major then
        dir_exec(repo, "git checkout " .. name .. "-" .. major)

    -- Checkout master, just to be sure.
    else
        local ok, _, branches = dir_exec(repo, "git branch")
        if branches ~= "" then
            dir_exec(repo, "git checkout master")
        end
    end

    -- Check if commit chronology can be retained - if not, checkout a new branch based on preceeding tagged version
    local my_major_versions = get_module_versions(repo, major)
    if major and #my_major_versions then
        local largest = constraints.parse_version(my_major_versions[1])
        local current = constraints.parse_version(version)
        if largest and current and largest > current then
            local start_point
            for i = 1, #my_major_versions do
                if current > constraints.parse_version(my_major_versions[i]) then
                    start_point = my_major_versions[i]
                    break
                end
            end

            if start_point then
                dir_exec(repo, "git checkout -b " .. name .. "-" .. version .. " " .. start_point)
            else
                dir_exec(repo, "git checkout --orphan " .. name .. "-" .. version)
            end
        end
    end

    -- Cleanup repo contents
    cleanup_dir(repo)

    -- Move module to repo
    move_module(module_dir, repo)

    -- Add rockspec file with modified source definition
    local rockspec = update_rockspec_source(spec_file, name, version)
    file.write(path.join(repo, path.basename(spec_file)), rockspec)

    -- Commit changes
    dir_exec(repo, "git add -A")
    dir_exec(repo, "git commit -m '" .. "Update to version " .. version .. "'")

    -- Tag Git version
    dir_exec(repo, "git tag -a '" .. version .. "' -m '" .. "Update to version " .. version .. "'")

end


-- Process given module.
function process_module(name, versions)
    local repo = prepare_module_repo(name)

    if not repo then
        log:error("Failed to prepare Git repo for the module " .. name)
        return
    end

    -- Check blacklist
    if tablex.find(config.blacklist, name) ~= nil then
        log:warn("Module %s is blacklisted", name)
        return
    end

    for version, spec_file in tablex.sort(versions, constraints.compare_versions) do
        process_module_version(name, version, repo, spec_file)
    end

end


-- Generate manifest file
function generate_manifest(mods)
    local modules = {}
    local headline = os.date([[
-- LuaDist Manifest file
-- Generated on %Y-%m-%d, %H:%M
]])
    for name, versions in pairs(mods) do
        modules[name] = {}
        for ver, spec_file in tablex.sort(versions) do
            local contents = file.read(spec_file)
            local lines = contents:splitlines()

            -- Remove possible hashbangs
            if lines[1]:match("^#!.*") then
                table.remove(lines, 1)
            end

            -- Load rockspec file as table
            local spec = pretty.load(("\n"):join(lines), nil, false)
            local manifest = {}
            if spec then
                if spec['dependencies'] then manifest['dependencies'] = spec['dependencies'] end
                if spec['supported_platforms'] then manifest['supported_platforms'] = spec['supported_platforms'] end
            end
            modules[name][ver] = manifest
        end
    end

    local manifest = {
        package_path = config.git_module_source,
        packages = modules
    }

    file.write(config.manifest_file, headline .. pretty.write(manifest))
end


--------------------------------------------------------------------------------


-- If no argument is given, process all modules from the luarocks mirror repository.
if #arg < 1 then
    log = logging.file(config.log_file, config.log_date_format)
    log:setLevel(config.log_level)

    dir_exec(config.mirror_dir, "git pull origin master")

    local modules = get_luarocks_modules()
    for name, versions in tablex.sort(modules) do
        process_module(name, versions)
    end

    cleanup_dir(config.temp_dir)

    generate_manifest(modules)

-- If module name is given as an argument, process given module.
else
    log = logging.console("%level %message\n")

    local modules = get_luarocks_modules()
    local name = arg[1]

    if not modules[name] then
        log:error("No such module '%s'.", name)
    else
        process_module(name, modules[name])
        cleanup_dir(config.temp_dir)
    end
end
