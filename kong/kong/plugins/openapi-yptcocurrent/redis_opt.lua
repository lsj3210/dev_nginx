local open_api_config = require "kong.openapi.Config"
--local timestamp = require "kong.tools.timestamp"
--local reports = require "kong.reports"
local  redis = require "resty.redis"

local kong = kong
local pairs = pairs
local null = ngx.null
local fmt = string.format


local function is_present(str)
  return str and str ~= "" and str ~= null
end


local Redis_opt={}
Redis_opt.__index = Redis_opt

function Redis_opt:init()
    local self = setmetatable({}, Redis_opt)
    self.my_red = self:getRedis()
    return self ;
end

function Redis_opt:getRedis()
      local sock_opts = {}
        -- 初始化redis
      local my_red = redis:new()
--      ngx.log(ngx.ERR,  "Redis_opt:getRedis====00000000===== ", err )
      my_red:set_timeout( open_api_config.redis_timeout)
      -- use a special pool name only if redis_database is set to non-zero
      -- otherwise use the default pool name host:port - 连接池的名字
--      ngx.log(ngx.ERR,  "Redis_opt:init()====1111===== ", open_api_config.redis_host .. ":" .. open_api_config.redis_port ,'====' , open_api_config.redis_database  )

      sock_opts.pool = open_api_config.redis_database and
                       open_api_config.redis_host .. ":" .. open_api_config.redis_port ..
                       ":" .. open_api_config.redis_database
--      ngx.log(ngx.ERR,  "Redis_opt:init()====2222===== ", open_api_config.redis_host .. ":" .. open_api_config.redis_port ,'===='   , open_api_config.redis_database  )
      local ok, err = my_red:connect(open_api_config.redis_host, open_api_config.redis_port,
                                  sock_opts)
      if not ok then
        kong.log.err("failed to connect to Redis: ", err)
        return nil, err
      end
      -- s是否第一次使用连接
      local times, err = my_red:get_reused_times()
      if err then
        kong.log.err("failed to get connect reused times: ", err)
        return nil, err
      end
--      kong.log.err("===重用次数====times: ", times)
      if times == 0 then
        if is_present(open_api_config.redis_password) then
          local ok, err = my_red:auth(open_api_config.redis_password)
          if not ok then
            kong.log.err("failed to auth Redis: ", err)
            return nil, err
          end
        end

        if open_api_config.redis_database ~= 0 then
          -- Only call select first time, since we know the connection is shared
          -- between instances that use the same redis database

          local ok, err = my_red:select(open_api_config.redis_database)
          if not ok then
            kong.log.err("failed to change Redis database: ", err)
            return nil, err
          end
        end
      end

     return  my_red ;
end

-- timeout seconds
function Redis_opt:increment_inc(  redis_key ,inc_val, timeout )

        local res, err = self.my_red:get( redis_key  )

--        ngx.log(ngx.ERR,  "Redis_opt:increment()====0000===== res=",res ,',inc_val=' , inc_val,',  type=',type( res )  )
        local int_res = res;
        if  res~=nil and res~=null then
            int_res = tonumber(res)
        end;

        if not res or res==nil or res==null or int_res<=0   then
--              ngx.log(ngx.ERR,  "Redis_opt:increment()====33333===== ",res  )
              local res_tmp, err =self.my_red:incrby( redis_key ,inc_val )
              self.my_red:expire( redis_key, timeout )
              return res_tmp,timeout
        end;
--        ngx.log(ngx.ERR,  "Redis_opt:increment()====11111===== "  )
        local res, err = self.my_red:incrby( redis_key ,inc_val )
--        local ttl = self.my_red:ttl( redis_key )
--        ngx.log(ngx.ERR,  "Redis_opt:increment()====2222===== res= ",res ,'   ttl=', ttl  )

        if not res then
            ngx.log(ngx.ERR, "yptcocurrent increment_inc 4444 error ==", err)
            return
        end
--        ngx.log(ngx.ERR, "Redis_opt:increment_inc4444  ==", res)
--        if res <= 1 or ttl==-1 then
--            ngx.log(ngx.ERR, "Redis_opt:increment_inc 设置过期时间==",timeout )
--            -- 过期时间为秒
--            self.my_red:expire( redis_key, timeout )
--        end
--      self:close(my_red)
      return res,self.my_red:ttl( redis_key )
end

-- timeout milliseconds
function Redis_opt:increment_inc_mis(  redis_key ,inc_val, timeout )

        local res, err = self.my_red:get( redis_key  )


        local int_res = res;
        if  res~=nil and res~=null then
            int_res = tonumber(res)
        end;

        if not res or res==nil or res==null or int_res<=0   then
--              ngx.log(ngx.ERR,  "Redis_opt:increment()====33333===== ",res  )
              local res_tmp, err =self.my_red:incrby( redis_key ,inc_val )
              self.my_red:pexpire( redis_key, timeout )
              return res_tmp,timeout
        end;

        local res, err = self.my_red:incrby( redis_key ,inc_val )

        if not res then
            ngx.log(ngx.ERR, "yptcocurrent increment_inc 4444 error ==", err)
            return
        end

       ttl = self.my_red:pttl( redis_key )
       if ttl==-1 then
           self.my_red:pexpire( redis_key, timeout )
       end

      return res,ttl
end


function Redis_opt:close()
    local ok, err = self.my_red:set_keepalive(10000, 100)
    if not ok then
          kong.log.err("failed to set Redis keepalive: ", err)
      return nil, err
    end
end


return  Redis_opt ;
