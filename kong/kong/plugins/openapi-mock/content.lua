-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2019/9/3
-- Desc: abtest plugin 
--

local ngx   = ngx
local cjson = require "cjson"

local _M = {}

_M.mock_data = function(conf)
    local delay = tonumber(conf["delay"])
    local body  = conf["body"]
    local code  = tonumber(conf["code"])
    local headers = cjson.decode(conf["headers"])

    if delay > 0 then
      ngx.sleep(delay/1000)
    end

    for i = 1, #headers do
      local _key = headers[i].key
      local _value = headers[i].value
      ngx.header[_key] = _value
    end
    ngx.status = code
    ngx.say(body)
    return ngx.exit(code)
end

return _M