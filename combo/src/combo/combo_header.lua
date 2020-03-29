-- Copyright 2018 demo Inc.
-- Author    : lijian@demo.com.cn
-- Describe  : concat static files

local _M = {
    _VERSION = "18.08.29",
}

_M.main = function()
    ngx.header["Content-Type"] = ngx.var.new_content_type
    ngx.header["Access-Control-Allow-Origin"] = "*"
    ngx.header["Timing-Allow-Origin"] = "*"
    ngx.header["Vary"] = "Accept-Encoding";
    ngx.header["Last-Modified"] = os.date("%a, %d %b %Y %X GMT");
end

_M.main()
