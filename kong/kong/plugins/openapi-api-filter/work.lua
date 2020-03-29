-- Created by Lijian.
-- User: Lijian <lijian@demo.com.cn>
-- Date: 2019/9/18
-- Desc: api-filter plugin 
--

local ngx   = ngx
local kong  = kong
local utils = require("kong.plugins.openapi-api-filter.utils")
local cjson_decode = require("cjson.safe").decode
local cjson_encode = require("cjson.safe").encode

local _M = {}

_M.get_env = function()
    return {
      ngx = {
        ctx = ngx.ctx,
        var = ngx.var,
        null = ngx.null,
        req = {
            get_headers   =  ngx.req.get_headers,
            set_header    =  ngx.req.set_header,
            clear_header  =  ngx.req.clear_header,
            get_method    =  ngx.req.get_method,
            get_body_data =  ngx.req.get_body_data,
            set_body_data =  ngx.req.set_body_data,
            get_uri_args  =  ngx.req.get_uri_args,
            set_uri_args  =  ngx.req.set_uri_args,
        },
        resp = {
          get_headers = ngx.resp.get_headers,
        }
      }
    }
end

_M.content = function(conf)
    -- kong.log.err("rewrite conf: "..cjson_encode(conf))

    -- reset args
    local argstr = conf["args"]
    ngx.req.set_uri_args(cjson_decode(argstr))

    ngx.req.read_body()
    local s, req_json_body = pcall(function() return cjson_decode(ngx.req.get_body_data()) end)
    if not s then
        req_json_body = nil
    end
    ngx.ctx.req_json_body = req_json_body

    local status_, do_func = utils.func_load(conf.exec_str, _M.get_env())
    if not status_ then
      return kong.response.exit(500, do_func)
    end

    local p_status, f_code, f_body_or_err  = utils.func_exec(do_func)
    if not p_status then
      return kong.response.exit(500, "执行错误，请检查lua脚本.")
    end

    if type(f_body_or_err) ~= "string"  or type(f_code) ~= "number" then
      return kong.response.exit(500, "返回值错误，请检查lua脚本.")
    end

    -- _M.dev_print_req_info()

    ngx.status = f_code
    ngx.say(f_body_or_err)
    return ngx.exit(f_code)
end

_M.access = function(conf)

    ngx.req.read_body()
    local s, req_json_body = pcall(function() return cjson_decode(ngx.req.get_body_data()) end)
    if not s then
        req_json_body = nil
    end

    ngx.ctx._parsing_error_in_access_phase = false
    ngx.ctx.req_uri = ngx.var.uri
    ngx.ctx.req_headers = ngx.req.get_headers()
    ngx.ctx.req_uri_args = ngx.req.get_uri_args()
    ngx.ctx.req_method = ngx.req.get_method()
    ngx.ctx.req_json_body = req_json_body

    local l_status, do_func  = utils.func_load(conf.req_filter_str, _M.get_env())
    if not l_status then
      ngx.ctx._parsing_error_in_access_phase = true
      return kong.response.exit(500, do_func)
    end
  
    local p_status, f_status, req_body_or_err  = utils.func_exec(do_func)
  
    if not p_status then
      ngx.ctx._parsing_error_in_access_phase = true
      return kong.response.exit(500, "执行错误, 请检查lua脚本。")
    end
  
    if not f_status then
      ngx.ctx._parsing_error_in_access_phase = true
      return kong.response.exit(500, req_body_or_err)
    end
  
    if type(req_body_or_err) ~= "string" then
      ngx.ctx._parsing_error_in_access_phase = true
      return kong.response.exit(500, "未知错误。")
    end
  
    if string.len(req_body_or_err) > 0 then
      ngx.req.set_body_data(req_body_or_err)
      ngx.req.set_header(CONTENT_LENGTH, #req_body_or_err)
    end
end

_M.body_filter = function(conf)
  if ngx.ctx._parsing_error_in_access_phase then
    ngx.arg[1] = ""
    return
  end

  local chunk, eof = ngx.arg[1], ngx.arg[2]

  if not eof then
    if ngx.ctx._resp_buffer and chunk then
      ngx.ctx._resp_buffer = ngx.ctx._resp_buffer .. chunk
    end
    ngx.arg[1] = nil

  else
    -- body is fully read
    local raw_body = ngx.ctx._resp_buffer
    if raw_body == nil then
      return ngx.ERROR
    end
    ngx.ctx.resp_json_body = cjson_decode(raw_body)

    local l_status, do_func  = utils.func_load(conf.resp_filter_str, _M.get_env())
    if not l_status then
      ngx.ctx._parsing_error_in_access_phase = true
      return kong.response.exit(500, do_func)
    end

    local p_status, f_status, resp_body_or_err  = utils.func_exec(do_func)

    local resp_body = {
      data = {},
      error = {code = -1, message = ""}
    }

    if (not p_status) or (type(resp_body_or_err) ~= "string") then
      if true then
        resp_body.error.code = 500
        resp_body.error.message = "执行错误, 请检查lua脚本。"
        ngx.arg[1] = cjson_encode(resp_body)
      else
        ngx.arg[1] = ""
        return kong.response.exit(500, "执行错误, 请检查lua脚本。")
      end
    elseif not f_status then
      if true then
        resp_body.error.code = 500
        resp_body.error.message = resp_body_or_err
        ngx.arg[1] = cjson_encode(resp_body)
      else
        ngx.arg[1] = ""
        return kong.response.exit(500, resp_body_or_err)
      end
    else
      ngx.arg[1] = resp_body_or_err
    end

  end
end

_M.header_filter = function(conf)
  if ngx.ctx._parsing_error_in_access_phase then
    return
  end
  ngx.header["content-length"] = nil
  if true then
    ngx.status = 200
  end
end

_M.dev_print_req_info = function()
    local req_uri = ngx.var.uri
    kong.log.err("req_uri: "..req_uri)

    local req_method = ngx.req.get_method()
    kong.log.err("req_method: "..req_method)

    local req_body = ngx.req.get_body_data()
    kong.log.err("req_body: "..req_body)

    local req_uri_args = ngx.req.get_uri_args()
    kong.log.err("req_uri_args: "..cjson.encode(req_uri_args))

    local req_headers = ngx.req.get_headers()
    kong.log.err("req_headers: "..cjson.encode(req_headers))
end

return _M