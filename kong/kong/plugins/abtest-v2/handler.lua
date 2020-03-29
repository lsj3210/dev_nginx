local cjson = require "cjson"

local BasePlugin = require "kong.plugins.base_plugin"
local OpenApiUtils = require "kong.openapi.Utils"

 local AbTestV2Handler = BasePlugin:extend()
--local AbTestV2Handler = {}

AbTestV2Handler.PRIORITY = 10

function AbTestV2Handler:new()
	AbTestV2Handler.super.new(self, "abtest-v2")
end



function AbTestV2Handler:access(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  AbTestV2Handler.super.access(self)

  local client_ip = OpenApiUtils.get_client_ip();

  if   OpenApiUtils.containVal(config.client_ips,client_ip) then
--       ngx.log( ngx.ERR ,"  执行转发动作tourl= " ,config.to_uri );
        ngx.var.upstream_uri=config.to_uri;
  end;



end



return AbTestV2Handler
