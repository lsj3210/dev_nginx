-- local BasePlugin = require "kong.plugins.base_plugin"
local basic_serializer = require "kong.plugins.openapi-log.custom-basic"
local cjson = require "cjson"

local OpenApiLogHandler = {}

OpenApiLogHandler.PRIORITY = 17
OpenApiLogHandler.VERSION = "2.0.0"

local function log(premature, conf, message)

  -- ngx.log(ngx.CRIT, '-----------------log')

  if premature then
    return
  end

  local ok, err
  local host = conf.host
  local port = conf.port
  local timeout = conf.timeout
  local keepalive = conf.keepalive

  local sock = ngx.socket.tcp()
  sock:settimeout(timeout)

  ok, err = sock:connect(host, port)
  if not ok then
    ngx.log(ngx.ERR, "[tcp-log] failed to connect to " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end

  if conf.tls then
    ok, err = sock:sslhandshake(true, conf.tls_sni, false)
    if not ok then
      ngx.log(ngx.ERR, "[tcp-log] failed to perform TLS handshake to ",
                       host, ":", port, ": ", err)
      return
    end
  end

  ok, err = sock:send(cjson.encode(message) .. "\r\n")
  if not ok then
    ngx.log(ngx.ERR, "[tcp-log] failed to send data to " .. host .. ":" .. tostring(port) .. ": ", err)
  end

  ok, err = sock:setkeepalive(keepalive)
  if not ok then
    ngx.log(ngx.ERR, "[tcp-log] failed to keepalive to " .. host .. ":" .. tostring(port) .. ": ", err)
    return
  end
end

-- func lijian add for get appname and teamid and cluster_id
function get_appname_and_teamid_and_clusterid(_name)
    local str_split = "__"
    local app_name, team_id,cluster_id = nil,nil,nil
    local p_app = string.find(_name,str_split)
    if p_app ~= nil then
        app_name = string.sub(_name,1,p_app-1)
        local sub_team = string.sub(_name,p_app+#str_split,#_name)
        local p_team = string.find(sub_team,str_split)
        if p_team ~= nil then
            team_id = string.sub(sub_team,1,p_team-1)
            local sub_cluster = string.sub(sub_team,p_team+#str_split,#sub_team)
            local p_cluster = string.find(sub_cluster,str_split)
            if p_cluster ~= nil then
              cluster_id = string.sub(sub_cluster,1,p_cluster-1)
            end
        end
    end
    return app_name,team_id,cluster_id
end

function OpenApiLogHandler:log(conf)
  -- get log message
  local message = basic_serializer.serialize(ngx)
  -- get team_id and app_name and cluster_id
  local service = message["service"]
  if service ~= nil then
    local service_name = service["name"]
    local app_name,team_id,cluster_id = get_appname_and_teamid_and_clusterid(service_name)
    -- app name
    if app_name ~= nil then
      message["app_name"] = app_name
    end
    -- team id
    if team_id ~= nil then
      message["team_id"] = team_id
    end
    -- cluster id
    if cluster_id ~= nil then
      message["cluster_id"] = cluster_id
    end
  end
  -- upstream addr
  if ngx.var.upstream_addr ~= nil and string.len(ngx.var.upstream_addr) ~= 0 then
      message["upstream_addr"] = ngx.var.upstream_addr
  end
  
  -- send log message
  --ngx.log(ngx.ERR,cjson.encode(message))
  local ok, err = ngx.timer.at(0, log, conf, message)
  if not ok then
    ngx.log(ngx.ERR, "[tcp-log] failed to create timer: ", err)
  end
end

return OpenApiLogHandler
