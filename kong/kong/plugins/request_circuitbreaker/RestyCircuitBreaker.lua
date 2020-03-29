-- Openresty Circuit Breaker
-- lua-nginx-module 版本 >= v0.9.17
-- TODO:  降级，失败率
--   2018/5/21
local Redis_opt = require "kong.plugins.request_circuitbreaker.redis_opt"

local cjson = require "cjson"
local RestyCircuitBreaker={}
RestyCircuitBreaker.__index = RestyCircuitBreaker
----接口超时时间，毫秒
--local INTERRUPT_ON_TIMEOUT_MS = 5000
----超时个数阈值，15秒内大于此阈值熔断
--local TIMEOUT_TIMES = 20
----熔断时间，秒
--local CIRCUIT_TIME = 5
----熔断超时时间,秒
--local CIRCUIT_TIMEOUT = 15


--local CIRCUIT_STATUS_OPEN = 1
local CIRCUIT_STATUS_OPEN  = 'open_circuit_breaker'
local CIRCUIT_STATUS_CLOSE = 'close_circuit_breaker'
local CIRCUIT_STATUS_TRY   = 'try_circuit_breaker'
local TRY_TIME = 1



-- 初始化 - init_worker_by_lua
function RestyCircuitBreaker:init( breaker_name_param )
    local self = setmetatable({}, RestyCircuitBreaker)
    self.breaker_name = tostring(breaker_name_param) ;
    -- 超时次数
    self.timeout_dict_shared_new = ngx.shared["resty_circuit_breake_timeout_new"]
    self.timeout_dict_shared_old = ngx.shared["resty_circuit_breake_timeout_old"]
    --  ngx.log(ngx.ERR, "timeout_dict_shared_new=", self.timeout_dict_shared_new, '===timeout_dict_shared_old ' ,self.timeout_dict_shared_old )
    return self
end

function table.containKey( t, key )
    for k, v in pairs(t) do
        -- ngx.log(ngx.ERR, "table.containKey===========: ", tostring(key) ..'===' ..  tostring(v) ,'==', type( v ) , '=' ,type(key))
        if key == v then
        -- ngx.log(ngx.ERR, "table.containKey====return true=======", tostring(key) ..'===' ..  tostring(v) ,'==', type( v ) , '=' ,type(key))
            return true;
        end
    end
    return false;
end

-- 日志的时候记录日志
function RestyCircuitBreaker:write_circuit_log(routid,conf )

    -- 当前url的返回状态
    local stat = ngx.var.upstream_status
    local timeout_key = "TimeOut_"..routid
    -- ngx.log( ngx.ERR, "write_circuit_log1111111111111111,timeout_key=",timeout_key,",stat=",stat    )
    -- timeout
    if table.containKey( conf.circuit_response_codes ,stat ) then
        -- 设置超时次数+1
        local timeout_times, err = self.timeout_dict_shared_new:incr(timeout_key, 1)
        -- ngx.log( ngx.ERR, "write_circuit_log22222222222222,timeout_key=",timeout_key,',timeout_times=',timeout_times  )
        if err == "not found" then
            self.timeout_dict_shared_new:set(timeout_key, 1, conf.time_pane )
            -- ngx.log( ngx.ERR, "RestyCircuitBreaker:write_circuit_log2,timeout_key=",timeout_key   )
        end
    end
--    self:test_log(routid);
end

function RestyCircuitBreaker:test_log(routid  )

    -- 当前url的返回状态
    local timeout_key = "TimeOut_"..routid
    -- timeout
    local timeout_dict_shared_new_tmp =  self.timeout_dict_shared_new:get(timeout_key)
    local timeout_dict_shared_old_tmp =  self.timeout_dict_shared_old:get(timeout_key)
    ngx.log( ngx.ERR, "RestyCircuitBreaker:test_log, timeout_key=",timeout_key,',timeout_dict_shared_new_tmp=',timeout_dict_shared_new_tmp," ,  timeout_dict_shared_old_tmp=" ,timeout_dict_shared_old_tmp )
end

