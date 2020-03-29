local config = require("kong.openapi.Config");
OpenApiUtils = {}



-- 字符串拆分
function OpenApiUtils.split(str,reps)
    local resultStrList = {}

    string.gsub(str,'[^'..reps..']+',function ( w )
        table.insert(resultStrList,w)
    end)
    return resultStrList
end

-- 过期网关hosts
function OpenApiUtils.getHostName()
    local headers = ngx.req.get_headers()
    local host = OpenApiUtils.split(headers["Host"],":")[1]
    return host
end

-- 生成缓存名称
function OpenApiUtils.getCacheName(host,request_uri)
    local filename= ngx.md5(host..request_uri)
    return filename
end

-- 生成proxy 代理内容缓存Key
function OpenApiUtils.getProxyCacheKey()
    local host = OpenApiUtils.getHostName()
    local request_uri = ngx.var.request_uri
    --网关host+url(带参数的URL)
    local cache_key= ngx.md5(host..request_uri)

    return cache_key
end

-- 自动注册日志，是否写入调试日志
function OpenApiUtils.writeAutoRegLog(msg)

   if config.debug.auto_reg then
   	  ngx.log(ngx.CRIT, msg)
   end

end

-- 缓存限流，是否写入调试日志
function OpenApiUtils.writeCacheLog(msg)

   if config.debug.cache then
   	  ngx.log(ngx.CRIT, msg)
   end

end
function OpenApiUtils.writeErrorHandlerLog(msg)

   if config.debug.error_handler then
   	  ngx.log(ngx.CRIT, msg)
   end

end

function OpenApiUtils.get_client_ip()
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
    return ClientIP
end

function OpenApiUtils.containKey( t, key )

    for k, v in pairs(t) do
--         ngx.log(ngx.ERR, "table.containKey===========: ", tostring(key) ..'===' ..  tostring(v) ,'==', type( v ) , '=' ,type(key))
        if key == v then
--            ngx.log(ngx.ERR, "table.containKey====return true=======", tostring(key) ..'===' ..  tostring(v) ,'==', type( v ) , '=' ,type(key))
            return true;
        end
    end
    return false;
end

function OpenApiUtils.containVal( t, val )

    for k, v in pairs(t) do
--         ngx.log(ngx.ERR, "table.containKey===========: ", tostring(key) ..'===' ..  tostring(v) ,'==', type( v ) , '=' ,type(key))
        if val == v then
--            ngx.log(ngx.ERR, "table.containKey====return true=======", tostring(key) ..'===' ..  tostring(v) ,'==', type( v ) , '=' ,type(key))
            return true;
        end
    end
    return false;
end


return OpenApiUtils
