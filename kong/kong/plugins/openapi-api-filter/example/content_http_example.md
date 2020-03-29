-- 发送http请求(请参考 https://github.com/ledgetech/lua-resty-http)
local httpc = http.new()
local res, err = httpc:request_uri("http://127.0.0.1:8001/services", {
    method = "GET",
    body = "",
    headers = {
      ["Content-Type"] = "application/json",
    },
    keepalive_timeout = 60,
    keepalive_pool = 10
})

if not res then
	return 500, "request faild from gw "
end

return res.status, res.body
---------------------------------------------------------------------------
-- 链接redis(请参考 https://github.com/openresty/lua-resty-redis)
local redc = redis:new()
redc:set_timeout(1000) -- 1 sec

local ok, err = redc:connect("10.168.96.90", 6888)
if not ok then
    return 500, "connect redis faild"
end

ok, err = redc:set("dog", "an animal")
if not ok then
    return 500, "faild set dog to redis"
end


local res, err = redc:get("dog")
if not res then
    return 500, "failed to get dog from"
end

if res == ngx.null then
    return 500, "dog not found"
end

-- put it into the connection pool of size 100,
-- with 10 seconds max idle time
local ok, err = redc:set_keepalive(10000, 100)
if not ok then
    return 500, "set redis conn to pool faild"
end

-- or just close the connection right away:
-- local ok, err = red:close()
-- if not ok then
--     return 500, "faild to close redis client"
-- end

return 200, res

---------------------------------------------------------------------------------
-- 链接mysql(请参考 https://github.com/openresty/lua-resty-mysql)

local db, err = mysql:new()
if not db then
    return 500, "create mysql faild from gw "
end
db:set_timeout(1000) -- 1 sec

local ok, err, errcode, sqlstate = db:connect {
    host = "10.168.100.164",
    port = 3306,
    database = "flowcontrol",
    user = "root",
    password = "root",
    charset = "utf8",
    max_packet_size = 1024 * 1024,
}

if not ok then
    return 500, "connect mysql faild."
end

local res, err, errcode, sqlstate = db:query("select * from service_conf", 100)
if not res then
    return 500, "exec select faild."
end

local ret_str = cjson_encode(res)

-- put it into the connection pool of size 100,
-- with 10 seconds max idle timeout
local ok, err = db:set_keepalive(10000, 100)
if not ok then
    return 500, "set mysql conn to pool faild"
end

-- or just close the connection right away:
-- local ok, err = db:close()
-- if not ok then
--     return 500, "close mysql conn  faild"
-- end

return 200, ret_str