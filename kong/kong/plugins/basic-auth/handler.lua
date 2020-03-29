-- Copyright (C) Kong Inc.
local access = require "kong.plugins.basic-auth.access"


local BasicAuthHandler = {}


function BasicAuthHandler:access(conf)

  -- options
  local method = ngx.var.request_method
  if method == 'OPTIONS' then
    return
  end

  -- bigdata appkey auth
  local appkey = ngx.var.arg_APPKEY
  if appkey == nil then
    local headers = ngx.req.get_headers()
    appkey = headers["APPKEY"]
  end
  if appkey ~= nil then
    return
  end

  access.execute(conf)
end


BasicAuthHandler.PRIORITY = 1001
BasicAuthHandler.VERSION = "2.0.0"


return BasicAuthHandler
