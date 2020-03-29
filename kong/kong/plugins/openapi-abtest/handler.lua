-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2019/8/12
-- Desc: abtest plugin 
--
local kong = kong
local cjson = require "cjson"
local work = require "kong.plugins.openapi-abtest.worker"
local util = require "kong.plugins.openapi-abtest.utils"

local ABTestHandler = {}

ABTestHandler.PRIORITY = 10
ABTestHandler.VERSION = "2.0.0"


function ABTestHandler:access(conf)
    local c = cjson.encode(conf)
    kong.log.err(c)
    
    local run_urls = conf[util.STR_RUN_URLS]
    work.run(conf)
end


return ABTestHandler