-- local BasePlugin = require "kong.plugins.base_plugin"

local cjson = require "cjson"

local cjson_decode = require("cjson").decode
local cjson_encode = require("cjson").encode
local body_filter = require "kong.plugins.response-transformer.body_transformer"
local header_filter = require "kong.plugins.response-transformer.header_transformer"
local is_body_transform_set = header_filter.is_body_transform_set
local is_json_body = header_filter.is_json_body
local http = require "resty.http"
local open_api_cache = require "kong.openapi.Cache"

local utils = require "kong.openapi.Utils"
-- Your plugin handler's constructor. If you are extending the
-- Base Plugin handler, it's only role is to instanciate itself
-- with a name. The name is your plugin name as it will be printed in the logs.


local FaultHandler = {}

FaultHandler.PRIORITY = 9998
FaultHandler.VERSION = "2.0.0"


function FaultHandler:access(config)
  -- Eventually, execute the parent implementation
  -- (will log that your plugin is entering this context)
  ngx.var.fault_enabled="true"
  ngx.var.fault_bottomJson= config.bottomJson
  ngx.var.fault_strategy= config.strategy
end


return FaultHandler