--
-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2019/5/8
-- Desc: api-offline
--

-- local BasePlugin = require "kong.plugins.base_plugin"
local cjson = require "cjson"

local APIOfflineHandler = {}

APIOfflineHandler.PRIORITY = 1088
APIOfflineHandler.VERSION = "2.0.0"

-- func for split string
--local str_split =  function(_str,_reps)
--  local res = {}
--  if type(_str) ~= nil then
--    string.gsub(_str,'[^'.._reps..']+',function (w) table.insert(res,w) end)
--  end
--  return res
--end

-- function APIOfflineHandler:new()
--   APIOfflineHandler.super.new(self, "openapi-api-offline")
-- end

function APIOfflineHandler:access(conf)
  -- APIOfflineHandler.super.access(self)
  --local all = conf.route_ids
  --local tt = str_split(all,',')
  --for i = 1, #tt do
  --  local route_id = ngx.ctx.route.id
  --  if route_id == tt[i] then
  --    ngx.status = 404
  --    ngx.say("api is offline!")
  --    ngx.exit(404)
  --  end
  --end
  ngx.status = 404
  ngx.say("api is offline!")
  ngx.exit(404)
end

return APIOfflineHandler
