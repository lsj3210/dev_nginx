local BasePlugin = require "kong.plugins.base_plugin"
local Redis_opt = require "kong.plugins.openapi-yptcocurrent.redis_opt"

local meta = require "kong.meta"
local cjson = require "cjson"

-- 派生出一个子类，其实这里是为了继承来自 Classic 的 __call 元方法，
-- 方便 Kong 在 init 阶段预加载插件的时候执行构造函数 new()
local YptCocurrentHandler = BasePlugin:extend()

-- 设置插件的优先级，Kong 将按照插件的优先级来确定其执行顺序（越大越优先）
-- 需要注意的是应用于 Consumer 的插件因为依赖于 Auth，所以 Auth 类插件优先级普遍比较高
YptCocurrentHandler.PRIORITY = 20
YptCocurrentHandler.VERSION = "0.1.1"


function YptCocurrentHandler:new()
   YptCocurrentHandler.super.new(self, "openapi-yptcocurrent")
--    local worker_id = ngx.worker.pid()
--   ngx.log(NGX_ERR, "CircuitBreakerHandler:new \"", self._name, "\": new",'worker_id = ' , open_api_config.cache.strategy  )

end


function YptCocurrentHandler:access(conf)

    if ngx.ctx.route ~= nil and ngx.ctx.route.id ~= "" then
        local redis_opt = Redis_opt.init()

        local route_id = ngx.ctx.route.id
        local redis_key = "ypt_cocurrent_kong" .. route_id ;
        --- 1 s 中
        local history_conrrent_times,ttl = redis_opt:increment_inc_mis(redis_key,1,1000  )
        local concurrency_times = conf.concurrency
    --            ngx.log(ngx.ERR, "发生拦截=" ,circuit_key ,'==',cjson.encode(conf ) )
        redis_opt:close()

--        kong.log.err("配置json文件:" .. cjson.encode( conf ) .. history_conrrent_times  .. ttl  ) ;

        if history_conrrent_times > concurrency_times then
            if conf.strategy=='type_to_url' then
--                kong.log.err( '执行了url转向i=', conf.to_url );
                ngx.var.upstream_uri=conf.to_url;

            end;
            if conf.strategy=='type_show_str' then
--               kong.log.err( '执行了显示 托底数据type_show_str'  );
                ngx.header.content_type = "application/json"
                ngx.header.concurrency = history_conrrent_times
                ngx.status = conf.response_code
                ngx.say(conf.bottomJson);

                return ngx.exit(ngx.status)
            end;

        end

    end
end


return YptCocurrentHandler
