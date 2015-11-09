-- Rocks2Git - Automatic Luarocks to Git importer
-- luaci@luadist.org
-- verzie skusit zoradit, pripadne orphan, to iste ked znova ideme a uz funguje
-- source cez commentre
-- logovanie len chyb + co failo

module("rocks2git", package.seeall)

local lfs = require "lfs"

require "pl"
stringx.import()

local logging = require "logging"
require "logging.console"
local log = logging.console()

local config = require "rocks2git.config"
local constraints = require "rocks2git.constraints"


------------ UTILS


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
    local specs = dir.getfiles(config.mirror_repo, "*.rockspec")

    tablex.foreachi(specs, function(spec, i)
        local f = path.splitext(path.basename(spec))

        name, version, rev = f:match("(.+)%-(.+)%-(%d+)")

        -- Check correct rockspec filename
        if not(name and version and rev) then
            log:error("Incorrect rockspec filename: %s", path.basename(spec))
            return
        end

        -- Check blacklist
        if tablex.find(config.blacklist, name) ~= nil then
            log:warn("Module name %s is blacklisted", name)
            return
        end

        -- Add version to table
        if not modules[name] then modules[name] = {} end
        modules[name][version .. "-" .. rev] = spec

    end
    )

    return modules
end


-- Update source in the rockspec to new LuaDist github repo
function update_rockspec_source(spec_file, name, version)
    local lines = file.read(spec_file):splitlines()
    local source_start, source_end

    -- Find source definition line numbers
    for i = 1, #lines do
        if lines[i]:match("^%s*source%s*=%s{") then
            source_start = i
        end
        if source_start and i >= source_start and lines[i]:match("^%s*}") then
            source_end = i
            break
        end
    end

    -- Comment out old source definition
    for i = source_start, source_end do
        lines[i] = "-- " .. lines[i]
    end

    -- Prepare new source definition
    new_source = {
        url = config.git_module_source:format(name),
        tag = version
    }
    source_string = "-- LuaDist source\nsource = " .. pretty.write(new_source) .. "\n"
    lines[source_start] = source_string .. lines[source_start]

    return ("\n"):join(lines)
end


------------ GIT-RELATED


function dir_exec(dir, cmd, capture)
    ok, pwd = change_dir(dir)
    if not ok then error("Could not change directory.") end

    log:debug("Running command: " .. cmd)

    ok, code, out, err = utils.executeex(cmd)

    okk = change_dir(pwd)
    if not okk then error("Could not change directory.") end

    if not capture then
        return ok, code
    else
        return ok, code, out, err
    end
end


-- List of all tagged versions, sorted.
-- If argument 'major' is specified, only versions with that major are returned, sorted by commit date newest-first.
function get_module_versions(repo, major)
    if major then
        ok, code, out, err = dir_exec(repo, "git for-each-ref --sort=-taggerdate --format '%(refname:short)' refs/tags | grep '^"
            .. major .. "[.-]'", true)

        if err ~= "" then
            return nul, err
        end
        return out:splitlines()
    end

    ok, code, out, err = dir_exec(repo, "git tag --sort='v:refname'", true)

    if code ~= 0 then
        return nil, err
    end
    return out:splitlines()
end


-- Prepare module's repository, creating it if one doesn't exist
function prepare_module_repo(module)
    local repo_path = path.join(config.git_base, module)

    if path.exists(repo_path) and path.isdir(repo_path) then
        -- TODO pull all branches and tags
        return repo_path
    end

    dir.makepath(repo_path)
    dir_exec(repo_path, "git init")
    dir_exec(repo_path, "git config --local user.name '"  .. config.git_user_name .. "'")
    dir_exec(repo_path, "git config --local user.email '" .. config.git_user_mail .. "'")
    return repo_path
end


