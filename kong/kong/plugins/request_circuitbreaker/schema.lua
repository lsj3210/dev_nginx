local typedefs = require "kong.db.schema.typedefs"
-- 在一定时间窗格（单位为s）内 指定的状态码 出现的次数  ，指定返回的状态码和返回的消息
-- time_pane 时间窗格
-- timeout_times 出现状态码次数
-- circuit_timeout 熔断超过这个时间自动恢复 单位s

return {
  name="request_circuitbreaker",
  fields = {
    {
      consumer = typedefs.no_consumer
    },
    {
      run_on = typedefs.run_on_first
    },
    {
      protocols = typedefs.protocols_http
    },
    {
      config = {
        type = "record",
        fields = {
          {
            time_pane = { type = "number", default = 10, },
          },
          { timeout_times = { type = "number" , default = 2000 },
          },
          {circuit_response_codes = {
              type = "array" ,
              required = true,
              elements = {
                type = "string"
              },
              default = {
                  "500",
              }
            },
          },
          { circuit_timeout = { type = "number" , default = 60 },
          },
          {response_msg = { type = "string" , default = "熔断开启" },
          },
          {response_code = { type = "string" , default = "503" },
          },
          {is_redirect = { type = "boolean" , default = false },
          },
          {redirect_uri = { type = "string" , required = false  },
          },

        },
      custom_validator = function(config)
            if config.circuit_timeout then
              if config.circuit_timeout < 0 or config.circuit_timeout > 1000 then
                return false,"circuit_timeout must be between 1 .. 1000"
              end
            end

            if config.timeout_times then
              if config.timeout_times<=0 then
                return false, "timeout_times must be gt 0 "
              end
            end
            return true
        end,

      },
    },
  },
  entity_checks = {
    -- Describe your plugin's entity validation rules


  },

}


