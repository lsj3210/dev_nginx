local tablex = require "pl.tablex"

local _M = {}

local EMPTY = tablex.readonly({})

function _M.get_int_part(x)
    if x<= 0 then
        return math.ceil(x)
    end
    if math.ceil(x) == x then
        x = math.ceil(x)
    else
        x = math.ceil(x)-1
    end
    return x
end

--  序列化日志格式 最全
function _M.serialize_all(ngx)
  local authenticated_entity
  if ngx.ctx.authenticated_credential ~= nil then
    authenticated_entity = {
      id = ngx.ctx.authenticated_credential.id,
      consumer_id = ngx.ctx.authenticated_credential.consumer_id
    }
  end

  return {
    request = {
      uri = ngx.var.request_uri,
      url = ngx.var.scheme .. "://" .. ngx.var.host .. ":" .. ngx.var.server_port .. ngx.var.request_uri,
      querystring = ngx.req.get_uri_args(), -- parameters, as a table
      method = ngx.req.get_method(), -- http method
      headers = ngx.req.get_headers(),
      size = ngx.var.request_length
    },
    upstream_uri = ngx.var.upstream_uri,
    response = {
      status = ngx.status,
      headers = ngx.resp.get_headers(),
      size = ngx.var.bytes_sent
    },
    tries = (ngx.ctx.balancer_address or EMPTY).tries,
    latencies = {
      kong = (ngx.ctx.KONG_ACCESS_TIME or 0) +
             (ngx.ctx.KONG_RECEIVE_TIME or 0) +
             (ngx.ctx.KONG_REWRITE_TIME or 0) +
             (ngx.ctx.KONG_BALANCER_TIME or 0),
      proxy = ngx.ctx.KONG_WAITING_TIME or -1,
      request = ngx.var.request_time * 1000
    },
    authenticated_entity = authenticated_entity,
    api = ngx.ctx.api,
    consumer = ngx.ctx.authenticated_consumer,
    client_ip = ngx.var.remote_addr,
    started_at = ngx.req.start_time() * 1000
  }
end

-- 序列化日志格式 nginx/scs
function _M.serialize_new(ngx)
  local all = {}

  local h8 = 8*60*60
  local tmp_date = os.date("%Y-%m-%dT%H:%M:%S",ngx.req.start_time())
  local tmp = ngx.req.start_time()
  local result = _M.get_int_part((tmp-_M.get_int_part(tmp))* 1000)
  table.insert(all, tmp_date.."."..result.."Z") --time
  table.insert(all, ngx.var.request_uri) --request_uri
  table.insert(all, ngx.status) --status
  table.insert(all, ngx.var.bytes_sent) -- byte_send
  table.insert(all, "-") --upstream_cache_status
  table.insert(all, ngx.var.request_time) --request_time
  local latencie_proxy = ngx.ctx.KONG_WAITING_TIME or 0
  table.insert(all, latencie_proxy * 0.001) --upstream_response_time
  table.insert(all, ngx.var.host) --host
  table.insert(all, ngx.var.remote_addr) --remote_addr
  table.insert(all, ngx.var.server_addr) --server_addr
  local upstream_addr = "-"
  if ngx.var.upstream_addr ~= nil and string.len(ngx.var.upstream_addr) ~= 0 then
      upstream_addr = ngx.var.upstream_addr
  end
  table.insert(all, upstream_addr) --upstream_addr
  local referer = "-"
  if ngx.var.http_referer ~= nil then
      referer = ngx.var.http_referer
  end
  table.insert(all, referer) --http_referer
  local ua = "-"
  if ngx.var.http_user_agent ~= nil then
    ua = ngx.var.http_user_agent
  end
  table.insert(all, ua) --http_user_agent
  local http_xff = "-"
  if ngx.var.http_x_forwarded_for ~= nil then
      http_xff = ngx.var.http_x_forwarded_for
  end
  table.insert(all, http_xff) --http_x_forwarded_for
  table.insert(all, "openapi") --type scs/nginx/openapi
  table.insert(all, "-") --cachezone
  table.insert(all, "-") --sent_http_cache_control
  table.insert(all, "-") --upstream_status
  table.insert(all, ngx.var.scheme) --scheme
  table.insert(all, ngx.var.request_method) --request_method
  local cname = "-"
  if ngx.ctx.authenticated_consumer ~= nil then
      cname = ngx.ctx.authenticated_consumer.username
  end
  table.insert(all, cname) --consumer name
  local lapi = "-"
  if ngx.ctx.api ~= nil and ngx.ctx.api.name ~= nil then
      lapi = ngx.ctx.api.name
  end
  --ngx.log(ngx.ERR,lapi)
  table.insert(all, lapi) --api name
  local lservice = "-"
  if ngx.ctx.service ~= nil and ngx.ctx.service.name ~= nil  then
      lservice = ngx.ctx.service.name
  end
  table.insert(all, lservice) --service name
  local lroute = "-"
  if ngx.ctx.route ~= nil and ngx.ctx.route.id ~= "" then
      lroute = ngx.ctx.route.id
  end
  table.insert(all, lroute) -- route name

  --local cjson = require "cjson"
  --ngx.log(ngx.ERR,cjson.encode(ngx.ctx.api))

  return table.concat(all, "\t")
