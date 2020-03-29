--
-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2018/7/11
-- Desc: middle auth
--

-- local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"

local MiddleAuthHandler = {}

MiddleAuthHandler.PRIORITY = 998
MiddleAuthHandler.VERSION = "2.0.0"

-- binstr to hex str
local function bin2hex(str)
  return ({str:gsub(".", function(c) return string.format("%02X", c:byte(1)) end)})[1]
end

-- HTTP
local function httpClient(url, method, body, timeout)
  local my_http = require "resty.http"
  local conn = my_http.new()
  timeout = timeout or 30000
  conn:set_timeout(timeout)
  local res,err = conn:request_uri(url,{
      method = method,
      body = body,
      headers = {
         ["Content-Type"] = "application/json",
      }
  })
  if not res then
     return nil,err
  else
     --ngx.log(ngx.ERR,res.status)
     if res.status == 200 then
         return res.body,err
     else
         return nil,err
     end
  end
end

-- Base64 编码
local function encodeBase64(source_str)
  local b64chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
  local s64 = ''
  local str = source_str
  while #str > 0 do
    local bytes_num = 0
    local buf = 0
    for byte_cnt=1,3 do
      buf = (buf * 256)
      if #str > 0 then
        buf = buf + string.byte(str, 1, 1)
        str = string.sub(str, 2)
        bytes_num = bytes_num + 1
      end
    end
    for group_cnt=1,(bytes_num+1) do
      local b64char = math.fmod(math.floor(buf/262144), 64) + 1
      s64 = s64 .. string.sub(b64chars, b64char, b64char)
      buf = buf * 64
    end
    for fill_cnt=1,(3-bytes_num) do
      s64 = s64 .. '='
    end
  end
  return s64
end

-- dba_auth func
local function dba_auth(conf)
  ngx.req.clear_header("Authorization")
  local auth = encodeBase64(conf.user..":"..conf.pwd)
  --ngx.log(ngx.ERR,auth)
  ngx.req.set_header("Authorization","Basic "..auth)
end

-- dba_hmac_ahth
local function dba_hmac_auth(conf)
  --local timestamp = ngx.req.start_time()*1000
  -- get args
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local uu = conf.user
  local pp = conf.pwd
  local tokenUrl = conf.token_url
  --ngx.log(ngx.ERR,tokenUrl)
  -- get key
  local tmp = timestamp..'\n'..uu
  --local crypto = require("crypto")
  --local hmac = require("crypto.hmac")
  --local secret = hmac.digest("sha1", tmp, pp)
  local hmac_sha1 = ngx.hmac_sha1
  local digest = hmac_sha1(pp, tmp)
  local secret = string.lower(bin2hex(digest))

  local hashval = string.sub(secret,11,20)
  -- get toten
  local body = '{"username":"'..uu..'","timestamp":"'..timestamp..'","auth_key":"'..hashval..'"}'
  --ngx.log(ngx.ERR,body)
  local res,err = httpClient(tokenUrl, "GET",body, 20000)
  --ngx.log(ngx.ERR,res)
  if res then
    local cjson = require "cjson"
    local tmp = cjson.decode(res)
    --ngx.log(ngx.ERR,tmp["token"])
    local auth = 'Basic '..encodeBase64(tmp["token"]..':')
    ngx.req.clear_header("Authorization")
    ngx.req.set_header("Authorization",auth)
  end
end

-- intranet_auth func
local function intranet_auth(conf)
  ngx.req.clear_header("Authorization")
  --local token = ngx.var.arg_token
  local headers = ngx.req.get_headers()
  local token = headers["Token"]

  if type(token) ~= "nil" then
    --ngx.log(ngx.ERR,"token "..token)
    ngx.req.set_header("Authorization","Token "..token)
  end
end

-- docker middle auth func
local function docker_auth(conf)
  --ngx.log(ngx.ERR,"docker auth")
  local timestamp = ngx.req.start_time()*1000
  local proxyuser = ngx.var.http_proxy_user
  if type(proxyuser) == "nil" then
    responses.send(401, "MISS Header[proxy_user]")
  end
  local uu = conf.user
  local pp = conf.pwd
  local tmp = timestamp..'\n'..uu..'\n'..proxyuser
  --local crypto = require("crypto")
  --local hmac = require("crypto.hmac")
  --local secret = hmac.digest("sha1", tmp, pp)
  local hmac_sha1 = ngx.hmac_sha1
  local digest = hmac_sha1(pp, tmp)
  local secret = string.lower(bin2hex(digest))

  local hashval = string.sub(secret,11,15)
  --ngx.log(ngx.ERR,"val:"..hashval)
  ngx.req.set_header("hash_val",hashval)
  ngx.req.set_header("time_stamp",timestamp)
  ngx.req.set_header("access_name",uu)
  ngx.req.clear_header("Authorization")
end

--cmdb middle auth func
local function cmdb_auth(conf)
  --ngx.log(ngx.ERR,"cmdb auth")
  local timestamp = ngx.req.start_time()*1000
  local uu = conf.user
  local pp = conf.pwd
  local tmp = timestamp..'\n'..uu
  --local crypto = require("crypto")
  --local hmac = require("crypto.hmac")
  --local secret = hmac.digest("sha1", tmp, pp)
  local hmac_sha1 = ngx.hmac_sha1
  local digest = hmac_sha1(pp, tmp)
  local secret = string.lower(bin2hex(digest))

  local hashval = string.sub(secret,11,15)
  local args = ngx.req.get_uri_args()
  local new_args =  {time_stamp=timestamp,username=uu,hash_val=hashval}
  for k,v in pairs(new_args) do
    args[k] = v
  end
  ngx.req.set_uri_args(args)
  ngx.req.clear_header("Authorization")
end

-- monitor middle auth func
local function monitor_auth(conf)
  --ngx.log(ngx.ERR,conf.token)
  ngx.req.set_header("APIToken",conf.token)
end

local function oa_xff(conf)
  ngx.req.clear_header("X-Forwarded-For")
  ngx.var.upstream_x_forwarded_for = ""
end

-- function MiddleAuthHandler:new()
--   MiddleAuthHandler.super.new(self, "middle-auth")
-- end

function MiddleAuthHandler:access(conf)
  -- MiddleAuthHandler.super.access(self)
  -- ngx.log(ngx.ERR,conf.type[1])
  tmp = conf.type[1]
  if tmp == "docker" then
    docker_auth(conf)
  elseif tmp == "cmdb" then
    cmdb_auth(conf)
  elseif tmp == "monitor" then
    monitor_auth(conf)
  elseif tmp == "intranet" then
    intranet_auth(conf)
  elseif tmp == "dba" then
    dba_auth(conf)
  elseif tmp == "dba-hmac" then
    dba_hmac_auth(conf)
  elseif tmp == "oa" then
    oa_xff(conf)
  end
end

return MiddleAuthHandler
