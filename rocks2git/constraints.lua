-- Rocks2Git version constraints functions
-- Peter Drahoš, LuaDist Project, 2010
-- Original Code borrowed from LuaRocks Project

-- Version constraints handling functions.
-- Dependencies are represented in LuaDist through strings with
-- a dist name followed by a comma-separated list of constraints.
-- Each constraint consists of an operator and a version number.
-- In this string format, version numbers are represented as
-- naturally as possible, like they are used by upstream projects
-- (e.g. "2.0beta3"). Internally, LuaDist converts them to a purely
-- numeric representation, allowing comparison following some
-- "common sense" heuristics. The precise specification of the
-- comparison criteria is the source code of this module, but the
-- test/test_depends.lua file included with LuaDist provides some
-- insights on what these criteria are.

--  Version supported syntax is of form (in ABNF, see rfc5234):
--  DIGIT = %x30-39 ; 0-9
--  ALPHA = %x41-5A / %x61-7A ; A-Z / a-z
--  NUMSEP = "." / "_" / "-"
--  VERSION = 1*DIGIT *(NUMSEP 1*DIGIT)
--  TAG = 1*ALPHA *(NUMSEP 1*ALPHA)
--  SEMANTIC_VERSION = *(VERSION / TAG) ["-" 1*DIGIT]
--
--  Note: because of multiple sets of VERSION and TAG, version_mt is actually
--  able to compare SEMANTIC_VERSION with the similar sequence of VERSION / TAG.
--  e.g. alpha-2.9.0 can be compared to beta-3.0.0, but
--  "LUAPRJ_V1.3" cannot be successfully compared with "1.4"
--  and "alpha-1.0.0" cannot be successfully compared with "1.0.0-alpha"


module("rocks2git.constraints", package.seeall)


local precedence = {
    scm =   -100,
    rc =    -1000,
    pre =   -10000,
    beta =  -100000,
    alpha = -1000000,
    work =  -10000000,
    devel = -100000000,
    other = -1000000000,
}


local version_mt = {
    --- Equality comparison for versions.
    -- All version numbers must be equal. Missing numbers are replaced by 0.
    -- If both versions have revision numbers, they must be equal;
    -- otherwise the revision number is ignored.
    -- @param v1 table: version table to compare.
    -- @param v2 table: version table to compare.
    -- @return boolean: true if they are considered equivalent.
    __eq = function(v1, v2)
        if #v1 ~= #v2 then
            return false
        end
        for i = 1, math.max(#v1, #v2) do
            local v1i, v2i = v1[i] or {}, v2[i] or {}
            for j = 1, math.max(#v1i, #v2i) do
                local v1ij, v2ij = v1i[j] or 0, v2i[j] or 0
                if v1ij ~= v2ij then
                    return false
                end
            end
        end
        if v1.revision and v2.revision then
            return (v1.revision == v2.revision)
        end
        return true
    end,

    --- Comparison for versions.
    -- All version numbers are compared. Missing numbers are replaced by 0.
    -- If both versions have revision numbers, they are compared;
    -- otherwise the revision number is ignored.
    -- @param v1 table: version table to compare.
    -- @param v2 table: version table to compare.
    -- @return boolean: true if v1 is considered lower than v2.
    __lt = function(v1, v2)
        for i = 1, math.max(#v1, #v2) do
            local v1i, v2i = v1[i] or {}, v2[i] or {}
            for j = 1, math.max(#v1i, #v2i) do
                local v1ij, v2ij = v1i[j] or 0, v2i[j] or 0
                if v1ij ~= v2ij then
                    return (v1ij < v2ij)
                end
            end
        end
        if v1.revision and v2.revision then
            return (v1.revision < v2.revision)
        end
        return false
    end
}


local version_cache = {}
setmetatable(version_cache, {
    __mode = "kv"
})


--- Parse a version string, converting to table format.
-- A version table contains all components of the version string
-- converted to numeric format, stored in the array part of the table.
-- If the version contains a revision, it is stored numerically
-- in the 'revision' field. The original string representation of
-- the string is preserved in the 'string' field.
-- Returned version tables use a metatable
-- allowing later comparison through relational operators.
-- @param vstring string: A version number in string format.
-- @return table or nil: A version table or nil
-- if the input string contains invalid characters.
function parse_version(vstring)
    if not vstring then return nil end
    assert(type(vstring) == "string")

    -- function that actually parse the version string
    local function parse(vstring)

        local version = {}
        setmetatable(version, version_mt)
        local add_table = function()
            local t = {}
            table.insert(version, t)
            return t
        end
        local t = add_table()
        -- trim leading and trailing spaces
        vstring = vstring:match("^%s*(.*)%s*$")
        version.string = vstring
        -- store revision separately if any
        local main, revision = vstring:match("(.*)%-(%d+)$")
        if revision then
            vstring = main
            version.revision = tonumber(revision)
        end
        local number
        while #vstring > 0 do
            -- extract a number
            local token, rest = vstring:match("^(%d+)[%.%-%_]*(.*)")
            if token then
                if number == false then
                    t = add_table()
                end
                table.insert(t, tonumber(token))
                number = true
            else
                -- extract a word
                token, rest = vstring:match("^(%a+)[%.%-%_]*(.*)")
                if token then
                    if number == true then
                        t = add_table()
                    end
                    table.insert(t, precedence[token:lower()] or precedence.other)
                    number = false
                end
            end
            vstring = rest
        end
        return version
    end

    -- return the cached version, if any
    local version = version_cache[vstring]
    if version == nil then
        -- or parse the version and add it to the cache beforehand
        version = parse(vstring)
        version_cache[vstring] = version
    end

    return version
end


--- Utility function to compare version numbers given as strings.
-- @param a string: one version.
-- @param b string: another version.
-- @return boolean: True if a > b.
function compare_versions(a, b)
    return parse_version(a) < parse_version(b)
end
