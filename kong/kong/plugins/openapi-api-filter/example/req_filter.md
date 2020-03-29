-- 读取请求uri
local req_uri = ngx.var.uri
dev_log(req_uri)

-- 读取请求方法
local req_method = ngx.req.get_method()
dev_log(req_method)

-- 读取请求body(json格式-如果请求body非json格式此值为空)
local req_json_body = ngx.ctx.req_json_body
dev_log(cjson_encode(req_json_body))

-- 读取请求数据(string格式)
local req_body = ngx.req.get_body_data()
dev_log(req_body)

-- 读取请求参数
local req_uri_args = ngx.req.get_uri_args()
dev_log(req_uri_args)

-- 读取请求header
local req_headers = ngx.req.get_headers()
dev_log(cjson_encode(req_headers))

-- 添加请求头
ngx.req.set_header("add-header-key", "add-header-value")

-- 删除请求头
ngx.req.clear_header("host")


-- 添加请求参数
local tmp_args = ngx.req.get_uri_args()
tmp_args["bb"] = "123"
tmp_args["cc"] = "456"
ngx.req.set_uri_args(tmp_args)

-- 删除请求参数
local del_args_key = "bb"
local del_args = {}
for k, v in pairs(ngx.req.get_uri_args()) do
  if k ~= del_args_key then
    del_args[k] = v
  end
end
ngx.req.set_uri_args(del_args)

-- 修改请求body
local modify_body = '1234567890'
ngx.req.set_body_data(modify_body)


-- do some thing
-- do some thing

-- 返回值必须
return true, ""