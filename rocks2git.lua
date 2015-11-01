-- Rocks2Git - Automatic Luarocks to Git importer

local lfs = require "lfs"

require "pl"
stringx.import()

local logging = require "logging"
require "logging.console"
local log = logging.console()

local config = dofile("config.lua")


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


-- Check for a sensible version number.
-- Accepts X.Y[.Z] with arbitrary alphanumeric suffix ("beta", "rc2", etc...)
function check_version(v)
    return v:match("^%d?%d%.%d+[%w%-%.%+]*") or v:match("^%d?%d%.%d+%.%d+[%w%-%.%+]*")
end


function unpack_version(v)
    local x, y, z, _, r
    if v:match("^%d?%d%.%d+%.%d+[%w%-%.%+]*") then
        x, y, z, _, r = v:match("^(%d?%d)%.(%d+)%.(%d+)([%w%-%.%+]*)%-(%d+)$")
        return {
            x = tonumber(x),
            y = tonumber(y),
            z = tonumber(z),
            _ = _,
            r = tonumber(r)
        }
    end
    if v:match("^%d?%d%.%d+[%w%-%.%+]*") then
        x, y, _, r = v:match("^(%d?%d)%.(%d+)([%w%-%.%+]*)%-(%d+)$")
        return {
            x = tonumber(x),
            y = tonumber(y),
            z = 0,
            _ = _,
            r = tonumber(r)
        }
    end
end


function version_comparator(x, y)
    local a = unpack_version(x)
    local b = unpack_version(y)

    if a.x < b.x then
        return true
    end
    if a.x == b.x then
        if a.y < b.y then
            return true
        end
        if a.y == b.y then
            if a.z < b.z then
                return true
            end
            if a.z == b.z then
                if a._ < b._ then
                    return true
                end
                if a._ and b._ and a._ == b._ then
                    if a.r < b.r then
                        return true
                    end
                end
            end
        end
    end

    return false
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
            log:warn("Incorrect rockspec filename: %s", path.basename(spec))
            return
        end

        -- Check blacklist
        if tablex.find(blacklist, name) ~= nil then
            log:warn("Module name %s is blacklisted", name)
            return
        end

        -- Check version format
        if not check_version(version) then
            log:warn("Incorrect version '%s' in module %s", version, name)
            return
        end

        -- Add version to table
        if not modules[name] then modules[name] = {} end
        modules[name][version .. "-" .. rev] = spec

    end
    )

    return modules
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


-- List of all tagged versions, sorted
function get_module_versions(repo)
    ok, code, out, err = dir_exec(repo, "git tag --sort='v:refname'", true)

    if code ~= 0 then
        return nil, err
    end
    return out:splitlines()
end


-- Get a module's repository, creating it if one doesn't exist
function get_module_repo(module)
    local repo_path = path.join(config.git_base, module)

    if path.exists(repo_path) and path.isdir(repo_path) then
        return repo_path
    end

    dir.makepath(repo_path)
    dir_exec(repo_path, "git init")
    return repo_path
end


function luarocks_download_module(module, version, spec_file, target_dir)

    ok, code, out, err = dir_exec(target_dir, "luarocks unpack '" .. spec_file .. "'", true)

    if err:match("Error") or out == '' then
        --log:error(err)
        -- TODO try to download src.rock
        return nil, err
    end

    -- extract module location from luarocks output
    output = out:splitlines()
    return target_dir .. '/' .. output[#output-1]

end


function cleanup_repo(repo)
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
    last_major = tonumber(#tagged_versions and tagged_versions[#tagged_versions]:match("^(%d+)%.") or nil)

    -- Version already processed
    if tablex.find(tagged_versions, version) ~= nil then
        return
    end

    -- Download module from LuaRocks
    module_dir = luarocks_download_module(module, version, spec_file, config.temp_dir)
    if not module_dir or not (path.exists(module_dir) and path.isdir(module_dir)) then
        log:error("Module %s-%s could not be downloaded.", name, version)
        return
    end

    major = tonumber(version:match("^(%d+)%."))

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

    -- Cleanup repo contents
    cleanup_repo(repo)

    -- Move module to repo
    move_module(module_dir, repo)

    -- Add rockspec file
    -- TODO modify source
    file.copy(spec_file, path.join(repo, path.basename(spec_file)))

    -- Commit changes
    dir_exec(repo, "git add -A")
    dir_exec(repo, "git commit -m '" .. "Update to version " .. version .. "'")

    -- Tag Git version
    dir_exec(repo, "git tag -a '" .. version .. "' -m '" .. "Update to version " .. version .. "'")

    -- Cleanup tmp repo
    --a, b, c, d = dir_exec(config.temp_dir, "rm -rf ./", true)
    --if not a or tonumber(b) ~= 0 then print(c, d) end
end


function process_module(name, versions)

    repo = get_module_repo(name)

    print(name)
    for version, spec_file in tablex.sort(versions, version_comparator) do
        print('\t'..version)
        process_module_version(name, version, repo, spec_file)
    end

end



log:setLevel(logging.ERROR)

local modules = get_luarocks_modules()
for name, versions in tablex.sort(modules) do
    process_module(name, versions)
end


--name = 'busted'
--process_module(name, modules[name])

--print(version_comparator('2.0-5', '1.0.34-1'))