function luarocks_download_module(spec_file, target_dir)

    ok, code, out, err = dir_exec(target_dir, "luarocks unpack '" .. spec_file .. "' --timeout=" .. config.luarocks_timeout, true)

    if err:match("Error") or out == "" then
        return nil, err
    end

    -- Extract module location from luarocks output
    output = out:splitlines()
    return target_dir .. "/" .. output[#output-1]

end


function cleanup_dir(repo)
    files = dir.getfiles(repo)
    for i = 1, #files do
        file.delete(files[i])
    end
    dirs = dir.getdirectories(repo)
    for i = 1, #dirs do
        if path.basename(dirs[i]) ~= ".git" then
            dir.rmtree(dirs[i])
        end
    end
end


function move_module(module_dir, repo)
    files = dir.getfiles(module_dir)
    for i = 1, #files do
        dir.movefile(files[i], path.join(repo, path.basename(files[i])))
    end
    dirs = dir.getdirectories(module_dir)
    for i = 1, #dirs do
        if path.basename(dirs[i]) ~= ".git" then
            dir.movefile(dirs[i], path.join(repo, path.basename(dirs[i])))
        end
    end
end


function process_module_version(name, version, repo, spec_file)
    -- Get processed versions
    tagged_versions = get_module_versions(repo)

    -- Get latest major version
    last_major = tonumber(#tagged_versions and tagged_versions[#tagged_versions]:match("^(%d+)[%.%-]") or nil)

    -- Version already processed
    if tablex.find(tagged_versions, version) ~= nil then
        return
    end

    -- Download module from LuaRocks
    module_dir = luarocks_download_module(spec_file, config.temp_dir)

    -- Try to find src.rock in the mirror repo
    src_file = path.join(config.mirror_repo, name .. "-" .. version .. ".src.rock")
    if not module_dir and path.exists(src_file) and path.isfile(src_file) then
        --module_dir = luarocks_download_module(src_file, config.temp_dir)
    end

    if not module_dir or not (path.exists(module_dir) and path.isdir(module_dir)) then
        log:error("Module %s-%s could not be downloaded.", name, version)
        return
    end

    major = tonumber(version:match("^(%d+)[%.%-]"))

    -- Create major branch for last major and checkout master
    if last_major and major > last_major then
        dir_exec(repo, "git checkout -b " .. name .. "-" .. last_major)
        dir_exec(repo, "git checkout master")

    -- Checkout correct major branch
    elseif last_major and major < last_major then
        dir_exec(repo, "git checkout " .. name .. "-" .. major)

    -- Checkout master, just to be sure.
    else
        ok, _, branches = dir_exec(repo, "git branch")
        if branches ~= "" then
            dir_exec(repo, "git checkout master")
        end
    end

    -- Check if commit chronology can be retained - if not, checkout a new branch based on preceeding tagged version
    my_major_versions = get_module_versions(repo, major)
    if #my_major_versions then
        local largest = constraints.parse_version(my_major_versions[1])
        local current = constraints.parse_version(version)
        if largest > current then
            local start_point
            for i = 1, #my_major_versions do
                if current > constraints.parse_version(my_major_versions[i]) then
                    start_point = my_major_versions[i]
                    break
                end
            end

            dir_exec(repo, "git checkout -b " .. name .. "-" .. version .. " " .. start_point)
        end
    end

    -- Cleanup repo contents
    cleanup_dir(repo)

    -- Move module to repo
    move_module(module_dir, repo)

    -- Add rockspec file with modified source definition
    rockspec = update_rockspec_source(spec_file, name, version)
    file.write(path.join(repo, path.basename(spec_file)), rockspec)

    -- Commit changes
    dir_exec(repo, "git add -A")
    dir_exec(repo, "git commit -m '" .. "Update to version " .. version .. "'")

    -- Tag Git version
    dir_exec(repo, "git tag -a '" .. version .. "' -m '" .. "Update to version " .. version .. "'")

end


function process_module(name, versions)

    repo = prepare_module_repo(name)

    print(name)
    for version, spec_file in tablex.sort(versions, constraints.compare_versions) do
        print("\t"..version)
        process_module_version(name, version, repo, spec_file)
    end

end



log:setLevel(logging.ERROR)

--TODO pull luarocks mirror repo
dir_exec(config.mirror_repo, "git pull origin master")

local modules = get_luarocks_modules()
--for name, versions in tablex.sort(modules) do
--    process_module(name, versions)
--end

name = 'busted'
process_module(name, modules[name])


cleanup_dir(config.temp_dir)
