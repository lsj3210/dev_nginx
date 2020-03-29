-- local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"

local cjson_decode = require("cjson").decode
local cjson_encode = require("cjson").encode
local body_filter = require "kong.plugins.response-transformer.body_transformer"
local header_filter = require "kong.plugins.response-transformer.header_transformer"
local is_body_transform_set = header_filter.is_body_transform_set
local is_json_body = header_filter.is_json_body
local http = require "resty.http"
local open_api_cache = require "kong.openapi.Cache"
local open_api_config = require "kong.openapi.Config"
local open_api_proxy_cache = require "kong.openapi.ProxyCache"
local utils = require "kong.openapi.Utils"
-- Your plugin handler's constructor. If you are extending the
-- Base Plugin handler, it's only role is to instanciate itself
-- with a name. The name is your plugin name as it will be printed in the logs.

local CacheHandler = {}

CacheHandler.PRIORITY = 9999
CacheHandler.VERSION = "2.0.0"


-- 应用缓存策略、输出缓存到页面，中断后续请求流程
-- @percentage: 分流概率
function cacheResponse(percentage,second)  
  local cache_key =  utils.getProxyCacheKey()  
  local uri = ngx.var.uri;  
  local request_uri = ngx.var.request_uri
  local is_exists_response_body_data,data = open_api_proxy_cache[open_api_config.cache.strategy].get(cache_key,uri,second)
  if is_exists_response_body_data==false  then 
    utils.writeCacheLog("cachename------------过期 ")    
    return 
  else
    ngx.var.cache="true"
    ngx.var.cache_percentage= percentage
    kong.response.set_header("cache", "true")
    kong.response.set_header("cache_percentage", percentage)
    ngx.header['Content-Type']="application/json;charset=UTF-8"
    ngx.say(data)               
    return ngx.exit(200)   
  end
end


function CacheHandler:access(conf)
  utils.writeCacheLog( "CacheHandler:access")  
  local request_method = ngx.var.request_method
  local cache_key =  utils.getProxyCacheKey()  
  local request_method = ngx.var.request_method
  local second = conf.minute*60
  -- 添加判断、只处理GET 请求
  if request_method=='GET'  then
    --是否按百分比走缓存数据
    if(conf.percentage>0) then    
      local count =  math.random(1,100)
      utils.writeCacheLog( "count= " ..count) 
      if count<= conf.percentage then
        cacheResponse(conf.percentage,second)             
      end
    else
      cacheResponse(0)
    end
  end
end

return CacheHandler