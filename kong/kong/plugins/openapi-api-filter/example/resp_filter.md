-- 读取请求uri
local req_uri = ngx.var.uri
dev_log(req_uri)

-- 读取请求方法
local req_method = ngx.req.get_method()
dev_log(req_method)

-- 读取请求body(json格式-如果请求body非json格式 此值为空)
local req_json_body = ngx.ctx.req_json_body
dev_log(req_json_body)

-- 读取请求数据(string格式)
local req_body = ngx.req.get_body_data()
dev_log(req_body)

-- 读取请求参数
local req_uri_args = ngx.req.get_uri_args()
dev_log(req_uri_args)

-- 读取请求header
local req_headers = ngx.req.get_headers()
dev_log(cjson_encode(req_headers))


-- 读取响应body(json格式-如果响应非json格式此值为空)
local resp_json_body = ngx.ctx.resp_json_body
dev_log("resp_json_body: "..cjson_encode(resp_json_body))

--读取响应body(string格式)
local resp_body = ngx.ctx._resp_buffer
dev_log("resp_body: "..resp_body)


--读取响应header
local resp_headers = ngx.resp.get_headers()
dev_log("resp_headers: "..cjson_encode(resp_headers))

--读取响应状态码
local resp_status =ngx.var.upstream_status
dev_log(resp_status)

-- do some thing
-- do some thing

-- 设置并返回响应body
-- 注意：返回的body 需要string格式,lua的table需要调用cjson_encode函数转成string
-- local ret_body_str = "response body" 
local json_tmp = {}
json_tmp["code"] = 1
json_tmp["msg"] = "success"
local ret_body_str = cjson_encode(json_tmp)

-- 返回 修改后的响应body
return true, ret_body_str