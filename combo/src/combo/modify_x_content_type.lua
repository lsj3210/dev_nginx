-- Copyright 2018 demo Inc.
-- Author    : lijian@demo.com.cn
-- Describe  : modify x.autoimg.cn content_type

local mimetypes = require "mime_types"

local _M = {
    _VERSION = "18.08.29",
}

_M.main =function() 
    local ctype = mimetypes.guess(ngx.var.uri)
    ngx.header["Content-Type"] = ctype
    ngx.header["Timing-Allow-Origin"] = "*";
    ngx.header["Vary"] = "Accept-Encoding";
    ngx.header["Last-Modified"] = os.date("%a, %d %b %Y %X GMT");
end

_M.main()

