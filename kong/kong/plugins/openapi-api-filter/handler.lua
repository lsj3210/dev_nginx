-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2019/9/16
-- Desc: api-filter plugin 
--

local kong = kong
local cjson_encode = require("cjson").encode
local work = require("kong.plugins.openapi-api-filter.work")


local APIFilterHandler = {}

APIFilterHandler.PRIORITY = 801
APIFilterHandler.VERSION = "2.0.0"


function APIFilterHandler:access(conf)
    if conf.mode_type == "rewrite" then
      -- 1. content rewrite
      local execonf = {}
      execonf["exec_str"] = conf.content_rewrite_str
      execonf["args"] = cjson_encode(ngx.req.get_uri_args())
      execonf["route_id"] = kong.router.get_route().id
      local jump_url = '/openapi/api-filter'
      return ngx.exec(jump_url, execonf) 
    elseif conf.mode_type == "filter" then
      -- 2. request filter (modify req info)
      ngx.ctx._resp_buffer = ''
      if conf.req_filter_str == nil or conf.req_filter_str == "" then
        return
      else
        work.access(conf)
      end
    end
end

function APIFilterHandler:body_filter(conf)
  if (conf.mode_type == "filter") and (conf.resp_filter_str ~= nil) and (conf.resp_filter_str ~= "") then 
    work.body_filter(conf)
  else
    return
  end
end

function APIFilterHandler:header_filter(conf)
  if conf.mode_type == "filter" then
    work.header_filter(conf)
  end
end

return APIFilterHandler