-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2019/9/16
-- Desc: api-filter plugin 
--

local MODE_TYPE = {
  "filter",
  "rewrite",
}

return {
  no_consumer = true,
  fields = {
    mode_type = { type = "string", default = "filter", },
    req_filter_str = { type = "string" },
    resp_filter_str = { type = "string" },
    content_rewrite_str = { type = "string" },
  },
}