-- luacheck: globals meta
local suite = require 'suite'
local assert = require 'assert'
local LuaSuite = suite.Suite:new()

function TestLuaSuite(t)
    assert:Greater(t, suite.Run(t, LuaSuite), 0, "no tests were discovered in LuaSuite")
end

function LuaSuite:SetupTest()
    meta.spec.MetaSpace = self:T():TempDir()
end

-- test starting key is empty
function LuaSuite:Test_foo_starts_as_nil()
    local foo = meta.get("foo")
    assert:Nil(self:T(), foo)
end

-- test setting foo to "bar" then getting "foo" returns bar
function LuaSuite:Test_set_get_string()
    meta.set("foo", "bar")
    foo = meta.get("foo")
    assert:Equal(self:T(), "bar", foo)
end

-- test setting a variable to number and then getting and doing arithmetic works
function LuaSuite:Test_get_set_num()
    meta.set("num", 123)
    local num = meta.get("num")
    assert:Equal(self:T(), 123, num)
end

-- test "ternary" for unset
function LuaSuite:Test_ternary_for_unset()
    local yada = meta.get("yada")
    assert:Nil(self:T(), yada)
    local num = yada == nil and 0 or tonumber(yada)
    assert:Equal(self:T(), 0, num)
end

-- test "ternary" for set
function LuaSuite:Test_ternary_for_set()
    meta.set("num", 123)
    local num = meta.get("num") == nil and 0 or tonumber(meta.get("num"))
    assert:Equal(self:T(), 123, num)
end

-- test inspiratinal use-case
function LuaSuite:Test_increment_use_case()
    -- [[inc safely]]
    local function inc(key)
        local ret = (meta.get(key) or 0) + 1
        meta.set(key, ret)
        return ret
    end

    local missing = meta.get("missing")
    assert:Nil(self:T(), missing)
    missing = inc("missing")
    assert:Equal(self:T(), 1, missing)
    missing = inc("missing")
    assert:Equal(self:T(), 2, missing)
end

-- test dump
function LuaSuite:Test_set_then_dump_yields_all()
    assert:Nil(self:T(), meta.set("yowza", "abc"))
    local d, err = meta.dump()
    assert:NoError(self:T(), err)
    assert:Equal(self:T(), "abc", d["yowza"])
end

-- test other types
-- number
function LuaSuite:Test_number()
    meta.set("abc", 123)
    assert:Equal(self:T(), 123, meta.get("abc"))

    meta.set("def", 543.21)
    assert:Equal(self:T(), 543.21, meta.get("def"))
end

-- nested table
function LuaSuite:Test_nested_table()
    local json = require('json')
    myvals = { foo = "bar", yada = { yada = "yada" } }
    meta.set("table", myvals)
    assert:Equal(self:T(), myvals.foo, meta.get("table.foo"))
    assert:Equal(self:T(), myvals.yada.yada, meta.get("table.yada.yada"))
    assert:Equal(self:T(), json.encode(myvals), json.encode(meta.get("table")))
end

-- test cloning & setting variables
function LuaSuite:Test_cloning_meta()
    local m2 = meta.clone()
    assert:NotNil(self:T(), m2)
    assert:Equal(self:T(), "meta", m2.MetaFile)
    m2.MetaFile = "meta2"
    assert:Equal(self:T(), "meta2", m2.MetaFile)
    assert:NotEqual(self:T(), "", m2.MetaSpace)
    assert:NotEqual(self:T(), "/dev/null", m2.MetaSpace)
    m2.MetaSpace = "/dev/null"
    assert:Equal(self:T(), "/dev/null", m2.MetaSpace)
end

function LuaSuite:Test_cloning_LastSuccessfulMetaRequest()
    meta.spec.LastSuccessfulMetaRequest.SdToken = 123
    assert:Equal(self:T(), "123", meta.spec.LastSuccessfulMetaRequest.SdToken)
    local l2 = meta.spec.LastSuccessfulMetaRequest:clone()
    assert:Equal(self:T(), "123", l2.SdToken)
    l2.SdToken = 543
    assert:Equal(self:T(), "543", l2.SdToken)
    assert:Equal(self:T(), "123", meta.spec.LastSuccessfulMetaRequest.SdToken)
    meta.spec.LastSuccessfulMetaRequest = l2
    assert:Equal(self:T(), "543", meta.spec.LastSuccessfulMetaRequest.SdToken)
end

-- test that JSONValue cannot be set
function LuaSuite:Test_JSONValue_cannot_be_set()
    local ran, errorMsg = pcall(function()
        meta.spec.JSONValue = false
    end)
    assert:False(self:T(), ran, tostring(ran))
    assert:True(self:T(), errorMsg:find("(JSONValue cannot be set)"), tostring(errorMsg))
end

-- test enforcement of undump matching dump
-- undump of dump is allowed
function LuaSuite:Test_undump_of_dump_allowed()
    local ran, errorMessage = pcall(function()
        meta.undump(meta.dump())
    end)
    assert:True(self:T(), ran)
    assert:NoError(self:T(), errorMessage)
end

-- undump of cloned dump is not allowed
function LuaSuite:Test_undump_of_cloned_dump_is_not_allowed()
    local ran, errorMessage = pcall(function()
        meta.undump(meta.clone():dump())
    end)
    assert:False(self:T(), ran, tostring(ran))
    assert:True(self:T(), errorMessage:find("(object passed to undump must have been dumped by same spec)"), tostring(errorMsg))
end

-- Ensure that the spec metatable doesn't leak into the dumped object
function LuaSuite:Test_spec_metatable_doesnt_leak_into_dumped_object()
    local dump = meta.dump()
    assert:False(self:T(), dump.spec, string.format("dump.spec=%s", dump.spec))
    assert:NotNil(self:T(), getmetatable(dump).spec)
    assert:Equal(self:T(), getmetatable(dump).spec, meta.spec)
end

-- test undumping a plain table
function LuaSuite:Test_undump_plain_table_not_allowed()
    local ran, errorMessage = pcall(function()
        meta.undump({ foo = "bar" })
    end)
    assert:False(self:T(), ran, tostring(ran))
    assert:True(self:T(), errorMessage:find("(object passed to undump must have been dumped by same spec)"), tostring(errorMessage))
end

-- test workaround for undumping
function LuaSuite:Test_undump_workaround()
    local ran, errorMessage = pcall(function()
        local d = { workaround = "achievement unlocked!" }
        setmetatable(d, { spec = meta.spec })
        meta.spec:undump(d)
    end)
    assert:True(self:T(), ran)
    assert:NoError(self:T(), errorMessage)
    local workaround = meta.get("workaround")
    assert(workaround == "achievement unlocked!", tostring(workaround))
end

-- test metaFilePath works
function LuaSuite:Test_metaFilePath_returns_non_empty()
    assert:NotNil(self:T(), meta.metaFilePath())
    assert:Equal(self:T(), meta.spec:metaFilePath(), meta.metaFilePath())
end
