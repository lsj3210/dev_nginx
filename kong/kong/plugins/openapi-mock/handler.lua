-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2019/9/3
-- Desc: abtest plugin 
--

local ngx   = ngx
local cjson = require "cjson"


local MockHandler = {}

MockHandler.PRIORITY = 949
MockHandler.VERSION = "2.0.0"


function MockHandler:access(conf)
    ngx.var.mock="true"
    ngx.header["By-Mock"]=ngx.var.mock

    local execonf = {
        delay = conf["mock"]["delay"],
        body  = conf["mock"]["body"],
        code  = conf["mock"]["code"],
        headers = cjson.encode(conf["mock"]["headers"]),
    }

    ngx.status = 200
    local jump_url = '/openapi/mock'
    Kong = require 'kong'
    Kong.customLog()
    return ngx.exec(jump_url, execonf) 
end

return MockHandler