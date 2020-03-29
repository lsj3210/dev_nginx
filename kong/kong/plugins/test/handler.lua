local BasePlugin = require "kong.plugins.base_plugin"
local CustomHandler = BasePlugin:extend()

function CustomHandler:new()
  CustomHandler.super.new(self, "my-custom-plugin")
end

function CustomHandler:access(config)
  CustomHandler.super.access(self)

  kong.log.inspect(config.environment) -- "development"
  kong.log.inspect(config.server.host) -- "http://localhost"
  kong.log.inspect(config.server.port) -- 8080



  
end

return CustomHandler