end

-- 序列化日志格式 部分
function _M.serialize_part(ngx)
  local cname = ""
  if ngx.ctx.authenticated_consumer ~= nil then
      cname = ngx.ctx.authenticated_consumer.username
  end
 
  local lapi = ""
  if ngx.ctx.api ~= nil then
      lapi = ngx.ctx.api.name
  end 
  
  local h8 = 8*60*60
  local tmp_date = os.date("%Y-%m-%dT%H:%M:%SZ",ngx.req.start_time()-h8)
 
  return {
    date = tmp_date,
    --timestrap = ngx.req.start_time() * 1000,
    timestrap = ngx.req.start_time(),
    request_host = ngx.var.host,
    request_url = ngx.var.scheme .. "://" .. ngx.var.host .. ":" .. ngx.var.server_port .. ngx.var.request_uri,
    request_query = ngx.req.get_uri_args(),
    request_method = ngx.req.get_method(),
    request_size = ngx.var.request_length,
    --request_header = ngx.req.get_headers(),
    response_status = ngx.status,
    response_size = ngx.var.bytes_sent,
    remote_addr = ngx.var.remote_addr,
    upstream_addr = ngx.var.upstream_addr,
    server_addr = ngx.var.server_addr,
    consumer = cname,
    api_name = lapi,
    upstream_uri = ngx.var.upstream_uri,
    latencie_kong = (ngx.ctx.KONG_ACCESS_TIME or 0) + 
                    (ngx.ctx.KONG_RECEIVE_TIME or 0) + 
                    (ngx.ctx.KONG_REWRITE_TIME or 0) + 
                    (ngx.ctx.KONG_BALANCER_TIME or 0),
    latencie_proxy = ngx.ctx.KONG_WAITING_TIME or -1,
    latencie_request = ngx.var.request_time * 1000
  }
end



-- 序列化日志格式 错误日志专用
function _M.serialize_error(ngx)
  local cname = ""
  if ngx.ctx.authenticated_consumer ~= nil then
      cname = ngx.ctx.authenticated_consumer.username
  end
 
  local lapi = ""
  if ngx.ctx.api ~= nil then
      lapi = ngx.ctx.api.name
  end 
  
  local tmp_date = os.date("%Y-%m-%d %H:%M:%S",ngx.req.start_time())
 
  return {
    date = tmp_date,
    request_url = ngx.var.scheme .. "://" .. ngx.var.host .. ":" .. ngx.var.server_port .. ngx.var.request_uri,
    status = ngx.status,
    upstream_addr = ngx.var.upstream_addr,
    server_addr = ngx.var.server_addr,
    consumer = cname,
    api_name = lapi
  }
end

return _M