function RestyCircuitBreaker:set_circuit_flag_new(conf)

    local route_id = ngx.ctx.route.id
    local circuit_key = "Circuit_"..route_id
    local timeout_key = "TimeOut_"..route_id
    local check_flag_key  = "CheckFlag_"..route_id
    local check_count_key = "CheckCount_"..route_id

    local redis_opt = Redis_opt.init()

    -- 1. breaker open
    local circuit_status = redis_opt:getObj(circuit_key)
    if type(circuit_status)~='nil' and circuit_status == CIRCUIT_STATUS_OPEN then
           -- ngx.log(ngx.ERR, "发生拦截=" ,circuit_key ,'==',cjson.encode(conf ) )
            -- return 503


          if  conf.is_redirect then
             --ngx.log(ngx.ERR, "发生拦截22222=跳转开始" ,conf.redirect_uri ,'==',cjson.encode(conf ) )
             redis_opt:close()
             ngx.var.upstream_uri=conf.redirect_uri;
            return
          else
              --ngx.log(ngx.ERR, "发生拦截33333=返回托底数据" ,circuit_key ,'==',cjson.encode(conf ) )
              ngx.header.content_type = "application/json"
              ngx.status = conf.response_code
              ngx.say(conf.response_msg);
              redis_opt:close()
              return ngx.exit(ngx.status)
          end
        -- ngx.log(ngx.ERR, "发生拦截4444=判断结束" ,circuit_key ,'==',cjson.encode(conf ) )
    end




    -- 2. breaker try close
    local check_flag = redis_opt:getObj(check_flag_key)
    -- local ttl = redis_opt:ttl(check_flag_key)
    -- kong.log.err(ttl)
    if type(check_flag)~='nil' and check_flag == CIRCUIT_STATUS_TRY then
        local count_new_tmp =  self.timeout_dict_shared_new:get(timeout_key)
        if count_new_tmp==nil then
            -- ngx.log( ngx.ERR, "try close 111111111=timeout_key=", timeout_key, ' , = timeout_dict_shared_new_tmp=' ,timeout_dict_shared_new_tmp  )
            return
        end
        local count_old_tmp =  self.timeout_dict_shared_old:get(timeout_key)
        if count_old_tmp==nil then
            count_old_tmp = 0;
        end
        if count_new_tmp==count_old_tmp then
            -- ngx.log( ngx.ERR, "try close 22222222", timeout_key, ' , = timeout_dict_shared_new_tmp=' ,timeout_dict_shared_new_tmp ,"timeout_dict_shared_old_tmp=",timeout_dict_shared_old_tmp  )
            return
        end

        local inc_val = count_new_tmp - count_old_tmp
        local timeout_times, ttl = redis_opt:increment_inc(timeout_key, inc_val, conf.time_pane)
        -- ngx.log( ngx.ERR, "try close 33333333333,timeout_key=", timeout_key, ' , = timeout_times=' ,timeout_times, '=ttl== ', ttl )

        self.timeout_dict_shared_old:set(timeout_key,count_new_tmp, ttl)
        self.timeout_dict_shared_new:expire(timeout_key, ttl)

        -- ngx.log(ngx.ERR, "try close 444444 now_count:", timeout_times, " all_count:", conf.timeout_times/conf.time_pane * TRY_TIME)
        if timeout_times >= conf.timeout_times/conf.time_pane * TRY_TIME-1 then
            -- 设置 开启熔断，并设置熔断超时时间
            redis_opt:setStr(circuit_key, CIRCUIT_STATUS_OPEN, conf.circuit_timeout)
            redis_opt:setStr(timeout_key, '0', conf.circuit_timeout)
            redis_opt:setStr(check_flag_key, CIRCUIT_STATUS_TRY, conf.circuit_timeout + TRY_TIME)
            self.timeout_dict_shared_old:delete(timeout_key)
            self.timeout_dict_shared_new:delete(timeout_key)
        end
        redis_opt:close()
        return
    end

    -- 3. breaker close
    local count_new_tmp =  self.timeout_dict_shared_new:get(timeout_key)
    if count_new_tmp==nil then
        -- ngx.log( ngx.ERR, "set_circuit_flag3333333333333=timeout_key=", timeout_key, ' , = timeout_dict_shared_new_tmp=' ,timeout_dict_shared_new_tmp  )
        return
    end
    local count_old_tmp =  self.timeout_dict_shared_old:get(timeout_key)
    if count_old_tmp==nil then
        count_old_tmp = 0;
    end
    if count_new_tmp==count_old_tmp then
        -- ngx.log( ngx.ERR, "set_circuit_flag44444444444444444", timeout_key, ' , = timeout_dict_shared_new_tmp=' ,timeout_dict_shared_new_tmp ,"timeout_dict_shared_old_tmp=",timeout_dict_shared_old_tmp  )
        return
    end

    local inc_val = count_new_tmp - count_old_tmp
    local timeout_times,ttl  = redis_opt:increment_inc(timeout_key, inc_val, conf.time_pane)
    --ngx.log( ngx.ERR, "set_circuit_flag55555555555555,timeout_key=", timeout_key, ' , = timeout_times=' ,timeout_times, '=ttl== ', ttl )

    self.timeout_dict_shared_old:set(timeout_key,count_new_tmp, ttl)
    self.timeout_dict_shared_new:expire(timeout_key, ttl)

    local circuit_status = redis_opt:getObj(circuit_key)
    if circuit_status==nil then
        circuit_status = CIRCUIT_STATUS_CLOSE
    end

    if timeout_times >= conf.timeout_times-1 and circuit_status ~= CIRCUIT_STATUS_OPEN then
        -- 设置 开启熔断，并设置熔断超时时间
        redis_opt:setStr(circuit_key, CIRCUIT_STATUS_OPEN, conf.circuit_timeout)
        redis_opt:setStr(timeout_key, '0', conf.circuit_timeout)
        redis_opt:setStr(check_flag_key, CIRCUIT_STATUS_TRY, conf.circuit_timeout + TRY_TIME)
        self.timeout_dict_shared_old:delete(timeout_key)
        self.timeout_dict_shared_new:delete(timeout_key)
    end
    -- ngx.log( ngx.ERR, "Rset_circuit_flag666666666666 ==", circuit_key, '=timeout_dict_shared_new_tmp== ', timeout_dict_shared_new_tmp,'== ' ,   "timeout_dict_shared_old_tmp=",timeout_dict_shared_old_tmp , " , ttl=", ttl )

    redis_opt:close()
