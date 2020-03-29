local typedefs = require "kong.db.schema.typedefs"
-- 云平台-并发限流功能
-- 每s中并发超过多少则出发限流策略
-- concurrency
-- response_code
-- strategy    策略
--bottomJson 托蒂数据
--to_url  转向url

return {
    fields = {
        concurrency = { type = "number", default = 0 },
        response_code = { type = "string"  },
         strategy =
          {
            type = "string" ,
            default = "type_show_str",
          },
        bottomJson = { type = "string" },
        to_url = { type = "string"  },

    }
}



