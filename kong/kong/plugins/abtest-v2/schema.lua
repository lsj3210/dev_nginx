local typedefs = require "kong.db.schema.typedefs"
-- 设置一定的ip进行，ab测试转发

local isNULL = function(v)
    return not v or v == ngx.null
end

return {
  name="abtest-v2",
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
          { to_uri = { type = "string"  },
          },
          {client_ips = {
              type = "array" ,
              required = true,
              elements = {
                type = "string"
              }
            },
          },
        },
      custom_validator = function(config)
            if config.client_ips then
              if next(config.client_ips) == nil   then
                return false,"client ip is not empty"
              end
            end

            if not config.to_uri then
                return false, "B url is not empty "
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


