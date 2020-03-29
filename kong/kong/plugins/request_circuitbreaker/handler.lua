local BasePlugin = require "kong.plugins.base_plugin"
local Redis_opt = require "kong.plugins.request_circuitbreaker.redis_opt"
local open_api_config = require "kong.openapi.Config"
local redis = require "resty.redis"

local ngx = ngx
local ngx_socket_udp = ngx.socket.udp
local ngx_log        = ngx.log
local NGX_ERR        = ngx.ERR
local NGX_DEBUG      = ngx.DEBUG
local setmetatable   = setmetatable
local tostring       = tostring
local fmt            = string.format

--[[
local singletons = require "kong.singletons"
local responses = require "kong.tools.responses"
local constants = require "kong.constants"
]]

local meta = require "kong.meta"
local cjson = require "cjson"

local RestyCircuitBreaker = require("kong.plugins.request_circuitbreaker.RestyCircuitBreaker")

local  restyCircuitBreaker = RestyCircuitBreaker:init(worker_id);

-- 派生出一个子类，其实这里是为了继承来自 Classic 的 __call 元方法，
-- 方便 Kong 在 init 阶段预加载插件的时候执行构造函数 new()
local CircuitBreakerHandler = BasePlugin:extend()

-- 设置插件的优先级，Kong 将按照插件的优先级来确定其执行顺序（越大越优先）
-- 需要注意的是应用于 Consumer 的插件因为依赖于 Auth，所以 Auth 类插件优先级普遍比较高
CircuitBreakerHandler.PRIORITY = 2
CircuitBreakerHandler.VERSION = "0.1.1"


function CircuitBreakerHandler:new()
   CircuitBreakerHandler.super.new(self, "request_circuitbreaker")
--    local worker_id = ngx.worker.pid()
--   ngx.log(NGX_ERR, "CircuitBreakerHandler:new \"", self._name, "\": new",'worker_id = ' , open_api_config.cache.strategy  )

end

function CircuitBreakerHandler:init_worker()
--  local worker_id = ngx.worker.pid()
--   ngx.log(NGX_ERR, "executing plugin \"", self._name, "\": init_worker" .. worker_id)

end

function CircuitBreakerHandler:rewrite()
--  ngx.log(NGX_ERR, "executing plugin \"", self._name, "\": rewrite")
end

function CircuitBreakerHandler:access(conf)
    if ngx.ctx.route ~= nil and ngx.ctx.route.id ~= "" then
        restyCircuitBreaker:set_circuit_flag_new(conf)
    end
end

function CircuitBreakerHandler:log(conf)
    if ngx.ctx.route ~= nil and ngx.ctx.route.id ~= "" then
        local  route_id = ngx.ctx.route.id
        restyCircuitBreaker:write_circuit_log(route_id,conf)
    end
end



return CircuitBreakerHandler