end

  -- 查看某值是否为表tbl中的key值
  function table.kIn(tbl, key)
      if tbl == nil then
          return false
      end
      for k, v in pairs(tbl) do
          if k == key then
              return true
          end
      end
      return false
  end

-- access阶段使用 ，  记录超时时间 - 每次访问要记录超时信息 - log  ,routid-路由id
function RestyCircuitBreaker:set_circuit_flag(routid,conf ,redis_opt)

    local circuit_key = "Circuit_"..routid
    local timeout_key = "TimeOut_"..routid

    local timeout_dict_shared_new_tmp =  self.timeout_dict_shared_new:get(timeout_key)
    if timeout_dict_shared_new_tmp==nil then
--        ngx.log( ngx.ERR, "set_circuit_flag3333333333333=timeout_key=", timeout_key, ' , = timeout_dict_shared_new_tmp=' ,timeout_dict_shared_new_tmp  )
        return
    end;
    local timeout_dict_shared_old_tmp =  self.timeout_dict_shared_old:get(timeout_key)
    if timeout_dict_shared_old_tmp==nil then
        timeout_dict_shared_old_tmp = 0;
    end;
    if timeout_dict_shared_new_tmp==timeout_dict_shared_old_tmp then
--        ngx.log( ngx.ERR, "set_circuit_flag44444444444444444", timeout_key, ' , = timeout_dict_shared_new_tmp=' ,timeout_dict_shared_new_tmp ,"timeout_dict_shared_old_tmp=",timeout_dict_shared_old_tmp  )
        return
    end;

    local inc_val = timeout_dict_shared_new_tmp-timeout_dict_shared_old_tmp
    local timeout_times,ttl  = redis_opt:increment_inc(timeout_key ,inc_val , conf.time_pane )
--    ngx.log( ngx.ERR, "set_circuit_flag55555555555555,timeout_key=", timeout_key, ' , = timeout_times=' ,timeout_times, '=ttl== ', ttl )

    self.timeout_dict_shared_old:set(timeout_key,timeout_dict_shared_new_tmp , ttl )
    self.timeout_dict_shared_new:expire(timeout_key ,ttl  ) ;

    local circuit_status = redis_opt:getObj(circuit_key)
    if circuit_status==nil then
        circuit_status = CIRCUIT_STATUS_CLOSE
    end;

    if timeout_times >= conf.timeout_times  and circuit_status ~= CIRCUIT_STATUS_OPEN then
      -- 设置 开启熔断，并设置熔断超时时间
        redis_opt:setStr(circuit_key, CIRCUIT_STATUS_OPEN, conf.circuit_timeout)
        redis_opt:setStr(timeout_key, '0', conf.circuit_timeout)
        self.timeout_dict_shared_old:delete(timeout_key)
        self.timeout_dict_shared_new:delete(timeout_key)

    end
--    ngx.log( ngx.ERR, "Rset_circuit_flag666666666666 ==", circuit_key, '=timeout_dict_shared_new_tmp== ', timeout_dict_shared_new_tmp,'== ' ,   "timeout_dict_shared_old_tmp=",timeout_dict_shared_old_tmp , " , ttl=", ttl )

end


-- 每次访问要检查 路由的 状态 ，打开-截断 ，半开-状态设置为检查- access
function RestyCircuitBreaker:run( routeid,conf ,redis_opt )

    local circuit_key = "Circuit_" .. routeid
--    local circuit_status, err = self.circuit_dict_shared:get(circuit_key)

    local circuit_status = redis_opt:getObj( circuit_key)
--    ngx.log(ngx.ERR, " 当前路由状态== " ,circuit_key ,', circuit_status=',circuit_status)
    if type( circuit_status)=='nil' then
--        ngx.log(ngx.ERR, " 当前路由状态为空== " ,circuit_key ,'==',circuit_status)
        return CIRCUIT_STATUS_CLOSE;
    end;
    --  检查 当前 熔断状态为 打开 则直接返回
    if circuit_status == CIRCUIT_STATUS_OPEN then
--        ngx.log(ngx.ERR, "发生拦截=" ,circuit_key ,'==',cjson.encode(conf ) )
        -- return 503
        ngx.header.content_type = "application/json"
        ngx.status = conf.response_code
        ngx.say(conf.response_msg);
        ngx.exit(ngx.status)
        return CIRCUIT_STATUS_OPEN
    end
end
return RestyCircuitBreaker
