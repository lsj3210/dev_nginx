-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2019/9/17
-- Desc: api-filter plugin 
--
local _M = {}

local inspect_ = require "inspect"
local cookie_  = require "kong.plugins.openapi-api-filter.tools.cookie"
local http_    = require "kong.plugins.openapi-api-filter.tools.http"
local mysql_   = require "kong.plugins.openapi-api-filter.tools.mysql"
local redis_   = require "kong.plugins.openapi-api-filter.tools.redis"
local zlib_    = require "zlib"

-- define globle env
local _G_ENV = {
    print = _G.print,
    assert = _G.assert,
    error = _G.error,
    ipairs = _G.ipairs,
    next = _G.next,
    pairs = _G.pairs,
    pcall = _G.pcall,
    select = _G.select,
    tonumber = _G.tonumber,
    tostring = _G.tostring,
    type = _G.type,
    unpack = _G.unpack,
    xpcall = _G.xpcall,
    string = {
      byte = string.byte,
      char = string.char,
      find = string.find,
      format = string.format,
      gmatch = string.gmatch,
      gsub = string.gsub,
      len = string.len,
      match = string.match,
      rep = string.rep,
      reverse = string.reverse,
      sub = string.sub,
      upper = string.upper,
    },
    table = {
      insert = table.insert,
      maxn = table.maxn,
      remove = table.remove,
      sort = table.sort,
      insert = table.insert,
      concate = table.concate,
    },
  
    inspect = inspect_,
    cjson_decode = require('cjson').decode,
    cjson_encode = require('cjson').encode,
    cookie       = cookie_,
    http         = http_,
    mysql        = mysql_,
    redis        = redis_,
    zlib         = zlib_,
    url_encode   = _M.url_encode,
    url_decode   = _M.url_decode,
    merge_tables = function(...)
      local tabs = {...}
      if not tabs then
          return {}
      end
      local origin = tabs[1]
      for i = 2,#tabs do
          if origin then
              if tabs[i] then
                  for k,v in pairs(tabs[i]) do
                      table.insert(origin,v)
                  end
              end
          else
              origin = tabs[i]
          end
      end
      return origin
    end,
    rm_table_elements = function(tbl, keys)
      local tmp = {}
      for i in pairs(tbl) do
          table.insert(tmp,i)
      end
      local new_tbl = {}
      for i = 1, #tmp do
          local val = tmp [i]
          local is_rm = false
          for j = 1, #keys do
            if val == keys[j] then
              is_rm = true
            end
          end
          if not is_rm then
            new_tbl[val] = tbl[val]
          end
      end
      return new_tbl
    end,
    dev_log = function(e)
      ngx.log(ngx.ERR, inspect_(e))
    end,
}

-- func for encode url
function _M.url_encode(s)
  s = string.gsub(s, "([^%w%.%- ])", function(c) return string.format("%%%02X", string.byte(c)) end)
  return string.gsub(s, " ", "+")
end

-- func for decode url
function _M.url_decode(s)
  s = string.gsub(s, '%%(%x%x)', function(h) return string.char(tonumber(h, 16)) end)
  return s
end

-- func for load string lua function
function _M.func_load(lua_str, _env)
  local f = loadstring(lua_str)
  if not f then
    return false, "load lua string faild"
  end
  for k,v in pairs(_G_ENV) do
    _env[k] = v
  end
  setfenv(f, _env)
  return true, f
end


-- func for exec function
function _M.func_exec(f)
  return xpcall(f, function() ngx.log(ngx.ERR, debug.traceback()) end)
end


return _M
