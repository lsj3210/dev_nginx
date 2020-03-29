--
-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2019/5/14
-- Desc: bigdata-auth
--

-- local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local redis = require "kong.plugins.openapi-bigdata-auth.redis"

-- dev
-- local redis_host = '10.27.15.58'
-- local redis_port = 15003
-- product
local redis_host = 'codis.dataproduct.lq.demo.com.cn'
local redis_port = 19109
local redis_pool_max_idle_time = 10000
local redis_pool_size = 100

-- close redis conn
local function close_redis(_redis)
  if not _redis then
      return
  end
  local ok, err = _redis:set_keepalive(redis_pool_max_idle_time, redis_pool_size)
  if not ok then
      ngx.log(ngx.ERR,"set redis conn keepalive error: ", err)
  end
end

-- func for split string
local str_split =  function(_str,_reps)
 local res = {}
 if type(_str) ~= nil then
   string.gsub(_str,'[^'.._reps..']+',function (w) table.insert(res,w) end)
 end
 return res
end

-- func for get real ip
local function get_real_ip()
    local real_ip = ngx.req.get_headers()["X-Real-IP"]
    if real_ip == nil then
        real_ip = ngx.req.get_headers()["X-Forwarded-For"]
        if real_ip then
            local colon_pos = string.find(real_ip, ' ')
            if colon_pos then
                real_ip = string.sub(real_ip, 1, colon_pos - 1)
            end
        end
    end
    if real_ip == nil then
        real_ip = ngx.var.remote_addr
    end
    if real_ip then
        real_ip = real_ip
    end
    return real_ip
end

-- func 403 deny
local function deny(_msg)
  ngx.status = 403
  ngx.say(_msg)
  ngx.exit(403)
end

local BigdataAuthHandler = {}

BigdataAuthHandler.PRIORITY = 1066
BigdataAuthHandler.VERSION = "2.0.0"

-- function BigdataAuthHandler:new()
--   BigdataAuthHandler.super.new(self, "openapi-bigdata-auth")
-- end

function BigdataAuthHandler:access(conf)
  -- BigdataAuthHandler.super.access(self)

  -- options
  local method = ngx.var.request_method
  if method == 'OPTIONS' then
    return
  end

  -- basic auth ignore appkey
  local headers = ngx.req.get_headers()
  auth = headers["Authorization"]
  if auth ~= nil then
    return
  end

  local appkey = ngx.var.arg_APPKEY
  if appkey == nil then
    appkey = headers["APPKEY"]
  end

  if appkey ~= nil then
    local try = false
    local _redis = redis:new()
    _redis:set_timeout(1000)
    local ok, err = _redis:connect(redis_host, redis_port)
    if not ok then
      ngx.log(ngx.ERR,"connect to redis error: ", err)
      close_redis(_redis)
      try = true
      return
    end

    if try then
      local ok, err = _redis:connect(redis_host, redis_port)
      if not ok then
        ngx.log(ngx.ERR,"re try connect to redis error: ", err)
        close_redis(_redis)
        return
      end
    end

    local resp, err = _redis:hget("\"micro:dc\"","\""..appkey.."\"")
    close_redis(_redis)
    local tmp = cjson.encode(resp);
    if tmp ~= 'null' then
      local authinfo = cjson.decode(resp)
      local keyinfo = authinfo[2].appkey
      local whiteips = authinfo[2].whiteips
      local apiurl = authinfo[2].apiurl
      -- chgeck api url
      _, ok = string.find(apiurl, ngx.var.uri)
      if ok == nil then
        deny('{"code":-2,"msg":"this appkey do not allow acessess this api"}')
      end
      -- check whiteips
      if whiteips ~= nil and tostring(whiteips) ~= 'userdata: NULL' and #whiteips > 0 then
        local ok = false
        local ip = get_real_ip()
        --ngx.log(ngx.ERR,ip)
        --ngx.log(ngx.ERR,whiteips)
        local all = str_split(whiteips,',')
        for i = 1, #all do
          if ip == all[i] then
            ok = true
          end
          --ngx.log(ngx.ERR,all[i])
        end
        if not ok then
          deny('{"code":-2,"msg":"ip deny"}')
        end
      end
      --ngx.log(ngx.ERR, whiteips)
    else
      deny('{"code":-2,"msg":"APPKEY that does not exist"}')
    end
  else
    deny('{"code":-2,"msg":"APPKEY that does not exist"}')
  end
end

return BigdataAuthHandler
