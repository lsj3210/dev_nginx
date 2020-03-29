-- local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"
local open_api_config = require "kong.openapi.Config"
local cjson_decode = require("cjson").decode
local cjson_encode = require("cjson").encode
local body_filter = require "kong.plugins.response-transformer.body_transformer"
local header_filter = require "kong.plugins.response-transformer.header_transformer"
local is_body_transform_set = header_filter.is_body_transform_set
local is_json_body = header_filter.is_json_body
local http = require "resty.http"
local open_api_cache = require "kong.openapi.Cache"
local open_api_proxy_cache = require "kong.openapi.ProxyCache"
local utils = require "kong.openapi.Utils"
-- Your plugin handler's constructor. If you are extending the
-- Base Plugin handler, it's only role is to instanciate itself
-- with a name. The name is your plugin name as it will be printed in the logs.


local CocurrentHandler = {}


CocurrentHandler.PRIORITY = 555
CocurrentHandler.VERSION = "2.0.0"

local function getIP()
    local ClientIP = ngx.req.get_headers()["X-Real-IP"]
    if ClientIP == nil then
        ClientIP = ngx.req.get_headers()["X-Forwarded-For"]
        if ClientIP then
            local colonPos = string.find(ClientIP, ' ')
            if colonPos then
                ClientIP = string.sub(ClientIP, 1, colonPos - 1) 
            end
        end
    end
    if ClientIP == nil then
        ClientIP = ngx.var.remote_addr
    end
    if ClientIP then 
        ClientIP = ClientIP
    end
    return ClientIP
end


-- if ngx.var.fault_enabled~="true" then  
--     Kong = require 'kong'
--     Kong.customLog()
-- end
-- @strategy: 并发处理策略
-- @bottomJson: 托底数据
-- @status: z状态
function buildJumpParms(strategy,bottomJson,status)

  local uri = ngx.var.uri;
  local jump_url = nil
  if(strategy==1) then
    Kong = require 'kong'
    Kong.customLog()
    return false,nil       
  end
  -- 缓存数据
  if(strategy==2) then
    local cache_key =  utils.getProxyCacheKey()  
    -- 判断是否存在缓存数据、 如果存在缓存数据、 直接输出缓存数据
    local is_exists_response_body_data,data = open_api_proxy_cache[open_api_config.cache.strategy].get(cache_key,uri)
    if is_exists_response_body_data==false  then 
      ngx.log(ngx.CRIT, "没有缓存文件------------过期 cache_key="..cache_key)    
      return false,nil
    else               
      -- ngx.var.cocurrent_strategy= 2
      -- ngx.header["cocurrent_strategy"]=ngx.var.cocurrent_strategy
      -- jump_url = '/openapi/cocurrent?name='..cache_key..'&optype=2&uri='..uri
      ngx.var.cache="true"
      kong.response.set_header("cache", "true")
      ngx.header['Content-Type']="application/json;charset=UTF-8"
      ngx.say(data)   
      return true,jump_url    
    end
  end
  -- 托底
  if(strategy==3) then
    kong.response.set_header("cocurrent_strategy", 3)
    ngx.say(bottomJson)   
    return true,jump_url
  end
            
  --没有缓存数据，读取托底数据
  if(strategy==4) then
    local cache_key =  utils.getProxyCacheKey()  
    -- 判断是否存在缓存数据、 如果存在缓存数据、 直接输出缓存数据
    local is_exists_response_body_data,data = open_api_proxy_cache[open_api_config.cache.strategy].get(cache_key,uri)
    if is_exists_response_body_data==false  then 
      ngx.header['Content-Type']="application/json;charset=UTF-8"
      ngx.say(bottomJson)   
      return true,jump_url                
    else
      ngx.var.cache="true"
      kong.response.set_header("cache", "true")
      ngx.say(data)   
      return true,jump_url    
    end
  end
end


-- @concurrency: concurrency 并发数
-- @strategy: 并发处理策略
-- @routeId: 托底数据
-- @status: z状态
-- @remark: 备注
function cocurrentResponse(concurrency,strategy,bottomJson,status,remark)
  ngx.var.cocurrent="true"
  ngx.var.cocurrent_concurrency= concurrency
  ngx.var.cocurrent_strategy= strategy

  -- ngx.header["cocurrent"]=ngx.var.cocurrent
  -- ngx.header["cocurrent_concurrency"]=ngx.var.cocurrent_concurrency

  kong.response.set_header("cocurrent", "true")
  kong.response.set_header("cocurrent_concurrency", concurrency)
  kong.response.set_header("cocurrent_strategy", strategy)


  local res, jump_url =buildJumpParms(strategy,bottomJson,status)
  if res then
    -- utils.writeCacheLog( "jump_url " .. jump_url) 
    -- return ngx.exec(jump_url) 
    return ngx.exit(200)        
  else
    return ngx.exit(status)
  end
end


function CocurrentHandler:access(conf)
  ngx.log(ngx.CRIT, 'CocurrentHandler')
  -- CocurrentHandler.super.access(self)

  -- -- 并发限流
  -- upstream_config_data.trafficStrategy   value=1 返回缓存数据 value=2 返回托底数据  
  -- upstream_config_data.bottomJson        托底数据
  if(conf.concurrency>0 ) then
    local limit_req = require "resty.limit.req"
    local lim, err = limit_req.new("my_limit_req_store", conf.concurrency,0)
    if not lim then --申请limit_req对象失败
      cocurrentResponse(conf.concurrency,conf.strategy,conf.bottomJson,504,"申请limit_req对象失败" )
    end
    -- 使用ip地址作为限流的key
    local key = getIP()
    local delay, err = lim:incoming(key, true)
    if not delay then
      if err == "rejected" then                                    
        --超时
        cocurrentResponse(conf.concurrency,conf.strategy,conf.bottomJson,504,"超时" )
        ngx.log(ngx.ERR,"rejected")
      end
      cocurrentResponse(conf.concurrency,conf.strategy,conf.bottomJson,504,"not rejected" )
      ngx.log(ngx.ERR,"not rejected")
    end
    if delay~=nil and delay > 0 then
      cocurrentResponse(conf.concurrency,conf.strategy,conf.bottomJson,504,"delay" )
      ngx.log(ngx.ERR,"delay")
    end
  end
end

return CocurrentHandler